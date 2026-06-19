import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class ExportResult {
  final String patientId;
  final String status;
  final String message;
  final String? demPatientId;

  ExportResult({
    required this.patientId,
    required this.status,
    required this.message,
    this.demPatientId,
  });

  factory ExportResult.fromJson(Map<String, dynamic> json) {
    return ExportResult(
      patientId: json['patient_id'] ?? '',
      status: json['status'] ?? 'error',
      message: json['message'] ?? '',
      demPatientId: json['dem_patient_id'],
    );
  }
}

class DemBridgeService {
  static final DemBridgeService _instance = DemBridgeService._internal();
  factory DemBridgeService() => _instance;
  DemBridgeService._internal();

  String? _scriptPathCache;
  bool _isLoggedIn = false;

  Future<String> _getScriptPath() async {
    if (_scriptPathCache != null) return _scriptPathCache!;

    try {
      final currentDir = Directory.current.path;
      final scriptPath = path.join(currentDir, 'scripts', 'dem_bridge.py');
      final file = File(scriptPath);
      if (await file.exists()) {
        _scriptPathCache = scriptPath;
        return scriptPath;
      }

      final appDir = await getApplicationDocumentsDirectory();
      final possiblePaths = [
        path.join(currentDir, '..', 'scripts', 'dem_bridge.py'),
        path.join(appDir.parent.path, 'scripts', 'dem_bridge.py'),
      ];

      for (final p in possiblePaths) {
        if (await File(p).exists()) {
          _scriptPathCache = p;
          return p;
        }
      }

      _scriptPathCache = scriptPath;
      return scriptPath;
    } catch (e) {
      debugPrint('DEM Bridge: Error resolving script path: $e');
      _scriptPathCache = 'scripts/dem_bridge.py';
      return _scriptPathCache!;
    }
  }

  Future<Map<String, dynamic>> _runCommand(List<String> args) async {
    try {
      final scriptPath = await _getScriptPath();
      debugPrint('DEM Bridge: Running command with script: $scriptPath');
      debugPrint('DEM Bridge: Args: $args');

      final pythonExecutable = Platform.isWindows ? 'python' : 'python3';
      final result = await Process.run(pythonExecutable, [
        scriptPath,
        ...args,
      ]);

      debugPrint('DEM Bridge stdout: ${result.stdout}');
      debugPrint('DEM Bridge stderr: ${result.stderr}');
      debugPrint('DEM Bridge exitCode: ${result.exitCode}');

      if (result.exitCode == 0) {
        final output = result.stdout as String;
        return json.decode(output);
      } else {
        return {
          'status': 'error',
          'message': 'Command failed: ${result.stderr}',
        };
      }
    } catch (e) {
      debugPrint('DEM Bridge exception: $e');
      return {'status': 'error', 'message': 'Exception: $e'};
    }
  }

  Future<bool> login() async {
    debugPrint('DEM Bridge: Attempting login...');
    final result = await _runCommand(['login']);
    _isLoggedIn = result['status'] == 'success';
    debugPrint('DEM Bridge: Login ${_isLoggedIn ? "successful" : "failed"}');
    return _isLoggedIn;
  }

  Future<List<PatientData>> getServicePatients({
    String serviceId = '125',
  }) async {
    final result = await _runCommand(['get-patients', serviceId]);

    if (result['status'] == 'success') {
      final patients = result['patients'] as List;
      return patients.map((p) => PatientData.fromJson(p)).toList();
    }
    return [];
  }

  Future<PatientFullData?> getPatientData(String patientId) async {
    final result = await _runCommand(['get-patient', patientId]);

    if (result['status'] == 'success') {
      return PatientFullData.fromJson(result['data']);
    }
    return null;
  }



  /// Discharge a patient from DEM
  Future<bool> dischargePatient(
    String patientId, {
    String? dischargeDate,
    String? diagnostic,
  }) async {
    if (!_isLoggedIn) {
      await login();
    }

    final args = ['discharge', patientId];
    if (dischargeDate != null) args.add(dischargeDate);
    if (diagnostic != null) args.add(diagnostic);

    final result = await _runCommand(args);

    return result['status'] == 'success';
  }
}

class PatientData {
  final String id;
  final String name;

  PatientData({required this.id, required this.name});

  factory PatientData.fromJson(Map<String, dynamic> json) {
    return PatientData(id: json['id'] ?? '', name: json['name'] ?? '');
  }
}

class PatientFullData {
  final String patientId;
  final String admissionDate;
  final String diagnosis;
  final List<ObservationData> observations;
  final List<LabResultData> labResults;

  PatientFullData({
    required this.patientId,
    required this.admissionDate,
    required this.diagnosis,
    required this.observations,
    required this.labResults,
  });

  factory PatientFullData.fromJson(Map<String, dynamic> json) {
    return PatientFullData(
      patientId: json['patient_id'] ?? '',
      admissionDate: json['admission_date'] ?? '',
      diagnosis: json['diagnosis'] ?? '',
      observations: (json['observations'] as List? ?? [])
          .map((o) => ObservationData.fromJson(o))
          .toList(),
      labResults: (json['lab_results'] as List? ?? [])
          .map((l) => LabResultData.fromJson(l))
          .toList(),
    );
  }
}

class ObservationData {
  final String number;
  final String date;
  final String exam;

  ObservationData({
    required this.number,
    required this.date,
    required this.exam,
  });

  factory ObservationData.fromJson(Map<String, dynamic> json) {
    return ObservationData(
      number: json['number'] ?? '',
      date: json['date'] ?? '',
      exam: json['exam'] ?? '',
    );
  }
}

class LabResultData {
  final String date;
  final String patientId;

  LabResultData({required this.date, required this.patientId});

  factory LabResultData.fromJson(Map<String, dynamic> json) {
    return LabResultData(
      date: json['date'] ?? '',
      patientId: json['patient_id'] ?? '',
    );
  }
}


