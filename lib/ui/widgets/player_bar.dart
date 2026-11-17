import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/audio_player_service.dart';
import '../../services/library_service.dart';
import '../../services/lyrics_service.dart';

class PlayerBar extends StatelessWidget {
  const PlayerBar({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<MezoxPlayerController>();
    final lib = context.watch<LibraryService>();
    final lyrics = context.watch<LyricsService>();
    final track = player.current;
    if (track == null) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.08))),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (track.artworkUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.network(track.artworkUrl, width: 48, height: 48, fit: BoxFit.cover),
                )
              else
                Container(width: 48, height: 48, color: Colors.white10, child: const Icon(Icons.music_note)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(track.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ]),
              ),
              IconButton(
                icon: Icon(lib.isFavourite(track.id) ? Icons.favorite : Icons.favorite_border, color: Colors.redAccent),
                onPressed: () => lib.toggleFavourite(track),
              ),
              IconButton(icon: const Icon(Icons.skip_previous), onPressed: () => player.player.seek(Duration.zero)),
              StreamBuilder<bool>(
                stream: player.player.playingStream,
                builder: (_, snap) {
                  final playing = snap.data ?? false;
                  return IconButton(
                    icon: Icon(playing ? Icons.pause_circle_filled : Icons.play_circle_filled, size: 36),
                    onPressed: player.togglePlayPause,
                  );
                },
              ),
              IconButton(
                icon: Icon(Icons.repeat_one, color: player.repeatOne ? Colors.redAccent : Colors.white54),
                tooltip: 'Repeat song',
                onPressed: player.toggleRepeatOne,
              ),
              IconButton(
                icon: Icon(Icons.repeat, color: player.repeatAll ? Colors.redAccent : Colors.white54),
                tooltip: 'Repeat all',
                onPressed: player.toggleRepeatAll,
              ),
            ],
          ),
          Row(
            children: [
              const Icon(Icons.volume_up, size: 18),
              Expanded(
                child: Slider(
                  min: 100, max: 300, divisions: 20,
                  value: player.volumePercent.toDouble(),
                  label: '${player.volumePercent}%',
                  onChanged: (v) => player.setVolumePercent(v.round()),
                ),
              ),
              SizedBox(width: 48, child: Text('${player.volumePercent}%', style: const TextStyle(fontSize: 12))),
            ],
          ),
          if (lyrics.loading || lyrics.currentLyrics.isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8)),
              constraints: const BoxConstraints(maxHeight: 90),
              child: SingleChildScrollView(
                child: Text(
                  lyrics.loading ? 'Fetching lyrics...' : lyrics.currentLyrics,
                  style: const TextStyle(fontSize: 13, height: 1.35, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
