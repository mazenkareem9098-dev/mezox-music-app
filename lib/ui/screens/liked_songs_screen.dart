import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/track.dart';
import '../../services/audio_player_service.dart';
import '../../services/library_service.dart';
import '../../theme/m_theme.dart';
import '../widgets/music_card.dart';
import '../widgets/track_tile.dart';
import 'playlists_screen.dart';

class LikedSongsScreen extends StatefulWidget {
  const LikedSongsScreen({super.key});

  @override
  State<LikedSongsScreen> createState() => _LikedSongsScreenState();
}

class _LikedSongsScreenState extends State<LikedSongsScreen> {
  final _searchCtrl = TextEditingController();
  bool _grid = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Track> _visible(List<Track> favourites) {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return favourites;
    return favourites
        .where((t) =>
            t.title.toLowerCase().contains(q) ||
            t.artist.toLowerCase().contains(q))
        .toList();
  }

  void _play(List<Track> tracks, int index, BuildContext context) {
    if (index < 0 || index >= tracks.length) return;
    context.read<MezoxPlayerController>().playQueue(tracks, index);
  }

  @override
  Widget build(BuildContext context) {
    final lib = context.watch<LibraryService>();
    final player = context.read<MezoxPlayerController>();
    final tracks = _visible(lib.favourites);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: GlassPanel(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(Icons.favorite, color: MColors.primary, size: 26),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Liked Songs',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${lib.favourites.length} songs · Listen. Enjoy. Repeat.',
                        style: const TextStyle(color: MColors.muted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                GlowButton(
                  label: 'Play all',
                  icon: Icons.play_arrow_rounded,
                  filled: true,
                  compact: true,
                  onPressed: tracks.isEmpty
                      ? () => MToast.show(context, 'No songs to play')
                      : () => player.playQueue(tracks, 0),
                ),
                const SizedBox(width: 6),
                GlowButton(
                  label: 'Shuffle',
                  icon: Icons.shuffle,
                  compact: true,
                  onPressed: tracks.isEmpty
                      ? () => MToast.show(context, 'No songs to shuffle')
                      : () {
                          final shuffled = List<Track>.from(tracks)..shuffle();
                          player.playQueue(shuffled, 0);
                        },
                ),
                const SizedBox(width: 6),
                IconButton(
                  icon: Icon(_grid ? Icons.view_list : Icons.grid_view),
                  color: MColors.muted,
                  tooltip: _grid ? 'List view' : 'Grid view',
                  onPressed: () => setState(() => _grid = !_grid),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Filter liked songs / تصفية الأغاني المعجبة',
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              suffixIcon: _searchCtrl.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close, color: MColors.muted),
                      tooltip: 'Clear filter',
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() {});
                      },
                    ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 2),
          child: SectionLabel(
            'Songs',
            trailing: Text(
              '${tracks.length} shown',
              style: const TextStyle(color: MColors.muted, fontSize: 11),
            ),
          ),
        ),
        Expanded(
          child: tracks.isEmpty
              ? Center(
                  child: GlassPanel(
                    margin: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.favorite_border, color: MColors.primary, size: 42),
                        const SizedBox(height: 12),
                        Text(
                          lib.favourites.isEmpty
                              ? 'No liked songs yet. Tap ♥ on any track in Search.'
                              : 'No liked songs match your filter.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: MColors.muted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                )
              : _grid
                  ? GridView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 4, 6, 24),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 186,
                        mainAxisSpacing: 4,
                        crossAxisSpacing: 4,
                        childAspectRatio: 0.66,
                      ),
                      itemCount: tracks.length,
                      itemBuilder: (_, i) {
                        final t = tracks[i];
                        return MusicCard(
                          track: t,
                          width: 172,
                          onPlay: () => _play(tracks, i, context),
                          onMore: () => showAddToPlaylistSheet(context, t),
                        );
                      },
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
                      itemCount: tracks.length,
                      itemBuilder: (_, i) {
                        final t = tracks[i];
                        return TrackTile(
                          track: t,
                          index: i,
                          onPlay: () => _play(tracks, i, context),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.playlist_add,
                                  color: MColors.bright,
                                  size: 19,
                                ),
                                tooltip: 'Add to playlist',
                                onPressed: () => showAddToPlaylistSheet(context, t),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.favorite,
                                  color: MColors.bright,
                                  size: 18,
                                ),
                                tooltip: 'Unlike',
                                onPressed: () async {
                                  await lib.removeFavourite(t.id);
                                  if (context.mounted) {
                                    MToast.show(context, 'Removed ${t.title}');
                                  }
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}
