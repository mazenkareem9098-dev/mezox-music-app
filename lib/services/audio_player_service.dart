import 'dart:async';
import 'dart:math' as math;

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../models/track.dart';
import 'auth_service.dart';
import 'friends_service.dart';
import 'library_service.dart';
import 'lyrics_service.dart';
import 'youtube_service.dart';

class MezoxAudioHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer _player = AudioPlayer();
  AndroidLoudnessEnhancer? _enhancer;

  AudioPlayer get player => _player;

  MezoxAudioHandler() {
    _init();
  }

  Future<void> _init() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
    } catch (_) {}
    try {
      _enhancer = AndroidLoudnessEnhancer();
      await _enhancer!.setEnabled(true);
      await _enhancer!.setTargetGain(0.0);
    } catch (_) {
      _enhancer = null;
    }
    _player.playbackEventStream.map(_transformEvent).pipe(playbackState);
  }

  PlaybackState _transformEvent(PlaybackEvent event) {
    return PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        _player.playing ? MediaControl.pause : MediaControl.play,
        MediaControl.stop,
        MediaControl.skipToNext,
      ],
      systemActions: const {MediaAction.seek},
      androidCompactActionIndices: const [0, 1, 3],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: _player.playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: event.currentIndex,
    );
  }

  Future<void> setBoostPercent(int percent) async {
    final clamped = percent.clamp(100, 300);
    final linear = clamped / 100.0;
    final gainMb = 20.0 * (math.log(linear) / math.ln10) * 100.0;
    try {
      await _enhancer?.setTargetGain(gainMb);
    } catch (_) {}
    await _player.setVolume(1.0);
  }

  @override
  Future<void> play() => _player.play();
  @override
  Future<void> pause() => _player.pause();
  @override
  Future<void> stop() => _player.stop();
  @override
  Future<void> seek(Duration position) => _player.seek(position);

  /// YouTube audio links reject requests without these headers on some networks.
  Future<void> playUrl(String url, MediaItem item) async {
    mediaItem.add(item);
    await _player.setAudioSource(
      AudioSource.uri(
        Uri.parse(url),
        headers: const <String, String>{
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
          'Referer': 'https://www.youtube.com/',
        },
      ),
    );
    await _player.play();
  }

  Future<void> disposeHandler() async {
    await _player.dispose();
  }
}

class MezoxPlayerController extends ChangeNotifier {
  final MezoxAudioHandler handler;
  AuthService? _auth;
  YouTubeService? _yt;
  LibraryService? _library;
  FriendsService? _friends;
  LyricsService? _lyrics;

  Track? _current;
  List<Track> _queue = <Track>[];
  int _queueIndex = -1;
  bool _repeatOne = false;
  bool _repeatAll = false;
  int _volumePercent = 100;

  Track? get current => _current;
  List<Track> get queue => List.unmodifiable(_queue);
  bool get repeatOne => _repeatOne;
  bool get repeatAll => _repeatAll;
  int get volumePercent => _volumePercent;
  AudioPlayer get player => handler.player;

  MezoxPlayerController(this.handler) {
    handler.player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _onCompleted();
      }
    });
  }

  void bind({
    required AuthService auth,
    required YouTubeService yt,
    required LibraryService library,
    required FriendsService friends,
    required LyricsService lyrics,
  }) {
    _auth = auth;
    _yt = yt;
    _library = library;
    _friends = friends;
    _lyrics = lyrics;
  }

  Future<void> playQueue(List<Track> tracks, int index) async {
    if (tracks.isEmpty || index < 0 || index >= tracks.length) return;
    _queue = List<Track>.from(tracks);
    _queueIndex = index;
    await playTrack(_queue[index]);
  }

  Future<void> playTrack(Track track, {bool fromSync = false}) async {
    _current = track;
    notifyListeners();

    final item = MediaItem(
      id: track.id,
      title: track.title,
      artist: track.artist,
      artUri: track.artworkUrl.isNotEmpty ? Uri.parse(track.artworkUrl) : null,
      duration: track.duration,
    );

    final urls = await _yt?.getAudioUrls(track.sourceId) ?? <String>[];
    var started = false;
    for (final url in urls) {
      try {
        await handler.playUrl(url, item);
        await Future<void>.delayed(const Duration(milliseconds: 350));
        if (handler.player.playing) {
          started = true;
          break;
        }
      } catch (_) {
        continue;
      }
    }
    if (!started) {
      await handler.stop();
      return;
    }
    await handler.setBoostPercent(_volumePercent);

    if (_lyrics != null) {
      _lyrics!.scheduleFetch(track);
    }
    if (!fromSync && _friends != null) {
      _friends!.broadcastPlay(track);
    }
  }

  Future<void> nextTrack() async {
    if (_queue.isEmpty) return;
    if (_queueIndex + 1 >= _queue.length) {
      if (_repeatAll) {
        _queueIndex = 0;
      } else {
        return;
      }
    } else {
      _queueIndex++;
    }
    await playTrack(_queue[_queueIndex]);
  }

  Future<void> previousTrack() async {
    if (_queue.isEmpty) return;
    if (_queueIndex <= 0) {
      await handler.player.seek(Duration.zero);
      return;
    }
    _queueIndex--;
    await playTrack(_queue[_queueIndex]);
  }

  void _onCompleted() {
    if (_repeatOne && _current != null) {
      playTrack(_current!);
    } else {
      nextTrack();
    }
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

  Future<void> setVolumePercent(int p) async {
    _volumePercent = p.clamp(100, 300);
    await handler.setBoostPercent(_volumePercent);
    notifyListeners();
  }

  Future<void> togglePlayPause() async {
    if (handler.player.playing) {
      await handler.pause();
    } else {
      await handler.play();
    }
    notifyListeners();
  }
}
