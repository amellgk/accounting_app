import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../services/api_service.dart' as api;

class AuthProvider extends ChangeNotifier {
  final ApiService _api;
  static const String _tokenKey = 'auth_token';
  static const String _usernameKey = 'username';
  static const String _userIdKey = 'user_id';

  late SharedPreferences _prefs;
  User? _user;
  String? _token;
  bool _loading = false;
  String? _error;
  bool _initialized = false;

  User? get user => _user;
  String? get token => _token;
  bool get loading => _loading;
  String? get error => _error;
  bool get isLoggedIn => _user != null && _token != null;

  AuthProvider(this._api);

  Future<void> _ensureInit() async {
    if (!_initialized) {
      _prefs = await SharedPreferences.getInstance();
      _initialized = true;
    }
  }

  Future<void> tryAutoLogin() async {
    await _ensureInit();
    final token = _prefs.getString(_tokenKey);
    final username = _prefs.getString(_usernameKey);
    final userId = _prefs.getString(_userIdKey);
    if (token != null && username != null && userId != null) {
      _token = token;
      _user = User(id: userId, username: username);
      _api.setToken(token);
      notifyListeners();
    }
  }

  Future<bool> login(String username, String password) async {
    await _ensureInit();
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final data = await _api.login(username, password);
      _token = data['token'];
      _user = User.fromJson(data['user']);
      _api.setToken(_token);

      await _prefs.setString(_tokenKey, _token!);
      await _prefs.setString(_usernameKey, _user!.username);
      await _prefs.setString(_userIdKey, _user!.id);

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
    await _ensureInit();
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final data = await _api.register(username, password);
      _token = data['token'];
      _user = User.fromJson(data['user']);
      _api.setToken(_token);

      await _prefs.setString(_tokenKey, _token!);
      await _prefs.setString(_usernameKey, _user!.username);
      await _prefs.setString(_userIdKey, _user!.id);

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
    await _ensureInit();
    _user = null;
    _token = null;
    _api.setToken(null);
    await _prefs.remove(_tokenKey);
    await _prefs.remove(_usernameKey);
    await _prefs.remove(_userIdKey);
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
