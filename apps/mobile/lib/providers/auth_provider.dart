import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/auth_response.dart';
import '../services/api_client.dart';

class AuthProvider extends ChangeNotifier {
  static const _storage = FlutterSecureStorage();

  String? _token;
  int? _userId;
  String? _username;
  int _linkScore = 0;
  bool _initialized = false;

  String? get token => _token;
  int? get userId => _userId;
  String? get username => _username;
  int get linkScore => _linkScore;
  bool get isLoggedIn => _token != null;
  bool get initialized => _initialized;

  Future<void> initialize() async {
    final results = await Future.wait([
      _storage.read(key: 'jwt_token'),
      _storage.read(key: 'user_id'),
      _storage.read(key: 'username'),
      _storage.read(key: 'link_score'),
    ]);
    _token = results[0];
    _userId = results[1] != null ? int.tryParse(results[1]!) : null;
    _username = results[2];
    _linkScore = results[3] != null ? int.tryParse(results[3]!) ?? 0 : 0;

    if (_token != null) {
      ApiClient.setTokenCache(_token);
      try {
        final profile = await ApiClient.getMyProfile();
        _linkScore = (profile['linkScore'] as num).toInt();
        _username = profile['username'] as String? ?? _username;
        await _storage.write(key: 'link_score', value: '$_linkScore');
      } catch (_) {
        // 토큰이 만료됐거나 유효하지 않으면 로그아웃 처리
        await _clearAuth();
      }
    }

    _initialized = true;
    notifyListeners();
  }

  Future<void> _clearAuth() async {
    _token = null;
    _userId = null;
    _username = null;
    _linkScore = 0;
    ApiClient.setTokenCache(null);
    await _storage.deleteAll();
  }

  Future<void> _saveAuth(AuthResponse auth) async {
    _token = auth.token;
    _userId = auth.userId;
    _username = auth.username;
    _linkScore = auth.linkScore;
    ApiClient.setTokenCache(auth.token);
    await Future.wait([
      _storage.write(key: 'jwt_token', value: auth.token),
      _storage.write(key: 'user_id', value: '${auth.userId}'),
      _storage.write(key: 'username', value: auth.username),
      _storage.write(key: 'link_score', value: '${auth.linkScore}'),
    ]);
    notifyListeners();
  }

  Future<void> login(String username, String password) async {
    final auth = await ApiClient.login(username: username, password: password);
    await _saveAuth(auth);
  }

  Future<void> signup({
    required String username,
    required String email,
    required String password,
    String? realName,
    String? phoneNumber,
    String? refundBank,
    String? refundAccountNumber,
    String? refundAccountHolder,
  }) async {
    final auth = await ApiClient.signup(
      username: username,
      email: email,
      password: password,
      realName: realName,
      phoneNumber: phoneNumber,
      refundBank: refundBank,
      refundAccountNumber: refundAccountNumber,
      refundAccountHolder: refundAccountHolder,
    );
    await _saveAuth(auth);
  }

  Future<void> refreshProfile() async {
    try {
      final profile = await ApiClient.getMyProfile();
      _linkScore = (profile['linkScore'] as num).toInt();
      await _storage.write(key: 'link_score', value: '$_linkScore');
      notifyListeners();
    } catch (_) {}
  }

  Future<void> logout() async {
    await _clearAuth();
    notifyListeners();
  }
}
