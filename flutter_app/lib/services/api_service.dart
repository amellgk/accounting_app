import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ApiService {
  // 修改这里为你的服务器地址
  // Android 模拟器用 10.0.2.2，iOS 模拟器用 localhost，真机用局域网 IP
  static const String baseUrl = 'http://10.0.2.2:3000/api';

  String? _token;

  void setToken(String? token) {
    _token = token;
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  // ============ 认证 ============

  Future<Map<String, dynamic>> register(String username, String password) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: _headers,
      body: jsonEncode({'username': username, 'password': password}),
    );
    return _handleResponse(res);
  }

  Future<Map<String, dynamic>> login(String username, String password) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: _headers,
      body: jsonEncode({'username': username, 'password': password}),
    );
    return _handleResponse(res);
  }

  // ============ 分类 ============

  Future<List<dynamic>> getCategories() async {
    final res = await http.get(
      Uri.parse('$baseUrl/categories'),
      headers: _headers,
    );
    final data = _handleResponse(res);
    return data['categories'] ?? [];
  }

  Future<Map<String, dynamic>> createCategory(
      String name, String icon, String type) async {
    final res = await http.post(
      Uri.parse('$baseUrl/categories'),
      headers: _headers,
      body: jsonEncode({'name': name, 'icon': icon, 'type': type}),
    );
    return _handleResponse(res);
  }

  // ============ 账单 ============

  Future<Map<String, dynamic>> getTransactions({
    int page = 1,
    int limit = 50,
    String? type,
    String? categoryId,
    String? startDate,
    String? endDate,
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (type != null) params['type'] = type;
    if (categoryId != null) params['categoryId'] = categoryId;
    if (startDate != null) params['startDate'] = startDate;
    if (endDate != null) params['endDate'] = endDate;

    final uri = Uri.parse('$baseUrl/transactions').replace(queryParameters: params);
    final res = await http.get(uri, headers: _headers);
    return _handleResponse(res);
  }

  Future<Map<String, dynamic>> createTransaction({
    required String categoryId,
    required String type,
    required double amount,
    String note = '',
    String? transactionDate,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/transactions'),
      headers: _headers,
      body: jsonEncode({
        'categoryId': categoryId,
        'type': type,
        'amount': amount,
        'note': note,
        if (transactionDate != null) 'transactionDate': transactionDate,
      }),
    );
    return _handleResponse(res);
  }

  Future<Map<String, dynamic>> updateTransaction(
      String id, Map<String, dynamic> data) async {
    final res = await http.put(
      Uri.parse('$baseUrl/transactions/$id'),
      headers: _headers,
      body: jsonEncode(data),
    );
    return _handleResponse(res);
  }

  Future<void> deleteTransaction(String id) async {
    final res = await http.delete(
      Uri.parse('$baseUrl/transactions/$id'),
      headers: _headers,
    );
    _handleResponse(res);
  }

  // ============ 统计 ============

  Future<Map<String, dynamic>> getMonthlyStats({int? year, int? month}) async {
    final now = DateTime.now();
    year ??= now.year;
    month ??= now.month;
    final res = await http.get(
      Uri.parse('$baseUrl/stats/monthly?year=$year&month=$month'),
      headers: _headers,
    );
    return _handleResponse(res);
  }

  Future<Map<String, dynamic>> getYearlyStats({int? year}) async {
    year ??= DateTime.now().year;
    final res = await http.get(
      Uri.parse('$baseUrl/stats/yearly?year=$year'),
      headers: _headers,
    );
    return _handleResponse(res);
  }

  // ============ 导入 ============

  Future<Map<String, dynamic>> importFile(String source, String filePath) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/import/$source'),
    );
    request.headers['Authorization'] = 'Bearer $_token';
    request.files.add(await http.MultipartFile.fromPath('file', filePath));
    final streamedRes = await request.send();
    final res = await http.Response.fromStream(streamedRes);
    return _handleResponse(res);
  }

  // ============ 导出 ============

  Future<String> exportCsv() async {
    final res = await http.get(
      Uri.parse('$baseUrl/export/csv'),
      headers: _headers,
    );
    if (res.statusCode == 200) {
      return res.body;
    }
    throw Exception('导出失败: ${res.statusCode}');
  }

  // ============ 同步 ============

  Future<Map<String, dynamic>> syncTransactions(List<Map<String, dynamic>> transactions) async {
    final res = await http.post(
      Uri.parse('$baseUrl/sync'),
      headers: _headers,
      body: jsonEncode({'transactions': transactions}),
    );
    return _handleResponse(res);
  }

  Future<Map<String, dynamic>> getFullSync() async {
    final res = await http.get(
      Uri.parse('$baseUrl/sync/full'),
      headers: _headers,
    );
    return _handleResponse(res);
  }

  // ============ 通用 ============

  Map<String, dynamic> _handleResponse(http.Response res) {
    final body = jsonDecode(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return body;
    }
    throw ApiException(body['error'] ?? '请求失败', res.statusCode);
  }
}

class ApiException implements Exception {
  final String message;
  final int statusCode;
  ApiException(this.message, this.statusCode);

  @override
  String toString() => message;
}
