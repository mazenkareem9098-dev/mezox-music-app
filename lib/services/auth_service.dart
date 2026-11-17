import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/user_profile.dart';
import 'api_service.dart';

class AuthService extends ChangeNotifier {
  final _storage = const FlutterSecureStorage();
  UserProfile? _user;
  late ApiService _api;

  UserProfile? get user => _user;
  bool get isLoggedIn => _user != null;

  AuthService() {
    _api = ApiService();
    _restore();
  }

  ApiService get api => _api;

  Future<void> _restore() async {
    final raw = await _storage.read(key: 'mezox_user');
    if (raw != null) {
      _user = UserProfile.fromJson(jsonDecode(raw));
      _api.setToken(_user!.token);
      notifyListeners();
    }
  }

  Future<void> _save(UserProfile u) async {
    _user = u;
    _api.setToken(u.token);
    await _storage.write(key: 'mezox_user', value: jsonEncode({
      'username': u.username,
      'displayName': u.displayName,
      'age': u.age,
      'token': u.token,
    }));
    notifyListeners();
  }

  /// Name-only sign up. The server creates/reuses an account and returns a token.
  /// No password or external login is required.
  Future<String?> signUpWithName(String name) async {
    final clean = name.trim();
    if (clean.isEmpty) return 'Enter your name first';
    try {
      final res = await _api.dio.post('/auth/name/ensure', data: {
        'name': clean,
        'displayName': clean,
      });
      await _save(UserProfile.fromJson(Map<String, dynamic>.from(res.data)));
      return null;
    } catch (e) {
      return 'Sign up failed: $e';
    }
  }

  Future<void> logout() async {
    _user = null;
    _api.setToken(null);
    await _storage.delete(key: 'mezox_user');
    notifyListeners();
  }
}
