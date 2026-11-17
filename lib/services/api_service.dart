import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService extends ChangeNotifier {
  static const String _defaultBaseUrl = String.fromEnvironment(
    'MEZOX_API',
    defaultValue: 'http://10.0.2.2:3000',
  );
  static const String _key = 'mezox_server_url';

  String _baseUrl = _defaultBaseUrl;
  late final Dio dio;

  String get baseUrl => _baseUrl;

  ApiService() {
    dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
    ));
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    if (saved != null && saved.trim().isNotEmpty) {
      _setBaseUrlInternal(saved.trim());
    }
  }

  void _setBaseUrlInternal(String url) {
    _baseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
    dio.options.baseUrl = _baseUrl;
  }

  Future<void> setBaseUrl(String url) async {
    final clean = url.trim();
    if (clean.isEmpty) return;
    _setBaseUrlInternal(clean);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, _baseUrl);
    notifyListeners();
  }

  String? _token;
  String? get token => _token;

  void setToken(String? t) {
    _token = t;
    if (t != null) {
      dio.options.headers['Authorization'] = 'Bearer $t';
    } else {
      dio.options.headers.remove('Authorization');
    }
    notifyListeners();
  }
}
