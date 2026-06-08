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
    _token = await _storage.read(key: 'jwt_token');
    final uid = await _storage.read(key: 'user_id');
    _userId = uid != null ? int.tryParse(uid) : null;
    _username = await _storage.read(key: 'username');
    final ls = await _storage.read(key: 'link_score');
    _linkScore = ls != null ? int.tryParse(ls) ?? 0 : 0;
    _initialized = true;
    notifyListeners();
  }

  Future<void> _saveAuth(AuthResponse auth) async {
    _token = auth.token;
    _userId = auth.userId;
    _username = auth.username;
    _linkScore = auth.linkScore;
    await _storage.write(key: 'jwt_token', value: auth.token);
    await _storage.write(key: 'user_id', value: '${auth.userId}');
    await _storage.write(key: 'username', value: auth.username);
    await _storage.write(key: 'link_score', value: '${auth.linkScore}');
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
    String? phoneNumber,
  }) async {
    final auth = await ApiClient.signup(
      username: username,
      email: email,
      password: password,
      phoneNumber: phoneNumber,
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
    _token = null;
    _userId = null;
    _username = null;
    _linkScore = 0;
    await _storage.deleteAll();
    notifyListeners();
  }
}
