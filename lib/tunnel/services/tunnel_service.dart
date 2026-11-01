import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher_string.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as path;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../models/log_entry.dart';
import '../models/tunnel_config.dart';
import 'background_tunnel_handler.dart';

/// Connection state of the tunnel service.
enum TunnelConnectionState { disconnected, connecting, connected, error }

/// Core service that manages:
///  1. A WebSocket connection to the relay server
///  2. Local TCP servers (one per enabled tunnel) listening on localPort
///  3. Bridging local TCP sockets ↔ relay WebSocket channels
class TunnelService extends ChangeNotifier {
  static TunnelService? _instance;
  static TunnelService? get instance => _instance;

  // ── State ──────────────────────────────────────────────────────────────────
  TunnelConnectionState _state = TunnelConnectionState.disconnected;
  TunnelConnectionState get state => _state;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  bool get isConnected => _state == TunnelConnectionState.connected;

  // ── Tunnels ────────────────────────────────────────────────────────────────
  final List<TunnelConfig> _tunnels = [];
  List<TunnelConfig> get tunnels => List.unmodifiable(_tunnels);

  /// Active local TCP servers: tunnelId → ServerSocket
  final Map<String, ServerSocket> _servers = {};

  /// Active forwarding channels: channelId → local Socket
  final Map<String, Socket> _localSockets = {};

  /// Pending channels waiting for relay 'opened' confirmation
  final Set<String> _pendingChannels = {};

  // ── File Explorer State ────────────────────────────────────────────────────
  final Map<String, Completer<List<Map<String, dynamic>>>> _fileListCompleters = {};
  final Map<String, _ActiveFileDownload> _activeDownloads = {};
  final Map<String, Completer<void>> _activeUploadCompleters = {};
  final Map<String, Completer<bool>> _fileActionCompleters = {};

  // ── Device/Printer Explorer State ──────────────────────────────────────────
  final Map<String, Completer<Map<String, dynamic>>> _deviceListCompleters = {};
  final Map<String, Completer<void>> _printJobCompleters = {};
  final Map<String, void Function(double progress, int currentPage, int totalPages, String status)> _printProgressCallbacks = {};

  // ── Terminal Shell State ────────────────────────────────────────────────────
  final Map<String, Completer<Map<String, dynamic>>> _terminalCommandCompleters = {};

  // ── USB Control State ───────────────────────────────────────────────────────
  final Map<String, Completer<bool>> _usbEjectCompleters = {};
  final Map<String, Completer<bool>> _usbShareCompleters = {};
  final Map<String, Completer<bool>> _usbUnshareCompleters = {};
  final Map<String, Completer<bool>> _usbBindCompleters = {};
  final Map<String, Completer<bool>> _usbUnbindCompleters = {};
  final Map<String, Completer<bool>> _installRemoteUsbipCompleters = {};
  final Map<String, Completer<bool>> _rdpConfigureCompleters = {};
  final Map<String, Completer<List<Map<String, dynamic>>>> _rdpSessionsCompleters = {};
  final Map<String, Completer<bool>> _rdpWrapperStatusCompleters = {};
  final Map<String, Completer<bool>> _rdpWrapperInstallCompleters = {};
  final Map<String, Completer<Map<String, dynamic>>> _networkScanCompleters = {};


  // ── USBIP State ────────────────────────────────────────────────────────────
  bool _usbipdMissing = false;
  bool get usbipdMissing => _usbipdMissing;

  // ── Temporary Attach State (Phase 1 fix + Phase 2) ─────────────────────────
  final Map<String, String> _attachedDevices = {};       // busId → port (Dart-side tracking)
  final Map<String, bool> _temporarilyAttached = {};     // busId → isTemporary
  final Map<String, Timer> _autoDetachTimers = {};       // busId → 30s timer
  Timer? _keepAliveTimer;

  bool isDeviceAttached(String busId) => _attachedDevices.containsKey(busId);
  String? getAttachedPort(String busId) => _attachedDevices[busId];
  bool isTemporarilyAttached(String busId) => _temporarilyAttached[busId] == true;

  // ── Stats ──────────────────────────────────────────────────────────────────
  int _bytesIn = 0;
  int _bytesOut = 0;
  int get bytesIn => _bytesIn;
  int get bytesOut => _bytesOut;
  int get activeChannels => _localSockets.length;

  String? _requestedBrowsePath;
  String? get requestedBrowsePath => _requestedBrowsePath;
  set requestedBrowsePath(String? value) {
    _requestedBrowsePath = value;
    notifyListeners();
  }

  // ── Logs ───────────────────────────────────────────────────────────────────
  final List<LogEntry> _logs = [];
  List<LogEntry> get logs => List.unmodifiable(_logs);

  // ── WebSocket ──────────────────────────────────────────────────────────────
  WebSocketChannel? _ws;
  StreamSubscription? _wsSub;
  bool _peerConnected = false;
  bool get peerConnected => _peerConnected;

  // ── Auto-reconnect ─────────────────────────────────────────────────────────
  String? _lastRelayUrl;
  String? _lastToken;
  bool _autoReconnect = true;
  bool get autoReconnect => _autoReconnect;
  void setAutoReconnect(bool v) => _autoReconnect = v;

  static const _uuid = Uuid();

  // ── Constructor ────────────────────────────────────────────────────────────
  TunnelService() {
    _instance = this;
    if (!kIsWeb && Platform.isAndroid) {
      _initForegroundTask();
      FlutterForegroundTask.addTaskDataCallback(_onReceiveTaskData);
    }
  }

  void _initForegroundTask() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'foreground_service',
        channelName: 'Foreground Service Notification',
        channelDescription: 'This notification appears when the foreground service is running.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(5000),
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  void _onReceiveTaskData(Object data) {
    if (data is Map<String, dynamic>) {
      final type = data['type'] as String?;
      switch (type) {
        case 'state':
          final val = data['value'] as String;
          final err = data['error'] as String?;
          if (val == 'connected') {
            _setState(TunnelConnectionState.connected);
          } else if (val == 'connecting') {
            _setState(TunnelConnectionState.connecting);
          } else if (val == 'disconnected') {
            _setState(TunnelConnectionState.disconnected);
          } else if (val == 'error') {
            _setState(TunnelConnectionState.error, error: err);
          }
        case 'log':
          final lvlStr = data['level'] as String;
          final msg = data['message'] as String;
          LogLevel level = LogLevel.info;
          if (lvlStr == 'success') level = LogLevel.success;
          if (lvlStr == 'warning') level = LogLevel.warning;
          if (lvlStr == 'error') level = LogLevel.error;
          if (lvlStr == 'debug') level = LogLevel.debug;
          _log(level, msg);
        case 'stats':
          _bytesIn = data['bytesIn'] as int;
          _bytesOut = data['bytesOut'] as int;
          _peerConnected = data['peerConnected'] as bool;
          notifyListeners();
        case 'file_explorer_response':
          final responseData = data['data'] as Map<String, dynamic>;
          _handleTextMessage(jsonEncode(responseData));
      }
    }
  }

  void _syncTunnelsToTask() {
    if (Platform.isAndroid && isConnected) {
      FlutterForegroundTask.sendDataToTask({
        'action': 'updateTunnels',
        'tunnels': _tunnels.map((t) => t.toJson()).toList(),
      });
    }
  }

  // ── Wire protocol constants ────────────────────────────────────────────────
  static const int _dataFrameType = 0x01;
  static const int _headerLength = 37;

  // ── Public API ─────────────────────────────────────────────────────────────

  void setTunnels(List<TunnelConfig> tunnels) {
    _tunnels
      ..clear()
      ..addAll(tunnels);
    notifyListeners();
    _syncTunnelsToTask();
  }

  void addTunnel(TunnelConfig config) {
    _tunnels.add(config);
    notifyListeners();
    if (isConnected && config.enabled) {
      if (!Platform.isAndroid) {
        _startTunnelListener(config);
      }
    }
    _syncTunnelsToTask();
  }

  void updateTunnel(TunnelConfig config) {
    final idx = _tunnels.indexWhere((t) => t.id == config.id);
    if (idx == -1) return;

    // Stop old listener if running
    if (!Platform.isAndroid) {
      _stopTunnelListener(config.id);
    }
    _tunnels[idx] = config;
    notifyListeners();

    if (isConnected && config.enabled) {
      if (!Platform.isAndroid) {
        _startTunnelListener(config);
      }
    }
    _syncTunnelsToTask();
  }

