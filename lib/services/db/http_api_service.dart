import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class ApiConfig {
  // Supabase cloud backend API base URL
  static String get baseUrl {
    if (kIsWeb) {
      // In browser, dynamically use the current host origin (e.g. https://medevsync.com)
      final currentOrigin = Uri.base.origin;
      return '$currentOrigin/chifa/api';
    }
    final envUrl = dotenv.env['BACKEND_API_URL'];
    if (envUrl != null && envUrl.isNotEmpty) {
      return envUrl;
    }
    return 'https://srv50.octenium.net/chifa/api';
  }

  static String get syncKey => dotenv.env['SYNC_KEY'] ?? 'chifa_sync_secure_key_2026';
  static const Duration timeout = Duration(seconds: 30);
}

class HttpApiService {
  static final HttpApiService _instance = HttpApiService._internal();
  
  HttpApiService._internal();
  
  factory HttpApiService() => _instance;
  
  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'X-Sync-Key': ApiConfig.syncKey,
  };

  Future<Map<String, dynamic>> postQuery({
    required String sql,
    List<dynamic>? params,
    bool isInsert = false,
  }) async {
    final candidateUris = <Uri>[
      Uri.parse('${ApiConfig.baseUrl}/sync/query'),
    ];

    if (kIsWeb) {
      final origin = Uri.base.origin;
      final alt1 = Uri.parse('$origin/chifa/api/sync/query');
      final alt2 = Uri.parse('$origin/api/sync/query');
      if (!candidateUris.contains(alt1)) candidateUris.add(alt1);
      if (!candidateUris.contains(alt2)) candidateUris.add(alt2);
    }

    String lastError = '';
    for (final uri in candidateUris) {
      try {
        final response = await http.post(
          uri,
          headers: _headers,
          body: jsonEncode({
            'sql': sql,
            'params': params ?? [],
            'is_insert': isInsert,
          }),
        ).timeout(ApiConfig.timeout);

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          return data;
        } else {
          lastError = 'HTTP ${response.statusCode}: ${response.body}';
        }
      } catch (e) {
        lastError = e.toString();
      }
    }

    debugPrint('[HttpApiService] SQL query relay error: $lastError');
    return {'error': lastError, 'success': false};
  }

  Future<Map<String, dynamic>> pushChanges({
    required String sourceId,
    required Map<String, List<Map<String, dynamic>>> changes,
  }) async {
    final candidateUris = <Uri>[
      Uri.parse('${ApiConfig.baseUrl}/sync/push'),
    ];

    for (final uri in candidateUris) {
      try {
        final response = await http.post(
          uri,
          headers: _headers,
          body: jsonEncode({
            'source_id': sourceId,
            'changes': changes,
          }),
        ).timeout(ApiConfig.timeout);

        if (response.statusCode == 200) {
          return jsonDecode(response.body) as Map<String, dynamic>;
        }
      } catch (e) {
        debugPrint('[HttpApiService] pushChanges error: $e');
      }
    }
    return {'success': false};
  }

  Future<Map<String, dynamic>> pullChanges({
    required String since,
    String? sourceId,
  }) async {
    final candidateUris = <Uri>[
      Uri.parse('${ApiConfig.baseUrl}/sync/pull?since=${Uri.encodeComponent(since)}&source_id=${Uri.encodeComponent(sourceId ?? "")}'),
    ];

    for (final uri in candidateUris) {
      try {
        final response = await http.get(uri, headers: _headers).timeout(ApiConfig.timeout);
        if (response.statusCode == 200) {
          return jsonDecode(response.body) as Map<String, dynamic>;
        }
      } catch (e) {
        debugPrint('[HttpApiService] pullChanges error: $e');
      }
    }
    return {'changes': {}};
  }
}

class ApiDatabaseService {
  static final ApiDatabaseService _instance = ApiDatabaseService._internal();
  
  ApiDatabaseService._internal();
  
  factory ApiDatabaseService() => _instance;
  
  final HttpApiService _api = HttpApiService();
  
  bool _isConnected = false;
  bool get isConnected => _isConnected;
  bool get connected => _isConnected;
  
  Future<void> connect() async {
    _isConnected = true;
    debugPrint('ApiDatabaseService ready (Connected via HTTP SQL Relay to Octenium)');
  }
  
  Future<List<Map<String, dynamic>>> query(String sql, [List<dynamic>? params]) async {
    final res = await _api.postQuery(sql: sql, params: params, isInsert: false);
    if (res['data'] is List) {
      return (res['data'] as List).map((row) => Map<String, dynamic>.from(row as Map)).toList();
    }
    return [];
  }
  
  Future<int> insert(String sql, [List<dynamic>? params]) async {
    final res = await _api.postQuery(sql: sql, params: params, isInsert: true);
    final id = res['insertId'];
    if (id is int) return id;
    if (id is String) return int.tryParse(id) ?? 0;
    return 0;
  }
  
  Future<int> execute(String sql, [dynamic params]) async {
    List<dynamic>? paramList;
    if (params is List) {
      paramList = params;
    } else if (params is Map) {
      paramList = params.values.toList();
    }
    final res = await _api.postQuery(sql: sql, params: paramList, isInsert: false);
    final affected = res['affectedRows'];
    if (affected is int) return affected;
    if (affected is String) return int.tryParse(affected) ?? 0;
    return res['success'] == true ? 1 : 0;
  }

  Future<T> transaction<T>(Future<T> Function(dynamic conn) callback) async {
    return await callback(this);
  }

  Future<bool> tableExists(String table) async {
    final results = await query(
      "SELECT COUNT(*) as count FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = ?",
      [table],
    );
    return results.isNotEmpty && (int.tryParse(results.first['count'].toString()) ?? 0) > 0;
  }

  Future<bool> columnExists(String table, String column) async {
    final results = await query(
      "SELECT COUNT(*) as count FROM information_schema.columns WHERE table_schema = DATABASE() AND table_name = ? AND column_name = ?",
      [table, column],
    );
    return results.isNotEmpty && (int.tryParse(results.first['count'].toString()) ?? 0) > 0;
  }

  Future<List<String>> getTables() async {
    final results = await query("SHOW TABLES");
    return results.map((row) => row.values.first.toString()).toList();
  }

  Future<void> runMigrations() async {
    debugPrint('Web Mode: Migrations handled directly on Cloud database.');
  }
}