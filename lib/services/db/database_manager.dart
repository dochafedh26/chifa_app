import 'dart:async';
import 'package:chifa/services/db/database_migrations.dart';
import 'package:chifa/services/db/http_api_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mysql_client/mysql_client.dart';

/// Database configuration for XAMPP MySQL (Local)
class XamppDatabaseConfig {
  static String get host => dotenv.env['LOCAL_DB_HOST'] ?? 'localhost';
  static int get port => int.tryParse(dotenv.env['LOCAL_DB_PORT'] ?? '') ?? 3306;
  static String get database => dotenv.env['LOCAL_DB_NAME'] ?? 'clinic';
  static String get user => dotenv.env['LOCAL_DB_USER'] ?? 'chiffa';
  static String get password => dotenv.env['LOCAL_DB_PASSWORD'] ?? '';
}

/// Database configuration for Octenium MySQL (Remote)
class OcteniumDatabaseConfig {
  static String get host => dotenv.env['REMOTE_DB_HOST'] ?? 'srv50.octenium.net';
  static int get port => int.tryParse(dotenv.env['REMOTE_DB_PORT'] ?? '') ?? 3306;
  static String get database => dotenv.env['REMOTE_DB_NAME'] ?? 'rnhgnubg_chifa';
  static String get user => dotenv.env['REMOTE_DB_USER'] ?? 'rnhgnubg_chifa';
  static String get password => dotenv.env['REMOTE_DB_PASSWORD'] ?? 'MyNetPass@2026';
}

class RemoteDatabaseService {
  MySQLConnection? _connection;
  String? _mode; // 'octenium', 'xampp', or 'direct'
  String? _directHost;
  int? _directPort;
  String? _directUser;
  String? _directPassword;
  String? _directDatabase;
  bool _directSecure = true;
  Future<void>? _lock;
  ApiDatabaseService? _fallbackApi;

  bool get isConnected => _connection?.connected ?? false;

  /// Serialize operations on the single MySQLConnection socket to prevent
  /// concurrent packet interleaving or unexpected socket closure.
  Future<T> _synchronized<T>(Future<T> Function() action) async {
    while (_lock != null) {
      try {
        await _lock;
      } catch (_) {}
    }
    final completer = Completer<void>();
    _lock = completer.future;
    try {
      return await action();
    } finally {
      _lock = null;
      completer.complete();
    }
  }

  bool _isConnectionClosedError(Object e) {
    final msg = e.toString().toLowerCase();
    return msg.contains('connection closed') ||
        msg.contains('not connected') ||
        msg.contains('can not execute query') ||
        msg.contains('socket') ||
        msg.contains('broken pipe') ||
        msg.contains('connection reset') ||
        msg.contains('closed');
  }

  /// Ensure the underlying MySQLConnection is open, reconnecting if needed.
  Future<void> _ensureConnected() async {
    if (_connection != null && _connection!.connected) {
      return;
    }

    try {
      await _connection?.close();
    } catch (_) {}
    _connection = null;

    debugPrint('🔄 Reconnecting to MySQL database (mode: ${_mode ?? "octenium"})...');
    if (_mode == 'xampp') {
      await connectToXampp();
    } else if (_mode == 'direct' && _directHost != null) {
      await connectDirectly(
        host: _directHost!,
        port: _directPort ?? 3306,
        user: _directUser ?? '',
        password: _directPassword ?? '',
        database: _directDatabase ?? '',
        secure: _directSecure,
      );
    } else {
      await connectToOctenium();
    }
  }

