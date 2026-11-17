import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/album.dart';
import '../models/track.dart';

class LibraryService extends ChangeNotifier {
  static const _favKey = 'mezox_favourites';
  static const _albumsKey = 'mezox_albums';

  final List<Track> _favourites = [];
  final List<Album> _albums = [];
  final _uuid = const Uuid();

  List<Track> get favourites => List.unmodifiable(_favourites);
  List<Album> get albums => List.unmodifiable(_albums);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final favRaw = prefs.getString(_favKey);
    final albRaw = prefs.getString(_albumsKey);
    _favourites
      ..clear()
      ..addAll(favRaw == null
          ? []
          : (jsonDecode(favRaw) as List)
              .map((e) => Track.fromJson(Map<String, dynamic>.from(e))));
    _albums
      ..clear()
      ..addAll(albRaw == null
          ? []
          : (jsonDecode(albRaw) as List)
              .map((e) => Album.fromJson(Map<String, dynamic>.from(e))));
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _favKey, jsonEncode(_favourites.map((t) => t.toJson()).toList()));
    await prefs.setString(
        _albumsKey, jsonEncode(_albums.map((a) => a.toJson()).toList()));
  }

  bool isFavourite(String trackId) => _favourites.any((t) => t.id == trackId);

  Future<void> toggleFavourite(Track t) async {
    final idx = _favourites.indexWhere((x) => x.id == t.id);
    if (idx >= 0) {
      _favourites.removeAt(idx);
    } else {
      _favourites.add(t);
    }
    await _persist();
    notifyListeners();
  }

  Future<Album> createAlbum(String name) async {
    final a = Album(id: _uuid.v4(), name: name);
    _albums.add(a);
    await _persist();
    notifyListeners();
    return a;
  }

  Future<void> renameAlbum(String albumId, String name) async {
    final a = _albums.firstWhere((x) => x.id == albumId);
    a.name = name;
    await _persist();
    notifyListeners();
  }

  Future<void> deleteAlbum(String albumId) async {
    _albums.removeWhere((x) => x.id == albumId);
    await _persist();
    notifyListeners();
  }

  Future<void> addToAlbum(String albumId, Track t) async {
    final a = _albums.firstWhere((x) => x.id == albumId);
    if (!a.tracks.any((x) => x.id == t.id)) {
      a.tracks.add(t);
      await _persist();
      notifyListeners();
    }
  }

  Future<void> removeFromAlbum(String albumId, String trackId) async {
    final a = _albums.firstWhere((x) => x.id == albumId);
    a.tracks.removeWhere((x) => x.id == trackId);
    await _persist();
    notifyListeners();
  }
}
