import 'track.dart';

/// A user-created playlist. Kept as `Album` internally for storage compatibility.
class Album {
  Album({
    required this.id,
    required this.name,
    List<Track>? tracks,
    this.description = '',
    this.coverUrl = '',
    this.createdAtMs,
  }) : tracks = tracks ?? <Track>[];

  final String id;
  String name;
  String description;
  String coverUrl;
  final int? createdAtMs;
  List<Track> tracks;

  Duration get totalDuration => tracks.fold<Duration>(
        Duration.zero,
        (sum, t) => sum + (t.duration ?? Duration.zero),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'description': description,
        'coverUrl': coverUrl,
        'createdAtMs': createdAtMs ?? DateTime.now().millisecondsSinceEpoch,
        'tracks': tracks.map((t) => t.toJson()).toList(),
      };

  factory Album.fromJson(Map<String, dynamic> j) => Album(
        id: j['id']?.toString() ?? DateTime.now().microsecondsSinceEpoch.toString(),
        name: j['name']?.toString() ?? 'Playlist',
        description: j['description']?.toString() ?? '',
        coverUrl: j['coverUrl']?.toString() ?? '',
        createdAtMs: j['createdAtMs'] is int ? j['createdAtMs'] as int : null,
        tracks: (j['tracks'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map(Track.fromJson)
            .toList(),
      );
}
