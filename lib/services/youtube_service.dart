import 'package:flutter/foundation.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../models/track.dart';

class YouTubeService extends ChangeNotifier {
  final YoutubeExplode _yt = YoutubeExplode();

  Future<List<Track>> search(String query) async {
    if (query.trim().isEmpty) return [];
    final results = await _yt.search.search(query);
    return results.take(30).map((v) {
      return Track(
        id: 'yt_${v.id.value}',
        title: v.title,
        artist: v.author,
        artworkUrl: v.thumbnails.mediumResUrl,
        source: 'youtube',
        sourceId: v.id.value,
        duration: v.duration,
      );
    }).toList();
  }

  /// Direct audio-only stream URL (no in-player ad UI).
  Future<String> getAudioUrl(String videoId) async {
    final manifest = await _yt.videos.streamsClient.getManifest(videoId);
    final audio = manifest.audioOnly.withHighestBitrate();
    return audio.url.toString();
  }

  @override
  void dispose() {
    _yt.close();
    super.dispose();
  }
}
