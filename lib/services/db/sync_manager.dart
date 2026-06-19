import 'dart:convert';

import 'package:chifa/app/widgets/xampp_connection_dialog.dart';
import 'package:chifa/services/db/database_manager.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

class SyncProgress {
  final bool isSyncing;
  final String? currentTable;
  final double progress;
  final String? error;

  SyncProgress({
    required this.isSyncing,
    this.currentTable,
    this.progress = 0.0,
    this.error,
  });
}

class SyncResult {
  final int pushedCount;
  final int pulledCount;
  final int conflictCount;
  final Duration duration;
  final String? error;

  SyncResult({
    this.pushedCount = 0,
    this.pulledCount = 0,
    this.conflictCount = 0,
    this.duration = Duration.zero,
    this.error,
  });
}

class SyncManager {
  static final SyncManager _instance = SyncManager._internal();

  static const int _maxRetries = 3;
  static const int _retryDelayMs = 1000;

  final ValueNotifier<SyncProgress> syncProgress = ValueNotifier(
    SyncProgress(isSyncing: false),
  );

  RemoteDatabaseService get _localDb => DatabaseManager.instance;
  RemoteDatabaseService? get _remoteDb => DatabaseManager.secondary;
  final Uuid _uuid = const Uuid();

  SyncManager._internal();

  factory SyncManager() {
    return _instance;
  }

  void _log(String level, String message, [Map<String, dynamic>? data]) {
    final timestamp = DateTime.now().toIso8601String();
    final dataStr = data != null ? ' ${jsonEncode(data)}' : '';
    debugPrint('[$timestamp] [$level] $message$dataStr');
  }

  void _logInfo(String msg, [Map<String, dynamic>? data]) =>
      _log('INFO', msg, data);
  void _logError(String msg, [Map<String, dynamic>? data]) =>
      _log('ERROR', msg, data);
  void _logWarn(String msg, [Map<String, dynamic>? data]) =>
      _log('WARN', msg, data);

  bool _isXamppConnectionError(dynamic error) {
    final errorStr = error.toString().toLowerCase();
    return errorStr.contains('econnrefused') ||
        errorStr.contains('connection refused') ||
        errorStr.contains('connect econnrefused');
  }

