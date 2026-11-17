import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/library_service.dart';
import '../../services/audio_player_service.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final lib = context.watch<LibraryService>();
    final player = context.read<MezoxPlayerController>();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Welcome to MEZOX MUSIC', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        const Text('Stream from YouTube with direct audio playback (no in-player ads), song lyrics after 10s, and listen together.',
            style: TextStyle(color: Colors.white70)),
        const SizedBox(height: 20),
        const Text('Favourites', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        if (lib.favourites.isEmpty)
          const Text('No favourites yet. Tap ♥ on any track.', style: TextStyle(color: Colors.white54))
        else
          ...lib.favourites.map((t) => ListTile(
                leading: t.artworkUrl.isNotEmpty
                    ? Image.network(t.artworkUrl, width: 44, height: 44, fit: BoxFit.cover)
                    : const Icon(Icons.music_note),
                title: Text(t.title),
                subtitle: Text(t.artist),
                trailing: IconButton(icon: const Icon(Icons.play_arrow), onPressed: () => player.playTrack(t)),
                onTap: () => player.playTrack(t),
              )),
        const SizedBox(height: 20),
        const Text('Your Albums', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        if (lib.albums.isEmpty)
          const Text('No albums yet. Create one in Library.', style: TextStyle(color: Colors.white54))
        else
          ...lib.albums.map((a) => ListTile(
                leading: const Icon(Icons.album),
                title: Text(a.name),
                subtitle: Text('${a.tracks.length} tracks'),
                onTap: () { if (a.tracks.isNotEmpty) player.playTrack(a.tracks.first); },
              )),
      ],
    );
  }
}
