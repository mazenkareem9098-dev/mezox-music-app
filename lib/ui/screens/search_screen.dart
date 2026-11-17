import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/track.dart';
import '../../services/audio_player_service.dart';
import '../../services/library_service.dart';
import '../../services/search_query_service.dart';
import '../../services/youtube_service.dart';
import '../../theme/m_theme.dart';
import '../widgets/track_tile.dart';
import 'playlists_screen.dart';

const List<String> _categories = <String>[
  'All',
  'Songs',
  'Videos',
  'Artists',
  'Playlists',
  'Albums',
];

const List<String> _sorts = <String>[
  'Relevance',
  'Title A–Z',
  'Artist A–Z',
  'Shortest first',
  'Longest first',
];

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _ctrl = TextEditingController();
  Timer? _debounce;
  Timer? _suggestDebounce;
  int _suggestSerial = 0;
  int _lastRevision = -1;

  String _category = 'All';
  String _sort = 'Relevance';
  List<Track> _results = <Track>[];
  List<Track> _suggestions = <Track>[];
  bool _loading = false;
  bool _suggestLoading = false;
  bool _searched = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final shared = context.read<SearchQueryService>();
    _lastRevision = shared.revision;
    shared.addListener(_onSharedQuery);
    if (shared.query.isNotEmpty) {
      _ctrl.text = shared.query;
      WidgetsBinding.instance.addPostFrameCallback((_) => _runSearch(record: true));
    }
  }

  @override
  void dispose() {
    final shared = context.read<SearchQueryService>();
    shared.removeListener(_onSharedQuery);
    _debounce?.cancel();
    _suggestDebounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onSharedQuery() {
    final shared = context.read<SearchQueryService>();
    if (shared.revision == _lastRevision) return;
    _lastRevision = shared.revision;
    if (shared.query.isEmpty) return;
    _ctrl.text = shared.query;
    _suggestDebounce?.cancel();
    _runSearch(record: true);
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _suggestDebounce?.cancel();
    if (value.trim().isEmpty) {
      if (mounted) {
        setState(() {
          _suggestions = <Track>[];
          _suggestLoading = false;
          _searched = false;
          _results = <Track>[];
          _error = null;
        });
      }
      return;
    }
    if (mounted) setState(() => _suggestLoading = true);
    _suggestDebounce = Timer(const Duration(milliseconds: 380), _fetchSuggestions);
  }

  Future<void> _fetchSuggestions() async {
    if (!mounted) return;
    final q = _ctrl.text.trim();
    if (q.isEmpty) {
      if (mounted) setState(() => _suggestLoading = false);
      return;
    }
    final serial = ++_suggestSerial;
    final yt = context.read<YouTubeService>();
    try {
      final tracks = await yt.suggest(q);
      if (!mounted || serial != _suggestSerial) return;
      setState(() {
        _suggestions = tracks.take(6).toList();
        _suggestLoading = false;
      });
    } catch (_) {
      if (mounted && serial == _suggestSerial) {
        setState(() {
          _suggestions = <Track>[];
          _suggestLoading = false;
        });
      }
    }
  }

  Future<void> _runSearch({bool record = true}) async {
    if (!mounted) return;
    _debounce?.cancel();
    _suggestDebounce?.cancel();
    final q = _ctrl.text.trim();
    if (q.isEmpty) {
      if (mounted) {
        setState(() {
          _results = <Track>[];
          _suggestions = <Track>[];
          _searched = false;
          _error = null;
        });
      }
      return;
    }
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
        _suggestions = <Track>[];
      });
    }

    final yt = context.read<YouTubeService>();
    final library = context.read<LibraryService>();
    try {
      final tracks = await yt.search(q, limit: 60);
      if (record) await library.recordSearch(q);
      if (!mounted) return;
      setState(() {
        _results = tracks;
        _searched = true;
        if (tracks.isEmpty && yt.lastError != null) _error = yt.lastError;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _results = <Track>[];
          _searched = true;
          _error = 'Search failed: $e';
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _submitFromHistory(String query) {
    _ctrl.text = query;
    _category = 'All';
    _runSearch(record: true);
    FocusScope.of(context).unfocus();
  }

  void _clearField() {
    _ctrl.clear();
    _debounce?.cancel();
    _suggestDebounce?.cancel();
    _suggestSerial++;
    setState(() {
      _results = <Track>[];
      _suggestions = <Track>[];
      _searched = false;
      _loading = false;
      _suggestLoading = false;
      _error = null;
    });
  }

  List<Track> get _sortedResults {
    final list = List<Track>.from(_results);
    switch (_sort) {
      case 'Title A–Z':
        list.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case 'Artist A–Z':
        list.sort((a, b) => a.artist.toLowerCase().compareTo(b.artist.toLowerCase()));
        break;
      case 'Shortest first':
        list.sort((a, b) => (a.duration ?? Duration.zero)
            .compareTo(b.duration ?? Duration.zero));
        break;
      case 'Longest first':
        list.sort((a, b) => (b.duration ?? Duration.zero)
            .compareTo(a.duration ?? Duration.zero));
        break;
      default:
        break;
    }
    return list;
  }

  List<MapEntry<String, List<Track>>> get _artistGroups {
    final groups = <String, List<Track>>{};
    for (final t in _sortedResults) {
      final key = t.artist.trim().isEmpty ? 'Unknown artist' : t.artist;
      groups.putIfAbsent(key, () => <Track>[]).add(t);
    }
    final entries = groups.entries.toList();
    if (_sort == 'Artist A–Z') {
      entries.sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));
    }
    return entries;
  }

  void _playAt(int index) {
    final tracks = _sortedResults;
    if (index < 0 || index >= tracks.length) return;
    context.read<MezoxPlayerController>().playQueue(tracks, index);
  }

  Widget _buildSuggestion(Track t) {
    return InkWell(
      onTap: () => _submitFromHistory(t.title),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: t.artworkUrl.isEmpty
                  ? Container(
                      width: 44,
                      height: 34,
                      color: MColors.darkRed,
                      child: const Icon(Icons.music_note, color: Colors.white70, size: 18),
                    )
                  : Image.network(
                      t.artworkUrl,
                      width: 44,
                      height: 34,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 44,
                        height: 34,
                        color: MColors.darkRed,
                        child: const Icon(Icons.music_note, color: Colors.white70, size: 18),
                      ),
                    ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    t.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: MColors.muted, fontSize: 10),
                  ),
                ],
              ),
            ),
            if (t.duration != null)
              Text(
                formatDuration(t.duration),
                style: const TextStyle(color: MColors.muted, fontSize: 10),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistory(LibraryService lib) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
      children: [
        SectionLabel(
          'Recent searches',
          trailing: lib.searchHistory.isEmpty
              ? null
              : GlowButton(
                  label: 'Clear history',
                  icon: Icons.delete_sweep_outlined,
                  compact: true,
                  onPressed: () async {
                    await lib.clearSearchHistory();
                    if (mounted) MToast.show(context, 'Search history cleared');
                  },
                ),
        ),
        const SizedBox(height: 12),
        if (lib.searchHistory.isEmpty)
          const GlassPanel(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.search_rounded, color: MColors.primary, size: 40),
                SizedBox(height: 10),
                Text(
                  'ابدأ البحث — Search songs, artists and videos',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 6),
                Text(
                  'Live suggestions from YouTube appear as you type. Arabic and English both work.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: MColors.muted, fontSize: 11),
                ),
              ],
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: lib.searchHistory.map((q) => GlassPanel(
              onTap: () => _submitFromHistory(q),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              radius: 22,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.history, color: MColors.bright, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    q,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            )).toList(),
          ),
      ],
    );
  }

  Widget _buildArtistGroups() {
    final groups = _artistGroups;
    if (groups.isEmpty) {
      return const Center(
        child: Text('No artists found for this search.', style: TextStyle(color: MColors.muted)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
      itemCount: groups.length,
      itemBuilder: (_, i) {
        final entry = groups[i];
        final tracks = entry.value;
        final first = tracks.first;
        return GlassPanel(
          onTap: () => context
              .read<MezoxPlayerController>()
              .playQueue(tracks, 0),
          margin: const EdgeInsets.symmetric(vertical: 5),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          radius: 14,
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: first.artworkUrl.isEmpty
                    ? Container(
                        width: 52,
                        height: 52,
                        color: MColors.darkRed,
                        child: const Icon(Icons.person, color: Colors.white70),
                      )
                    : Image.network(
                        first.artworkUrl,
                        width: 52,
                        height: 52,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 52,
                          height: 52,
                          color: MColors.darkRed,
                          child: const Icon(Icons.person, color: Colors.white70),
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.key,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${tracks.length} tracks on YouTube',
                      style: const TextStyle(color: MColors.muted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.play_arrow_rounded, color: MColors.bright),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLibraryCategory(LibraryService lib) {
    final q = _ctrl.text.trim().toLowerCase();
    final albums = lib.playlists.where((a) {
      if (q.isEmpty) return true;
      return a.name.toLowerCase().contains(q) ||
          a.description.toLowerCase().contains(q);
    }).toList();
    if (_sort == 'Title A–Z') {
      albums.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }
    if (albums.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No matching playlists in your library.',
            textAlign: TextAlign.center,
            style: TextStyle(color: MColors.muted, fontSize: 12),
          ),
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(18, 4, 6, 24),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 190,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.62,
      ),
      itemCount: albums.length,
      itemBuilder: (_, i) {
        final a = albums[i];
        return PlaylistCard(
          album: a,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => PlaylistDetailPage(playlistId: a.id),
            ),
          ),
          onMore: () => showPlaylistActionsSheet(context, a),
        );
      },
    );
  }

  Widget _buildResults(String? currentId) {
    final tracks = _sortedResults;
    if (tracks.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No results. Try a different spelling or language.',
            textAlign: TextAlign.center,
            style: TextStyle(color: MColors.muted, fontSize: 12),
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
      itemCount: tracks.length,
      itemBuilder: (_, i) {
        final t = tracks[i];
        return TrackTile(
          track: t,
          index: i,
          onPlay: () => _playAt(i),
          onMore: () => showTrackMoreSheet(context, t),
          highlight: currentId == t.id,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final lib = context.watch<LibraryService>();
    final currentId = context.watch<MezoxPlayerController>().current?.id;
    final query = _ctrl.text.trim();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: GlassPanel(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    onChanged: _onChanged,
                    textInputAction: TextInputAction.search,
                    onEditingComplete: () => _runSearch(record: true),
                    onSubmitted: (_) => _runSearch(record: true),
                    decoration: const InputDecoration(
                      hintText: 'ابحث عن أغنية أو فنان... Search songs, artists, videos',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
                if (query.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.close, color: MColors.muted),
                    tooltip: 'Clear search',
                    onPressed: _clearField,
                  ),
                const SizedBox(width: 6),
                GlowButton(
                  label: 'Search',
                  icon: Icons.search,
                  filled: true,
                  compact: true,
                  onPressed: () => _runSearch(record: true),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final c = _categories[i];
                return GlowButton(
                  label: c,
                  icon: c == 'All' ? Icons.apps : c == 'Songs' ? Icons.music_note : c == 'Videos' ? Icons.music_video : c == 'Artists' ? Icons.person_outline : c == 'Playlists' ? Icons.playlist_play : Icons.album_outlined,
                  compact: true,
                  filled: _category == c,
                  onPressed: () => setState(() => _category = c),
                );
              },
            ),
          ),
        ),
        if (_loading) const LinearProgressIndicator(minHeight: 2),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _error!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: MColors.bright, fontSize: 11),
                  ),
                ),
                GlowButton(
                  label: 'Retry',
                  icon: Icons.refresh,
                  compact: true,
                  onPressed: () => _runSearch(record: false),
                ),
              ],
            ),
          ),
        if (query.isNotEmpty && !_searched && (_suggestLoading || _suggestions.isNotEmpty))
          GlassPanel(
            margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: SectionLabel('Live suggestions'),
                ),
                if (_suggestLoading && _suggestions.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      'Getting suggestions...',
                      style: TextStyle(color: MColors.muted, fontSize: 11),
                    ),
                  )
                else
                  ..._suggestions.map(_buildSuggestion),
              ],
            ),
          ),
        if (_searched && _category != 'Artists' && _category != 'Playlists' && _category != 'Albums')
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '$_category — ${_sortedResults.length} results',
                    style: const TextStyle(color: MColors.muted, fontSize: 11),
                  ),
                ),
                PopupMenuButton<String>(
                  initialValue: _sort,
                  color: MColors.surface,
                  tooltip: 'Sort results',
                  onSelected: (value) => setState(() => _sort = value),
                  itemBuilder: (_) => _sorts
                      .map((s) => PopupMenuItem<String>(value: s, child: Text(s)))
                      .toList(),
                  child: Row(
                    children: [
                      const Icon(Icons.sort, color: MColors.muted, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        _sort,
                        style: const TextStyle(color: MColors.bright, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: _loading && !_searched
              ? const Center(
                  child: CircularProgressIndicator(color: MColors.primary),
                )
              : !_searched
                  ? _buildHistory(lib)
                  : _category == 'Artists'
                      ? _buildArtistGroups()
                      : _category == 'Playlists' || _category == 'Albums'
                          ? _buildLibraryCategory(lib)
                          : _buildResults(currentId),
        ),
      ],
    );
  }
}
