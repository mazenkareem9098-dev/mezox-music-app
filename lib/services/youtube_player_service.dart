import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Wraps the official YouTube IFrame Player API inside a WebView.
///
/// No direct audio extraction, no stream decipher, no ad removal — playback
/// always goes through YouTube's own player.
class YouTubePlayerService extends ChangeNotifier {
  final bool _debug = Platform.environment['MM_DEBUG_PLAYER'] == '1';

  YouTubePlayerService() {
    _settings = InAppWebViewSettings(
      javaScriptEnabled: true,
      mediaPlaybackRequiresUserGesture: false,
      allowsInlineMediaPlayback: true,
      supportZoom: false,
      transparentBackground: true,
      allowBackgroundAudioPlaying: true,
      disableContextMenu: true,
      disableVerticalScroll: true,
      disableHorizontalScroll: true,
      useHybridComposition: false,
      mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
    );
  }

  late final InAppWebViewSettings _settings;
  InAppWebViewController? _controller;
  String? _pendingVideoId;
  bool _apiReady = false;
  bool _playing = false;
  bool _buffering = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _volume = 0.8;
  bool _muted = false;
  String? _error;
  int _state = -1;

  bool get apiReady => _apiReady;
  bool get isPlaying => _playing;
  bool get isBuffering => _buffering;
  Duration get position => _position;
  Duration get duration => _duration;
  double get volume => _volume;
  bool get muted => _muted;
  String? get error => _error;
  int get state => _state;

  /// The single WebView instance. Keep it mounted for the lifetime of the app.
  Widget buildView({Key? key}) => InAppWebView(
        key: key,
        initialSettings: _settings,
        initialData: InAppWebViewInitialData(data: _playerHtml),
        onWebViewCreated: (controller) {
          _controller = controller;
          controller.addJavaScriptHandler(
            handlerName: 'mmReady',
            callback: (_) {
              _apiReady = true;
              _error = null;
              _log('ready volume=${(_volume * 100).round()}');
              setVolume(_volume);
              if (_muted) setMuted(true);
              notifyListeners();
              final id = _pendingVideoId;
              if (id != null) {
                _pendingVideoId = null;
                load(id);
              }
              return true;
            },
          );
          controller.addJavaScriptHandler(
            handlerName: 'mmState',
            callback: (args) {
              if (args.isEmpty) return true;
              final data = _asMap(args.first);
              _state = _asInt(data['state']);
              _playing = _state == 1;
              _buffering = _state == 3;
              _log('state=$_state playing=$_playing buffering=$_buffering');
              if (_state == 5) {
                // Video cued — nothing else to do.
              }
              _error = null;
              notifyListeners();
              return true;
            },
          );
          controller.addJavaScriptHandler(
            handlerName: 'mmTime',
            callback: (args) {
              if (args.isEmpty) return true;
              final data = _asMap(args.first);
              _position = Duration(milliseconds: _asInt(data['position']));
              final d = _asInt(data['duration']);
              if (d > 0) _duration = Duration(seconds: d);
              notifyListeners();
              return true;
            },
          );
          controller.addJavaScriptHandler(
            handlerName: 'mmError',
            callback: (args) {
              _error = args.isEmpty ? 'YouTube player error' : args.first.toString();
              _log('error=$_error');
              _playing = false;
              _buffering = false;
              notifyListeners();
              return true;
            },
          );
        },
        onLoadStop: (controller, url) async {
          await controller.evaluateJavascript(
            source: 'window.__mmNotifyReady && window.__mmNotifyReady();',
          );
        },
      );

  Future<void> load(String videoId) async {
    _log('load=$videoId ready=$_apiReady');
    _error = null;
    _position = Duration.zero;
    _duration = Duration.zero;
    _playing = false;
    _buffering = true;
    notifyListeners();
    final controller = _controller;
    if (controller == null || !_apiReady) {
      _pendingVideoId = videoId;
      return;
    }
    await _run("window.mmLoad('${_esc(videoId)}')");
  }

  Future<void> play() => _run('window.mmPlay()');
  Future<void> pause() => _run('window.mmPause()');
  Future<void> togglePlayPause() => _run('window.mmToggle()');
  Future<void> stop() => _run('window.mmStop()');

  Future<void> seek(Duration position) async {
    _position = position;
    notifyListeners();
    await _run('window.mmSeek(${position.inSeconds})');
  }

  Future<void> setVolume(double value) async {
    _volume = value.clamp(0.0, 1.0).toDouble();
    notifyListeners();
    await _run('window.mmVolume(${(_volume * 100).round()})');
  }

  Future<void> setMuted(bool muted) async {
    _muted = muted;
    notifyListeners();
    await _run('window.mmMute(${muted ? 'true' : 'false'})');
  }

