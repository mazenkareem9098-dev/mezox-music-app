import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/audio_player_service.dart';
import '../../services/library_service.dart';
import '../../theme/m_theme.dart';
import '../widgets/track_tile.dart';

/// Recently played tracks, backed by [LibraryService.recentlyPlayed].
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final lib = context.watch<LibraryService>();
    final player = context.read<MezoxPlayerController>();
    final recent = lib.recentlyPlayed;

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
                child: const Icon(Icons.history, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionLabel('Recently played'),
                    SizedBox(height: 6),
                    Text(
                      'Every track you play lands here, newest first.',
                      style: TextStyle(color: MColors.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              GlowButton(
                label: 'Play all',
                icon: Icons.play_arrow_rounded,
                compact: true,
                onPressed: () {
                  if (recent.isEmpty) {
                    MToast.show(context, 'Nothing in history yet');
                    return;
                  }
                  player.playQueue(recent, 0);
                  MToast.show(context, 'Playing your recent tracks');
                },
              ),
              const SizedBox(width: 8),
              GlowButton(
                label: 'Clear',
                icon: Icons.delete_sweep_outlined,
                compact: true,
                onPressed: () async {
                  if (recent.isEmpty) {
                    MToast.show(context, 'History is already empty');
                    return;
                  }
                  await lib.clearRecentlyPlayed();
                  if (context.mounted) MToast.show(context, 'History cleared');
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        SectionLabel(
          'History',
          trailing: Text(
            '${recent.length} ${recent.length == 1 ? 'track' : 'tracks'}',
            style: const TextStyle(color: MColors.muted, fontSize: 11),
          ),
        ),
        const SizedBox(height: 10),
        if (recent.isEmpty)
          GlassPanel(
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
            child: Column(
              children: const [
                Icon(Icons.history_toggle_off, color: MColors.muted, size: 38),
                SizedBox(height: 12),
                Text(
                  'Your listening history is empty.',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 6),
                Text(
                  'Play a song anywhere in M MUSIC and it will show up here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: MColors.muted, fontSize: 12),
                ),
              ],
            ),
          )
        else
          GlassPanel(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Column(
              children: [
                for (var i = 0; i < recent.length; i++)
                  TrackTile(
                    track: recent[i],
                    index: i,
                    highlight: player.current?.id == recent[i].id,
                    onPlay: () => player.playQueue(recent, i),
                    trailing: IconButton(
                      tooltip: lib.isFavourite(recent[i].id)
                          ? 'Remove from liked songs'
                          : 'Add to liked songs',
                      icon: Icon(
                        lib.isFavourite(recent[i].id)
                            ? Icons.favorite
                            : Icons.favorite_border,
                        color: lib.isFavourite(recent[i].id)
                            ? MColors.bright
                            : MColors.muted,
                        size: 18,
                      ),
                      onPressed: () => lib.toggleFavourite(recent[i]),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
