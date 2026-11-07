import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class ApiConfig {
  static String? _safeEnv(String key) {
    try {
      if (dotenv.isInitialized) {
        return dotenv.env[key]?.trim();
      }
    } catch (_) {}
    return null;
  }

  // Octenium Cloud backend API base URL (isolated on chifa.medevsync.com)
  static String get baseUrl {
    if (kIsWeb) {
      final currentOrigin = Uri.base.origin;
      final path = Uri.base.path;
      if (path.startsWith('/chifa')) {
        return '$currentOrigin/chifa/api';
      }
      return '$currentOrigin/api';
    }
    final envUrl = _safeEnv('BACKEND_API_URL');
    if (envUrl != null &&
        envUrl.isNotEmpty &&
        !envUrl.contains('localhost:3000') &&
        !envUrl.contains('supabase') &&
        !envUrl.contains('srv50.octenium.net')) {
      return envUrl.replaceAll(RegExp(r'/+$'), '');
    }
    return 'https://chifa.medevsync.com/api';
  }

  static String get syncKey =>
      _safeEnv('SYNC_KEY') ?? 'chifa_sync_secure_key_2026';
  static const Duration timeout = Duration(seconds: 20);
}

class HttpApiService {
  static final HttpApiService _instance = HttpApiService._internal();

  HttpApiService._internal();

  factory HttpApiService() => _instance;