  void _log(String message) {
    if (_debug) debugPrint('MM_PLAYER $message');
  }

  Future<void> _run(String source) async {
    final controller = _controller;
    if (controller == null || !_apiReady) return;
    try {
      await controller.evaluateJavascript(source: source);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is String) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    return <String, dynamic>{};
  }

  static int _asInt(dynamic value) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static String _esc(String s) => s.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '');

  @override
  void dispose() {
    _controller = null;
    super.dispose();
  }

  static const String _playerHtml = r'''
<!doctype html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<meta name="referrer" content="strict-origin-when-cross-origin">
<style>
  html, body { margin:0; padding:0; width:100%; height:100%; background:#080808; overflow:hidden; }
  #player { width:100%; height:100%; }
  iframe { width:100%; height:100%; border:0; pointer-events:none; }
</style>
</head>
<body>
<div id="player"></div>
<script>
var mmPlayer = null;
var mmReady = false;
var mmQueued = null;
var mmAutoPlayPending = false;
function mmSend(handler, data) {
  try {
    if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
      window.flutter_inappwebview.callHandler(handler, data || {});
    }
  } catch (e) {}
}
window.__mmNotifyReady = function () { if (mmReady) mmSend('mmReady', {ok:true}); };
window.onYouTubeIframeAPIReady = function () {
  mmPlayer = new YT.Player('player', {
    width: '100%',
    height: '100%',
    playerVars: {
      playsinline: 1,
      controls: 0,
      disablekb: 1,
      fs: 0,
      iv_load_policy: 3,
      modestbranding: 1,
      rel: 0,
      showinfo: 0
    },
    events: {
      onReady: function () {
        mmReady = true;
        mmPlayer.setVolume(80);
        mmSend('mmReady', {ok:true});
        if (mmQueued) { mmLoad(mmQueued); mmQueued = null; }
      },
      onStateChange: function (e) {
        mmSend('mmState', {state: e.data});
        if ((e.data === YT.PlayerState.PAUSED ||
             e.data === YT.PlayerState.CUED ||
             e.data === -1) && mmAutoPlayPending) {
          mmAutoPlayPending = false;
          try { mmPlayer.unMute(); mmPlayer.playVideo(); } catch (err) {}
        }
        if (e.data === YT.PlayerState.PLAYING) mmAutoPlayPending = false;
        if (e.data === YT.PlayerState.ENDED) mmSend('mmState', {state: 0});
      },
      onError: function (e) {
        mmSend('mmError', {code: e.data});
      }
    }
  });
  var mmIframe = document.querySelector('iframe');
  if (mmIframe) {
    mmIframe.setAttribute('referrerpolicy', 'strict-origin-when-cross-origin');
  }
};
function mmLoad(id) {
  if (!mmReady) { mmQueued = id; return; }
  mmAutoPlayPending = true;
  try {
    mmPlayer.unMute();
    mmPlayer.loadVideoById(id);
    setTimeout(function () {
      if (!mmAutoPlayPending) return;
      mmAutoPlayPending = false;
      try { mmPlayer.unMute(); mmPlayer.playVideo(); } catch (err) {}
    }, 700);
  } catch (e) { mmSend('mmError', {message: String(e)}); }
}
function mmPlay() { try { mmPlayer.playVideo(); } catch (e) {} }
function mmPause() { try { mmPlayer.pauseVideo(); } catch (e) {} }
function mmToggle() {
  try {
    if (mmPlayer.getPlayerState() === YT.PlayerState.PLAYING) mmPlayer.pauseVideo();
    else mmPlayer.playVideo();
  } catch (e) {}
}
function mmStop() { try { mmPlayer.stopVideo(); } catch (e) {} }
function mmSeek(sec) { try { mmPlayer.seekTo(sec, true); } catch (e) {} }
function mmVolume(v) { try { mmPlayer.setVolume(v); } catch (e) {} }
function mMute(m) {
  try { if (m) mmPlayer.mute(); else mmPlayer.unMute(); } catch (e) {}
}
window.mmLoad = mmLoad;
window.mmPlay = mmPlay;
window.mmPause = mmPause;
window.mmToggle = mmToggle;
window.mmStop = mmStop;
window.mmSeek = mmSeek;
window.mmVolume = mmVolume;
window.mmMute = mMute;
setInterval(function () {
  if (!mmReady || !mmPlayer || !mmPlayer.getCurrentTime) return;
  try {
    mmSend('mmTime', {
      position: Math.floor(mmPlayer.getCurrentTime() * 1000),
      duration: Math.floor(mmPlayer.getDuration() || 0)
    });
  } catch (e) {}
}, 250);
</script>
<script src="https://www.youtube.com/iframe_api"></script>
</body>
</html>
''';
}