  /// Connect to database using XAMPP configuration
  Future<void> connectToXampp() async {
    _mode = 'xampp';
    try {
      _connection = await MySQLConnection.createConnection(
        host: XamppDatabaseConfig.host,
        port: XamppDatabaseConfig.port,
        userName: XamppDatabaseConfig.user,
        password: XamppDatabaseConfig.password,
        databaseName: XamppDatabaseConfig.database,
        secure: false,
      );
      debugPrint(
        'Attempting to connect to ${XamppDatabaseConfig.host}:${XamppDatabaseConfig.port} as ${XamppDatabaseConfig.user}...',
      );
      await _connection!.connect(timeoutMs: 60000);
      debugPrint('Connected to XAMPP database');
    } catch (e) {
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('econnrefused') ||
          errorStr.contains('connection refused')) {
        debugPrint('XAMPP connection refused - XAMPP may not be running: $e');
      } else {
        debugPrint('Error connecting to XAMPP database: $e');
      }
      rethrow;
    }
  }

  /// Connect to database using Octenium configuration directly
  Future<void> connectToOctenium() async {
    _mode = 'octenium';
    try {
      _connection = await MySQLConnection.createConnection(
        host: OcteniumDatabaseConfig.host,
        port: OcteniumDatabaseConfig.port,
        userName: OcteniumDatabaseConfig.user,
        password: OcteniumDatabaseConfig.password,
        databaseName: OcteniumDatabaseConfig.database,
        secure: false, // Set to true if Octenium supports SSL
      );

      await _connection!.connect(timeoutMs: 60000);
      debugPrint('Connected directly to Octenium database');
    } catch (e) {
      debugPrint('Connection to Octenium failed: $e');
      rethrow;
    }
  }

  /// Connect to a remote MySQL database directly (supports SSL)
  Future<void> connectDirectly({
    required String host,
    required int port,
    required String user,
    required String password,
    required String database,
    bool secure = true,
  }) async {
    _mode = 'direct';
    _directHost = host;
    _directPort = port;
    _directUser = user;
    _directPassword = password;
    _directDatabase = database;
    _directSecure = secure;
    try {
      _connection = await MySQLConnection.createConnection(
        host: host,
        port: port,
        userName: user,
        password: password,
        databaseName: database,
        secure: secure,
      );
      await _connection!.connect(timeoutMs: 60000);
      debugPrint('Connected directly to MySQL database');
    } catch (e) {
      debugPrint('Error connecting directly to MySQL: $e');
      rethrow;
    }
  }

  /// Helper to convert positional SQL (?) to named params for mysql_client
  String _prepareSql(
    String sql,
    List<dynamic>? params,
    Map<String, dynamic> namedParams,
  ) {
    if (params == null || params.isEmpty) return sql;

    var index = 0;
    return sql.replaceAllMapped('?', (match) {
      final name = 'p${index++}';
      namedParams[name] = params[index - 1];
      return ':$name';
    });
  }

  /// Internal helper that serializes execution, ensures an active connection,
  /// and automatically reconnects + retries once if the MySQL socket was closed.
  Future<IResultSet> _executeWithReconnect(
    String processedSql,
    Map<String, dynamic> namedParams,
  ) async {
    return _synchronized(() async {
      await _ensureConnected();
      try {
        return await _connection!.execute(processedSql, namedParams);
      } catch (e) {
        if (_isConnectionClosedError(e)) {
          debugPrint('⚠️ MySQL connection lost ($e). Reconnecting and retrying...');
          try {
            await _connection?.close();
          } catch (_) {}
          _connection = null;
          await _ensureConnected();
          return await _connection!.execute(processedSql, namedParams);
        }
        rethrow;
      }
    });
  }

  /// Execute a query and return results
  Future<List<Map<String, dynamic>>> query(
    String sql, [
    List<dynamic>? params,
  ]) async {
    final Map<String, dynamic> namedParams = {};
    final processedSql = _prepareSql(sql, params, namedParams);

    try {
      final result = await _executeWithReconnect(processedSql, namedParams);
      return result.rows.map((row) => row.typedAssoc()).toList();
    } catch (e) {
      if (_mode == 'octenium' && _isConnectionClosedError(e)) {
        debugPrint('⚠️ Falling back to Octenium HTTP API for query...');
        _fallbackApi ??= ApiDatabaseService()..connect();
        return await _fallbackApi!.query(sql, params);
      }
      rethrow;
    }
  }

  /// Execute an insert, update, or delete
  Future<int> execute(String sql, [List<dynamic>? params]) async {
    final Map<String, dynamic> namedParams = {};
    final processedSql = _prepareSql(sql, params, namedParams);

    try {
      final result = await _executeWithReconnect(processedSql, namedParams);
      return result.affectedRows.toInt();
    } catch (e) {
      if (_mode == 'octenium' && _isConnectionClosedError(e)) {
        debugPrint('⚠️ Falling back to Octenium HTTP API for execute...');
        _fallbackApi ??= ApiDatabaseService()..connect();
        return await _fallbackApi!.execute(sql, params);
      }
      rethrow;
    }
  }

  /// Execute a transaction
  Future<T> transaction<T>(
    Future<T> Function(MySQLConnection conn) callback,
  ) async {
    await _synchronized(() => _ensureConnected());

    try {
      await execute('START TRANSACTION');
      final result = await callback(_connection!);
      await execute('COMMIT');
      return result;
    } catch (e) {
      try {
        if (_connection != null && _connection!.connected) {
          await execute('ROLLBACK');
        }
      } catch (_) {}

      if (_isConnectionClosedError(e)) {
        debugPrint('⚠️ Transaction failed due to closed connection ($e). Reconnecting and retrying...');
        await _synchronized(() async {
          try {
            await _connection?.close();
          } catch (_) {}
          _connection = null;
          await _ensureConnected();
        });
        await execute('START TRANSACTION');
        try {
          final result = await callback(_connection!);
          await execute('COMMIT');
          return result;
        } catch (retryError) {
          try {
            if (_connection != null && _connection!.connected) {
              await execute('ROLLBACK');
            }
          } catch (_) {}
          rethrow;
        }
      }
      rethrow;
    }
  }

  /// Insert and return the last inserted ID
  Future<int> insert(String sql, [List<dynamic>? params]) async {
    final Map<String, dynamic> namedParams = {};
    final processedSql = _prepareSql(sql, params, namedParams);

    try {
      final result = await _executeWithReconnect(processedSql, namedParams);
      return result.lastInsertID.toInt();
    } catch (e) {
      if (_mode == 'octenium' && _isConnectionClosedError(e)) {
        debugPrint('⚠️ Falling back to Octenium HTTP API for insert...');
        _fallbackApi ??= ApiDatabaseService()..connect();
        return await _fallbackApi!.insert(sql, params);
      }
      rethrow;
    }
  }

  /// Check if a column exists in a table
  Future<bool> columnExists(String tableName, String columnName) async {
    try {
      final results = await query(
        'SELECT COUNT(*) as count FROM information_schema.columns '
        'WHERE table_schema = DATABASE() AND table_name = ? AND column_name = ?',
        [tableName, columnName],
      );
      final countVal = results.first['count'];
      final count = countVal is int
          ? countVal
          : (countVal is String ? int.tryParse(countVal) ?? 0 : 0);
      return count > 0;
    } catch (e) {
      debugPrint('Error checking if column exists: $e');
      return false;
    }
  }

  /// Check if the database is empty and bootstrap if necessary
  Future<void> checkAndBootstrap() async {
    if (_connection == null) return;

    try {
      // Check if a core table exists (e.g., patients)
      final tables = await query('SHOW TABLES LIKE "patients"');
      if (tables.isEmpty) {
        debugPrint('Database is empty. Starting bootstrap process...');
        await bootstrapFromAsset(
          'lib/services/db/sql_statmenets/clinic_exported_cloud.sql',
        );
      } else {
        debugPrint('Database already populated.');
      }
    } catch (e) {
      debugPrint('Error checking database status: $e');
    }
  }

  /// Execute a SQL dump from an asset file
  Future<void> bootstrapFromAsset(String assetPath) async {
    if (_connection == null) return;

    try {
      final sqlContent = await rootBundle.loadString(assetPath);
      final statements = _splitSqlStatements(sqlContent);

      debugPrint('Executing ${statements.length} SQL statements...');

      int executedCount = 0;
      await _connection!.transactional((ctx) async {
        for (var statement in statements) {
          if (statement.trim().isEmpty) continue;
          try {
            await ctx.execute(statement);
            executedCount++;
            if (executedCount % 100 == 0) {
              debugPrint('Progress: $executedCount/${statements.length}...');
            }
          } catch (e) {
            debugPrint(
              'Warning: Failed to execute statement: ${statement.substring(0, 50)}... Error: $e',
            );
          }
        }
      });

      debugPrint(
        'Bootstrap completed successfully! Executed $executedCount statements.',
      );
    } catch (e) {
      debugPrint('Error during SQL bootstrap: $e');
    }
  }

  /// Helper to split SQL dump into individual statements
  List<String> _splitSqlStatements(String sql) {
    // Basic splitting by semicolon followed by newline
    // This handles most phpMyAdmin exports well
    final List<String> statements = [];
    final lines = sql.split('\n');
    var currentStatement = StringBuffer();

    for (var line in lines) {
      final trimmedLine = line.trim();
      if (trimmedLine.isEmpty ||
          trimmedLine.startsWith('--') ||
          trimmedLine.startsWith('/*')) {
        continue;
      }

      currentStatement.writeln(line);

      if (trimmedLine.endsWith(';')) {
        statements.add(currentStatement.toString().trim());
        currentStatement = StringBuffer();
      }
    }

    // Add any remaining content
    if (currentStatement.isNotEmpty) {
      statements.add(currentStatement.toString().trim());
    }

    return statements;
  }

  /// Close database connection
  Future<void> close() async {
    if (_connection != null) {
      await _connection!.close();
      debugPrint('Database connection closed');
    }
  }

  /// Run all schema migrations
  Future<void> runMigrations() async {
    debugPrint('🔄 Starting database migrations...');
    if (_connection == null) {
      throw Exception('Database connection is not established');
    }

    try {
      // Create tables if they don't exist and add sync columns
      await DatabaseMigrations.runMigrations(this);
      debugPrint('✅ Migrations completed for this database instance.');
    } catch (e) {
      debugPrint('❌ Error running remote migrations: $e');
      rethrow;
    }
  }

  /// Check if table exists
  Future<bool> tableExists(String table) async {
    final results = await query(
      "SELECT COUNT(*) as count FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = ?",
      [table],
    );
    return results.isNotEmpty &&
        (int.tryParse(results.first['count'].toString()) ?? 0) > 0;
  }

  /// List all tables
  Future<List<String>> getTables() async {
    final results = await query("SHOW TABLES");
    return results.map((row) => row.values.first.toString()).toList();
  }
}

