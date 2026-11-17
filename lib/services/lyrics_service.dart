import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/track.dart';

/// Lyrics come straight from public lyric APIs after 10 seconds of playback.
/// No AI key and no MEZOX server are involved.
class LyricsService extends ChangeNotifier {
  String _currentLyrics = '';
  bool _loading = false;
  Timer? _timer;
  String? _lastTrackId;

  String get currentLyrics => _currentLyrics;
  bool get loading => _loading;

  void clear() {
    _timer?.cancel();
    _currentLyrics = '';
    _loading = false;
    _lastTrackId = null;
    notifyListeners();
  }

  void scheduleFetch(Track track) {
    _timer?.cancel();
    if (_lastTrackId == track.id && _currentLyrics.isNotEmpty) return;
    _lastTrackId = track.id;
    _currentLyrics = '';
    _loading = false;
    notifyListeners();
    _timer = Timer(const Duration(seconds: 10), () => _fetch(track));
  }

  Future<void> _fetch(Track track) async {
    _loading = true;
    notifyListeners();
    try {
      final uri = Uri.https('lrclib.net', '/api/get', {
        'track_name': track.title,
        'artist_name': track.artist,
      });
      final res = await http
          .get(uri, headers: {'User-Agent': 'MEZOX MUSIC/1.0'})
          .timeout(const Duration(seconds: 12));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final synced = body['syncedLyrics'] as String?;
        final plain = body['plainLyrics'] as String?;
        _currentLyrics = (synced ?? plain ?? '').trim();
      }
      if (_currentLyrics.isEmpty) {
        final fallback = Uri.https('api.lyrics.ovh', '/v1/${track.artist}/${track.title}');
        final alt = await http.get(fallback).timeout(const Duration(seconds: 12));
        if (alt.statusCode == 200) {
          final body = jsonDecode(alt.body) as Map<String, dynamic>;
          _currentLyrics = (body['lyrics'] as String? ?? '').trim();
        }
      }
      if (_currentLyrics.isEmpty) _currentLyrics = 'Lyrics not found for this track.';
    } catch (_) {
      _currentLyrics = 'Lyrics unavailable right now.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
