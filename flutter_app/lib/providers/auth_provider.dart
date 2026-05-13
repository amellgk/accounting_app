import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user.dart';
import '../services/api_service.dart' as api;

class AuthProvider extends ChangeNotifier {
  final ApiService _api;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  User? _user;
  String? _token;
  bool _loading = false;
  String? _error;

  User? get user => _user;
  String? get token => _token;
  bool get loading => _loading;
  String? get error => _error;
  bool get isLoggedIn => _user != null && _token != null;

  AuthProvider(this._api);

  Future<void> tryAutoLogin() async {
    final token = await _storage.read(key: 'auth_token');
    final username = await _storage.read(key: 'username');
    final userId = await _storage.read(key: 'user_id');
    if (token != null && username != null && userId != null) {
      _token = token;
      _user = User(id: userId, username: username);
      _api.setToken(token);
      notifyListeners();
    }
  }

  Future<bool> login(String username, String password) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final data = await _api.login(username, password);
      _token = data['token'];
      _user = User.fromJson(data['user']);
      _api.setToken(_token);

      await _storage.write(key: 'auth_token', value: _token!);
      await _storage.write(key: 'username', value: _user!.username);
      await _storage.write(key: 'user_id', value: _user!.id);

      _loading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register(String username, String password) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final data = await _api.register(username, password);
      _token = data['token'];
      _user = User.fromJson(data['user']);
      _api.setToken(_token);

      await _storage.write(key: 'auth_token', value: _token!);
      await _storage.write(key: 'username', value: _user!.username);
      await _storage.write(key: 'user_id', value: _user!.id);

      _loading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    _user = null;
    _token = null;
    _api.setToken(null);
    await _storage.deleteAll();
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
