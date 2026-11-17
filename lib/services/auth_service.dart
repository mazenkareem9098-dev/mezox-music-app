import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import '../models/user_profile.dart';
import 'api_service.dart';

/// Local-only account. The typed name becomes the public username.
/// No password, no OAuth, no account server.
class AuthService extends ChangeNotifier {
  final _storage = const FlutterSecureStorage();
  UserProfile? _user;
  late ApiService _api;

  UserProfile? get user => _user;
  bool get isLoggedIn => _user != null;
  ApiService get api => _api;

  AuthService() {
    _api = ApiService();
    _restore();
  }

  Future<void> _restore() async {
    final raw = await _storage.read(key: 'mezox_user');
    if (raw != null) {
      _user = UserProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      notifyListeners();
    }
  }

  Future<void> _save(UserProfile u) async {
    _user = u;
    await _storage.write(key: 'mezox_user', value: jsonEncode({
          'username': u.username,
          'displayName': u.displayName,
          'age': u.age,
          'token': u.token,
        }));
    notifyListeners();
  }

  Future<String?> signUpWithName(String name) async {
    final clean = name.trim();
    if (clean.isEmpty) return 'Enter your name first';
    final username = normalizeName(clean);
    if (username.length < 2) return 'Name is too short';
    final profile = UserProfile(
      username: username,
      displayName: clean,
      age: 0,
      token: const Uuid().v4(),
    );
    await _save(profile);
    return null;
  }

  Future<void> logout() async {
    _user = null;
    await _storage.delete(key: 'mezox_user');
    notifyListeners();
  }
}

String normalizeName(String raw) {
  final s = raw.trim().toLowerCase();
  final cleaned = s.replaceAll(RegExp(r'[^\p{L}\p{N}_]', unicode: true), '');
  return cleaned.length > 24 ? cleaned.substring(0, 24) : cleaned;
}