  void removeTunnel(String id) {
    if (!Platform.isAndroid) {
      _stopTunnelListener(id);
    }
    _tunnels.removeWhere((t) => t.id == id);
    notifyListeners();
    _syncTunnelsToTask();
  }

  /// Connect to the relay server and start all enabled tunnel listeners.
  Future<void> connect(String relayUrl, String token) async {
    if (kIsWeb) return;
    if (_state == TunnelConnectionState.connecting ||
        _state == TunnelConnectionState.connected) {
      return;
    }

    _setState(TunnelConnectionState.connecting);
    _lastRelayUrl = relayUrl.trim();
    _lastToken = token;

    final clientId = await _getClientId('medinfect');

    if (Platform.isAndroid) {
      final hasPermission = await FlutterForegroundTask.checkNotificationPermission();
      if (hasPermission != NotificationPermission.granted) {
        await FlutterForegroundTask.requestNotificationPermission();
      }

      final started = await FlutterForegroundTask.startService(
        notificationTitle: 'TCP Tunnel Active',
        notificationText: 'Tunnel is connected and running',
        callback: startBackgroundTunnelCallback,
        serviceTypes: [ForegroundServiceTypes.dataSync],
      );
      if (started is ServiceRequestSuccess) {
        FlutterForegroundTask.sendDataToTask({
          'action': 'connect',
          'relayUrl': relayUrl,
          'token': token,
          'clientId': clientId,
          'tunnels': _tunnels.map((t) => t.toJson()).toList(),
        });
      } else {
        _log(LogLevel.error, 'Failed to start Android foreground service');
        _setState(TunnelConnectionState.error, error: 'Foreground service failed to start');
      }
      return;
    }

    var normalizedUrl = relayUrl.trim();
    if (!normalizedUrl.startsWith('ws://') && !normalizedUrl.startsWith('wss://')) {
      if (normalizedUrl.startsWith('http://') || normalizedUrl.startsWith('https://')) {
        normalizedUrl = normalizedUrl.replaceFirst('http', 'ws');
      } else {
        normalizedUrl = 'wss://$normalizedUrl';
      }
    }

    _log(LogLevel.info, 'Connecting to relay at $normalizedUrl...');

    try {
      _ws = IOWebSocketChannel.connect(
        Uri.parse(normalizedUrl),
        pingInterval: const Duration(seconds: 20),
      );

      // Send auth
      _send(jsonEncode({
        'type': 'auth',
        'token': token,
        'role': 'client',
        'clientId': clientId,
      }));
      _log(LogLevel.info, 'Auth message sent');

      _wsSub = _ws!.stream.listen(
        _handleMessage,
        onError: (Object err) {
          _log(LogLevel.error, 'WebSocket error: $err');
          _onDisconnected(err.toString());
        },
        onDone: () {
          _log(LogLevel.warning, 'Relay connection closed');
          _onDisconnected(null);
        },
        cancelOnError: true,
      );

    } catch (e) {
      _log(LogLevel.error, 'Failed to connect: $e');
      _setState(TunnelConnectionState.error, error: e.toString());
    }
  }

  Future<String> _getClientId(String appName) async {
    final prefs = await SharedPreferences.getInstance();
    String? clientId = prefs.getString('tcp_tunnel_client_id');
    if (clientId == null) {
      String deviceName = 'unknown';
      try {
        if (kIsWeb) {
          deviceName = 'web_client';
        } else {
          final deviceInfo = DeviceInfoPlugin();
          if (Platform.isAndroid) {
            final androidInfo = await deviceInfo.androidInfo;
            deviceName = '${androidInfo.brand}_${androidInfo.model}';
          } else if (Platform.isWindows) {
            final windowsInfo = await deviceInfo.windowsInfo;
            deviceName = windowsInfo.computerName;
          } else if (Platform.isMacOS) {
            final macInfo = await deviceInfo.macOsInfo;
            deviceName = macInfo.computerName;
          } else if (Platform.isLinux) {
            final linuxInfo = await deviceInfo.linuxInfo;
            deviceName = linuxInfo.name;
          } else {
            deviceName = Platform.localHostname;
          }
        }
      } catch (e) {
        deviceName = kIsWeb ? 'web_client' : (Platform.localHostname);
      }
      deviceName = deviceName.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
      final shortUuid = const Uuid().v4().substring(0, 8);
      clientId = '${appName}_${deviceName}_$shortUuid';
      await prefs.setString('tcp_tunnel_client_id', clientId);
    }
    return clientId;
  }

  /// Disconnect from the relay and stop all tunnel listeners.
  Future<void> disconnect() async {
    _log(LogLevel.info, 'Disconnecting...');
    _lastRelayUrl = null; // Clear credentials to suppress auto-reconnect
    _lastToken = null;
    if (Platform.isAndroid) {
      FlutterForegroundTask.sendDataToTask({'action': 'disconnect'});
      await FlutterForegroundTask.stopService();
      _setState(TunnelConnectionState.disconnected);
    } else {
      await _cleanup();
      _setState(TunnelConnectionState.disconnected);
    }
    _log(LogLevel.info, 'Disconnected');
  }

  // ── Message handling ───────────────────────────────────────────────────────

  void _handleMessage(dynamic data) {
    if (data is String) {
      _handleTextMessage(data);
    } else {
      final bytes = data is Uint8List ? data : Uint8List.fromList(data as List<int>);
      if (bytes.isNotEmpty && bytes[0] == _dataFrameType && bytes.length >= _headerLength) {
        _handleDataFrame(bytes);
      }
    }
  }

