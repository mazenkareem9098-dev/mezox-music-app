import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/audio_player_service.dart';
import '../../services/library_service.dart';
import '../../services/lyrics_service.dart';
import '../../theme/l10n.dart';
import '../../theme/m_theme.dart';
import 'visualizer.dart';

class NowPlayingPanel extends StatelessWidget {
  const NowPlayingPanel({super.key, this.showQueue = false, this.onCloseQueue});

  final bool showQueue;
  final VoidCallback? onCloseQueue;

  @override
  Widget build(BuildContext context) {
    final player = context.watch<MezoxPlayerController>();
    final library = context.watch<LibraryService>();
    final lyrics = context.watch<LyricsService>();
    final track = player.current;

    return GlassPanel(
      margin: const EdgeInsets.fromLTRB(0, 12, 12, 12),
      padding: const EdgeInsets.all(16),
      radius: 22,
      child: SizedBox(
        width: 292,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                SectionLabel(L10n.t(context, 'nowPlaying')),
                if (showQueue && onCloseQueue != null)
                  IconButton(
                    icon: const Icon(Icons.close, size: 16, color: MColors.muted),
                    tooltip: 'Close queue',
                    onPressed: onCloseQueue,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (track == null)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 180,
                        height: 180,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: MColors.darkRed.withOpacity(0.35),
                          border: Border.all(color: MColors.primary.withOpacity(0.35)),
                        ),
                        child: const Icon(Icons.graphic_eq, color: MColors.primary, size: 54),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        L10n.t(context, 'nothingPlaying'),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Pick a song from Home, Explore or Search.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: MColors.muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              Hero(
                tag: 'now-art-${track.id}',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: track.artworkUrl.isEmpty
                      ? Container(
                          height: 268,
                          color: MColors.darkRed,
                          child: const Icon(Icons.music_note, size: 80, color: Colors.white54),
                        )
                      : Image.network(
                          track.artworkUrl,
                          height: 268,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            height: 268,
                            color: MColors.darkRed,
                            child: const Icon(Icons.music_note, size: 80, color: Colors.white54),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                track.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                track.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: MColors.muted, fontSize: 13),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Visualizer(playing: player.isPlaying, bars: 22, height: 30),
                  const Spacer(),
                  Text(
                    player.isBuffering ? 'BUFFERING' : player.isPlaying ? 'PLAYING' : 'PAUSED',
                    style: TextStyle(
                      color: player.isPlaying ? MColors.bright : MColors.muted,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.4,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    icon: Icon(
                      library.isFavourite(track.id) ? Icons.favorite : Icons.favorite_border,
                      color: library.isFavourite(track.id) ? MColors.primary : MColors.muted,
                    ),
                    tooltip: 'Like',
                    onPressed: () => library.toggleFavourite(track),
                  ),
                  IconButton(
                    icon: const Icon(Icons.playlist_add, color: MColors.muted),
                    tooltip: 'Add to playlist',
                    onPressed: () => _showPlaylistSheet(context, library, track),
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_horiz, color: MColors.muted),
                    tooltip: 'More',
                    onPressed: () => _showTrackMenu(context, track),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (showQueue) Expanded(child: _buildQueue(context, player)) else const Spacer(),
              if (!showQueue && lyrics.currentLyrics.isNotEmpty) ...[
                SectionLabel(L10n.t(context, 'lyrics')),
                const SizedBox(height: 8),
                Expanded(
                  child: SingleChildScrollView(
                    child: Text(
                      lyrics.currentLyrics,
                      style: const TextStyle(color: MColors.muted, fontSize: 12, height: 1.6),
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQueue(BuildContext context, MezoxPlayerController player) {
    if (player.queue.isEmpty) {
      return Center(
        child: Text(
          L10n.t(context, 'queueEmpty'),
          style: const TextStyle(color: MColors.muted, fontSize: 12),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            SectionLabel(L10n.t(context, 'queue')),
            const Spacer(),
            TextButton(
              onPressed: player.clearQueue,
              child: Text(L10n.t(context, 'clear'), style: const TextStyle(color: MColors.muted, fontSize: 11)),
            ),
          ],
        ),
        Expanded(
          child: ReorderableListView.builder(
            itemCount: player.queue.length,
            onReorder: player.moveInQueue,
            itemBuilder: (_, i) {
              final t = player.queue[i];
              return ListTile(
                key: ValueKey('${t.id}-$i'),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: t.artworkUrl.isEmpty
                      ? Container(width: 38, height: 38, color: MColors.darkRed)
                      : Image.network(t.artworkUrl, width: 38, height: 38, fit: BoxFit.cover),
                ),
                title: Text(
                  t.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: i == player.queueIndex ? MColors.bright : Colors.white,
                    fontSize: 12,
                  ),
                ),
                subtitle: Text(t.artist, maxLines: 1, style: const TextStyle(fontSize: 10)),
                trailing: i == player.queueIndex
                    ? const Icon(Icons.graphic_eq, color: MColors.primary, size: 16)
                    : IconButton(
                        icon: const Icon(Icons.close, size: 14, color: MColors.muted),
                        onPressed: () => player.removeFromQueue(i),
                      ),
                onTap: () => player.playQueue(player.queue, i),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showPlaylistSheet(BuildContext context, LibraryService library, dynamic track) {
    showModalBottomSheet(
      context: context,
      backgroundColor: MColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SectionLabel('Add to playlist'),
              const SizedBox(height: 10),
              if (library.playlists.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(18),
                  child: Text(
                    'Create a playlist in Your Library first.',
                    style: TextStyle(color: MColors.muted),
                  ),
                )
              else
                ...library.playlists.map(
                  (p) => ListTile(
                    leading: const Icon(Icons.playlist_play, color: MColors.primary),
                    title: Text(p.name, style: const TextStyle(color: Colors.white)),
                    onTap: () {
                      library.addToPlaylist(p.id, track as dynamic);
                      Navigator.pop(context);
                      MToast.show(context, 'Added to ${p.name}');
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTrackMenu(BuildContext context, dynamic track) {
    showModalBottomSheet(
      context: context,
      backgroundColor: MColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.queue_music, color: MColors.primary),
              title: const Text('Play next', style: TextStyle(color: Colors.white)),
              onTap: () {
                context.read<MezoxPlayerController>().addToQueue(track as dynamic);
                Navigator.pop(context);
                MToast.show(context, 'Added to queue');
              },
            ),
            ListTile(
              leading: const Icon(Icons.share, color: MColors.primary),
              title: const Text('Copy YouTube link', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                MToast.show(context, 'https://www.youtube.com/watch?v=${track.sourceId}');
              },
            ),
          ],
        ),
      ),
    );
  }
}
