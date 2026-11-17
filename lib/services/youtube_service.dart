import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/track.dart';

/// YouTube metadata search.
///
/// Uses YouTube Data API v3 when an API key is configured in Settings and
/// falls back to public metadata frontends otherwise. Playback itself is
/// always handled by the official IFrame API in [YouTubePlayerService].
class YouTubeService extends ChangeNotifier {
  static const List<String> _frontends = <String>[
    'https://yt.chocolatemoo53.com',
    'https://pipedapi.kavin.rocks',
    'https://pipedapi.adminforge.de',
    'https://pipedapi.reallyaweso.me',
    'https://pipedapi.leptons.xyz',
  ];

  final Map<String, List<Track>> _cache = <String, List<Track>>{};

  String _apiKey = '';
  bool _loading = false;
  String? _lastError;

  bool get hasApiKey => _apiKey.isNotEmpty;
  bool get loading => _loading;
  String? get lastError => _lastError;

  void setApiKey(String key) {
    _apiKey = key.trim();
    notifyListeners();
  }

  Future<List<Track>> suggest(String query) => search(query, limit: 10);

  Future<List<Track>> category(String query, {int limit = 40}) =>
      search(query, limit: limit);

  Future<List<Track>> related(Track track) =>
      search('${track.title} ${track.artist}', limit: 30);

  Future<List<Track>> search(String query, {int limit = 60}) async {
    final q = query.trim();
    if (q.isEmpty) return <Track>[];
    final cacheKey = '$limit|$q';
    final cached = _cache[cacheKey];
    if (cached != null) return cached;

    _loading = true;
    _lastError = null;
    notifyListeners();

    List<Track> tracks = <Track>[];
    if (hasApiKey) {
      try {
        tracks = await _searchDataApi(q, limit);
      } catch (e) {
        _lastError = 'YouTube API: $e';
      }
    }
    if (tracks.isEmpty) {
      try {
        tracks = await _searchInvidious(q, limit);
      } catch (e) {
        _lastError ??= 'Invidious: $e';
      }
    }
    if (tracks.isEmpty) {
      try {
        tracks = await _searchFrontend(q, limit);
      } catch (e) {
        _lastError ??= 'Search unavailable: $e';
      }
    }

    if (tracks.isNotEmpty) {
      if (_cache.length > 40) _cache.clear();
      _cache[cacheKey] = tracks;
    }
    _loading = false;
    notifyListeners();
    return tracks;
  }

  Future<List<Track>> _searchDataApi(String q, int limit) async {
    final take = limit.clamp(1, 50);
    final searchUri = Uri.https('www.googleapis.com', '/youtube/v3/search', {
      'part': 'snippet',
      'type': 'video',
      'videoEmbeddable': 'true',
      'maxResults': '$take',
      'q': q,
      'key': _apiKey,
    });
    final res = await http.get(searchUri).timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw HttpException(res.statusCode, res.body);
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final items = (body['items'] as List<dynamic>? ?? const <dynamic>[]);
    final ids = <String>[];
    final partial = <String, Map<String, String>>{};

    for (final raw in items) {
      if (raw is! Map<String, dynamic>) continue;
      final id = (raw['id'] as Map<String, dynamic>?)?['videoId']?.toString();
      if (id == null || id.isEmpty) continue;
      final snippet = (raw['snippet'] as Map<String, dynamic>?) ?? const {};
      final thumbMap = (snippet['thumbnails'] as Map<String, dynamic>?) ?? const {};
      final medium = (thumbMap['medium'] as Map<String, dynamic>?) ??
          (thumbMap['default'] as Map<String, dynamic>?) ??
          const {};
      ids.add(id);
      partial[id] = <String, String>{
        'title': snippet['title']?.toString() ?? id,
        'artist': snippet['channelTitle']?.toString() ?? 'YouTube',
        'thumb': medium['url']?.toString() ?? 'https://i.ytimg.com/vi/$id/hqdefault.jpg',
      };
    }
    if (ids.isEmpty) return <Track>[];

    final durations = <String, Duration>{};
    try {
      final detailsUri = Uri.https('www.googleapis.com', '/youtube/v3/videos', {
        'part': 'contentDetails',
        'id': ids.join(','),
        'key': _apiKey,
      });
      final dres = await http.get(detailsUri).timeout(const Duration(seconds: 15));
      if (dres.statusCode == 200) {
        final db = jsonDecode(dres.body) as Map<String, dynamic>;
        for (final raw in (db['items'] as List<dynamic>? ?? const <dynamic>[])) {
          if (raw is! Map<String, dynamic>) continue;
          final id = raw['id']?.toString();
          final cd = (raw['contentDetails'] as Map<String, dynamic>?) ?? const {};
          if (id != null && cd['duration'] != null) {
            durations[id] = parseIsoDuration(cd['duration'].toString());
          }
        }
      }
    } catch (_) {}

    return ids.map((id) {
      final p = partial[id]!;
      return Track(
        id: 'yt_$id',
        title: p['title']!,
        artist: p['artist']!,
        artworkUrl: p['thumb']!,
        source: 'youtube',
        sourceId: id,
        duration: durations[id],
      );
    }).toList();
  }