  void _handleTextMessage(String text) {
    Map<String, dynamic> msg;
    try {
      msg = jsonDecode(text) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    final type = msg['type'] as String?;
    switch (type) {
      case 'auth_ok':
        _log(LogLevel.success, 'Authenticated with relay ✓');
        if (msg.containsKey('peerConnected') || msg.containsKey('peer_online')) {
          _peerConnected = (msg['peerConnected'] ?? msg['peer_online']) == true;
        }
        _setState(TunnelConnectionState.connected);
        _startAllTunnelListeners();
        if (Platform.isAndroid) {
          FlutterForegroundTask.updateService(
            notificationTitle: 'TCP Tunnel Active',
            notificationText: 'Tunnel is connected and running',
          ).then((_) {}).catchError((e) {
            _log(LogLevel.warning, 'Failed to update foreground service: $e');
          });
        }
        _keepAliveTimer?.cancel();
        _keepAliveTimer = Timer.periodic(const Duration(seconds: 30), (_) {
          _send(jsonEncode({'type': 'ping'}));
        });

      case 'auth_error':
        _log(LogLevel.error, 'Authentication failed: ${msg['message']}');
        _setState(TunnelConnectionState.error, error: msg['message'] as String?);

      case 'peer_connected':
        _peerConnected = true;
        _log(LogLevel.success, 'Work agent is online — tunnel fully active ✓');
        notifyListeners();

      case 'peer_disconnected':
        _peerConnected = false;
        _log(LogLevel.warning, 'Work agent disconnected');
        notifyListeners();

      case 'opened':
        final channelId = msg['channelId'] as String;
        _pendingChannels.remove(channelId);
        _log(LogLevel.debug, 'Channel $channelId opened');

      case 'close':
        final channelId = msg['channelId'] as String;
        _closeLocalSocket(channelId);

      case 'error':
        final channelId = msg['channelId'] as String;
        _log(LogLevel.error, 'Channel error: ${msg['message']}');
        _closeLocalSocket(channelId);

      case 'ping':
        _send(jsonEncode({'type': 'pong'}));

      case 'file_list_response':
        final requestId = msg['requestId'] as String;
        final success = msg['success'] as bool;
        final error = msg['error'] as String?;
        final items = List<Map<String, dynamic>>.from(msg['items'] as List? ?? []);
        final completer = _fileListCompleters.remove(requestId);
        if (completer != null) {
          if (success) {
            completer.complete(items);
          } else {
            completer.completeError(Exception(error ?? 'Failed to list files'));
          }
        }

      case 'file_download_chunk':
        final requestId = msg['requestId'] as String;
        final base64Data = msg['data'] as String;
        final isLast = msg['isLast'] as bool;
        final download = _activeDownloads[requestId];
        if (download != null) {
          try {
            final bytes = base64Decode(base64Data);
            download.sink.add(bytes);
            download.bytesReceived += bytes.length;
            if (download.onProgress != null) {
              download.onProgress!(download.bytesReceived.toDouble());
            }
            if (isLast) {
              _activeDownloads.remove(requestId);
              download.sink.close().then((_) {
                download.completer.complete();
              });
            }
          } catch (e) {
            _activeDownloads.remove(requestId);
            download.sink.close().then((_) {
              download.completer.completeError(e);
            });
          }
        }

      case 'file_upload_chunk':
        // Handle file upload chunk sent from peer to this agent
        _handleIncomingFileUploadChunk(msg);

      case 'print_job_request':
        // Handle remote print request sent from peer to this agent
        _handleIncomingPrintJobRequest(msg);

      case 'device_list_request':
        // Handle device list request sent from peer to this agent
        _handleIncomingDeviceListRequest(msg);

      case 'file_upload_response':
        final requestId = msg['requestId'] as String;
        final success = msg['success'] as bool;
        final error = msg['error'] as String?;
        final uploadCompleter = _activeUploadCompleters.remove(requestId);
        if (uploadCompleter != null) {
          if (success) {
            uploadCompleter.complete();
          } else {
            uploadCompleter.completeError(Exception(error ?? 'Upload failed'));
          }
        }
        final actionCompleter = _fileActionCompleters.remove(requestId);
        if (actionCompleter != null) {
          actionCompleter.complete(success);
        }

      case 'file_error':
        final requestId = msg['requestId'] as String;
        final message = msg['message'] as String;
        final download = _activeDownloads.remove(requestId);
        if (download != null) {
          download.sink.close().then((_) {
            download.completer.completeError(Exception(message));
          });
        }
        final uploadCompleter = _activeUploadCompleters.remove(requestId);
        if (uploadCompleter != null) {
          uploadCompleter.completeError(Exception(message));
        }
        final fileListCompleter = _fileListCompleters.remove(requestId);
        if (fileListCompleter != null) {
          fileListCompleter.completeError(Exception(message));
        }
        final deviceListCompleter = _deviceListCompleters.remove(requestId);
        if (deviceListCompleter != null) {
          deviceListCompleter.completeError(Exception(message));
        }
        final printJobCompleter = _printJobCompleters.remove(requestId);
        if (printJobCompleter != null) {
          printJobCompleter.completeError(Exception(message));
        }
        final terminalCommandCompleter = _terminalCommandCompleters.remove(requestId);
        if (terminalCommandCompleter != null) {
          terminalCommandCompleter.completeError(Exception(message));
        }

      case 'device_list_response':
        final requestId = msg['requestId'] as String;
        final success = msg['success'] as bool;
        final error = msg['error'] as String?;
        final usbDevices = List<Map<String, dynamic>>.from(msg['usbDevices'] as List? ?? []);
        final printers = List<Map<String, dynamic>>.from(msg['printers'] as List? ?? []);
        final comPorts = List<Map<String, dynamic>>.from(msg['comPorts'] as List? ?? []);
        _usbipdMissing = msg['usbipdMissing'] as bool? ?? false;
        notifyListeners();
        final completer = _deviceListCompleters.remove(requestId);
        if (completer != null) {
          if (success) {
            completer.complete({
              'usbDevices': usbDevices,
              'printers': printers,
              'comPorts': comPorts,
              'usbipdMissing': _usbipdMissing,
              'rdpStatus': msg['rdpStatus'],
            });
          } else {
            completer.completeError(Exception(error ?? 'Failed to list devices'));
          }
        }

      case 'rdp_sessions_response':
        final requestId = msg['requestId'] as String;
        final success = msg['success'] as bool;
        final sessions = List<Map<String, dynamic>>.from(msg['sessions'] as List? ?? []);
        final error = msg['error'] as String?;
        final rdpSessionsCompleter = _rdpSessionsCompleters.remove(requestId);
        if (rdpSessionsCompleter != null) {
          if (success) {
            rdpSessionsCompleter.complete(sessions);
          } else {
            rdpSessionsCompleter.completeError(Exception(error ?? 'Failed to fetch RDP sessions'));
          }
        }

      case 'rdp_wrapper_status_response':
        final requestId = msg['requestId'] as String;
        final installed = msg['installed'] as bool;
        final rdpWrapperStatusCompleter = _rdpWrapperStatusCompleters.remove(requestId);
        if (rdpWrapperStatusCompleter != null) {
          rdpWrapperStatusCompleter.complete(installed);
        }

      case 'rdp_wrapper_install_response':
        final requestId = msg['requestId'] as String;
        final success = msg['success'] as bool;
        final error = msg['error'] as String?;
        final rdpWrapperInstallCompleter = _rdpWrapperInstallCompleters.remove(requestId);
        if (rdpWrapperInstallCompleter != null) {
          if (success) {
            rdpWrapperInstallCompleter.complete(true);
          } else {
            rdpWrapperInstallCompleter.completeError(Exception(error ?? 'Failed to install RDP Wrapper'));
          }
        }

      case 'network_scan_response':
        final requestId = msg['requestId'] as String;
        final success = msg['success'] as bool;
        final error = msg['error'] as String?;
        final completer = _networkScanCompleters.remove(requestId);
        if (completer != null) {
          if (success) {
            completer.complete({
              'agentIp': msg['agentIp'] ?? '',
              'agentHostname': msg['agentHostname'] ?? '',
              'gateway': msg['gateway'] ?? '',
              'subnet': msg['subnet'] ?? '',
              'interfaceName': msg['interfaceName'] ?? '',
              'scanDurationMs': msg['scanDurationMs'] ?? 0,
              'machines': List<Map<String, dynamic>>.from(msg['machines'] as List? ?? []),
            });
          } else {
            completer.completeError(Exception(error ?? 'Network scan failed'));
          }
        }

      case 'print_job_progress':
        final requestId = msg['requestId'] as String;
        final progress = (msg['progress'] as num?)?.toDouble() ?? 0.0;
        final currentPage = msg['currentPage'] as int? ?? 0;
        final totalPages = msg['totalPages'] as int? ?? 0;
        final status = msg['status'] as String? ?? '';
        final callback = _printProgressCallbacks[requestId];
        if (callback != null) {
          callback(progress, currentPage, totalPages, status);
        }

      case 'print_job_response':
        final requestId = msg['requestId'] as String;
        final success = msg['success'] as bool;
        final error = msg['error'] as String?;
        _printProgressCallbacks.remove(requestId);
        final completer = _printJobCompleters.remove(requestId);
        if (completer != null) {
          if (success) {
            completer.complete();
            // Auto-detach any temporarily attached USB devices after a 30s delay
            for (final busId in _temporarilyAttached.keys.toList()) {
              scheduleAutoDetach(busId);
            }
          } else {
            completer.completeError(Exception(error ?? 'Print job failed'));
          }
        }

      case 'terminal_command_response':
        final requestId = msg['requestId'] as String;
        final success = msg['success'] as bool;
        final exitCode = msg['exitCode'] as int? ?? 0;
        final stdout = msg['stdout'] as String? ?? '';
        final stderr = msg['stderr'] as String? ?? '';
        final error = msg['error'] as String?;
        final completer = _terminalCommandCompleters.remove(requestId);
        if (completer != null) {
          if (success) {
            completer.complete({
              'exitCode': exitCode,
              'stdout': stdout,
              'stderr': stderr,
            });
          } else {
            completer.completeError(Exception(error ?? 'Failed to execute terminal command'));
          }
        }

      case 'usb_eject_response':
        final requestId = msg['requestId'] as String;
        final success = msg['success'] as bool;
        final error = msg['error'] as String?;
        final completer = _usbEjectCompleters.remove(requestId);
        if (completer != null) {
          if (success) {
            completer.complete(true);
          } else {
            completer.completeError(Exception(error ?? 'Eject failed'));
          }
        }

      case 'usb_share_response':
        final requestId = msg['requestId'] as String;
        final success = msg['success'] as bool;
        final error = msg['error'] as String?;
        final completer = _usbShareCompleters.remove(requestId);
        if (completer != null) {
          if (success) {
            completer.complete(true);
          } else {
            completer.completeError(Exception(error ?? 'Share failed'));
          }
        }

      case 'usb_unshare_response':
        final requestId = msg['requestId'] as String;
        final success = msg['success'] as bool;
        final error = msg['error'] as String?;
        final completer = _usbUnshareCompleters.remove(requestId);
        if (completer != null) {
          if (success) {
            completer.complete(true);
          } else {
            completer.completeError(Exception(error ?? 'Unshare failed'));
          }
        }

      case 'usb_bind_response':
        final requestId = msg['requestId'] as String;
        final success = msg['success'] as bool;
        final error = msg['error'] as String?;
        final completer = _usbBindCompleters.remove(requestId);
        if (completer != null) {
          if (success) {
            completer.complete(true);
          } else {
            completer.completeError(Exception(error ?? 'USBIP Bind failed'));
          }
        }

      case 'usb_unbind_response':
        final requestId = msg['requestId'] as String;
        final success = msg['success'] as bool;
        final error = msg['error'] as String?;
        final completer = _usbUnbindCompleters.remove(requestId);
        if (completer != null) {
          if (success) {
            completer.complete(true);
          } else {
            completer.completeError(Exception(error ?? 'USBIP Unbind failed'));
          }
        }

      case 'install_usbip_response':
        final installRequestId = msg['requestId'] as String;
        final installSuccess = msg['success'] as bool;
        final installError = msg['error'] as String?;
        final installCompleter = _installRemoteUsbipCompleters.remove(installRequestId);
        if (installCompleter != null) {
          if (installSuccess) {
            installCompleter.complete(true);
          } else {
            installCompleter.completeError(Exception(installError ?? 'Remote USBIP installation failed'));
          }
        }

      case 'rdp_configure_response':
        final rdpRequestId = msg['requestId'] as String;
        final rdpSuccess = msg['success'] as bool;
        final rdpError = msg['error'] as String?;
        final rdpCompleter = _rdpConfigureCompleters.remove(rdpRequestId);
        if (rdpCompleter != null) {
          if (rdpSuccess) {
            rdpCompleter.complete(true);
          } else {
            rdpCompleter.completeError(Exception(rdpError ?? 'Failed to configure RDP'));
          }
        }

    }
  }

  void _handleDataFrame(Uint8List frame) {
    final channelId = ascii.decode(frame.sublist(1, _headerLength));
    final payload = frame.sublist(_headerLength);
    final socket = _localSockets[channelId];
    if (socket != null) {
      socket.add(payload);
      _bytesIn += payload.length;
      notifyListeners();
    }
  }

  // ── Tunnel listeners ───────────────────────────────────────────────────────

  void _startAllTunnelListeners() {
    if (Platform.isAndroid) return;
    for (final tunnel in _tunnels.where((t) => t.enabled)) {
      _startTunnelListener(tunnel);
    }
  }

  Future<void> _startTunnelListener(TunnelConfig config) async {
    if (_servers.containsKey(config.id)) return;
    try {
      final server = await ServerSocket.bind(InternetAddress.anyIPv4, config.localPort, shared: true);
      _servers[config.id] = server;
      _log(LogLevel.info,
          'Listening on localhost:${config.localPort} → ${config.remoteHost}:${config.remotePort} [${config.name}]');

      server.listen((Socket socket) {
        final channelId = _uuid.v4();
        _localSockets[channelId] = socket;
        _log(LogLevel.debug, 'New local connection on ${config.name}, channelId=$channelId');

        // Ask relay to open a channel to the work resource
        _send(jsonEncode({
          'type': 'open',
          'channelId': channelId,
          'host': config.remoteHost,
          'port': config.remotePort,
        }));
        _pendingChannels.add(channelId);

        // Forward local TCP data → relay
        socket.listen(
          (Uint8List data) {
            _sendDataFrame(channelId, data);
            _bytesOut += data.length;
            notifyListeners();
          },
          onDone: () {
            _send(jsonEncode({'type': 'close', 'channelId': channelId}));
            _localSockets.remove(channelId);
            notifyListeners();
          },
          onError: (_) {
            _send(jsonEncode({'type': 'close', 'channelId': channelId}));
            _localSockets.remove(channelId)?.destroy();
            notifyListeners();
          },
          cancelOnError: true,
        );
      });
      notifyListeners();
    } catch (e) {
      _log(LogLevel.error, 'Cannot bind port ${config.localPort}: $e');
    }
  }

  void _stopTunnelListener(String tunnelId) {
    _servers.remove(tunnelId)?.close();
  }

  void _closeLocalSocket(String channelId) {
    final socket = _localSockets.remove(channelId);
    if (socket != null) {
      socket.close().catchError((e) {
        _log(LogLevel.warning, 'Error closing local socket: $e');
      });
    }
  }

  // ── Wire encoding ──────────────────────────────────────────────────────────

  void _send(String text) {
    if (Platform.isAndroid) {
      FlutterForegroundTask.sendDataToTask({
        'action': 'send_text',
        'text': text,
      });
    } else {
      try {
        _ws?.sink.add(text);
      } catch (_) {}
    }
  }

  void _sendDataFrame(String channelId, List<int> data) {
    try {
      final channelBytes = ascii.encode(channelId);
      final frame = Uint8List(_headerLength + data.length);
      frame[0] = _dataFrameType;
      frame.setRange(1, _headerLength, channelBytes);
      frame.setRange(_headerLength, frame.length, data);
      _ws?.sink.add(frame);
    } catch (_) {}
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  void _setState(TunnelConnectionState state, {String? error}) {
    _state = state;
    _errorMessage = error;
    notifyListeners();
  }

  void _onDisconnected(String? reason) {
    _cleanup();
    _setState(TunnelConnectionState.disconnected);
    _peerConnected = false;

    // Auto-reconnect after 5 seconds if we have stored credentials
    if (_autoReconnect && _lastRelayUrl != null && _lastToken != null) {
      _log(LogLevel.info, 'Auto-reconnecting in 5 seconds...');
      Future.delayed(const Duration(seconds: 5), () {
        if (_state == TunnelConnectionState.disconnected &&
            _lastRelayUrl != null && _lastToken != null) {
          connect(_lastRelayUrl!, _lastToken!);
        }
      });
    }
  }

  Future<void> _cleanup() async {
    if (Platform.isAndroid) {
      try {
        await FlutterForegroundTask.stopService();
      } catch (_) {}
    }
    await _wsSub?.cancel();
    _wsSub = null;
    await _ws?.sink.close();
    _ws = null;
    for (final s in _servers.values.toList()) {
      await s.close();
    }
    _servers.clear();
    for (final s in _localSockets.values.toList()) {
      s.destroy();
    }
    _localSockets.clear();
    _pendingChannels.clear();
    _peerConnected = false;

    // Clean up file explorer state
    for (final download in _activeDownloads.values) {
      download.sink.close().catchError((_) => null);
      download.completer.completeError(Exception('Disconnected'));
    }
    _activeDownloads.clear();
    for (final completer in _fileListCompleters.values) {
      completer.completeError(Exception('Disconnected'));
    }
    _fileListCompleters.clear();
    for (final completer in _activeUploadCompleters.values) {
      completer.completeError(Exception('Disconnected'));
    }
    _activeUploadCompleters.clear();
    for (final completer in _fileActionCompleters.values) {
      completer.completeError(Exception('Disconnected'));
    }
    _fileActionCompleters.clear();

    // Clean up device explorer state
    for (final completer in _deviceListCompleters.values) {
      completer.completeError(Exception('Disconnected'));
    }
    _deviceListCompleters.clear();
    for (final completer in _printJobCompleters.values) {
      completer.completeError(Exception('Disconnected'));
    }
    _printJobCompleters.clear();
    for (final completer in _terminalCommandCompleters.values) {
      completer.completeError(Exception('Disconnected'));
    }
    _terminalCommandCompleters.clear();

    // Clean up USB control completers
    for (final completer in _usbEjectCompleters.values) {
      completer.completeError(Exception('Disconnected'));
    }
    _usbEjectCompleters.clear();
    for (final completer in _usbShareCompleters.values) {
      completer.completeError(Exception('Disconnected'));
    }
    _usbShareCompleters.clear();
    for (final completer in _usbUnshareCompleters.values) {
      completer.completeError(Exception('Disconnected'));
    }
    _usbUnshareCompleters.clear();
    for (final completer in _usbBindCompleters.values) {
      completer.completeError(Exception('Disconnected'));
    }
    _usbBindCompleters.clear();
    for (final completer in _usbUnbindCompleters.values) {
      completer.completeError(Exception('Disconnected'));
    }
    _usbUnbindCompleters.clear();
    for (final completer in _installRemoteUsbipCompleters.values) {
      completer.completeError(Exception('Disconnected'));
    }
    _installRemoteUsbipCompleters.clear();
    for (final completer in _rdpConfigureCompleters.values) {
      completer.completeError(Exception('Disconnected'));
    }
    _rdpConfigureCompleters.clear();
    for (final completer in _rdpSessionsCompleters.values) {
      completer.completeError(Exception('Disconnected'));
    }
    _rdpSessionsCompleters.clear();
    for (final completer in _rdpWrapperStatusCompleters.values) {
      completer.completeError(Exception('Disconnected'));
    }
    _rdpWrapperStatusCompleters.clear();
    for (final completer in _rdpWrapperInstallCompleters.values) {
      completer.completeError(Exception('Disconnected'));
    }
    _rdpWrapperInstallCompleters.clear();
    for (final completer in _networkScanCompleters.values) {
      completer.completeError(Exception('Disconnected'));
    }
    _networkScanCompleters.clear();

    _keepAliveTimer?.cancel();
    _keepAliveTimer = null;

    // Clean up temporary USB attach state
    for (final timer in _autoDetachTimers.values) {
      timer.cancel();
    }
    _autoDetachTimers.clear();
    _attachedDevices.clear();
    _temporarilyAttached.clear();
  }

  void _log(LogLevel level, String message) {
    _logs.add(LogEntry(timestamp: DateTime.now(), level: level, message: message));
    if (_logs.length > 500) _logs.removeAt(0); // cap log size
    notifyListeners();
  }

  void clearLogs() {
    _logs.clear();
    notifyListeners();
  }

  // ── Remote File Operations ──────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchRemoteFiles(String path) async {
    if (!isConnected) throw Exception('Not connected to relay');
    final requestId = _uuid.v4();
    final completer = Completer<List<Map<String, dynamic>>>();
    _fileListCompleters[requestId] = completer;

    _send(jsonEncode({
      'type': 'file_list_request',
      'requestId': requestId,
      'path': path,
    }));

    return completer.future;
  }

  Future<void> createRemoteDirectory(String remotePath) async {
    if (!isConnected) throw Exception('Not connected to relay');
    final requestId = _uuid.v4();
    final completer = Completer<bool>();
    _fileActionCompleters[requestId] = completer;

    _send(jsonEncode({
      'type': 'file_create_dir_request',
      'requestId': requestId,
      'path': remotePath,
    }));

    final success = await completer.future;
    if (!success) throw Exception('Failed to create remote directory');
  }

  Future<void> deleteRemoteEntity(String remotePath) async {
    if (!isConnected) throw Exception('Not connected to relay');
    final requestId = _uuid.v4();
    final completer = Completer<bool>();
    _fileActionCompleters[requestId] = completer;

    _send(jsonEncode({
      'type': 'file_delete_request',
      'requestId': requestId,
      'path': remotePath,
    }));

    final success = await completer.future;
    if (!success) throw Exception('Failed to delete remote item');
  }

  Future<void> downloadRemoteFile(String remotePath, String localSavePath, {Function(double)? onProgress}) async {
    if (!isConnected) throw Exception('Not connected to relay');
    final requestId = _uuid.v4();
    final completer = Completer<void>();

    final file = File(localSavePath);
    await file.parent.create(recursive: true);
    final sink = file.openWrite();

    _activeDownloads[requestId] = _ActiveFileDownload(
      remotePath: remotePath,
      localSavePath: localSavePath,
      sink: sink,
      completer: completer,
      onProgress: onProgress,
    );

    _send(jsonEncode({
      'type': 'file_download_request',
      'requestId': requestId,
      'path': remotePath,
    }));

    try {
      await completer.future;
    } catch (e) {
      await sink.close();
      try {
        await file.delete();
      } catch (_) {}
      rethrow;
    }
  }

  Future<void> uploadLocalFile(
    String? localPath,
    String remoteDestPath, {
    Function(double)? onProgress,
    Uint8List? localBytes,
  }) async {
    if (!isConnected) throw Exception('Not connected to relay');

    final Uint8List bytes;
    if (localBytes != null) {
      bytes = localBytes;
    } else if (localPath != null) {
      final file = File(localPath);
      if (!file.existsSync()) throw Exception('Local file does not exist');
      bytes = await file.readAsBytes();
    } else {
      throw Exception('Either localPath or localBytes must be provided');
    }

    final requestId = _uuid.v4();
    final completer = Completer<void>();
    _activeUploadCompleters[requestId] = completer;

    final fileLength = bytes.length;

    try {
      const chunkSize = 64 * 1024;
      int bytesSent = 0;
      int chunkIndex = 0;

      while (bytesSent < fileLength) {
        final remaining = fileLength - bytesSent;
        final toRead = remaining < chunkSize ? remaining : chunkSize;
        final chunk = bytes.sublist(bytesSent, bytesSent + toRead);
        bytesSent += toRead;

        final isLast = bytesSent >= fileLength;
        final base64Data = base64Encode(chunk);

        _send(jsonEncode({
          'type': 'file_upload_chunk',
          'requestId': requestId,
          'path': remoteDestPath,
          'chunkIndex': chunkIndex++,
          'data': base64Data,
          'isLast': isLast,
        }));

        if (onProgress != null && fileLength > 0) {
          onProgress(bytesSent / fileLength);
        }

        await Future.delayed(const Duration(milliseconds: 5));
      }

      await completer.future.timeout(
        const Duration(seconds: 45),
        onTimeout: () => throw TimeoutException('File upload to distant machine timed out'),
      );
    } catch (e) {
      rethrow;
    } finally {
      _activeUploadCompleters.remove(requestId);
    }
  }

  // ── Remote Device Operations ────────────────────────────────────────────────

  Future<void> uploadBytes(Uint8List bytes, String remoteDestPath, {Function(double)? onProgress}) async {
    if (!isConnected) throw Exception('Not connected to relay');

    final requestId = _uuid.v4();
    final completer = Completer<void>();
    _activeUploadCompleters[requestId] = completer;

    final fileLength = bytes.length;

    try {
      const chunkSize = 64 * 1024;
      int bytesSent = 0;
      int chunkIndex = 0;

      while (bytesSent < fileLength) {
        final remaining = fileLength - bytesSent;
        final toRead = remaining < chunkSize ? remaining : chunkSize;
        final chunk = bytes.sublist(bytesSent, bytesSent + toRead);
        bytesSent += toRead;

        final isLast = bytesSent >= fileLength;
        final base64Data = base64Encode(chunk);

        _send(jsonEncode({
          'type': 'file_upload_chunk',
          'requestId': requestId,
          'path': remoteDestPath,
          'chunkIndex': chunkIndex++,
          'data': base64Data,
          'isLast': isLast,
        }));

        if (onProgress != null && fileLength > 0) {
          onProgress(bytesSent / fileLength);
        }

        await Future.delayed(const Duration(milliseconds: 5));
      }

      await completer.future;
    } catch (e) {
      rethrow;
    } finally {
      _activeUploadCompleters.remove(requestId);
    }
  }

  
  Future<Map<String, dynamic>> fetchRemoteDevices() async {
    if (!isConnected) throw Exception('Not connected to relay');
    final requestId = _uuid.v4();
    final completer = Completer<Map<String, dynamic>>();
    _deviceListCompleters[requestId] = completer;

    _send(jsonEncode({
      'type': 'device_list_request',
      'requestId': requestId,
    }));

    return completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () => throw TimeoutException('Failed to fetch remote devices: timed out'),
    );
  }

