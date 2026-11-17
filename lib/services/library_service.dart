import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/album.dart';
import '../models/track.dart';

/// Local, persistent user data — playlists, likes, history and preferences.
class LibraryService extends ChangeNotifier {
  static const String _favKey = 'mezox_favourites';
  static const String _albumsKey = 'mezox_albums';
  static const String _recentKey = 'mm_recently_played';
  static const String _searchKey = 'mm_search_history';
  static const String _settingPrefix = 'mm_setting_';

  SharedPreferences? _prefs;
  final _uuid = const Uuid();

  List<Track> _favourites = <Track>[];
  List<Album> _albums = <Album>[];
  List<Track> _recent = <Track>[];
  List<String> _searches = <String>[];

  List<Track> get favourites => List.unmodifiable(_favourites);
  List<Album> get albums => List.unmodifiable(_albums);
  List<Album> get playlists => List.unmodifiable(_albums);
  List<Track> get recentlyPlayed => List.unmodifiable(_recent);
  List<String> get searchHistory => List.unmodifiable(_searches);

  bool isFavourite(String trackId) => _favourites.any((t) => t.id == trackId);

  Future<void> load() async {
    _prefs ??= await SharedPreferences.getInstance();
    final p = _prefs!;
    _favourites = _decodeTracks(p.getStringList(_favKey));
    _albums = (p.getStringList(_albumsKey) ?? const <String>[])
        .map(_decodeAlbum)
        .whereType<Album>()
        .toList();
    _recent = _decodeTracks(p.getStringList(_recentKey));
    _searches = p.getStringList(_searchKey) ?? <String>[];
    notifyListeners();
  }

  static List<Track> _decodeTracks(List<String>? raw) =>
      (raw ?? const <String>[])
          .map((s) {
            try {
              return Track.fromJson(jsonDecode(s) as Map<String, dynamic>);
            } catch (_) {
              return null;
            }
          })
          .whereType<Track>()
          .toList();