  /// Primary metadata fallback — Invidious public API (JSON, no captcha).
  Future<List<Track>> _searchInvidious(String q, int limit) async {
    for (final base in _frontends) {
      try {
        final uri = Uri.parse('$base/api/v1/search').replace(
          queryParameters: <String, String>{'q': q, 'type': 'video'},
        );
        final res = await http
            .get(uri, headers: const {'User-Agent': 'M MUSIC/1.0'})
            .timeout(const Duration(seconds: 8));
        if (res.statusCode != 200) continue;
        final decoded = jsonDecode(res.body);
        if (decoded is! List) continue;

        final out = <Track>[];
        for (final item in decoded) {
          if (item is! Map<String, dynamic>) continue;
          if (item['type']?.toString() != 'video') continue;
          final id = item['videoId']?.toString() ?? '';
          if (id.length != 11) continue;
          final seconds = item['lengthSeconds'] is num
              ? (item['lengthSeconds'] as num).toInt()
              : int.tryParse(item['lengthSeconds']?.toString() ?? '');
          out.add(Track(
            id: 'yt_$id',
            title: item['title']?.toString() ?? id,
            artist: item['author']?.toString() ?? 'YouTube',
            artworkUrl: 'https://i.ytimg.com/vi/$id/hqdefault.jpg',
            source: 'youtube',
            sourceId: id,
            duration:
                seconds != null && seconds > 0 ? Duration(seconds: seconds) : null,
          ));
          if (out.length >= limit) break;
        }
        if (out.isNotEmpty) return out;
      } catch (_) {
        continue;
      }
    }
    return <Track>[];
  }

  Future<List<Track>> _searchFrontend(String q, int limit) async {
    for (final base in _frontends.skip(1)) {
      try {
        final uri = Uri.parse('$base/search').replace(
          queryParameters: <String, String>{'q': q, 'filter': 'videos'},
        );
        final res = await http
            .get(uri, headers: const {'User-Agent': 'M MUSIC/1.0'})
            .timeout(const Duration(seconds: 8));
        if (res.statusCode != 200) continue;
        final decoded = jsonDecode(res.body);
        if (decoded is! List) continue;

        final out = <Track>[];
        for (final item in decoded) {
          if (item is! Map<String, dynamic>) continue;
          final rawUrl = item['url']?.toString() ?? '';
          final id = RegExp(r'(?:v=|/)([a-zA-Z0-9_-]{11})')
              .firstMatch(rawUrl)?.group(1);
          if (id == null || id.isEmpty) continue;
          final seconds = item['duration'] is num
              ? (item['duration'] as num).toInt()
              : int.tryParse(item['lengthSeconds']?.toString() ?? '');
          out.add(Track(
            id: 'yt_$id',
            title: item['title']?.toString() ?? id,
            artist: item['uploaderName']?.toString() ??
                item['uploader']?.toString() ??
                'YouTube',
            artworkUrl: item['thumbnail']?.toString() ??
                'https://i.ytimg.com/vi/$id/hqdefault.jpg',
            source: 'youtube',
            sourceId: id,
            duration:
                seconds != null && seconds > 0 ? Duration(seconds: seconds) : null,
          ));
          if (out.length >= limit) break;
        }
        if (out.isNotEmpty) return out;
      } catch (_) {
        continue;
      }
    }
    return <Track>[];
  }

  static Duration parseIsoDuration(String iso) {
    final m = RegExp(r'PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?').firstMatch(iso);
    if (m == null) return Duration.zero;
    return Duration(
      hours: int.tryParse(m.group(1) ?? '0') ?? 0,
      minutes: int.tryParse(m.group(2) ?? '0') ?? 0,
      seconds: int.tryParse(m.group(3) ?? '0') ?? 0,
    );
  }
}

class HttpException implements Exception {
  const HttpException(this.statusCode, this.body);

  final int statusCode;
  final String body;

  @override
  String toString() => 'HTTP $statusCode';
}