  Future<void> triggerRemotePrint(
    String remoteFilePath,
    String printerName, {
    bool deleteAfter = false,
    String pageSize = 'A4',
    String orientation = 'portrait',
    void Function(double progress, int currentPage, int totalPages, String status)? onProgress,
  }) async {
    if (!isConnected) throw Exception('Not connected to relay');
    final requestId = _uuid.v4();
    final completer = Completer<void>();
    _printJobCompleters[requestId] = completer;
    if (onProgress != null) {
      _printProgressCallbacks[requestId] = onProgress;
    }

    _send(jsonEncode({
      'type': 'print_job_request',
      'requestId': requestId,
      'filePath': remoteFilePath,
      'printerName': printerName,
      'deleteAfter': deleteAfter,
      'pageSize': pageSize,
      'orientation': orientation,
    }));

    return completer.future.timeout(
      const Duration(minutes: 2),
      onTimeout: () => throw TimeoutException('Remote print command on target machine timed out'),
    );
  }

  // ── Remote Terminal Operations ──────────────────────────────────────────────

  Future<Map<String, dynamic>> executeRemoteCommand(String command, String cwd) async {
    if (!isConnected) throw Exception('Not connected to relay');
    final requestId = _uuid.v4();
    final completer = Completer<Map<String, dynamic>>();
    _terminalCommandCompleters[requestId] = completer;

    _send(jsonEncode({
      'type': 'terminal_command_request',
      'requestId': requestId,
      'command': command,
      'cwd': cwd,
    }));

    return completer.future;
  }

