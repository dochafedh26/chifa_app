import 'dart:convert';

import 'package:chifa/services/db/database_manager.dart';
import 'package:flutter/foundation.dart';

/// Detects and fixes UTF-8 double-encoded text.
///
/// Double-encoding happens when UTF-8 bytes are misinterpreted as Latin-1:
/// "symptômes" → bytes C3 B4 (UTF-8 for ô) → stored as two chars Ã´ → "symptÃ´mes"
///
/// The fix: re-encode the garbled string as Latin-1 bytes, then decode as UTF-8.
/// This is safe: correctly-encoded French chars (é, ô) have Latin-1 byte values
/// that are NOT valid as standalone UTF-8 bytes, so they'll throw and be skipped.
String fixDoubleEncodedUtf8(String text) {
  if (text.isEmpty) return text;
  try {
    final bytes = latin1.encode(text);
    final fixed = utf8.decode(bytes);
    if (fixed.length >= text.length) return text;
    return fixed;
  } catch (_) {
    return text;
  }
}

/// Scans all text columns across all tables and repairs double-encoded UTF-8 data.
Future<void> repairAllDoubleEncodedData(RemoteDatabaseService db) async {
  debugPrint('Starting double-encoded UTF-8 data repair...');

  final tables = await db.getTables();
  int totalFixed = 0;
  int totalRowsChecked = 0;

  for (final table in tables) {
    if (table == 'sync_status') continue;

    final columns = await db.query('''
      SELECT column_name, data_type
      FROM information_schema.columns
      WHERE table_schema = DATABASE()
        AND table_name = ?
        AND data_type IN ('char','varchar','tinytext','text','mediumtext','longtext')
    ''', [table]);

    if (columns.isEmpty) continue;

    final textCols = columns.map((c) => c['column_name'].toString()).toList();
    final idCol = await _getIdColumn(db, table);
    if (idCol == null) {
      debugPrint('No PK/UNIQUE column found for $table, skipping');
      continue;
    }

    const batchSize = 100;
    int offset = 0;

    while (true) {
      final rows = await db.query(
        'SELECT * FROM `$table` ORDER BY `$idCol` LIMIT ? OFFSET ?',
        [batchSize, offset],
      );

      if (rows.isEmpty) break;
      totalRowsChecked += rows.length;

      for (final row in rows) {
        final updates = <String, dynamic>{};

        for (final col in textCols) {
          final value = row[col];
          if (value is! String || value.isEmpty) continue;

          final fixed = fixDoubleEncodedUtf8(value);
          if (fixed != value) {
            updates[col] = fixed;
          }
        }

        if (updates.isNotEmpty) {
          final id = row[idCol];
          if (id == null) continue;

          final setClauses = <String>[];
          final updateParams = <dynamic>[];
          for (final entry in updates.entries) {
            setClauses.add('`${entry.key}` = ?');
            updateParams.add(entry.value);
          }
          updateParams.add(id);

          await db.execute(
            'UPDATE `$table` SET ${setClauses.join(', ')} WHERE `$idCol` = ?',
            updateParams,
          );
          totalFixed++;
        }
      }

      offset += batchSize;
    }
  }

  debugPrint(
    'Encoding repair complete. Checked $totalRowsChecked rows, fixed $totalFixed rows.',
  );
}

Future<String?> _getIdColumn(RemoteDatabaseService db, String table) async {
  final pkCols = await db.query('''
    SELECT column_name
    FROM information_schema.columns
    WHERE table_schema = DATABASE()
      AND table_name = ?
      AND column_key = 'PRI'
    LIMIT 1
  ''', [table]);

  if (pkCols.isNotEmpty) {
    return pkCols.first['column_name'].toString();
  }

  for (final col in ['id', 'uuid', 'patient_id', 'employee_id']) {
    final result = await db.query(
      "SELECT column_name FROM information_schema.columns WHERE table_schema = DATABASE() AND table_name = ? AND column_name = ?",
      [table, col],
    );
    if (result.isNotEmpty) return col;
  }

  return null;
}