  static Album? _decodeAlbum(String raw) {
    try {
      return Album.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> _save() async {
    final p = _prefs ?? await SharedPreferences.getInstance();
    _prefs = p;
    await p.setStringList(
      _favKey,
      _favourites.map((t) => jsonEncode(t.toJson())).toList(),
    );
    await p.setStringList(
      _albumsKey,
      _albums.map((a) => jsonEncode(a.toJson())).toList(),
    );
    await p.setStringList(
      _recentKey,
      _recent.map((t) => jsonEncode(t.toJson())).toList(),
    );
    await p.setStringList(_searchKey, _searches);
    notifyListeners();
  }

  // ---------------------------------------------------------------- favourites

  Future<void> toggleFavourite(Track t) async {
    if (isFavourite(t.id)) {
      _favourites.removeWhere((x) => x.id == t.id);
    } else {
      _favourites.insert(0, t);
    }
    await _save();
  }

  Future<void> addFavourite(Track t) async {
    if (isFavourite(t.id)) return;
    _favourites.insert(0, t);
    await _save();
  }

  Future<void> removeFavourite(String trackId) async {
    _favourites.removeWhere((t) => t.id == trackId);
    await _save();
  }

  // ---------------------------------------------------------------- playlists

  Future<Album> createAlbum(String name, [String description = '']) =>
      createPlaylist(name, description);

  Future<Album> createPlaylist(String name, [String description = '']) async {
    final album = Album(
      id: _uuid.v4(),
      name: name.trim().isEmpty ? 'My Playlist' : name.trim(),
      description: description.trim(),
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    _albums.insert(0, album);
    await _save();
    return album;
  }

  Future<void> renameAlbum(String albumId, String name) async {
    final a = _find(albumId);
    if (a == null) return;
    a.name = name.trim().isEmpty ? a.name : name.trim();
    await _save();
  }

  Future<void> updatePlaylist(String albumId,
      {String? name, String? description, String? coverUrl}) async {
    final a = _find(albumId);
    if (a == null) return;
    if (name != null && name.trim().isNotEmpty) a.name = name.trim();
    if (description != null) a.description = description.trim();
    if (coverUrl != null) a.coverUrl = coverUrl.trim();
    await _save();
  }

  Future<void> deleteAlbum(String albumId) async {
    _albums.removeWhere((a) => a.id == albumId);
    await _save();
  }

  Future<void> addToAlbum(String albumId, Track t) => addToPlaylist(albumId, t);

  Future<void> addToPlaylist(String albumId, Track t) async {
    final a = _find(albumId);
    if (a == null || a.tracks.any((x) => x.id == t.id)) return;
    a.tracks.add(t);
    if (a.coverUrl.isEmpty) a.coverUrl = t.artworkUrl;
    await _save();
  }

  Future<void> removeFromAlbum(String albumId, String trackId) async {
    final a = _find(albumId);
    if (a == null) return;
    a.tracks.removeWhere((t) => t.id == trackId);
    await _save();
  }

  Future<void> removeFromPlaylist(String albumId, String trackId) =>
      removeFromAlbum(albumId, trackId);

  Future<void> reorderPlaylist(
      String albumId, int oldIndex, int newIndex) async {
    final a = _find(albumId);
    if (a == null ||
        oldIndex < 0 ||
        oldIndex >= a.tracks.length ||
        newIndex < 0 ||
        newIndex >= a.tracks.length) {
      return;
    }
    final track = a.tracks.removeAt(oldIndex);
    a.tracks.insert(newIndex, track);
    await _save();
  }

  Album? _find(String id) {
    for (final a in _albums) {
      if (a.id == id) return a;
    }
    return null;
  }

  // ------------------------------------------------------------------- history

  Future<void> recordPlay(Track t) async {
    _recent.removeWhere((x) => x.id == t.id);
    _recent.insert(0, t);
    if (_recent.length > 100) _recent = _recent.sublist(0, 100);
    await _save();
  }

  Future<void> recordSearch(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    _searches.remove(q);
    _searches.insert(0, q);
    if (_searches.length > 25) _searches = _searches.sublist(0, 25);
    await _save();
  }

  Future<void> clearRecentlyPlayed() async {
    _recent = <Track>[];
    await _save();
  }

  Future<void> clearSearchHistory() async {
    _searches = <String>[];
    await _save();
  }

  // ------------------------------------------------------------------ settings

  T getSetting<T>(String key, T fallback) {
    final p = _prefs;
    if (p == null) return fallback;
    final k = '$_settingPrefix$key';
    final value = p.get(k);
    if (value is T) return value;
    return fallback;
  }

  Future<void> setSetting<T>(String key, T value) async {
    final p = _prefs ?? await SharedPreferences.getInstance();
    _prefs = p;
    final k = '$_settingPrefix$key';
    if (value is String) {
      await p.setString(k, value);
    } else if (value is bool) {
      await p.setBool(k, value);
    } else if (value is int) {
      await p.setInt(k, value);
    } else if (value is double) {
      await p.setDouble(k, value);
    } else {
      await p.setString(k, jsonEncode(value));
    }
    notifyListeners();
  }

  String get youtubeApiKey => getSetting<String>('youtubeApiKey', '');
  Future<void> setYoutubeApiKey(String key) => setSetting('youtubeApiKey', key.trim());

  // ------------------------------------------------------------ import/export

  String exportData() => jsonEncode(<String, dynamic>{
        'version': 1,
        'favourites': _favourites.map((t) => t.toJson()).toList(),
        'playlists': _albums.map((a) => a.toJson()).toList(),
        'recent': _recent.map((t) => t.toJson()).toList(),
        'searchHistory': _searches,
      });

  Future<void> importData(String raw) async {
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    _favourites = _decodeTracks(
      (decoded['favourites'] as List<dynamic>? ?? const <dynamic>[])
          .map((e) => jsonEncode(e))
          .toList(),
    );
    _albums = (decoded['playlists'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(Album.fromJson)
        .toList();
    _recent = _decodeTracks(
      (decoded['recent'] as List<dynamic>? ?? const <dynamic>[])
          .map((e) => jsonEncode(e))
          .toList(),
    );
    _searches = (decoded['searchHistory'] as List<dynamic>? ?? const <dynamic>[])
        .map((e) => e.toString())
        .toList();
    await _save();
  }

  Future<void> resetAll() async {
    _favourites = <Track>[];
    _albums = <Album>[];
    _recent = <Track>[];
    _searches = <String>[];
    await _save();
  }
}
