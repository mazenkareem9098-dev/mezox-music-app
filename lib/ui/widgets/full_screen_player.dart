import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/audio_player_service.dart';
import '../../services/library_service.dart';
import '../../theme/m_theme.dart';
import 'track_tile.dart';
import 'visualizer.dart';

class FullScreenPlayer extends StatelessWidget {
  const FullScreenPlayer({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final player = context.watch<MezoxPlayerController>();
    final library = context.watch<LibraryService>();
    final track = player.current;
    final size = MediaQuery.of(context).size;

    return AnimatedRedBackdrop(
      intensity: 1.35,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          fit: StackFit.expand,
          children: [
            if (track != null && track.artworkUrl.isNotEmpty)
              Positioned.fill(
                child: Image.network(
                  track.artworkUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            Positioned.fill(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 42, sigmaY: 42),
                child: Container(color: const Color(0xD6080808)),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const MLogo(size: 32),
                        const SizedBox(width: 10),
                        const Text(
                          'M MUSIC',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 2),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: onClose,
                          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
                          label: const Text('Close', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                    if (track == null)
                      const Expanded(
                        child: Center(
                          child: Text('Select a song to start.', style: TextStyle(color: MColors.muted)),
                        ),
                      )
                    else ...[
                      Expanded(
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 620),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Hero(
                                  tag: 'now-art-${track.id}',
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(26),
                                    child: Image.network(
                                      track.artworkUrl,
                                      width: mathMin(360, size.width * 0.5),
                                      height: mathMin(360, size.width * 0.5),
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        width: 320,
                                        height: 320,
                                        color: MColors.darkRed,
                                        child: const Icon(Icons.music_note, size: 90, color: Colors.white54),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 28),
                                Text(
                                  track.title,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 26,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  track.artist,
                                  style: const TextStyle(color: MColors.muted, fontSize: 14),
                                ),
                                const SizedBox(height: 18),
                                const Visualizer(playing: true, bars: 36, height: 46),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Text(formatDuration(player.position), style: const TextStyle(color: MColors.muted, fontSize: 11)),
                                Expanded(
                                  child: Slider(
                                    value: player.position.inSeconds.toDouble().clamp(
                                          0.0,
                                          player.duration.inSeconds > 0
                                              ? player.duration.inSeconds.toDouble()
                                              : 1.0,
                                        ),
                                    max: player.duration.inSeconds > 0
                                        ? player.duration.inSeconds.toDouble()
                                        : 1.0,
                                    onChanged: (v) => player.seek(Duration(seconds: v.round())),
                                  ),
                                ),
                                Text(formatDuration(player.duration), style: const TextStyle(color: MColors.muted, fontSize: 11)),
                              ],
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                  onPressed: () => library.toggleFavourite(track),
                                  icon: Icon(
                                    library.isFavourite(track.id) ? Icons.favorite : Icons.favorite_border,
                                    color: library.isFavourite(track.id) ? MColors.primary : Colors.white70,
                                    size: 26,
                                  ),
                                ),
                                const SizedBox(width: 18),
                                IconButton(
                                  onPressed: player.previousTrack,
                                  icon: const Icon(Icons.skip_previous, color: Colors.white, size: 34),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  width: 66,
                                  height: 66,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: MColors.redGradient,
                                    boxShadow: [BoxShadow(color: MColors.primary.withOpacity(0.6), blurRadius: 24)],
                                  ),
                                  child: IconButton(
                                    onPressed: player.togglePlayPause,
                                    icon: Icon(
                                      player.isPlaying ? Icons.pause : Icons.play_arrow,
                                      color: Colors.white,
                                      size: 34,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                IconButton(
                                  onPressed: player.nextTrack,
                                  icon: const Icon(Icons.skip_next, color: Colors.white, size: 34),
                                ),
                                const SizedBox(width: 18),
                                IconButton(
                                  onPressed: player.toggleMute,
                                  icon: Icon(
                                    player.muted ? Icons.volume_off : Icons.volume_up,
                                    color: Colors.white70,
                                    size: 26,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

double mathMin(double a, double b) => a < b ? a : b;
