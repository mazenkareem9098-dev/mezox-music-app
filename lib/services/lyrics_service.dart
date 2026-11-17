import 'dart:async';
import 'package:flutter/foundation.dart';
import 'api_service.dart';
import '../models/track.dart';

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

  /// Schedules lyrics fetch 10 seconds after playback starts for [track].
  void scheduleFetch(ApiService api, Track track) {
    _timer?.cancel();
    if (_lastTrackId == track.id && _currentLyrics.isNotEmpty) return;
    _lastTrackId = track.id;
    _currentLyrics = '';
    _loading = false;
    notifyListeners();
    _timer = Timer(const Duration(seconds: 10), () async {
      _loading = true;
      notifyListeners();
      try {
        final res = await api.dio.post('/lyrics', data: {
          'title': track.title,
          'artist': track.artist,
          'trackId': track.id,
        });
        _currentLyrics = (res.data['lyrics'] as String?)?.trim() ?? 'Lyrics not found.';
      } catch (_) {
        _currentLyrics = 'Lyrics unavailable right now.';
      } finally {
        _loading = false;
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
