import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'local_sqlite_service.dart';

/// Result returned after exporting local SinaClinic data to JSON & CSV.
class ClinicExportResult {
  final String jsonPath;
  final String csvPath;
  final Map<String, int> tableCounts;
  final DateTime exportedAt;

  const ClinicExportResult({
    required this.jsonPath,
    required this.csvPath,
    required this.tableCounts,
    required this.exportedAt,
  });

  int get totalRecords =>
      tableCounts.values.fold<int>(0, (sum, count) => sum + count);
}

/// Sovereign 1-click export service for SinaClinic (local-first SQLite).
///
/// Produces both:
/// 1. A complete JSON archive covering patients, appointments, medical
///    records, prescriptions, bilans, and invoices.
/// 2. A UTF-8 with BOM CSV file of active patients formatted for Microsoft
///    Excel / LibreOffice Calc.
class ClinicDataExportService {
  ClinicDataExportService._internal();
  static final ClinicDataExportService instance =
      ClinicDataExportService._internal();

  static const List<String> _exportTables = [
    'patients',
    'appointments',
    'medicalrecords',
    'prescriptions',
    'modern_prescriptions',
    'bilans',
    'invoices',
  ];

  static const List<String> _patientCsvColumns = [
    'patient_id',
    'uuid',
    'first_name',
    'last_name',
    'dob',
    'gender',
    'phone',
    'address',
    'national_id',
    'blood_group',
    'allergies',
    'notes',
    'created_at',
    'updated_at',
  ];

  Future<ClinicExportResult> exportClinicData({
    String clinicName = 'SinaClinic',
  }) async {
    if (kIsWeb) {
      throw UnsupportedError(
        'L\'export SQLite local est disponible uniquement sur l\'application Desktop/Mobile.',
      );
    }

    final db = await LocalSqliteService.instance.database;
    final exportedAt = DateTime.now();
    final stamp = _formatTimestamp(exportedAt);

    final docsDir = await getApplicationDocumentsDirectory();
    final exportDir = Directory(p.join(docsDir.path, 'SinaClinic_Exports'));
    if (!exportDir.existsSync()) {
      exportDir.createSync(recursive: true);
    }

    final existingTables = await _fetchExistingTables(db);
    final Map<String, List<Map<String, dynamic>>> tablesData = {};
    final Map<String, int> tableCounts = {};

    for (final table in _exportTables) {
      if (!existingTables.contains(table)) {
        tablesData[table] = const [];
        tableCounts[table] = 0;
        continue;
      }

      final rows = await _queryActiveRows(db, table);
      final sanitizedRows = rows
          .map((row) => _sanitizeRow(table, row))
          .toList(growable: false);
      tablesData[table] = sanitizedRows;
      tableCounts[table] = sanitizedRows.length;
    }

    final jsonFileName = 'sinaclinic_full_backup_$stamp.json';
    final csvFileName = 'sinaclinic_patients_$stamp.csv';
    final jsonPath = p.join(exportDir.path, jsonFileName);
    final csvPath = p.join(exportDir.path, csvFileName);

    final payload = <String, dynamic>{
      'brand': 'SinaClinic par MedevSync',
      'clinic_name': clinicName.trim().isEmpty ? 'SinaClinic' : clinicName.trim(),
      'exported_at': exportedAt.toUtc().toIso8601String(),
      'schema_version': 1,
      'table_counts': tableCounts,
      'tables': tablesData,
    };

    const encoder = JsonEncoder.withIndent('  ');
    await File(jsonPath).writeAsString(encoder.convert(payload), flush: true);

    final patientsRows = tablesData['patients'] ?? const <Map<String, dynamic>>[];
    final csvContent = _buildPatientsCsv(patientsRows);
    await File(csvPath).writeAsString('\uFEFF$csvContent', flush: true);

    return ClinicExportResult(
      jsonPath: jsonPath,
      csvPath: csvPath,
      tableCounts: tableCounts,
      exportedAt: exportedAt,
    );
  }

  Future<Set<String>> _fetchExistingTables(Database db) async {
    final rows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    );
    return rows
        .map((r) => r['name']?.toString() ?? '')
        .where((name) => name.isNotEmpty)
        .toSet();
  }

  Future<List<Map<String, dynamic>>> _queryActiveRows(
    Database db,
    String table,
  ) async {
    try {
      return await db.rawQuery(
        'SELECT * FROM $table WHERE COALESCE(is_deleted, 0) = 0',
      );
    } catch (_) {
      return await db.rawQuery('SELECT * FROM $table');
    }
  }

  Map<String, dynamic> _sanitizeRow(String table, Map<String, dynamic> row) {
    final copy = Map<String, dynamic>.from(row);
    if (table == 'patients') {
      copy.remove('portal_pin_hash');
    }
    return copy;
  }

  String _buildPatientsCsv(List<Map<String, dynamic>> rows) {
    final buffer = StringBuffer();
    buffer.writeln(_patientCsvColumns.join(','));
    for (final row in rows) {
      final line = _patientCsvColumns
          .map((col) => _escapeCsvField(row[col]?.toString() ?? ''))
          .join(',');
      buffer.writeln(line);
    }
    return buffer.toString();
  }

  String _escapeCsvField(String value) {
    final normalized = value.replaceAll('\r\n', ' ').replaceAll('\n', ' ');
    if (normalized.contains(',') ||
        normalized.contains('"') ||
        normalized.contains(';')) {
      return '"${normalized.replaceAll('"', '""')}"';
    }
    return normalized;
  }

  String _formatTimestamp(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    final ss = dt.second.toString().padLeft(2, '0');
    return '$y$m${d}_$hh$mm$ss';
  }
}