class DatabaseManager {
  static RemoteDatabaseService? _primary;
  static dynamic _secondary;
  static ApiDatabaseService? _webApi;

  static Future<void> initialize({String? databaseType}) async {
    final isMobile = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
    final isWeb = kIsWeb;

    // Logic:
    // - Web: Use Octenium HTTP API relay
    // - Mobile (Android/iOS): Connect directly to Octenium MySQL with HTTP relay fallback
    // - Desktop (Windows): XAMPP as local primary, Octenium as sync (fallback to Octenium if XAMPP offline)
    bool useOcteniumAsPrimary = isMobile || databaseType == 'octenium';
    bool useWebApi = isWeb || databaseType == 'web';

    if (useWebApi) {
      debugPrint('Initializing Octenium Web API service...');
      _primary = null;
      _webApi = ApiDatabaseService();
      await _webApi!.connect();
      return;
    }

    final candidatePrimary = RemoteDatabaseService();

    if (useOcteniumAsPrimary) {
      debugPrint('Connecting to Octenium as primary cloud database...');
      try {
        await candidatePrimary.connectToOctenium();
        await candidatePrimary.checkAndBootstrap();
        _primary = candidatePrimary;
        _webApi = null;
        _secondary = null;
      } catch (e) {
        debugPrint('Direct Octenium MySQL connection notice ($e). Using Octenium HTTP API relay...');
        _primary = null;
        _webApi = ApiDatabaseService();
        await _webApi!.connect();
        return;
      }
    } else {
      debugPrint('Connecting to local database as primary...');
      try {
        await candidatePrimary.connectToXampp();
        await candidatePrimary.checkAndBootstrap();
        _primary = candidatePrimary;
        _webApi = null;

        // Setup background sync connection to Octenium on Desktop
        final octeniumSync = RemoteDatabaseService();
        try {
          debugPrint('Setting up background sync connection to Octenium...');
          await octeniumSync.connectToOctenium();
          _secondary = octeniumSync;
          debugPrint('Octenium background sync connection established.');
        } catch (e) {
          debugPrint('Direct Octenium sync notice: $e. Falling back to HTTP sync...');
          try {
            final apiService = ApiDatabaseService();
            await apiService.connect();
            _secondary = apiService;
          } catch (_) {
            _secondary = null;
          }
        }
      } catch (e) {
        debugPrint('Local database connection failed: $e');
        rethrow;
      }
    }

    // Run migrations on primary
    if (_primary != null) {
      await _primary!.runMigrations();
    }

    // Run migrations on secondary (Cloud) if it exists
    if (_secondary != null && _secondary is RemoteDatabaseService) {
      debugPrint('Running migrations on secondary database...');
      await _secondary!.runMigrations();
    }
  }

  static bool get isInitialized => _primary != null || _webApi != null;

  static dynamic get instance {
    if (_webApi != null) return _webApi;
    if (_primary != null) return _primary;
    _webApi = ApiDatabaseService()..connect();
    return _webApi;
  }

  static ApiDatabaseService? get webApi => _webApi;
  static RemoteDatabaseService? get remote => _primary;
  static dynamic get secondary => _secondary;
}
