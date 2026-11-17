import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../models/track.dart';

class YouTubeService extends ChangeNotifier {
  final YoutubeExplode _yt = YoutubeExplode();

  static const List<String> _piped = <String>[
    'https://pipedapi.adminforge.de',
    'https://pipedapi.kavin.rocks',
    'https://pipedapi.reallyaweso.me',
    'https://pipedapi.leptons.xyz',
  ];

  /// YouTube search used by live suggestions and the search button.
  /// Returns up to [limit] results with a public-frontend fallback.
  Future<List<Track>> search(String query, {int limit = 100}) async {
    final q = query.trim();
    if (q.isEmpty) return <Track>[];

    List<Track> results = <Track>[];
    try {
      final videos = await _yt.search.search(q).timeout(const Duration(seconds: 15));
      results = videos
          .map((v) => Track(
                id: 'yt_${v.id.value}',
                title: v.title,
                artist: v.author,
                artworkUrl: v.thumbnails.mediumResUrl,
                source: 'youtube',
                sourceId: v.id.value,
                duration: v.duration,
              ))
          .toList();
    } catch (_) {
      results = <Track>[];
    }

    if (results.length < 5) {
      final seen = results.map((t) => t.sourceId).toSet();
      for (final t in await _searchPiped(q)) {
        if (seen.add(t.sourceId)) results.add(t);
      }
    }

    if (results.length > limit) results = results.sublist(0, limit);
    return results;
  }

  Future<List<Track>> _searchPiped(String q) async {
    for (final base in _piped) {
      try {
        final uri = Uri.parse('$base/search').replace(
          queryParameters: <String, String>{'q': q, 'filter': 'videos'},
        );
        final res = await http
            .get(uri, headers: const {'User-Agent': 'MEZOX MUSIC/1.0'})
            .timeout(const Duration(seconds: 10));
        if (res.statusCode != 200) continue;
        final decoded = jsonDecode(res.body);
        if (decoded is! List) continue;
        final out = <Track>[];
        for (final item in decoded) {
          if (item is! Map<String, dynamic>) continue;
          final id = item['url']?.toString().split('=').lastOrNull ?? '';
          if (id.length != 11) continue;
          out.add(Track(
            id: 'yt_$id',
            title: item['title']?.toString() ?? id,
            artist: item['uploaderName']?.toString() ?? 'YouTube',
            artworkUrl: item['thumbnail']?.toString() ??
                'https://i.ytimg.com/vi/$id/mqdefault.jpg',
            source: 'youtube',
            sourceId: id,
            duration: item['duration'] is num
                ? Duration(seconds: (item['duration'] as num).toInt())
                : null,
          ));
        }
        if (out.isNotEmpty) return out;
      } catch (_) {
        continue;
      }
    }
    return <Track>[];
  }

  /// Direct audio URLs. Piped is tried first: those links need no cipher.
  Future<List<String>> getAudioUrls(String videoId) async {
    final urls = <String>[];
    for (final base in _piped) {
      try {
        final res = await http
            .get(Uri.parse('$base/streams/$videoId'))
            .timeout(const Duration(seconds: 10));
        if (res.statusCode != 200) continue;
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        for (final s in (body['audioStreams'] as List<dynamic>? ?? const [])) {
          if (s is Map<String, dynamic> && s['url'] != null) {
            urls.add(s['url'].toString());
          }
        }
        if (urls.isNotEmpty) return urls.take(3).toList();
      } catch (_) {
        continue;
      }
    }

    try {
      final manifest = await _yt.videos.streamsClient
          .getManifest(videoId)
          .timeout(const Duration(seconds: 15));
      for (final s in manifest.audioOnly) {
        urls.add(s.url.toString());
      }
      for (final s in manifest.audioVideo) {
        urls.add(s.url.toString());
      }
    } catch (_) {}
    return urls.take(4).toList();
  }

  @override
  void dispose() {
    _yt.close();
    super.dispose();
  }
}
