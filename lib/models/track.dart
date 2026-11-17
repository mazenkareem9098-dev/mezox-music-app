class Track {
  final String id;
  final String title;
  final String artist;
  final String artworkUrl;
  final String source; // youtube
  final String sourceId;
  final Duration? duration;

  const Track({
    required this.id,
    required this.title,
    required this.artist,
    required this.artworkUrl,
    required this.source,
    required this.sourceId,
    this.duration,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'artist': artist,
        'artworkUrl': artworkUrl,
        'source': source,
        'sourceId': sourceId,
        'durationMs': duration?.inMilliseconds,
      };

  factory Track.fromJson(Map<String, dynamic> j) => Track(
        id: j['id'] as String,
        title: j['title'] as String? ?? '',
        artist: j['artist'] as String? ?? '',
        artworkUrl: j['artworkUrl'] as String? ?? '',
        source: j['source'] as String? ?? 'youtube',
        sourceId: j['sourceId'] as String? ?? j['id'],
        duration: j['durationMs'] != null
            ? Duration(milliseconds: j['durationMs'] as int)
            : null,
      );
}
