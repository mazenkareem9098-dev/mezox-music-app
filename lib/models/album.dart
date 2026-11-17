import 'track.dart';

class Album {
  final String id;
  String name;
  final List<Track> tracks;

  Album({required this.id, required this.name, List<Track>? tracks})
      : tracks = tracks ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'tracks': tracks.map((t) => t.toJson()).toList(),
      };

  factory Album.fromJson(Map<String, dynamic> j) => Album(
        id: j['id'] as String,
        name: j['name'] as String? ?? 'Album',
        tracks: (j['tracks'] as List? ?? [])
            .map((e) => Track.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
}
