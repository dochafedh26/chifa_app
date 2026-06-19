import 'dart:io';

import 'package:flutter/foundation.dart';

class XamppService {
  static final XamppService _instance = XamppService._internal();
  factory XamppService() => _instance;
  XamppService._internal();

  String? _xamppPath;
  bool _isMySqlRunning = false;
  bool _isApacheRunning = false;

  bool get isInstalled => _xamppPath != null;
  bool get isMySqlRunning => _isMySqlRunning;
  bool get isApacheRunning => _isApacheRunning;

  Future<void> _detectXamppPath() async {
    if (Platform.isWindows) {
      final possiblePaths = ['C:\\xampp', 'D:\\xampp', 'E:\\xampp'];
      for (final path in possiblePaths) {
        debugPrint('XamppService: Checking Windows path: $path');
        if (Directory(path).existsSync()) {
          _xamppPath = path;
          debugPrint('XamppService: XAMPP found at: $path');
          return;
        }
      }
    } else if (Platform.isLinux) {
      final possiblePaths = ['/opt/lampp', '/usr/local/lampp'];
      for (final path in possiblePaths) {
        debugPrint('XamppService: Checking Linux path: $path');
        if (Directory(path).existsSync()) {
          _xamppPath = path;
          debugPrint('XamppService: XAMPP found at: $path');
          return;
        }
      }
    } else if (Platform.isMacOS) {
      final possiblePaths = ['/Applications/XAMPP', '/Applications/xampp'];
      for (final path in possiblePaths) {
        debugPrint('XamppService: Checking macOS path: $path');
        if (Directory(path).existsSync()) {
          _xamppPath = path;
          debugPrint('XamppService: XAMPP found at: $path');
          return;
        }
      }
    }
    debugPrint('XamppService: XAMPP not found in any standard location');
  }

  bool _checkProcessRunning(String processName) {
    try {
      if (Platform.isWindows) {
        final result = Process.runSync('tasklist', [
          '/FI',
          'IMAGENAME eq $processName',
          '/NH',
        ], runInShell: true);
        final isRunning = result.stdout.toString().contains(processName);
        debugPrint('XamppService: Process $processName running: $isRunning');
        return isRunning;
      } else {
        final result = Process.runSync('pgrep', ['-x', processName]);
        final isRunning = result.exitCode == 0;
        debugPrint('XamppService: Process $processName running: $isRunning');
        return isRunning;
      }
    } catch (e) {
      debugPrint('XamppService: Error checking process $processName: $e');
      return false;
    }
  }

  Future<void> checkStatus() async {
    if (!kIsWeb &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      debugPrint('XamppService: Detecting XAMPP installation...');
      await _detectXamppPath();
      debugPrint('XamppService: Checking MySQL status...');
      _isMySqlRunning = _checkProcessRunning(
        Platform.isWindows ? 'mysqld.exe' : 'mysqld',
      );
      debugPrint('XamppService: Checking Apache status...');
      _isApacheRunning = _checkProcessRunning(
        Platform.isWindows ? 'httpd.exe' : 'httpd',
      );
    }
  }

  Future<bool> startMySql({String? password}) async {
    if (_isMySqlRunning) {
      debugPrint('XamppService: MySQL already running, skipping');
      return true;
    }
    if (_xamppPath == null) {
      debugPrint('XamppService: XAMPP path not set, cannot start MySQL');
      return false;
    }

    debugPrint('XamppService: Attempting to start MySQL from $_xamppPath');
    try {
      if (Platform.isWindows) {
        debugPrint('XamppService: Running mysql_start.bat');
        final result = await Process.run(
          '$_xamppPath\\mysql_start.bat',
          [],
          runInShell: true,
        );
        debugPrint('XamppService: MySQL exit code: ${result.exitCode}');
        debugPrint('XamppService: MySQL stdout: ${result.stdout}');
        debugPrint('XamppService: MySQL stderr: ${result.stderr}');
        if (result.exitCode == 0) {
          _isMySqlRunning = true;
          debugPrint('XamppService: MySQL started successfully');
          return true;
        }
      } else if (Platform.isLinux) {
        if (password != null && password.isNotEmpty) {
          debugPrint('XamppService: Running sudo -S xampp startmysql');
          final result = await Process.run('sh', [
            '-c',
            'echo "$password" | sudo -S $_xamppPath/xampp startmysql'
          ]);
          debugPrint('XamppService: MySQL exit code: ${result.exitCode}');
          if (result.exitCode == 0) {
            _isMySqlRunning = true;
            return true;
          }
        } else {
          debugPrint('XamppService: Running pkexec xampp startmysql');
          final result = await Process.run('pkexec', [
            '$_xamppPath/xampp',
            'startmysql',
          ], runInShell: true);
          debugPrint('XamppService: MySQL exit code: ${result.exitCode}');
          if (result.exitCode == 0) {
            _isMySqlRunning = true;
            return true;
          }
        }
      } else if (Platform.isMacOS) {
        debugPrint('XamppService: Running osascript to start MySQL');
        final result = await Process.run('osascript', [
          '-e',
          'do shell script "/Applications/XAMPP/xamppfiles/xampp startmysql" with administrator privileges',
        ], runInShell: true);
        debugPrint('XamppService: MySQL exit code: ${result.exitCode}');
        debugPrint('XamppService: MySQL stdout: ${result.stdout}');
        debugPrint('XamppService: MySQL stderr: ${result.stderr}');
        if (result.exitCode == 0) {
          _isMySqlRunning = true;
          debugPrint('XamppService: MySQL started successfully');
          return true;
        }
      }
    } catch (e) {
      debugPrint('XamppService: Failed to start MySQL: $e');
    }
    debugPrint('XamppService: MySQL failed to start');
    return false;
  }

