import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/library_service.dart';
import '../../theme/m_theme.dart';
import '../../services/audio_player_service.dart';
import 'track_tile.dart';
import 'visualizer.dart';

class BottomPlayerBar extends StatelessWidget {
  const BottomPlayerBar({
    super.key,
    required this.onToggleQueue,
    required this.onOpenFullscreen,
  });

  final VoidCallback onToggleQueue;
  final VoidCallback onOpenFullscreen;

  @override
  Widget build(BuildContext context) {
    final player = context.watch<MezoxPlayerController>();
    final library = context.watch<LibraryService>();
    final track = player.current;

    if (track == null) {
      return Container(
        height: 82,
        decoration: BoxDecoration(
          color: const Color(0x0D120809),
          border: Border(top: BorderSide(color: MColors.primary.withOpacity(0.18))),
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Visualizer(playing: false, bars: 12, height: 18, active: false),
              const SizedBox(width: 12),
              Text(
                'M MUSIC  •  Listen. Enjoy. Repeat.',
                style: TextStyle(color: MColors.muted.withOpacity(0.8), fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    final maxSeconds = player.duration.inSeconds > 0
        ? player.duration.inSeconds.toDouble()
        : 1.0;
    final posSeconds = player.position.inSeconds.toDouble().clamp(0.0, maxSeconds);
    final liked = library.isFavourite(track.id);

    return Container(
      height: 92,
      decoration: BoxDecoration(
        color: const Color(0xEE0A0506),
        border: Border(top: BorderSide(color: MColors.primary.withOpacity(0.28))),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.6), blurRadius: 20, offset: const Offset(0, -6)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            // LEFT — track identity
            SizedBox(
              width: 250,
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: track.artworkUrl.isEmpty
                        ? Container(
                            width: 54,
                            height: 54,
                            color: MColors.darkRed,
                            child: const Icon(Icons.music_note, color: Colors.white70),
                          )
                        : Image.network(
                            track.artworkUrl,
                            width: 54,
                            height: 54,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 54,
                              height: 54,
                              color: MColors.darkRed,
                              child: const Icon(Icons.music_note, color: Colors.white70),
                            ),
                          ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          track.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          track.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: MColors.muted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: liked ? 'Remove from Liked Songs' : 'Add to Liked Songs',
                    icon: Icon(
                      liked ? Icons.favorite : Icons.favorite_border,
                      color: liked ? MColors.primary : MColors.muted,
                      size: 20,
                    ),
                    onPressed: () async {
                      await library.toggleFavourite(track);
                      MToast.show(context, liked ? 'Removed from Liked Songs' : 'Added to Liked Songs');
                    },
                  ),
                ],
              ),
            ),

            // CENTER — transport + progress
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _ctrl(
                        icon: Icons.shuffle,
                        active: player.shuffle,
                        tooltip: 'Shuffle',
                        onPressed: player.toggleShuffle,
                      ),
                      _ctrl(
                        icon: Icons.skip_previous_rounded,
                        tooltip: 'Previous',
                        onPressed: player.previousTrack,
                      ),
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: MColors.redGradient,
                          boxShadow: [BoxShadow(color: MColors.primary.withOpacity(0.5), blurRadius: 16)],
                        ),
                        child: IconButton(
                          tooltip: player.isPlaying ? 'Pause' : 'Play',
                          icon: Icon(
                            player.isBuffering
                                ? Icons.hourglass_top
                                : player.isPlaying
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                          onPressed: player.togglePlayPause,
                        ),
                      ),
                      _ctrl(
                        icon: Icons.skip_next_rounded,
                        tooltip: 'Next',
                        onPressed: player.nextTrack,
                      ),
                      _ctrl(
                        icon: player.repeatOne ? Icons.repeat_one : Icons.repeat,
                        active: player.repeatOne || player.repeatAll,
                        tooltip: player.repeatOne ? 'Repeat one' : 'Repeat all',
                        onPressed: player.repeatOne ? player.toggleRepeatOne : player.toggleRepeatAll,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(formatDuration(player.position), style: const TextStyle(color: MColors.muted, fontSize: 10)),
                      Expanded(
                        child: Slider(
                          value: posSeconds,
                          max: maxSeconds,
                          onChanged: (v) => player.seek(Duration(seconds: v.round())),
                        ),
                      ),
                      Text(formatDuration(player.duration), style: const TextStyle(color: MColors.muted, fontSize: 10)),
                    ],
                  ),
                ],
              ),
            ),

            // RIGHT — extras
            SizedBox(
              width: 250,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  SizedBox(
                    width: 100,
                    child: Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            player.muted || player.volume == 0
                                ? Icons.volume_off
                                : Icons.volume_up,
                            color: MColors.muted,
                            size: 19,
                          ),
                          tooltip: 'Mute / unmute',
                          onPressed: player.toggleMute,
                        ),
                        Expanded(
                          child: Slider(
                            value: player.muted ? 0 : player.volume,
                            max: 1,
                            onChanged: (v) => player.setVolume(v),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Visualizer(playing: player.isPlaying, bars: 10, height: 20),
                  IconButton(
                    icon: const Icon(Icons.picture_in_picture_alt_outlined, color: MColors.muted, size: 19),
                    tooltip: 'Mini player',
                    onPressed: () {
                      player.setFullscreen(false);
                      MToast.show(context, 'Mini player active');
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.fullscreen_rounded, color: MColors.muted, size: 20),
                    tooltip: 'Full screen player',
                    onPressed: onOpenFullscreen,
                  ),
                  IconButton(
                    icon: const Icon(Icons.queue_music, color: MColors.muted, size: 20),
                    tooltip: 'Queue',
                    onPressed: onToggleQueue,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ctrl({
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
    bool active = false,
  }) {
    return IconButton(
      icon: Icon(
        icon,
        color: active ? MColors.primary : Colors.white70,
        size: active ? 22 : 21,
      ),
      tooltip: tooltip,
      onPressed: onPressed,
    );
  }
}