  /// Cached working endpoint style so subsequent calls succeed in 1 round-trip
  String? _cachedSyncBase;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'X-Sync-Key': ApiConfig.syncKey,
      };

  /// Normalize Dart parameter values for JSON transport to Node.js mysql2
  List<dynamic> _normalizeParams(List<dynamic>? params) {
    if (params == null || params.isEmpty) return const [];
    return params.map((val) {
      if (val == null) return null;
      if (val is num) return val;
      if (val is bool) return val ? 1 : 0;
      if (val is DateTime) {
        final formatted = val.toIso8601String().replaceAll('T', ' ');
        return formatted.length >= 19 ? formatted.substring(0, 19) : formatted;
      }
      return val.toString();
    }).toList();
  }

  /// Build ordered list of candidate URIs for a given sync action ('query', 'push', 'pull')
  List<Uri> _buildCandidateUris(String action, {String? queryString}) {
    final qs = (queryString != null && queryString.isNotEmpty) ? '?$queryString' : '';
    final uris = <Uri>[];

    void addCandidate(String urlStr) {
      final uri = Uri.parse(urlStr);
      if (!uris.contains(uri)) {
        uris.add(uri);
      }
    }

    if (_cachedSyncBase != null) {
      if (_cachedSyncBase!.contains('?route=')) {
        final extraQs = (queryString != null && queryString.isNotEmpty) ? '&$queryString' : '';
        addCandidate('$_cachedSyncBase/sync/$action$extraQs');
      } else {
        addCandidate('$_cachedSyncBase/sync/$action$qs');
      }
    }

    if (kIsWeb) {
      final origin = Uri.base.origin;
      addCandidate('$origin/api/sync/$action$qs');
      addCandidate('$origin/chifa/api/sync/$action$qs');
      final extraQs = (queryString != null && queryString.isNotEmpty) ? '&$queryString' : '';
      addCandidate('$origin/?route=/sync/$action$extraQs');
      addCandidate('$origin/chifa/?route=/sync/$action$extraQs');
    }

    final primaryBase = ApiConfig.baseUrl;
    addCandidate('$primaryBase/sync/$action$qs');
    addCandidate('https://chifa.medevsync.com/api/sync/$action$qs');
    final extraQs = (queryString != null && queryString.isNotEmpty) ? '&$queryString' : '';
    addCandidate('https://chifa.medevsync.com/?route=/sync/$action$extraQs');
    addCandidate('https://chifa.medevsync.com/chifa/api/sync/$action$qs');
    addCandidate('https://medevsync.com/chifa/?route=/sync/$action$extraQs');
    addCandidate('https://medevsync.com/chifa/api/sync/$action$qs');

    return uris;
  }

  void _rememberWorkingUri(Uri uri, String action) {
    final full = uri.toString();
    if (full.contains('?route=/sync/$action')) {
      _cachedSyncBase = full.split('?route=/sync/$action').first + '?route=';
    } else if (full.contains('/sync/$action')) {
      _cachedSyncBase = full.split('/sync/$action').first;
    }
  }

  bool _isJsonResponse(http.Response response) {
    final contentType = (response.headers['content-type'] ?? '').toLowerCase();
    final bodyTrimmed = response.body.trimLeft();
    if (bodyTrimmed.startsWith('<')) return false;
    return contentType.contains('application/json') ||
        bodyTrimmed.startsWith('{') ||
        bodyTrimmed.startsWith('[');
  }

  Future<Map<String, dynamic>> postQuery({
    required String sql,
    List<dynamic>? params,
    bool isInsert = false,
  }) async {
    final normalizedParams = _normalizeParams(params);
    final candidateUris = _buildCandidateUris('query');

    String lastError = '';
    for (final uri in candidateUris) {
      try {
        final response = await http
            .post(
              uri,
              headers: _headers,
              body: jsonEncode({
                'sql': sql,
                'params': normalizedParams,
                'is_insert': isInsert,
              }),
            )
            .timeout(ApiConfig.timeout);

        if (!_isJsonResponse(response)) {
          lastError = 'Invalid non-JSON response from $uri (HTTP ${response.statusCode})';
          continue;
        }

        if (response.statusCode == 200) {
          _rememberWorkingUri(uri, 'query');
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          return data;
        } else {
          try {
            final errData = jsonDecode(response.body) as Map<String, dynamic>;
            if (errData['error'] != null) {
              // If the backend itself returned a SQL error (HTTP 400/500), remember the URI and surface the SQL error immediately
              if (response.statusCode == 500 || response.statusCode == 400) {
                _rememberWorkingUri(uri, 'query');
                return {'error': errData['error'].toString(), 'success': false};
              }
            }
          } catch (_) {}
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
    final candidateUris = _buildCandidateUris('push');
    String lastError = '';

    for (final uri in candidateUris) {
      try {
        final response = await http
            .post(
              uri,
              headers: _headers,
              body: jsonEncode({
                'source_id': sourceId,
                'changes': changes,
              }),
            )
            .timeout(ApiConfig.timeout);

        if (!_isJsonResponse(response)) {
          lastError = 'Non-JSON response from $uri';
          continue;
        }

        if (response.statusCode == 200) {
          _rememberWorkingUri(uri, 'push');
          return jsonDecode(response.body) as Map<String, dynamic>;
        } else {
          lastError = 'HTTP ${response.statusCode}: ${response.body}';
        }
      } catch (e) {
        lastError = e.toString();
        debugPrint('[HttpApiService] pushChanges error ($uri): $e');
      }
    }
    throw Exception('Impossible de synchroniser (push) vers le serveur Cloud: $lastError');
  }

  Future<Map<String, dynamic>> pullChanges({
    required String since,
    String? sourceId,
  }) async {
    final qs =
        'since=${Uri.encodeComponent(since)}&source_id=${Uri.encodeComponent(sourceId ?? "")}';
    final candidateUris = _buildCandidateUris('pull', queryString: qs);
    String lastError = '';

    for (final uri in candidateUris) {
      try {
        final response =
            await http.get(uri, headers: _headers).timeout(ApiConfig.timeout);
        if (!_isJsonResponse(response)) {
          lastError = 'Non-JSON response from $uri';
          continue;
        }
        if (response.statusCode == 200) {
          _rememberWorkingUri(uri, 'pull');
          return jsonDecode(response.body) as Map<String, dynamic>;
        } else {
          lastError = 'HTTP ${response.statusCode}: ${response.body}';
        }
      } catch (e) {
        lastError = e.toString();
        debugPrint('[HttpApiService] pullChanges error ($uri): $e');
      }
    }
    throw Exception('Impossible de récupérer (pull) depuis le serveur Cloud: $lastError');
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
    debugPrint(
      'ApiDatabaseService ready (Connected via HTTPS Backend API: ${ApiConfig.baseUrl})',
    );
  }

  /// Convert named parameters (:p0, :p1) in SQL to positional (?) if a Map was passed
  String _normalizeSqlAndParams(
    String sql,
    dynamic rawParams,
    List<dynamic> outParams,
  ) {
    if (rawParams == null) return sql;
    if (rawParams is List) {
      outParams.addAll(rawParams);
      return sql;
    }
    if (rawParams is Map) {
      if (sql.contains(':')) {
        return sql.replaceAllMapped(RegExp(r':([a-zA-Z0-9_]+)'), (match) {
          final key = match.group(1)!;
          outParams.add(rawParams[key]);
          return '?';
        });
      } else {
        outParams.addAll(rawParams.values);
        return sql;
      }
    }
    outParams.add(rawParams);
    return sql;
  }

  Future<List<Map<String, dynamic>>> query(
    String sql, [
    dynamic params,
  ]) async {
    final paramList = <dynamic>[];
    final normalizedSql = _normalizeSqlAndParams(sql, params, paramList);
    final res = await _api.postQuery(
      sql: normalizedSql,
      params: paramList,
      isInsert: false,
    );
    if (res['success'] == false && res['error'] != null) {
      throw Exception(res['error'].toString());
    }
    if (res['data'] is List) {
      return (res['data'] as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
    }
    return [];
  }

  Future<int> insert(String sql, [dynamic params]) async {
    final paramList = <dynamic>[];
    final normalizedSql = _normalizeSqlAndParams(sql, params, paramList);
    final res = await _api.postQuery(
      sql: normalizedSql,
      params: paramList,
      isInsert: true,
    );
    if (res['success'] == false && res['error'] != null) {
      throw Exception(res['error'].toString());
    }
    final id = res['insertId'];
    if (id is int) return id;
    if (id is String) return int.tryParse(id) ?? 0;
    return 0;
  }

  Future<int> execute(String sql, [dynamic params]) async {
    final paramList = <dynamic>[];
    final normalizedSql = _normalizeSqlAndParams(sql, params, paramList);
    final res = await _api.postQuery(
      sql: normalizedSql,
      params: paramList,
      isInsert: false,
    );
    if (res['success'] == false && res['error'] != null) {
      throw Exception(res['error'].toString());
    }
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
    return results.isNotEmpty &&
        (int.tryParse(results.first['count'].toString()) ?? 0) > 0;
  }

  Future<bool> columnExists(String table, String column) async {
    final results = await query(
      "SELECT COUNT(*) as count FROM information_schema.columns WHERE table_schema = DATABASE() AND table_name = ? AND column_name = ?",
      [table, column],
    );
    return results.isNotEmpty &&
        (int.tryParse(results.first['count'].toString()) ?? 0) > 0;
  }

  Future<List<String>> getTables() async {
    final results = await query("SHOW TABLES");
    return results.map((row) => row.values.first.toString()).toList();
  }

  Future<void> runMigrations() async {
    debugPrint('Cloud API Mode: Schema migrations managed by Chifa Node.js backend.');
  }
}