  Future<bool> startApache({String? password}) async {
    if (_isApacheRunning) {
      debugPrint('XamppService: Apache already running, skipping');
      return true;
    }
    if (_xamppPath == null) {
      debugPrint('XamppService: XAMPP path not set, cannot start Apache');
      return false;
    }

    debugPrint('XamppService: Attempting to start Apache from $_xamppPath');
    try {
      if (Platform.isWindows) {
        debugPrint('XamppService: Running apache_start.bat');
        final result = await Process.run(
          '$_xamppPath\\apache_start.bat',
          [],
          runInShell: true,
        );
        debugPrint('XamppService: Apache exit code: ${result.exitCode}');
        debugPrint('XamppService: Apache stdout: ${result.stdout}');
        debugPrint('XamppService: Apache stderr: ${result.stderr}');
        if (result.exitCode == 0) {
          _isApacheRunning = true;
          debugPrint('XamppService: Apache started successfully');
          return true;
        }
      } else if (Platform.isLinux) {
        if (password != null && password.isNotEmpty) {
          debugPrint('XamppService: Running sudo -S xampp startapache');
          final result = await Process.run('sh', [
            '-c',
            'echo "$password" | sudo -S $_xamppPath/xampp startapache'
          ]);
          debugPrint('XamppService: Apache exit code: ${result.exitCode}');
          if (result.exitCode == 0) {
            _isApacheRunning = true;
            return true;
          }
        } else {
          debugPrint('XamppService: Running pkexec xampp startapache');
          final result = await Process.run('pkexec', [
            '$_xamppPath/xampp',
            'startapache',
          ], runInShell: true);
          debugPrint('XamppService: Apache exit code: ${result.exitCode}');
          if (result.exitCode == 0) {
            _isApacheRunning = true;
            return true;
          }
        }
      } else if (Platform.isMacOS) {
        debugPrint('XamppService: Running osascript to start Apache');
        final result = await Process.run('osascript', [
          '-e',
          'do shell script "/Applications/XAMPP/xamppfiles/xampp startapache" with administrator privileges',
        ], runInShell: true);
        debugPrint('XamppService: Apache exit code: ${result.exitCode}');
        debugPrint('XamppService: Apache stdout: ${result.stdout}');
        debugPrint('XamppService: Apache stderr: ${result.stderr}');
        if (result.exitCode == 0) {
          _isApacheRunning = true;
          debugPrint('XamppService: Apache started successfully');
          return true;
        }
      }
    } catch (e) {
      debugPrint('XamppService: Failed to start Apache: $e');
    }
    debugPrint('XamppService: Apache failed to start');
    return false;
  }

  Future<void> startAll({String? password}) async {
    if (!kIsWeb &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      debugPrint('XamppService: Starting XAMPP services...');
      await checkStatus();
      if (!isInstalled) {
        debugPrint('XamppService: XAMPP is not installed, aborting');
        return;
      }
      if (!_isMySqlRunning) {
        await startMySql(password: password);
      }
      if (!_isApacheRunning) {
        await startApache(password: password);
      }
      debugPrint(
        'XamppService: StartAll complete. MySQL: $_isMySqlRunning, Apache: $_isApacheRunning',
      );
    }
  }
}
