import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/auth_response.dart';
import '../models/moim_response.dart';
import '../models/participant_response.dart';

class ApiClient {
  static const String _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8080/api', // Android 에뮬레이터 → 로컬호스트
  );
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static Future<String?> _getToken() => _storage.read(key: 'jwt_token');

  static Future<Map<String, String>> _authHeaders() async {
    final token = await _getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static void _checkStatus(http.Response res) {
    if (res.statusCode >= 400) {
      final body = json.decode(res.body);
      throw ApiException(body['message'] ?? '오류가 발생했습니다. (${res.statusCode})');
    }
  }

  // Auth
  static Future<AuthResponse> signup({
    required String username,
    required String email,
    required String password,
    String? phoneNumber,
  }) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/auth/signup'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'username': username,
        'email': email,
        'password': password,
        if (phoneNumber != null) 'phoneNumber': phoneNumber,
      }),
    );
    _checkStatus(res);
    return AuthResponse.fromJson(json.decode(res.body));
  }

  static Future<AuthResponse> login({
    required String username,
    required String password,
  }) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'username': username, 'password': password}),
    );
    _checkStatus(res);
    return AuthResponse.fromJson(json.decode(res.body));
  }

  // Moims
  static Future<MoimResponse> createMoim(Map<String, dynamic> data) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/moims'),
      headers: await _authHeaders(),
      body: json.encode(data),
    );
    _checkStatus(res);
    return MoimResponse.fromJson(json.decode(res.body));
  }

  static Future<MoimResponse> joinMoim({
    required String inviteCode,
    String? refundBank,
    String? refundAccountNumber,
  }) async {
    final params = {
      'inviteCode': inviteCode,
      if (refundBank != null) 'refundBank': refundBank,
      if (refundAccountNumber != null) 'refundAccountNumber': refundAccountNumber,
    };
    final uri = Uri.parse('$_baseUrl/moims/join').replace(queryParameters: params);
    final res = await http.post(uri, headers: await _authHeaders());
    _checkStatus(res);
    return MoimResponse.fromJson(json.decode(res.body));
  }

  static Future<MoimResponse> getMoim(int moimId) async {
    final res = await http.get(
      Uri.parse('$_baseUrl/moims/$moimId'),
      headers: await _authHeaders(),
    );
    _checkStatus(res);
    return MoimResponse.fromJson(json.decode(res.body));
  }

  static Future<List<MoimResponse>> getMyMoims() async {
    final res = await http.get(
      Uri.parse('$_baseUrl/moims/my'),
      headers: await _authHeaders(),
    );
    _checkStatus(res);
    final list = json.decode(res.body) as List;
    return list.map((e) => MoimResponse.fromJson(e)).toList();
  }

  static Future<List<ParticipantResponse>> getParticipants(int moimId) async {
    final res = await http.get(
      Uri.parse('$_baseUrl/moims/$moimId/participants'),
      headers: await _authHeaders(),
    );
    _checkStatus(res);
    final list = json.decode(res.body) as List;
    return list.map((e) => ParticipantResponse.fromJson(e)).toList();
  }

  static Future<List<ParticipantResponse>> settle(int moimId) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/moims/$moimId/settle'),
      headers: await _authHeaders(),
    );
    _checkStatus(res);
    final list = json.decode(res.body) as List;
    return list.map((e) => ParticipantResponse.fromJson(e)).toList();
  }

  static Future<void> confirmDeposit(int moimId, int userId) async {
    final uri = Uri.parse('$_baseUrl/moims/$moimId/deposit/confirm')
        .replace(queryParameters: {'userId': '$userId'});
    final res = await http.post(uri, headers: await _authHeaders());
    _checkStatus(res);
  }
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => message;
}
