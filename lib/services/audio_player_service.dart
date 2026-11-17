import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/album.dart';
import '../models/track.dart';
import 'auth_service.dart';
import 'friends_service.dart';
import 'library_service.dart';
import 'lyrics_service.dart';
import 'youtube_player_service.dart';

/// High-level playback, queue and history controller.
///
/// Actual playback runs through [YouTubePlayerService] (official IFrame API).
class MezoxPlayerController extends ChangeNotifier {
  MezoxPlayerController(this.player);

  final YouTubePlayerService player;

  AuthService? _auth;
  LibraryService? _library;
  FriendsService? _friends;
  LyricsService? _lyrics;

  Track? _current;
  List<Track> _queue = <Track>[];
  int _queueIndex = -1;
  int _lastPlayerState = -1;
  bool _shuffle = false;
  bool _repeatOne = false;
  bool _repeatAll = false;
  bool _visualizerFullscreen = false;
  Timer? _playNudge;
  bool _closed = false;

  Track? get current => _current;
  List<Track> get queue => List.unmodifiable(_queue);
  int get queueIndex => _queueIndex;
  bool get isPlaying => player.isPlaying;
  bool get isBuffering => player.isBuffering;
  Duration get position => player.position;
  Duration get duration => player.duration;
  double get volume => player.volume;
  bool get muted => player.muted;
  String? get error => player.error;
  bool get shuffle => _shuffle;
  bool get repeatOne => _repeatOne;
  bool get repeatAll => _repeatAll;
  bool get visualizerFullscreen => _visualizerFullscreen;

  void bind({
    required AuthService auth,
    required LibraryService library,
    required FriendsService friends,
    required LyricsService lyrics,
  }) {
    _auth = auth;
    _library = library;
    _friends = friends;
    _lyrics = lyrics;
    final savedVolume = library.getSetting<double>('volume', 0.8);
    if (savedVolume > 0.2) {
      player.setVolume(savedVolume.clamp(0.5, 1.0).toDouble());
    } else {
      player.setVolume(0.8);
    }
  }

  Widget buildVideoView({Key? key}) => player.buildView(key: key);

  void attach() {
    player.addListener(_onPlayerChanged);
  }

  void _onPlayerChanged() {
    final state = player.state;
    if (state == 0 && _lastPlayerState == 1 && _queue.isNotEmpty) {
      _lastPlayerState = state;
      nextTrack();
      return;
    }
    _lastPlayerState = state;
    notifyListeners();
  }

  Future<void> playQueue(List<Track> tracks, int index) async {
    if (tracks.isEmpty || index < 0 || index >= tracks.length) return;
    _queue = List<Track>.from(tracks);
    _queueIndex = index;
    await playTrack(_queue[index]);
  }

  Future<void> playPlaylist(Album album, {bool shuffled = false}) async {
    if (album.tracks.isEmpty) return;
    final tracks = List<Track>.from(album.tracks);
    if (shuffled) tracks.shuffle();
    await playQueue(tracks, 0);
  }

  Future<void> playTrack(Track track, {bool fromSync = false}) async {
    _current = track;
    if (_queueIndex < 0 || _queue.isEmpty) {
      _queue = <Track>[track];
      _queueIndex = 0;
    }
    _lastPlayerState = -1;
    notifyListeners();

    await _library?.recordPlay(track);
    _lyrics?.scheduleFetch(track);
    if (!fromSync) _friends?.broadcastPlay(track);
    await player.load(track.sourceId);

    _playNudge?.cancel();
    final requestedId = track.id;
    _playNudge = Timer(const Duration(milliseconds: 900), () {
      if (_closed || _current?.id != requestedId) return;
      if (!player.apiReady || player.isPlaying) return;
      player.play();
    });
  }

  Future<void> play() async {
    await player.play();
    notifyListeners();
  }

  Future<void> pause() async {
    await player.pause();
    notifyListeners();
  }

  Future<void> togglePlayPause() async {
    if (_current == null) return;
    await player.togglePlayPause();
    notifyListeners();
  }

  Future<void> seek(Duration position) async {
    await player.seek(position);
    notifyListeners();
  }

  Future<void> setVolume(double value) async {
    await player.setVolume(value);
    await _library?.setSetting('volume', value);
    notifyListeners();
  }

  Future<void> toggleMute() async {
    await player.setMuted(!player.muted);
    notifyListeners();
  }

  Future<void> nextTrack() async {
    if (_queue.isEmpty) return;
    if (_shuffle && _queue.length > 1) {
      final rnd = math.Random();
      var next = _queueIndex;
      while (next == _queueIndex) {
        next = rnd.nextInt(_queue.length);
      }
      _queueIndex = next;
    } else if (_queueIndex + 1 >= _queue.length) {
      if (!_repeatAll) return;
      _queueIndex = 0;
    } else {
      _queueIndex++;
    }
    await playTrack(_queue[_queueIndex]);
  }

  Future<void> previousTrack() async {
    if (_queue.isEmpty) return;
    if (player.position > const Duration(seconds: 3)) {
      await seek(Duration.zero);
      return;
    }
    if (_queueIndex <= 0) {
      await seek(Duration.zero);
      return;
    }
    _queueIndex--;
    await playTrack(_queue[_queueIndex]);
  }

  void addToQueue(Track t) {
    _queue.add(t);
    notifyListeners();
  }

  void removeFromQueue(int index) {
    if (index < 0 || index >= _queue.length || index == _queueIndex) return;
    _queue.removeAt(index);
    if (index < _queueIndex) _queueIndex--;
    notifyListeners();
  }

  void moveInQueue(int oldIndex, int newIndex) {
    if (oldIndex < 0 ||
        oldIndex >= _queue.length ||
        newIndex < 0 ||
        newIndex >= _queue.length) {
      return;
    }
    final t = _queue.removeAt(oldIndex);
    _queue.insert(newIndex, t);
    if (oldIndex == _queueIndex) {
      _queueIndex = newIndex;
    } else if (oldIndex < _queueIndex && newIndex >= _queueIndex) {
      _queueIndex--;
    } else if (oldIndex > _queueIndex && newIndex <= _queueIndex) {
      _queueIndex++;
    }
    notifyListeners();
  }

  void clearQueue() {
    final keep = _current;
    _queue = keep == null ? <Track>[] : <Track>[keep];
    _queueIndex = keep == null ? -1 : 0;
    notifyListeners();
  }

  void toggleShuffle() {
    _shuffle = !_shuffle;
    _library?.setSetting('shuffle', _shuffle);
    notifyListeners();
  }

  void toggleRepeatOne() {
    _repeatOne = !_repeatOne;
    if (_repeatOne) _repeatAll = false;
    notifyListeners();
  }

  void toggleRepeatAll() {
    _repeatAll = !_repeatAll;
    if (_repeatAll) _repeatOne = false;
    notifyListeners();
  }

  void setFullscreen(bool value) {
    _visualizerFullscreen = value;
    notifyListeners();
  }

  Future<void> toggleFavourite() async {
    final t = _current;
    if (t == null) return;
    await _library?.toggleFavourite(t);
    notifyListeners();
  }

  @override
  void dispose() {
    _closed = true;
    _playNudge?.cancel();
    player.removeListener(_onPlayerChanged);
    super.dispose();
  }
}
