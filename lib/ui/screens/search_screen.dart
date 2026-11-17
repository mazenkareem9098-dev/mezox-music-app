import 'dart:async';

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
  Timer? _debounce;
  bool _loading = false;
  String? _error;
  List<Track> _results = [];

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _search({bool live = false}) async {
    _debounce?.cancel();
    final q = _ctrl.text.trim();
    if (q.isEmpty) {
      if (mounted) setState(() { _results = []; _error = null; });
      return;
    }
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final yt = await context.read<YouTubeService>().search(q, limit: 100);
      if (mounted) setState(() => _results = yt);
    } catch (e) {
      if (mounted) {
        setState(() {
          _results = [];
          _error = 'Search failed: $e';
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() { _results = []; _error = null; });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 450), () => _search(live: true));
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

  Widget _trackTile(Track t, int index) {
    final player = context.read<MezoxPlayerController>();
    return ListTile(
      leading: t.artworkUrl.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.network(
                t.artworkUrl,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(Icons.music_note),
              ),
            )
          : const Icon(Icons.music_note),
      title: Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(t.artist, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: IconButton(
        icon: const Icon(Icons.more_vert),
        onPressed: () => _showAddMenu(context, t),
      ),
      onTap: () => player.playQueue(_results, index),
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
                onChanged: _onChanged,
                decoration: const InputDecoration(
                  hintText: 'ابدأ بالكتابة — اقتراحات من YouTube مباشرة...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _search(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(icon: const Icon(Icons.search), onPressed: () => _search()),
          ]),
        ),
        if (_loading) const LinearProgressIndicator(minHeight: 2),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
          ),
        if (_results.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'نتائج YouTube — ${_results.length} أغنية',
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
            ),
          ),
        Expanded(
          child: _results.isEmpty && !_loading
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'اكتب حرف أو كلمة — هتظهر اقتراحات الأغاني من YouTube فوراً.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white54),
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: _results.length,
                  itemBuilder: (_, i) => _trackTile(_results[i], i),
                ),
        ),
      ],
    );
  }
}