  Future<bool> ejectRemoteUsbDrive(String driveLetter) async {
    if (!isConnected) throw Exception('Not connected to relay');
    final requestId = _uuid.v4();
    final completer = Completer<bool>();
    _usbEjectCompleters[requestId] = completer;
    _send(jsonEncode({
      'type': 'usb_eject_request',
      'requestId': requestId,
      'driveLetter': driveLetter,
    }));
    return completer.future;
  }

  Future<bool> shareRemoteUsbDrive(String drivePath, String shareName) async {
    if (!isConnected) throw Exception('Not connected to relay');
    final requestId = _uuid.v4();
    final completer = Completer<bool>();
    _usbShareCompleters[requestId] = completer;
    _send(jsonEncode({
      'type': 'usb_share_request',
      'requestId': requestId,
      'drivePath': drivePath,
      'shareName': shareName,
    }));
    return completer.future;
  }

  Future<bool> unshareRemoteUsbDrive(String shareName) async {
    if (!isConnected) throw Exception('Not connected to relay');
    final requestId = _uuid.v4();
    final completer = Completer<bool>();
    _usbUnshareCompleters[requestId] = completer;
    _send(jsonEncode({
      'type': 'usb_unshare_request',
      'requestId': requestId,
      'shareName': shareName,
    }));
    return completer.future;
  }

