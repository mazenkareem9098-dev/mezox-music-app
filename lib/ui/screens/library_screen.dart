import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/library_service.dart';
import '../../services/audio_player_service.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  Future<void> _createAlbum(BuildContext context) async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('New album'),
        content: TextField(controller: ctrl, decoration: const InputDecoration(hintText: 'Album name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, ctrl.text.trim()), child: const Text('Create')),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      await context.read<LibraryService>().createAlbum(name);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lib = context.watch<LibraryService>();
    final player = context.read<MezoxPlayerController>();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Favourites', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (lib.favourites.isEmpty)
          const Text('No favourites yet. Tap ♥ on any track.', style: TextStyle(color: Colors.white54))
        else
          ...lib.favourites.map((t) => ListTile(
                leading: t.artworkUrl.isNotEmpty
                    ? ClipRRect(borderRadius: BorderRadius.circular(4), child: Image.network(t.artworkUrl, width: 44, height: 44, fit: BoxFit.cover))
                    : const Icon(Icons.music_note),
                title: Text(t.title),
                subtitle: Text(t.artist),
                trailing: IconButton(icon: const Icon(Icons.play_arrow), onPressed: () => player.playTrack(t)),
                onTap: () => player.playTrack(t),
              )),
        const SizedBox(height: 24),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Albums', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          FilledButton.icon(onPressed: () => _createAlbum(context), icon: const Icon(Icons.add), label: const Text('New album')),
        ]),
        const SizedBox(height: 8),
        if (lib.albums.isEmpty)
          const Text('No albums yet.', style: TextStyle(color: Colors.white54))
        else
          ...lib.albums.map((a) => ExpansionTile(
                leading: const Icon(Icons.album),
                title: Text(a.name),
                subtitle: Text('${a.tracks.length} tracks'),
                children: [
                  if (a.tracks.isEmpty)
                    const ListTile(title: Text('No tracks yet. Add from Search.'))
                  else
                    ...a.tracks.map((t) => ListTile(
                          leading: t.artworkUrl.isNotEmpty
                              ? ClipRRect(borderRadius: BorderRadius.circular(4), child: Image.network(t.artworkUrl, width: 40, height: 40, fit: BoxFit.cover))
                              : const Icon(Icons.music_note),
                          title: Text(t.title),
                          subtitle: Text(t.artist),
                          trailing: IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: () => lib.removeFromAlbum(a.id, t.id),
                          ),
                          onTap: () => player.playTrack(t),
                        )),
                  ListTile(
                    leading: const Icon(Icons.delete, color: Colors.redAccent),
                    title: const Text('Delete album', style: TextStyle(color: Colors.redAccent)),
                    onTap: () => lib.deleteAlbum(a.id),
                  ),
                ],
              )),
      ],
    );
  }
}
