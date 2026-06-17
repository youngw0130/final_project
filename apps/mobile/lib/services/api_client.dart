import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/auth_response.dart';
import '../models/moim_response.dart';
import '../models/participant_response.dart';
import '../models/payment_response.dart';

class ApiClient {
  static const String _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://final-project-cx68.onrender.com/api',
  );
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static const _loginTimeout = Duration(seconds: 60);
  static const _timeout = Duration(seconds: 15);
  static const _warmTimeout = Duration(seconds: 60);

  static String? _tokenCache;

  static void setTokenCache(String? token) => _tokenCache = token;

  static Future<String?> _getToken() async {
    _tokenCache ??= await _storage.read(key: 'jwt_token');
    return _tokenCache;
  }

  static Future<Map<String, String>> _authHeaders() async {
    final token = await _getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static void _checkStatus(http.Response res) {
    if (res.statusCode >= 400) {
      try {
        final body = json.decode(res.body);
        throw ApiException(body['error'] ?? '오류가 발생했습니다. (${res.statusCode})');
      } on ApiException {
        rethrow;
      } catch (_) {
        throw ApiException('서버 오류가 발생했습니다. (${res.statusCode})');
      }
    }
  }

  // Auth
  static Future<AuthResponse> signup({
    required String username,
    required String email,
    required String password,
    String? realName,
    String? phoneNumber,
    String? refundBank,
    String? refundAccountNumber,
    String? refundAccountHolder,
  }) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/auth/signup'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'username': username,
        'email': email,
        'password': password,
        if (realName != null) 'realName': realName,
        if (phoneNumber != null) 'phoneNumber': phoneNumber,
        if (refundBank != null) 'refundBank': refundBank,
        if (refundAccountNumber != null) 'refundAccountNumber': refundAccountNumber,
        if (refundAccountHolder != null) 'refundAccountHolder': refundAccountHolder,
      }),
    ).timeout(_loginTimeout);
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
    ).timeout(_loginTimeout);
    _checkStatus(res);
    return AuthResponse.fromJson(json.decode(res.body));
  }

  // Moims
  static Future<MoimResponse> createMoim(Map<String, dynamic> data) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/moims'),
      headers: await _authHeaders(),
      body: json.encode(data),
    ).timeout(_timeout);
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
    final res = await http.post(uri, headers: await _authHeaders()).timeout(_timeout);
    _checkStatus(res);
    return MoimResponse.fromJson(json.decode(res.body));
  }

  static Future<MoimResponse> getMoim(int moimId) async {
    final res = await http.get(
      Uri.parse('$_baseUrl/moims/$moimId'),
      headers: await _authHeaders(),
    ).timeout(_timeout);
    _checkStatus(res);
    return MoimResponse.fromJson(json.decode(res.body));
  }

  static Future<List<MoimResponse>> getMyMoims() async {
    final res = await http.get(
      Uri.parse('$_baseUrl/moims/my'),
      headers: await _authHeaders(),
    ).timeout(_timeout);
    _checkStatus(res);
    final list = json.decode(res.body) as List;
    return list.map((e) => MoimResponse.fromJson(e)).toList();
  }

  static Future<List<ParticipantResponse>> getParticipants(int moimId) async {
    final res = await http.get(
      Uri.parse('$_baseUrl/moims/$moimId/participants'),
      headers: await _authHeaders(),
    ).timeout(_timeout);
    _checkStatus(res);
    final list = json.decode(res.body) as List;
    return list.map((e) => ParticipantResponse.fromJson(e)).toList();
  }

  static Future<List<ParticipantResponse>> settle(int moimId) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/moims/$moimId/settle'),
      headers: await _authHeaders(),
    ).timeout(_timeout);
    _checkStatus(res);
    final list = json.decode(res.body) as List;
    return list.map((e) => ParticipantResponse.fromJson(e)).toList();
  }

  static Future<void> confirmDeposit(int moimId, int userId) async {
    final uri = Uri.parse('$_baseUrl/moims/$moimId/deposit/confirm')
        .replace(queryParameters: {'userId': '$userId'});
    final res = await http.post(uri, headers: await _authHeaders()).timeout(_timeout);
    _checkStatus(res);
  }

  static Future<void> cancelMoim(int moimId) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/moims/$moimId/cancel'),
      headers: await _authHeaders(),
    ).timeout(_timeout);
    _checkStatus(res);
  }

  // Payments
  static Future<PaymentResponse> createPayment({
    required int moimId,
    required String merchantName,
    String? category,
    required double amount,
    String? portOnePaymentId,
  }) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/moims/$moimId/payments'),
      headers: await _authHeaders(),
      body: json.encode({
        'merchantName': merchantName,
        if (category != null) 'category': category,
        'amount': amount,
        if (portOnePaymentId != null) 'portOnePaymentId': portOnePaymentId,
      }),
    ).timeout(_timeout);
    _checkStatus(res);
    return PaymentResponse.fromJson(json.decode(res.body));
  }

  static Future<List<PaymentResponse>> getPayments(int moimId) async {
    final res = await http.get(
      Uri.parse('$_baseUrl/moims/$moimId/payments'),
      headers: await _authHeaders(),
    ).timeout(_timeout);
    _checkStatus(res);
    final list = json.decode(res.body) as List;
    return list.map((e) => PaymentResponse.fromJson(e)).toList();
  }

  // User
  static Future<Map<String, dynamic>> getMyProfile() async {
    final res = await http.get(
      Uri.parse('$_baseUrl/users/me'),
      headers: await _authHeaders(),
    ).timeout(_timeout);
    _checkStatus(res);
    return json.decode(res.body) as Map<String, dynamic>;
  }

  static Future<List<Map<String, dynamic>>> getLinkScoreHistory() async {
    final res = await http.get(
      Uri.parse('$_baseUrl/users/me/link-score/history'),
      headers: await _authHeaders(),
    ).timeout(_timeout);
    _checkStatus(res);
    final list = json.decode(res.body) as List;
    return list.cast<Map<String, dynamic>>();
  }

  // Render 콜드 스타트 예방 - 앱 시작 시 백그라운드에서 호출
  static Future<void> warmUp() async {
    try {
      await http.get(
        Uri.parse('${_baseUrl.replaceAll('/api', '')}/api/ping'),
      ).timeout(_warmTimeout);
    } catch (_) {}
  }

  static Future<void> saveToken(String token) async {
    _tokenCache = token;
    await _storage.write(key: 'jwt_token', value: token);
  }

  static Future<void> deleteToken() async {
    _tokenCache = null;
    await _storage.delete(key: 'jwt_token');
  }
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => message;
}
