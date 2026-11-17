import 'package:flutter/foundation.dart';

/// Shared query between the title-bar search field and the Search screen.
class SearchQueryService extends ChangeNotifier {
  String _query = '';
  int _revision = 0;

  String get query => _query;
  int get revision => _revision;

  void submit(String value) {
    _query = value.trim();
    _revision++;
    notifyListeners();
  }

  void clear() {
    _query = '';
    _revision++;
    notifyListeners();
  }
}