  void _handleXamppConnectionError(BuildContext context, dynamic error) {
    if (_isXamppConnectionError(error)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        XamppConnectionDialog.show(
          context,
          errorMessage: error.toString(),
          onRetry: () {
            syncProgress.value = SyncProgress(isSyncing: false);
            trySync(forceFullSync: true);
          },
        );
      });
    }
  }

  Future<void> trySync({String? tableName, bool forceFullSync = false}) async {
    if (!DatabaseManager.isInitialized || _remoteDb == null) {
      return;
    }

    final connectivityResult = await (Connectivity().checkConnectivity());
    if (!connectivityResult.contains(ConnectivityResult.none)) {
      if (tableName != null) {
        _logInfo('Real-time sync for table: $tableName');
        await syncTable(tableName);
      } else if (forceFullSync) {
        _logInfo('Starting full sync with Octenium...');
        await syncAll(forceFullSync: true);
      } else {
        _logInfo('Starting background sync with Octenium...');
        await syncAll();
      }
    }
  }

  Future<T> _withRetry<T>(Future<T> Function() fn, String context) async {
    dynamic lastError;
    for (int attempt = 1; attempt <= _maxRetries; attempt++) {
      try {
        return await fn();
      } catch (e) {
        lastError = e;
        _logWarn('Attempt $attempt/$_maxRetries failed for $context: $e');
        if (attempt < _maxRetries) {
          await Future.delayed(Duration(milliseconds: _retryDelayMs * attempt));
        }
      }
    }
    throw lastError;
  }

  Future<SyncResult> _syncSingleTable(
    String tableName, {
    bool forceFullSync = false,
  }) async {
    final stopwatch = Stopwatch()..start();
    int pushedCount = 0;
    int pulledCount = 0;
    int conflictCount = 0;

    try {
      final statusResult = await _localDb.query(
        'SELECT last_push_at, last_pull_at FROM sync_status WHERE table_name = ?',
        [tableName],
      );

      String lastPush = '1970-01-01 00:00:00';
      String lastPull = '1970-01-01 00:00:00';

      if (!forceFullSync && statusResult.isNotEmpty) {
        if (statusResult.first['last_push_at'] != null) {
          lastPush = statusResult.first['last_push_at'].toString();
        }
        if (statusResult.first['last_pull_at'] != null) {
          lastPull = statusResult.first['last_pull_at'].toString();
        }
      }

      final localChanges = await _localDb.query(
        'SELECT * FROM `$tableName` WHERE updated_at > ? AND needs_sync = 1 AND (source_id IS NULL OR source_id != "cloud_server")',
        [lastPush],
      );

      if (localChanges.isNotEmpty) {
        _logInfo('Pushing ${localChanges.length} local changes for $tableName');
        await _withRetry(
          () => _pushBatchToRemote(tableName, localChanges),
          'push $tableName',
        );
        pushedCount = localChanges.length;

        final uuids = localChanges
            .map((r) => r['uuid'])
            .where((u) => u != null)
            .toList();
        if (uuids.isNotEmpty) {
          final placeholders = List.filled(uuids.length, '?').join(', ');
          await _localDb.execute(
            'UPDATE `$tableName` SET needs_sync = 0, source_id = "local_server" WHERE uuid IN ($placeholders)',
            uuids,
          );
        }

        final now = DateTime.now()
            .toIso8601String()
            .replaceAll('T', ' ')
            .split('.')
            .first;
        await _localDb.execute(
          'INSERT INTO sync_status (table_name, last_push_at) VALUES (?, ?) ON DUPLICATE KEY UPDATE last_push_at = VALUES(last_push_at)',
          [tableName, now],
        );
      }

      final remoteChanges = await _remoteDb!.query(
        'SELECT * FROM `$tableName` WHERE updated_at > ? AND (source_id IS NULL OR source_id != "local_server")',
        [lastPull],
      );

      if (remoteChanges.isNotEmpty) {
        final localUuidRows = await _localDb.query(
          'SELECT uuid FROM `$tableName`',
        );
        final localUuidSet = localUuidRows
            .map((r) => r['uuid'])
            .where((u) => u != null)
            .toSet();

        for (final row in remoteChanges) {
          final uuid = row['uuid'];
          if (uuid != null && localUuidSet.contains(uuid)) {
            conflictCount++;
            _logWarn('Conflict detected for $tableName uuid=$uuid');
          }
        }

        _logInfo(
          'Pulling ${remoteChanges.length} remote changes for $tableName ($conflictCount conflicts)',
        );

        await _withRetry(
          () => _pullBatchToLocal(tableName, remoteChanges),
          'pull $tableName',
        );
        pulledCount = remoteChanges.length;

        final now = DateTime.now()
            .toIso8601String()
            .replaceAll('T', ' ')
            .split('.')
            .first;
        await _localDb.execute(
          'INSERT INTO sync_status (table_name, last_pull_at) VALUES (?, ?) ON DUPLICATE KEY UPDATE last_pull_at = VALUES(last_pull_at)',
          [tableName, now],
        );
      }

      stopwatch.stop();
      _logInfo(
        'Completed $tableName: pushed=$pushedCount, pulled=$pulledCount, conflicts=$conflictCount (${stopwatch.elapsedMilliseconds}ms)',
      );

      return SyncResult(
        pushedCount: pushedCount,
        pulledCount: pulledCount,
        conflictCount: conflictCount,
        duration: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      _logError('Error syncing table $tableName', {'message': e.toString()});
      return SyncResult(error: e.toString(), duration: stopwatch.elapsed);
    }
  }

  Future<void> _pushBatchToRemote(
    String tableName,
    List<Map<String, dynamic>> rows,
  ) async {
    if (rows.isEmpty) return;

    await _remoteDb!.transaction((conn) async {
      for (final row in rows) {
        final data = Map<String, dynamic>.from(row);
        data['source_id'] = 'local_server';
        data['needs_sync'] = 0;
        data['uuid'] = data['uuid'] ?? _uuid.v4();

        final keys = data.keys.map((k) => '`$k`').join(', ');

        // Use named parameters for mysql_client
        final namedParams = <String, dynamic>{};
        final placeholders = <String>[];
        var i = 0;
        for (final key in data.keys) {
          final paramName = 'p$i';
          placeholders.add(':$paramName');
          namedParams[paramName] = data[key];
          i++;
        }

        final updates = data.keys
            .map((k) {
              if (k == 'updated_at') {
                return '`updated_at` = IF(VALUES(`updated_at`) > `updated_at`, VALUES(`updated_at`), `updated_at`)';
              }
              return '`$k` = IF(VALUES(`updated_at`) > `updated_at`, VALUES(`$k`), `$k`)';
            })
            .join(', ');

        final sql =
            'INSERT INTO `$tableName` ($keys) VALUES (${placeholders.join(', ')}) ON DUPLICATE KEY UPDATE $updates';
        _logInfo('Pushing to $tableName: uuid=${data['uuid']}');
        await conn.execute(sql, namedParams);
      }
    });
  }

  Future<void> _pullBatchToLocal(
    String tableName,
    List<Map<String, dynamic>> rows,
  ) async {
    if (rows.isEmpty) return;

    await _localDb.transaction((conn) async {
      for (final row in rows) {
        final data = Map<String, dynamic>.from(row);
        data['source_id'] = 'cloud_server';
        data['needs_sync'] = 0;

        final keys = data.keys.map((k) => '`$k`').join(', ');

        // Use named parameters for mysql_client
        final namedParams = <String, dynamic>{};
        final placeholders = <String>[];
        var i = 0;
        for (final key in data.keys) {
          final paramName = 'p$i';
          placeholders.add(':$paramName');
          namedParams[paramName] = data[key];
          i++;
        }

        final updates = data.keys
            .map((k) {
              if (k == 'updated_at') {
                return '`updated_at` = IF(VALUES(`updated_at`) > `updated_at`, VALUES(`updated_at`), `updated_at`)';
              }
              return '`$k` = IF(VALUES(`updated_at`) > `updated_at`, VALUES(`$k`), `$k`)';
            })
            .join(', ');

        final sql =
            'INSERT INTO `$tableName` ($keys) VALUES (${placeholders.join(', ')}) ON DUPLICATE KEY UPDATE $updates';
        await conn.execute(sql, namedParams);
      }
    });
  }

  Future<void> syncAll({bool forceFullSync = false}) async {
    if (_remoteDb == null) return;

    try {
      _logInfo('Verifying remote connection for sync...');
      await _remoteDb!.query('SELECT 1');
    } catch (e) {
      try {
        _logWarn('Remote connection lost. Attempting to reconnect...');
        await _remoteDb!.connectToOctenium();
      } catch (e2) {
        _logError('Reconnection failed: $e2');
        syncProgress.value = SyncProgress(
          isSyncing: false,
          error: 'Database Offline',
        );
        return;
      }
    }

    final tables = [
      'patients',
      'appointments',
      'medicalrecords',
      'medicalrecord_services',
      'prescriptions',
      'modern_prescriptions',
      'bilans',
      'bilan_type',
      'invoices',
      'payments',
      'expenses',
      'employees',
      'hospitalizations',
      'inventory',
      'soins_medicaux',
      'soins_services',
      'lettres',
      'arret_de_travail',
      'certificat_bonne_sante',
      'certificat_dispense_sport',
      'certificat_maladie_chronique',
      'certificat_prenuptial',
      'ordonnance_type',
      'patients_fideles',
      'patients_suivi',
      'patient_suivi_categories',
      'medalgeriemedics',
    ];

    syncProgress.value = SyncProgress(
      isSyncing: true,
      currentTable: tables.first,
      progress: 0.0,
    );

    int totalPushed = 0;
    int totalPulled = 0;
    int totalConflicts = 0;
    final failedTables = <String>[];

    try {
      for (int i = 0; i < tables.length; i++) {
        final table = tables[i];
        syncProgress.value = SyncProgress(
          isSyncing: true,
          currentTable: table,
          progress: i / tables.length,
        );

        try {
          if (await _localDb.tableExists(table) &&
              await _remoteDb!.tableExists(table)) {
            final result = await _syncSingleTable(
              table,
              forceFullSync: forceFullSync,
            );
            totalPushed += result.pushedCount;
            totalPulled += result.pulledCount;
            totalConflicts += result.conflictCount;
          }
        } catch (e) {
          if (_isXamppConnectionError(e)) {
            _logError('XAMPP connection error detected: $e');
            syncProgress.value = SyncProgress(
              isSyncing: false,
              error: e.toString(),
            );
            return;
          }
          _logError('Failed to sync table $table');
          failedTables.add(table);
        }
      }
    } catch (e) {
      _logError('Global sync error: $e');
      syncProgress.value = SyncProgress(isSyncing: false, error: e.toString());
      return;
    }

    _logInfo('Sync completed', {
      'totalPushed': totalPushed,
      'totalPulled': totalPulled,
      'totalConflicts': totalConflicts,
      'failedTables': failedTables.isEmpty ? 'none' : failedTables.join(', '),
    });

    syncProgress.value = SyncProgress(isSyncing: false, progress: 1.0);
  }

  Future<void> syncTable(String tableName) async {
    if (_remoteDb == null) return;

    try {
      await _pushLocalToRemote(tableName);
      await _pullRemoteToLocal(tableName);
    } catch (e) {
      _logError('Error syncing table $tableName', {'message': e.toString()});
    }
  }

  Future<void> _pushLocalToRemote(String tableName) async {
    final localChanges = await _localDb.query(
      'SELECT * FROM `$tableName` WHERE needs_sync = 1 AND (source_id IS NULL OR source_id != "cloud_server")',
    );

    for (final row in localChanges) {
      final Map<String, dynamic> data = Map.from(row);
      final uuid = data['uuid'] ?? _uuid.v4();
      data['uuid'] = uuid;
      data['needs_sync'] = 0;
      data['source_id'] = 'local_server';

      final keys = data.keys.map((k) => '`$k`').join(', ');
      final placeholders = data.keys.map((_) => '?').join(', ');
      final updates = data.keys
          .map((k) {
            if (k == 'updated_at') {
              return '`updated_at` = IF(VALUES(`updated_at`) > `updated_at`, VALUES(`updated_at`), `updated_at`)';
            }
            return '`$k` = IF(VALUES(`updated_at`) > `updated_at`, VALUES(`$k`), `$k`)';
          })
          .join(', ');

      final sql =
          'INSERT INTO `$tableName` ($keys) VALUES ($placeholders) ON DUPLICATE KEY UPDATE $updates';

      await _remoteDb!.execute(sql, data.values.toList());

      final pkColumn = _guessPkColumn(tableName, data.keys.toList());
      if (pkColumn != null && data[pkColumn] != null) {
        await _localDb.execute(
          'UPDATE `$tableName` SET needs_sync = 0, uuid = ?, source_id = "local_server" WHERE `$pkColumn` = ?',
          [uuid, data[pkColumn]],
        );
      } else {
        await _localDb.execute(
          'UPDATE `$tableName` SET needs_sync = 0, uuid = ?, source_id = "local_server" WHERE uuid = ?',
          [uuid, uuid],
        );
      }
    }
  }

  String? _guessPkColumn(String table, List<String> columns) {
    const pkNames = [
      'id',
      'patient_id',
      'appointment_id',
      'record_id',
      'employee_id',
      'expense_id',
      'item_id',
      'soins_id',
      'payment_id',
      'soin_id',
      'billing_id',
      'invoice_id',
    ];
    for (final name in pkNames) {
      if (columns.contains(name)) return name;
    }
    final tableId = '${table}_id';
    if (columns.contains(tableId)) return tableId;
    if (table.endsWith('s')) {
      final singularId = '${table.substring(0, table.length - 1)}_id';
      if (columns.contains(singularId)) return singularId;
    }
    return null;
  }

  Future<void> _pullRemoteToLocal(String tableName) async {
    final lastSyncResult = await _localDb.query(
      'SELECT last_pull_at FROM sync_status WHERE table_name = ?',
      [tableName],
    );

    String lastPull =
        lastSyncResult.isNotEmpty &&
            lastSyncResult.first['last_pull_at'] != null
        ? lastSyncResult.first['last_pull_at'].toString()
        : '1970-01-01 00:00:00';

    final remoteChanges = await _remoteDb!.query(
      'SELECT * FROM `$tableName` WHERE updated_at > ? AND (source_id IS NULL OR source_id != "local_server")',
      [lastPull],
    );

    for (final row in remoteChanges) {
      final Map<String, dynamic> data = Map.from(row);
      data['needs_sync'] = 0;
      data['source_id'] = 'cloud_server';

      final keys = data.keys.map((k) => '`$k`').join(', ');
      final placeholders = data.keys.map((_) => '?').join(', ');
      final updates = data.keys
          .map((k) {
            if (k == 'updated_at') {
              return '`updated_at` = IF(VALUES(`updated_at`) > `updated_at`, VALUES(`updated_at`), `updated_at`)';
            }
            return '`$k` = IF(VALUES(`updated_at`) > `updated_at`, VALUES(`$k`), `$k`)';
          })
          .join(', ');

      final sql =
          'INSERT INTO `$tableName` ($keys) VALUES ($placeholders) ON DUPLICATE KEY UPDATE $updates';
      await _localDb.execute(sql, data.values.toList());
    }

    final now = DateTime.now()
        .toIso8601String()
        .replaceAll('T', ' ')
        .split('.')
        .first;
    await _localDb.execute(
      'INSERT INTO sync_status (table_name, last_pull_at) VALUES (?, ?) ON DUPLICATE KEY UPDATE last_pull_at = VALUES(last_pull_at)',
      [tableName, now],
    );
  }

  String generateUuid() => _uuid.v4();
}