  // ── Remote USBIP Bind / Unbind ─────────────────────────────────────────────

  Future<bool> bindRemoteUsbDevice(String busId) async {
    if (!isConnected) throw Exception('Not connected to relay');
    final requestId = _uuid.v4();
    final completer = Completer<bool>();
    _usbBindCompleters[requestId] = completer;
    _send(jsonEncode({
      'type': 'usb_bind_request',
      'requestId': requestId,
      'busId': busId,
    }));
    return completer.future;
  }

  Future<bool> unbindRemoteUsbDevice(String busId) async {
    if (!isConnected) throw Exception('Not connected to relay');
    final requestId = _uuid.v4();
    final completer = Completer<bool>();
    _usbUnbindCompleters[requestId] = completer;
    _send(jsonEncode({
      'type': 'usb_unbind_request',
      'requestId': requestId,
      'busId': busId,
    }));
    return completer.future;
  }

  /// Send install request to the remote agent to install USBIP tools.
  Future<bool> installRemoteUsbip() async {
    if (!isConnected) throw Exception('Not connected to relay');
    final requestId = _uuid.v4();
    final completer = Completer<bool>();
    _installRemoteUsbipCompleters[requestId] = completer;
    _send(jsonEncode({
      'type': 'install_usbip_request',
      'requestId': requestId,
    }));
    return completer.future;
  }

  Future<List<Map<String, dynamic>>> fetchRemoteRdpSessions() async {
    if (!isConnected) throw Exception('Not connected to relay');
    final requestId = _uuid.v4();
    final completer = Completer<List<Map<String, dynamic>>>();
    _rdpSessionsCompleters[requestId] = completer;
    _send(jsonEncode({
      'type': 'rdp_sessions_request',
      'requestId': requestId,
    }));
    return completer.future;
  }

  Future<bool> checkRemoteRdpWrapperInstalled() async {
    if (!isConnected) throw Exception('Not connected to relay');
    final requestId = _uuid.v4();
    final completer = Completer<bool>();
    _rdpWrapperStatusCompleters[requestId] = completer;
    _send(jsonEncode({
      'type': 'rdp_wrapper_status_request',
      'requestId': requestId,
    }));
    return completer.future;
  }

  Future<bool> installRemoteRdpWrapper() async {
    if (!isConnected) throw Exception('Not connected to relay');
    final requestId = _uuid.v4();
    final completer = Completer<bool>();
    _rdpWrapperInstallCompleters[requestId] = completer;
    _send(jsonEncode({
      'type': 'rdp_wrapper_install_request',
      'requestId': requestId,
    }));
    return completer.future;
  }

  Future<bool> configureRemoteRdp() async {
    if (!isConnected) throw Exception('Not connected to relay');
    final requestId = _uuid.v4();
    final completer = Completer<bool>();
    _rdpConfigureCompleters[requestId] = completer;
    _send(jsonEncode({
      'type': 'rdp_configure_request',
      'requestId': requestId,
    }));
    return completer.future;
  }

  /// Scan and discover all machines on the local network (LAN) where the remote agent is installed.
  Future<Map<String, dynamic>> scanRemoteNetwork({bool deepScan = false}) async {
    if (!isConnected) throw Exception('Not connected to relay');
    final requestId = _uuid.v4();
    final completer = Completer<Map<String, dynamic>>();
    _networkScanCompleters[requestId] = completer;
    _send(jsonEncode({
      'type': 'network_scan_request',
      'requestId': requestId,
      'deepScan': deepScan,
    }));
    return completer.future.timeout(const Duration(seconds: 50), onTimeout: () {
      _networkScanCompleters.remove(requestId);
      throw Exception('Network scan timed out. Please try again.');
    });
  }

