import 'dart:convert';

import 'package:http/http.dart' as http;
class ApiConfig {
  static const String baseUrl = 'https://medevsync.com/chiffa/api';
  static const Duration timeout = Duration(seconds: 30);
}

class HttpApiService {
  static final HttpApiService _instance = HttpApiService._internal();
  
  HttpApiService._internal();
  
  factory HttpApiService() => _instance;
  
  Future<Map<String, dynamic>> get(String endpoint, {Map<String, String>? params}) async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/$endpoint').replace(queryParameters: params);
      final response = await http.get(uri);
      
      return _handleResponse(response);
    } catch (e) {
      return {'error': e.toString()};
    }
  }
  
  Future<Map<String, dynamic>> post(String endpoint, Map<String, dynamic> data) async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/$endpoint');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );
      
      return _handleResponse(response);
    } catch (e) {
      return {'error': e.toString()};
    }
  }
  
  Future<Map<String, dynamic>> put(String endpoint, int id, Map<String, dynamic> data) async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/$endpoint/$id');
      final response = await http.put(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );
      
      return _handleResponse(response);
    } catch (e) {
      return {'error': e.toString()};
    }
  }
  
  Future<Map<String, dynamic>> delete(String endpoint, int id) async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/$endpoint/$id');
      final response = await http.delete(uri);
      
      return _handleResponse(response);
    } catch (e) {
      return {'error': e.toString()};
    }
  }
  
  Map<String, dynamic> _handleResponse(http.Response response) {
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    }
    
    return {'error': data['error'] ?? 'Request failed', 'statusCode': response.statusCode};
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
    // API database service ready (Web Mode)
  }
  
  Future<List<Map<String, dynamic>>> query(String sql, [List<dynamic>? params]) async {
    final table = _extractTableName(sql);
    if (table == null) return [];
    
    final isSelect = sql.trim().toLowerCase().startsWith('select');
    if (!isSelect) return [];
    
    final result = await _api.get(table);
    return (result['data'] as List?)?.cast<Map<String, dynamic>>() ?? [];
  }
  
  Future<int> insert(String sql, List<dynamic>? params) async {
    final table = _extractTableName(sql);
    if (table == null) return 0;
    
    final data = _buildInsertData(table, params);
    final result = await _api.post(table, data);
    
    return (result['id'] as int?) ?? 0;
  }
  
  Future<bool> execute(String sql, [List<dynamic>? params]) async {
    final table = _extractTableName(sql);
    if (table == null) return false;
    
    final isUpdate = sql.trim().toLowerCase().startsWith('update');
    final isDelete = sql.trim().toLowerCase().startsWith('delete');
    
    if (isUpdate) {
      final id = params?.first;
      if (id != null) {
        final data = _buildUpdateData(table, params);
        final result = await _api.put(table, id as int, data);
        return result['success'] == true;
      }
    }
    
    if (isDelete) {
      final id = params?.first;
      if (id != null) {
        final result = await _api.delete(table, id as int);
        return result['success'] == true;
      }
    }
    
    return false;
  }
  
  String? _extractTableName(String sql) {
    final regExp = RegExp(r'INSERT\s+INTO\s+|UPDATE\s+|DELETE\s+FROM\s+', caseSensitive: false);
    final match = regExp.firstMatch(sql);
    if (match != null) {
      final tableMatch = RegExp(r'[`"\[]?(\w+)[`"\]]?', caseSensitive: false).firstMatch(sql.substring(match.start));
      return tableMatch?.group(1);
    }
    return null;
  }
  
  Map<String, String> _buildQueryParams(List<dynamic> params) {
    return {};
  }
  
  Map<String, dynamic> _buildInsertData(String table, List<dynamic>? params) {
    final data = <String, dynamic>{};
    
    switch (table) {
      case 'patients':
        if (params != null && params.length >= 10) {
          data['first_name'] = params[1];
          data['last_name'] = params[2];
          data['gender'] = params[3];
          data['date_of_birth'] = params[4];
          data['phone'] = params[5];
          data['email'] = params[6];
          data['national_id'] = params[7];
          data['address'] = params[8];
          data['atcd'] = params[9];
        }
        break;
      case 'appointments':
        if (params != null && params.length >= 7) {
          data['patient_id'] = params[1];
          data['doctor_id'] = params[2];
          data['appointment_date'] = params[3];
          data['status'] = params[4];
          data['notes'] = params[5];
        }
        break;
      case 'medicalrecords':
        if (params != null && params.length >= 14) {
          data['patient_id'] = params[1];
          data['doctor_id'] = params[2];
          data['record_date'] = params[3];
          data['motif'] = params[4];
          data['details'] = params[5];
          data['diagnostic'] = params[6];
          data['prescriptions'] = params[7];
          data['weight'] = params[8];
          data['temperature'] = params[9];
          data['tension_arterielle'] = params[10];
          data['frequence_cardiaque'] = params[11];
          data['spao2'] = params[12];
        }
        break;
    }
    
    return data;
  }
  
  Map<String, dynamic> _buildUpdateData(String table, List<dynamic>? params) {
    return {};
  }
}