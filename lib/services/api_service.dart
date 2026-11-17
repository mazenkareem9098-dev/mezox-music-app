import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Holds the public MQTT relay used for friends and listen-together.
/// No server owned by the user is required: the default is a free public broker.
class ApiService extends ChangeNotifier {
  static const String _defaultRelay = String.fromEnvironment(
    'MEZOX_API',
    defaultValue: 'broker.hivemq.com',
  );
  static const String _key = 'mezox_relay_host';

  String _baseUrl = _defaultRelay;

  String get baseUrl => _baseUrl;
  String get host => _baseUrl;

  ApiService() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    if (saved != null && saved.trim().isNotEmpty) {
      _setInternal(saved);
    }
  }

  void _setInternal(String raw) {
    var s = raw.trim();
    s = s.replaceFirst(RegExp(r'^(wss?|https?)://'), '');
    final slash = s.indexOf('/');
    if (slash > 0) s = s.substring(0, slash);
    if (s.isEmpty) return;
    _baseUrl = s;
    notifyListeners();
  }

  Future<void> setBaseUrl(String url) async {
    final clean = url.trim();
    if (clean.isEmpty) return;
    _setInternal(clean);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, _baseUrl);
  }
}