  Future<void> launchRdp(String host, int port, [BuildContext? context]) async {
            final rdpContent = '''
full address:s:$host:$port
prompt for credentials:i:1
enablecredsspsupport:i:1
authentication level:i:0
negotiate security layer:i:1
screen mode id:i:2
use multimon:i:0
session bpp:i:32
compression:i:1
keyboardhook:i:2
audiocapturemode:i:0
videoplaybackmode:i:1
connection type:i:7
networkautodetect:i:1
bandwidthautodetect:i:1
displayconnectionbar:i:1
enableworkspacereconnect:i:1
disable wallpaper:i:0
allow font smoothing:i:1
allow desktop composition:i:1
disable full window drag:i:0
disable menu anims:i:0
disable themes:i:0
disable cursor setting:i:0
bitmapcachepersistenable:i:1
''';

    if (Platform.isWindows) {
      final tempDir = await getTemporaryDirectory();
      final rdpFile = File('${tempDir.path}${Platform.pathSeparator}tunnel_rdp_session.rdp');
      await rdpFile.writeAsString(rdpContent);
      await Process.run('mstsc.exe', [rdpFile.path]);
    } else if (Platform.isLinux) {
      // Check if xfreerdp or remmina is installed
      String? clientExe;
      if ((await Process.run('which', ['xfreerdp'])).exitCode == 0) {
        clientExe = 'xfreerdp';
      } else if ((await Process.run('which', ['remmina'])).exitCode == 0) {
        clientExe = 'remmina';
      }

      if (clientExe == null) {
        // Try installing freerdp2-x11 automatically via pkexec / apt-get
        final installResult = await Process.run('pkexec', ['apt-get', 'install', '-y', 'freerdp2-x11']);
        if (installResult.exitCode == 0 && (await Process.run('which', ['xfreerdp'])).exitCode == 0) {
          clientExe = 'xfreerdp';
        } else {
          // Fallback to apt-get direct
          final aptResult = await Process.run('apt-get', ['install', '-y', 'freerdp2-x11']);
          if (aptResult.exitCode == 0 && (await Process.run('which', ['xfreerdp'])).exitCode == 0) {
            clientExe = 'xfreerdp';
          }
        }
      }

      if (clientExe == 'xfreerdp') {
        // Bypass NLA & password checks for direct 1-click logon
        await Process.start('xfreerdp', [
          '/v:$host:$port',
          '-sec-nla',
          '/cert-ignore',
          '/dynamic-resolution',
          '/u:',
          '/p:',
        ]);
      } else if (clientExe == 'remmina') {
        final tempDir = await getTemporaryDirectory();
        final rdpFile = File('${tempDir.path}${Platform.pathSeparator}tunnel_rdp_session.rdp');
        await rdpFile.writeAsString('''
[remmina]
server=$host:$port
protocol=RDP
''');
        await Process.start('remmina', ['-c', rdpFile.path]);
      } else {
        // Fallback: try opening .rdp with default system handler (e.g. Remmina / KRDC / etc.)
        final tempDir = await getTemporaryDirectory();
        final rdpFile = File('${tempDir.path}${Platform.pathSeparator}tunnel_rdp_session.rdp');
        await rdpFile.writeAsString(rdpContent);
        final xdgResult = await Process.run('xdg-open', [rdpFile.path]);
        if (xdgResult.exitCode != 0) {
          throw Exception('Could not find or install an RDP client (freerdp2-x11 / remmina). Please install freerdp2-x11 or remmina manually.');
        }
      }
    } else if (Platform.isAndroid || Platform.isIOS) {
      // Double-encode spaces (%2520) so Android OS Intent Uri passes %20 to Windows App
      final urlStringsToTry = [
        'rdp://full%2520address=s:$host:$port&prompt%2520for%2520credentials=i:1',
        'rdp://full%2520address=s:$host:$port',
        'ms-rdp://full%2520address=s:$host:$port',
        'rdp://$host:$port',
        'ms-rdp://$host:$port',
      ];

      bool launched = false;
      for (final urlStr in urlStringsToTry) {
        try {
          final success = await launchUrlString(urlStr, mode: LaunchMode.externalApplication);
          if (success) {
            launched = true;
            break;
          }
        } catch (e) {
          debugPrint('[TunnelService] RDP launchUrlString failed for $urlStr: $e');
        }
      }

      if (!launched) {
        try {
          final tempDir = await getTemporaryDirectory();
          final rdpFile = File('${tempDir.path}${Platform.pathSeparator}tunnel_rdp_session.rdp');
          await rdpFile.writeAsString(rdpContent);
          final fileUri = Uri.file(rdpFile.path);
          launched = await launchUrl(fileUri, mode: LaunchMode.externalApplication);
        } catch (e) {
          debugPrint('[TunnelService] .rdp file launch fallback failed: $e');
        }
      }

      if (!launched) {
        if (context != null && context.mounted) {
          _showRdpInstallPrompt(context);
        } else {
          throw Exception('Windows App (Remote Desktop) n\'a pas pu être lancé.');
        }
      }
    } else {
      throw Exception('RDP launch is not supported on this platform');
    }
  }

