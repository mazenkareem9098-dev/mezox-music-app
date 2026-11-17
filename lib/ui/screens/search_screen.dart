import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/track.dart';
import '../../services/audio_player_service.dart';
import '../../services/library_service.dart';
import '../../services/youtube_service.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _ctrl = TextEditingController();
  bool _loading = false;
  List<Track> _results = [];

  Future<void> _search() async {
    final q = _ctrl.text.trim();
    if (q.isEmpty) return;
    setState(() => _loading = true);
    final ytSvc = context.read<YouTubeService>();
    try {
      final yt = await ytSvc.search(q);
      setState(() => _results = yt);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showAddMenu(BuildContext context, Track t) {
    final lib = context.read<LibraryService>();
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.favorite),
            title: Text(lib.isFavourite(t.id) ? 'Remove from favourites' : 'Add to favourites'),
            onTap: () { lib.toggleFavourite(t); Navigator.pop(context); },
          ),
          const Divider(height: 1),
          const Padding(
            padding: EdgeInsets.all(12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Add to album', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          if (lib.albums.isEmpty)
            const ListTile(title: Text('No albums yet. Create one in Library.'))
          else
            ...lib.albums.map((a) => ListTile(
                  leading: const Icon(Icons.album),
                  title: Text(a.name),
                  onTap: () { lib.addToAlbum(a.id, t); Navigator.pop(context); },
                )),
        ]),
      ),
    );
  }

  Widget _trackTile(Track t) {
    final player = context.read<MezoxPlayerController>();
    return ListTile(
      leading: t.artworkUrl.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.network(t.artworkUrl, width: 48, height: 48, fit: BoxFit.cover),
            )
          : const Icon(Icons.music_note),
      title: Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(t.artist, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: IconButton(icon: const Icon(Icons.more_vert), onPressed: () => _showAddMenu(context, t)),
      onTap: () => player.playTrack(t),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                decoration: const InputDecoration(
                  hintText: 'Search any song on YouTube...',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _search(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(icon: const Icon(Icons.search), onPressed: _search),
          ]),
        ),
        if (_loading) const LinearProgressIndicator(),
        Expanded(
          child: _results.isEmpty && !_loading
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Search for any song on YouTube.', style: TextStyle(color: Colors.white54)),
                  ),
                )
              : ListView(children: _results.map(_trackTile).toList()),
        ),
      ],
    );
  }
}
