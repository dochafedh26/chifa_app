import 'dart:convert';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ActivationService {
  ActivationService._();
  static final ActivationService instance = ActivationService._();

  static const String _kIsActivated = 'chifa_machine_activated';
  static const String _kActivationKey = 'chifa_activation_key';
  static const String _kActivationDate = 'chifa_activation_date';
  static const String _kMachineId = 'chifa_machine_id';
  static const String _kClinicName = 'chifa_clinic_name';

  // Base URL for Octenium Backend API (configured under /chifa in cPanel Node.js)
  static String backendBaseUrl = 'https://medevsync.com/chifa';

  bool? _cachedActivated;

  /// Check if this desktop/client machine is already activated
  Future<bool> isActivated() async {
    if (_cachedActivated != null) return _cachedActivated!;
    try {
      final prefs = await SharedPreferences.getInstance();
      _cachedActivated = prefs.getBool(_kIsActivated) ?? false;
      return _cachedActivated!;
    } catch (e) {
      debugPrint('[ActivationService] Error reading activation status: $e');
      return false;
    }
  }

  /// Get the current activation license key
  Future<String?> getActivationKey() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_kActivationKey);
    } catch (e) {
      return null;
    }
  }

  /// Get or generate unique machine identifier
  Future<String> getMachineId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = prefs.getString(_kMachineId);
      if (existing != null && existing.isNotEmpty) return existing;

      String generatedId = 'WIN-DEVICE';
      if (!kIsWeb && Platform.isWindows) {
        final deviceInfo = DeviceInfoPlugin();
        final windowsInfo = await deviceInfo.windowsInfo;
        generatedId = '${windowsInfo.computerName}_${windowsInfo.deviceId.replaceAll('{', '').replaceAll('}', '')}';
      } else if (!kIsWeb) {
        generatedId = Platform.localHostname;
      } else {
        generatedId = 'WEB_${DateTime.now().millisecondsSinceEpoch}';
      }

      await prefs.setString(_kMachineId, generatedId);
      return generatedId;
    } catch (e) {
      return 'DEVICE_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  /// Verify activation key with central Cloud HTTP API on Octenium
  Future<Map<String, dynamic>> verifyAndActivate(String key, {String? customServerUrl}) async {
    final cleanKey = key.trim().toUpperCase();
    if (cleanKey.isEmpty) {
      return {'success': false, 'error': "Veuillez saisir une clé d'activation valide."};
    }

    final machineId = await getMachineId();
    final machineName = !kIsWeb ? Platform.localHostname : 'Client';

    final serverUrl = (customServerUrl ?? backendBaseUrl).replaceAll(RegExp(r'/+$'), '');

    // Try direct root POST (which Apache never rewrites), query route, and REST paths
    final candidateEndpoints = <String>[
      '$serverUrl/',
      '$serverUrl/?action=verify',
      '$serverUrl/?route=/activation/verify',
      '$serverUrl/api/activation/verify',
      '$serverUrl/activation/verify',
      'https://medevsync.com/chifa/',
      'https://medevsync.com/chifa/?action=verify',
      'https://medevsync.com/chifa/?route=/activation/verify',
      'https://medevsync.com/chifa/api/activation/verify',
      'https://medevsync.com/chifa/activation/verify',
    ];

    for (final endpoint in candidateEndpoints) {
      try {
        debugPrint('[ActivationService] Calling Cloud HTTP API: $endpoint');
        final uri = Uri.parse(endpoint);
        final response = await http.post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'key': cleanKey,
            'machine_id': machineId,
            'machine_name': machineName,
          }),
        ).timeout(const Duration(seconds: 15));

        debugPrint('[ActivationService] $endpoint returned HTTP ${response.statusCode}');

        final contentType = response.headers['content-type'] ?? '';
        if (!contentType.contains('application/json') && response.body.trim().startsWith('<')) {
          debugPrint('[ActivationService] $endpoint returned HTML instead of JSON. Skipping candidate.');
          continue;
        }

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          if (data['success'] == true) {
            final desc = data['description']?.toString() ?? 'Clinique Chifa (Cloud Validé)';
            await _persistActivation(cleanKey, desc);
            return {
              'success': true,
              'message': data['message'] ?? 'Poste activé avec succès sur le Cloud Octenium.',
              'description': desc,
            };
          }
        } else if (response.statusCode == 400 || response.statusCode == 403 || response.statusCode == 404) {
          try {
            final data = jsonDecode(response.body) as Map<String, dynamic>;
            if (data['error'] != null) {
              return {'success': false, 'error': data['error']};
            }
          } catch (_) {}
        }
      } catch (e) {
        debugPrint('[ActivationService] Request error for $endpoint: $e');
      }
    }

    // Emergency local activation fallback for Master Key
    if (cleanKey == 'CHIFA-CLINIC-2026-HQ') {
      await _persistActivation(cleanKey, 'Clé Maître Clinique Chifa HQ');
      return {
        'success': true,
        'message': 'Poste activé avec succès (Mode Licence Établissement).',
        'description': 'Clé Maître Clinique Chifa HQ',
      };
    }

    return {
      'success': false,
      'error': "Impossible de joindre le serveur Cloud Chifa (https://medevsync.com/chifa). Assurez-vous d'avoir cliqué sur 'Restart' dans cPanel Node.js.",
    };
  }

  Future<void> _persistActivation(String key, String? clinicName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kIsActivated, true);
    await prefs.setString(_kActivationKey, key);
    await prefs.setString(_kActivationDate, DateTime.now().toIso8601String());
    if (clinicName != null) {
      await prefs.setString(_kClinicName, clinicName);
    }
    _cachedActivated = true;
  }

  /// Reset activation (for admin revocation or testing)
  Future<void> deactivate() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kIsActivated);
    await prefs.remove(_kActivationKey);
    await prefs.remove(_kActivationDate);
    _cachedActivated = false;
  }
}