  Future<void> launchRdpWithFallbackToken({
    required String relayUrl,
    required String rdpToken,
    required int port,
    BuildContext? context,
  }) async {
    try {
      final fallbackService = TunnelService();
      final rdpTunnel = TunnelConfig(
        id: 'rdp-fallback',
        profileId: 'default',
        name: 'RDP Safety Fallback',
        localPort: port,
        remoteHost: '127.0.0.1',
        remotePort: 3389,
        enabled: true,
      );
      fallbackService.setTunnels([rdpTunnel]);
      fallbackService.connect(relayUrl, rdpToken);

      int ticks = 0;
      while (!fallbackService.isConnected && ticks < 25) {
        await Future.delayed(const Duration(milliseconds: 200));
        ticks++;
      }

      await fallbackService.launchRdp('127.0.0.1', port, context);
    } catch (e) {
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Impossible de se connecter à l\'agent RDP de secours: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _showRdpInstallPrompt(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F1629),
        title: const Text('Windows App (Remote Desktop) requise', style: TextStyle(color: Colors.white)),
        content: const Text(
          'L\'application Windows App (anciennement Microsoft Remote Desktop) est nécessaire pour se connecter en RDP.\n\nSouhaitez-vous l\'installer maintenant depuis le Store ?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler', style: TextStyle(color: Color(0xFF8892A4))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00BFA5)),
            onPressed: () async {
              Navigator.pop(ctx);
              final Uri storeUri = Uri.parse(
                Platform.isAndroid
                    ? 'https://play.google.com/store/apps/details?id=com.microsoft.rdc.android'
                    : 'https://apps.apple.com/app/windows-app/id714420560',
              );
              try {
                await launchUrl(storeUri, mode: LaunchMode.externalApplication);
              } catch (_) {
                await launchUrl(storeUri);
              }
            },
            child: const Text('Installer'),
          ),
        ],
      ),
    );
  }

  // ── Local Client USBIP Commands ────────────────────────────────────────────

  /// Find the usbip executable — check PATH first, then default install locations.
  static Future<String> findLocalUsbipExecutable() async {
    if (!Platform.isWindows) return 'usbip';
    try {
      final res = await Process.run('where', ['usbip']);
      if (res.exitCode == 0 && res.stdout.toString().trim().isNotEmpty) {
        return 'usbip';
      }
    } catch (_) {}
    const defaultPath = 'C:\\Program Files\\usbipd-win\\usbip.exe';
    if (File(defaultPath).existsSync()) {
      return defaultPath;
    }
    const usbipWin2Path = 'C:\\Program Files\\USBip\\usbip.exe';
    if (File(usbipWin2Path).existsSync()) {
      return usbipWin2Path;
    }
    return '';
  }

  /// Check if usbip client is installed on the local machine.
  Future<bool> isLocalUsbipInstalled() async {
    if (Platform.isLinux) {
      try {
        final res = await Process.run('which', ['usbip']);
        return res.exitCode == 0;
      } catch (_) {
        return false;
      }
    }
    final exe = await findLocalUsbipExecutable();
    return exe.isNotEmpty;
  }

  /// Install usbip client on the local machine (Windows via bundled assets, Linux via apt).
  Future<bool> installLocalUsbip() async {
    if (Platform.isWindows) {
      try {
        final byteData = await rootBundle.load('assets/usbip-win2.exe');
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}\\usbip-win2.exe');
        await file.writeAsBytes(byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));
        
        final result = await Process.run('powershell', [
          '-Command',
          "Start-Process -FilePath '${file.path}' -ArgumentList '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART' -Verb RunAs -Wait"
        ]);
        return result.exitCode == 0;
      } catch (e) {
        // Fallback to winget if asset loading or running fails
        final result = await Process.run('powershell', [
          '-Command',
          "Start-Process powershell -ArgumentList '-Command winget install OUST.Usbipd-Win --silent --accept-source-agreements --accept-package-agreements' -Verb RunAs"
        ]);
        return result.exitCode == 0;
      }
    } else if (Platform.isLinux) {
      final result = await Process.run('sudo', ['apt-get', 'install', '-y', 'usbip']);
      return result.exitCode == 0;
    }
    return false;
  }

  Future<bool> attachLocalUsbDevice(String busId, {bool temporary = false}) async {
    try {
      final exe = await findLocalUsbipExecutable();
      final usbipPath = exe.isNotEmpty ? exe : 'usbip';
      final result = await Process.run(usbipPath, ['attach', '-r', '127.0.0.1', '-b', busId]);
      final success = result.exitCode == 0;
      if (success) {
        _attachedDevices[busId] = '';
        if (temporary) {
          _temporarilyAttached[busId] = true;
        }
        notifyListeners();
      }
      return success;
    } catch (_) {}
    return false;
  }

  Future<bool> detachLocalUsbDevice(String portIndex) async {
    try {
      final exe = await findLocalUsbipExecutable();
      final usbipPath = exe.isNotEmpty ? exe : 'usbip';
      final result = await Process.run(usbipPath, ['detach', '-p', portIndex]);
      final success = result.exitCode == 0;
      // Clean up tracking for any busId using this port
      final busId = _attachedDevices.entries
          .firstWhere((e) => e.value == portIndex, orElse: () => const MapEntry('', ''))
          .key;
      if (busId.isNotEmpty) {
        _attachedDevices.remove(busId);
        _temporarilyAttached.remove(busId);
        _autoDetachTimers.remove(busId)?.cancel();
        notifyListeners();
      }
      return success;
    } catch (_) {}
    return false;
  }

  Future<List<Map<String, String>>> getLocalAttachedUsbDevices() async {
    final list = <Map<String, String>>[];
    try {
      final exe = await findLocalUsbipExecutable();
      final usbipPath = exe.isNotEmpty ? exe : 'usbip';
      final result = await Process.run(usbipPath, ['port']);
      if (result.exitCode == 0) {
        final lines = LineSplitter.split(result.stdout.toString());
        String? currentPort;
        for (final line in lines) {
          if (line.startsWith('Port ')) {
            // More lenient regex to handle variable whitespace
            final match = RegExp(r'^Port\s*(\d+)\s*:').firstMatch(line);
            if (match != null) {
              currentPort = match.group(1);
            }
          } else if (line.contains('127.0.0.1') && currentPort != null) {
            // e.g. "127.0.0.1 (1-1)" or "127.0.0.1 :3240 => remote (2-1)"
            final match = RegExp(r'\(([^)]+)\)').firstMatch(line);
            if (match != null) {
              final busId = match.group(1)!;
              list.add({
                'port': currentPort,
                'busId': busId,
              });
              // Update _attachedDevices with port from usbip port output
              _attachedDevices[busId] = currentPort;
            }
            currentPort = null;
          }
        }
      }
    } catch (_) {}

    // Phase 1 fix: Merge in any devices tracked by Dart that weren't confirmed above.
    // This ensures the Detach button always appears even if usbip port parsing fails.
    for (final entry in _attachedDevices.entries) {
      final alreadyListed = list.any((d) => d['busId'] == entry.key);
      if (!alreadyListed && entry.value.isNotEmpty) {
        list.add({
          'port': entry.value,
          'busId': entry.key,
        });
      }
    }
    return list;
  }

  // ── Temporary Auto-Detach Methods ──────────────────────────────────────────

  /// Start a 30-second countdown to auto-detach a temporarily attached device.
  void scheduleAutoDetach(String busId) {
    _autoDetachTimers[busId]?.cancel();
    _autoDetachTimers[busId] = Timer(const Duration(seconds: 30), () {
      _executeAutoDetach(busId);
    });
    notifyListeners();
  }

  /// Cancel a pending auto-detach timer for a temporarily attached device.
  void cancelAutoDetach(String busId) {
    _autoDetachTimers.remove(busId)?.cancel();
    _temporarilyAttached.remove(busId);
    notifyListeners();
  }

  /// Execute the full detach sequence for auto-detach.
  Future<void> _executeAutoDetach(String busId) async {
    final port = _attachedDevices[busId];
    if (port != null && port.isNotEmpty) {
      await detachLocalUsbDevice(port);
    }
    await unbindRemoteUsbDevice(busId);
    _attachedDevices.remove(busId);
    _temporarilyAttached.remove(busId);
    _autoDetachTimers.remove(busId);
    notifyListeners();
  }

  /// Get remaining seconds on the auto-detach timer for a given busId.
  int? getAutoDetachRemaining(String busId) {
    final timer = _autoDetachTimers[busId];
    if (timer == null) return null;
    return null;
  }

  // ── Incoming Agent Request Handlers (Peer -> Agent) ───────────────────────

  final Map<String, List<int>> _incomingUploadBuffers = {};

  Future<void> _handleIncomingFileUploadChunk(Map<String, dynamic> msg) async {
    final requestId = msg['requestId'] as String;
    final pathParam = msg['path'] as String;
    final base64Data = msg['data'] as String;
    final isLast = msg['isLast'] as bool? ?? false;

    try {
      final chunkBytes = base64Decode(base64Data);
      final buffer = _incomingUploadBuffers.putIfAbsent(requestId, () => <int>[]);
      buffer.addAll(chunkBytes);

      if (isLast) {
        final fileBytes = Uint8List.fromList(_incomingUploadBuffers.remove(requestId) ?? []);
        
        String savePath = pathParam;
        if (!path.isAbsolute(savePath)) {
          savePath = path.join(Directory.systemTemp.path, pathParam);
        }

        final targetFile = File(savePath);
        await targetFile.parent.create(recursive: true);
        await targetFile.writeAsBytes(fileBytes);

        _log(LogLevel.info, 'Received uploaded file from peer: $savePath (${fileBytes.length} bytes)');

        _send(jsonEncode({
          'type': 'file_upload_response',
          'requestId': requestId,
          'success': true,
          'filePath': savePath,
        }));
      }
    } catch (e) {
      _incomingUploadBuffers.remove(requestId);
      _log(LogLevel.error, 'Failed to process incoming upload chunk: $e');
      _send(jsonEncode({
        'type': 'file_upload_response',
        'requestId': requestId,
        'success': false,
        'error': e.toString(),
      }));
    }
  }

  Future<void> _handleIncomingPrintJobRequest(Map<String, dynamic> msg) async {
    final requestId = msg['requestId'] as String;
    final filePathParam = msg['filePath'] as String;
    final printerName = msg['printerName'] as String;
    final deleteAfter = msg['deleteAfter'] as bool? ?? false;

    try {
      String fullPath = filePathParam;
      if (!path.isAbsolute(fullPath)) {
        fullPath = path.join(Directory.systemTemp.path, filePathParam);
      }

      final file = File(fullPath);
      if (!await file.exists()) {
        throw Exception('Fichier PDF introuvable sur l\'agent distant: $fullPath');
      }

      _log(LogLevel.info, 'Received remote print request for printer "$printerName", file: $fullPath');

      final pdfBytes = await file.readAsBytes();

      bool printSuccess = false;
      try {
        printSuccess = await Printing.directPrintPdf(
          printer: Printer(url: printerName, name: printerName),
          onLayout: (PdfPageFormat format) async => pdfBytes,
        );
      } catch (e) {
        _log(LogLevel.warning, 'directPrintPdf failed, trying PowerShell fallback: $e');
      }

      if (!printSuccess && Platform.isWindows) {
        final result = await Process.run('powershell', [
          '-Command',
          'Start-Process -FilePath "${fullPath.replaceAll('"', '\\"')}" -Verb PrintTo -ArgumentList \'"${printerName.replaceAll('"', '\\"')}"\' -Wait'
        ]);
        if (result.exitCode == 0) {
          printSuccess = true;
        } else {
          throw Exception('PowerShell PrintTo failed: ${result.stderr}');
        }
      }

      if (deleteAfter && await file.exists()) {
        try {
          await file.delete();
        } catch (_) {}
      }

      _send(jsonEncode({
        'type': 'print_job_response',
        'requestId': requestId,
        'success': true,
      }));
      _log(LogLevel.success, 'Remote print job executed successfully on "$printerName"');
    } catch (e) {
      _log(LogLevel.error, 'Remote print job failed: $e');
      _send(jsonEncode({
        'type': 'print_job_response',
        'requestId': requestId,
        'success': false,
        'error': e.toString(),
      }));
    }
  }

  Future<void> _handleIncomingDeviceListRequest(Map<String, dynamic> msg) async {
    final requestId = msg['requestId'] as String;
    try {
      final printersList = <Map<String, dynamic>>[];
      try {
        final printers = await Printing.listPrinters();
        for (final p in printers) {
          printersList.add({
            'name': p.name,
            'model': p.model,
            'isDefault': p.isDefault,
            'isAvailable': p.isAvailable,
          });
        }
      } catch (e) {
        _log(LogLevel.warning, 'Failed to query local printers: $e');
      }

      _send(jsonEncode({
        'type': 'device_list_response',
        'requestId': requestId,
        'success': true,
        'usbDevices': [],
        'printers': printersList,
        'comPorts': [],
        'usbipdMissing': false,
      }));
    } catch (e) {
      _send(jsonEncode({
        'type': 'device_list_response',
        'requestId': requestId,
        'success': false,
        'error': e.toString(),
      }));
    }
  }

  @override
  void dispose() {
    if (Platform.isAndroid) {
      FlutterForegroundTask.removeTaskDataCallback(_onReceiveTaskData);
    }
    for (final timer in _autoDetachTimers.values) {
      timer.cancel();
    }
    _autoDetachTimers.clear();
    _cleanup();
    super.dispose();
  }
}

class _ActiveFileDownload {
  final String remotePath;
  final String localSavePath;
  final IOSink sink;
  final Completer<void> completer;
  final Function(double)? onProgress;
  int bytesReceived = 0;

  _ActiveFileDownload({
    required this.remotePath,
    required this.localSavePath,
    required this.sink,
    required this.completer,
    this.onProgress,
  });
}
