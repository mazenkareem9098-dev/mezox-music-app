import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/track.dart';
import '../../services/audio_player_service.dart';
import '../../services/youtube_service.dart';
import '../../theme/m_theme.dart';
import '../widgets/music_card.dart';
import '../widgets/track_tile.dart';

/// Full-album discovery driven by live [YouTubeService.category] searches.
class AlbumsScreen extends StatefulWidget {
  const AlbumsScreen({super.key});

  @override
  State<AlbumsScreen> createState() => _AlbumsScreenState();
}

class _AlbumsScreenState extends State<AlbumsScreen> {
  static const List<String> _queries = <String>[
    'full album official audio',
    'ألبوم كامل رسمي',
  ];

  List<Track> _tracks = <Track>[];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loading = true;
    _load();
  }

  Future<void> _load() async {
    final yt = context.read<YouTubeService>();
    final merged = <String, Track>{};
    for (final query in _queries) {
      try {
        final page = await yt.category(query, limit: 40);
        for (final track in page) {
          merged.putIfAbsent(track.id, () => track);
        }
      } catch (_) {
        // A failed query still leaves the other queries in the list.
      }
      if (!mounted) return;
    }
    final results = merged.values.toList();
    final error = yt.lastError;
    if (!mounted) return;
    setState(() {
      _tracks = results;
      _error = results.isEmpty
          ? (error ?? 'No albums found right now. Try again in a moment.')
          : null;
      _loading = false;
    });
  }

  void _refresh() {
    setState(() {
      _loading = true;
      _error = null;
    });
    _load();
  }

  void _play(Track track) {
    final index = _tracks.indexWhere((t) => t.id == track.id);
    context
        .read<MezoxPlayerController>()
        .playQueue(_tracks, index < 0 ? 0 : index);
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<MezoxPlayerController>();
    final featured = _tracks.take(8).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        GlassPanel(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: MColors.redGradient,
                  boxShadow: [
                    BoxShadow(color: MColors.primary.withOpacity(0.4), blurRadius: 14),
                  ],
                ),
                child: const Icon(Icons.album_outlined, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionLabel('Albums'),
                    SizedBox(height: 6),
                    Text(
                      'Full albums and official audio collections from YouTube.',
                      style: TextStyle(color: MColors.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              GlowButton(
                label: 'Refresh',
                icon: Icons.refresh,
                compact: true,
                onPressed: _refresh,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const SectionLabel('Featured albums'),
        const SizedBox(height: 12),
        if (_loading)
          Wrap(
            spacing: 14,
            runSpacing: 10,
            children: [
              for (var i = 0; i < 5; i++)
                GlassPanel(
                  padding: const EdgeInsets.all(10),
                  child: Container(
                    width: 148,
                    height: 198,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
            ],
          )
        else if (_tracks.isEmpty)
          const Text(
            'No featured albums to show right now.',
            style: TextStyle(color: MColors.muted, fontSize: 12),
          )
        else
          Wrap(
            spacing: 14,
            runSpacing: 10,
            children: [
              for (final track in featured)
                MusicCard(
                  track: track,
                  onPlay: () => _play(track),
                  subtitle: track.artist,
                ),
            ],
          ),
        const SizedBox(height: 20),
        SectionLabel(
          'All results',
          trailing: Text(
            '${_tracks.length} ${_tracks.length == 1 ? 'track' : 'tracks'}',
            style: const TextStyle(color: MColors.muted, fontSize: 11),
          ),
        ),
        const SizedBox(height: 10),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 28),
            child: Center(
              child: CircularProgressIndicator(color: MColors.primary, strokeWidth: 2),
            ),
          )
        else if (_error != null)
          GlassPanel(
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: MColors.bright, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _error!,
                    style: const TextStyle(color: MColors.muted, fontSize: 12),
                  ),
                ),
                GlowButton(
                  label: 'Retry',
                  icon: Icons.refresh,
                  compact: true,
                  onPressed: _refresh,
                ),
              ],
            ),
          )
        else if (_tracks.isEmpty)
          GlassPanel(
            padding: const EdgeInsets.symmetric(vertical: 30),
            child: const Center(
              child: Text(
                'No results yet. Check your connection or add a YouTube API key in Settings.',
                textAlign: TextAlign.center,
                style: TextStyle(color: MColors.muted, fontSize: 12),
              ),
            ),
          )
        else
          GlassPanel(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Column(
              children: [
                for (var i = 0; i < _tracks.length; i++)
                  TrackTile(
                    track: _tracks[i],
                    index: i,
                    highlight: player.current?.id == _tracks[i].id,
                    onPlay: () => _play(_tracks[i]),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
