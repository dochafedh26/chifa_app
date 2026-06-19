import 'package:chifa/services/db/database_manager.dart';
import 'package:chifa/services/db/database_manager.dart' as db_manager;
import 'package:chifa/services/db/sync_manager.dart';
import 'package:flutter/material.dart';

/// Hybrid Database Service
/// This class acts as the main interface for repositories.
/// It uses RemoteDatabaseService (MySQL) for immediate operations
/// and triggers SyncManager for background cloud synchronization.
class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  final SyncManager _sync = SyncManager();

  DatabaseService._internal();

  factory DatabaseService() {
    return _instance;
  }

  /// The active database service (XAMPP or Octenium)
  RemoteDatabaseService get _db => db_manager.DatabaseManager.instance;

  /// Check if connected to remote
  bool get isConnected =>
      db_manager.DatabaseManager.isInitialized && _db.isConnected;

  /// Connect/Initialize
  Future<void> connect() async {
    debugPrint('Database service ready');
    if (db_manager.DatabaseManager.secondary != null) {
      await _sync.trySync();
    }
  }

  String? _extractTableName(String sql) {
    final RegExp insertRegExp = RegExp(
      r'INSERT\s+INTO\s+[`"\[]?(\w+)[`"\]]?',
      caseSensitive: false,
    );
    final RegExp updateRegExp = RegExp(
      r'UPDATE\s+[`"\[]?(\w+)[`"\]]?',
      caseSensitive: false,
    );
    final RegExp deleteRegExp = RegExp(
      r'DELETE\s+FROM\s+[`"\[]?(\w+)[`"\]]?',
      caseSensitive: false,
    );

    final insertMatch = insertRegExp.firstMatch(sql);
    if (insertMatch != null) return insertMatch.group(1);

    final updateMatch = updateRegExp.firstMatch(sql);
    if (updateMatch != null) return updateMatch.group(1);

    final deleteMatch = deleteRegExp.firstMatch(sql);
    if (deleteMatch != null) return deleteMatch.group(1);

    return null;
  }

  Future<List<Map<String, dynamic>>> query(
    String sql, [
    List<dynamic>? params,
  ]) async {
    return await _db.query(sql, params);
  }

  Future<int> execute(String sql, [List<dynamic>? params]) async {
    return await _db.execute(sql, params);
  }

  Future<int> insert(String sql, [List<dynamic>? params]) async {
    return await _db.insert(sql, params);
  }

  Future<T> transaction<T>(Future<T> Function(DatabaseService) callback) async {
    return await _db.transaction((_) async {
      return await callback(this);
    });
  }

  Future<bool> tableExists(String tableName) async {
    return await _db.tableExists(tableName);
  }

  Future<bool> columnExists(String tableName, String columnName) async {
    return await _db.columnExists(tableName, columnName);
  }

  Future<List<String>> getTables() async {
    return await _db.getTables();
  }

  Future<void> runMigrations() async {
    await _db.runMigrations();
  }
}
