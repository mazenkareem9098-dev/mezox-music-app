import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/track.dart';
import '../../services/audio_player_service.dart';
import '../../services/library_service.dart';
import '../../services/youtube_service.dart';
import '../../theme/m_theme.dart';
import '../widgets/section_carousel.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _Category {
  const _Category(this.group, this.label, this.query);

  final String group;
  final String label;
  final String query;
}

class _ExploreScreenState extends State<ExploreScreen> {
  static const List<_Category> _categories = <_Category>[
    _Category('Arabic', 'Arabic Hits', 'Arabic hits music'),
    _Category('Arabic', 'Egyptian Music', 'Egyptian music hits'),
    _Category('Arabic', 'Arabic Pop', 'Arabic pop music'),
    _Category('Arabic', 'Arabic Rap', 'Arabic rap music'),
    _Category('Arabic', 'Classic Arabic', 'classic Arabic music'),
    _Category('International', 'English Pop', 'English pop music'),
    _Category('International', 'Hip Hop', 'hip hop music'),
    _Category('International', 'Electronic', 'electronic music'),
    _Category('International', 'Rock', 'rock music'),
    _Category('International', 'Classical', 'classical music'),
    _Category('International', 'Instrumental', 'instrumental music'),
    _Category('Mood', 'Chill', 'chill music'),
    _Category('Mood', 'Sad', 'sad songs'),
    _Category('Mood', 'Happy', 'happy music'),
    _Category('Mood', 'Focus', 'focus music'),
    _Category('Mood', 'Gaming', 'gaming music'),
    _Category('Mood', 'Night Drive', 'night drive music'),
  ];

  List<Track> _trending = <Track>[];
  List<Track> _artists = <Track>[];
  List<Track> _categoryTracks = <Track>[];
  _Category? _selected;
  bool _featuredLoading = true;
  bool _categoryLoading = false;
  String? _featuredError;
  String? _categoryError;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _loadFeatured();
  }

  Future<void> _loadFeatured() async {
    if (!mounted) return;
    setState(() {
      _featuredLoading = true;
      _featuredError = null;
    });
    final YouTubeService yt = context.read<YouTubeService>();
    try {
      final List<List<Track>> results = await Future.wait<List<Track>>(
        <Future<List<Track>>>[
          yt.search('trending music videos', limit: 40),
          yt.search('popular music artists', limit: 40),
        ],
      );
      if (!mounted) return;
      setState(() {
        _trending = results[0];
        _artists = results[1];
        if (_trending.isEmpty &&
            _artists.isEmpty &&
            yt.lastError != null) {
          _featuredError = yt.lastError;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _featuredError = "Couldn't reach YouTube: $e");
    } finally {
      if (mounted) setState(() => _featuredLoading = false);
    }
  }

  Future<void> _select(_Category? category) async {
    final int generation = ++_generation;
    setState(() {
      _selected = category;
      _categoryTracks = <Track>[];
      _categoryError = null;
      _categoryLoading = category != null;
    });
    if (category == null) return;

    final YouTubeService yt = context.read<YouTubeService>();
    try {
      final List<Track> tracks =
          await yt.category(category.query, limit: 40);
      if (!mounted || generation != _generation) return;
      setState(() {
        _categoryTracks = tracks;
        if (tracks.isEmpty && yt.lastError != null) {
          _categoryError = yt.lastError;
        }
      });
    } catch (e) {
      if (!mounted || generation != _generation) return;
      setState(() => _categoryError = 'Search failed: $e');
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _categoryLoading = false);
      }
    }
  }

  void _play(List<Track> tracks, Track track) {
    final int index = tracks.indexOf(track);
    context
        .read<MezoxPlayerController>()
        .playQueue(tracks, index < 0 ? 0 : index);
    MToast.show(context, 'Playing ${track.title}');
  }

  void _showTrackMenu(BuildContext context, Track track) {
    final LibraryService lib = context.read<LibraryService>();
    final MezoxPlayerController player = context.read<MezoxPlayerController>();
    final bool wasFavourite = lib.isFavourite(track.id);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: MColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: MColors.primary.withOpacity(0.4)),
      ),
      builder: (BuildContext sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const SizedBox(height: 8),
            ListTile(
              leading: Icon(
                wasFavourite ? Icons.favorite : Icons.favorite_border,
                color: MColors.primary,
              ),
              title: Text(
                wasFavourite
                    ? 'Remove from favourites'
                    : 'Add to favourites',
              ),
              onTap: () {
                lib.toggleFavourite(track);
                Navigator.pop(sheetContext);
                MToast.show(
                  context,
                  wasFavourite
                      ? 'Removed from favourites'
                      : 'Added to favourites',
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.queue_music, color: MColors.primary),
              title: const Text('Add to queue'),
              onTap: () {
                player.addToQueue(track);
                Navigator.pop(sheetContext);
                MToast.show(context, 'Added to queue');
              },
            ),
            const Divider(height: 1),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'ADD TO PLAYLIST',
                  style: TextStyle(
                    color: MColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                  ),
                ),
              ),
            ),
            if (lib.playlists.isEmpty)
              ListTile(
                leading: const Icon(Icons.add, color: MColors.primary),
                title: const Text('Create “My Playlist” and add'),
                onTap: () async {
                  final album = await lib.createPlaylist('My Playlist');
                  await lib.addToPlaylist(album.id, track);
                  if (sheetContext.mounted) Navigator.pop(sheetContext);
                  MToast.show(context, 'Added to My Playlist');
                },
              )
            else
              ...lib.playlists.map(
                (album) => ListTile(
                  leading: const Icon(Icons.playlist_play, color: MColors.primary),
                  title: Text(album.name, overflow: TextOverflow.ellipsis),
                  subtitle: Text('${album.tracks.length} tracks'),
                  onTap: () {
                    lib.addToPlaylist(album.id, track);
                    Navigator.pop(sheetContext);
                    MToast.show(context, 'Added to ${album.name}');
                  },
                ),
              ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return GlassPanel(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: <Widget>[
          const MLogo(size: 46),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const <Widget>[
                Text(
                  'M MUSIC',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.2,
                    fontSize: 13,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'EXPLORE',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 30,
                    letterSpacing: -0.8,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Listen. Enjoy. Repeat.',
                  style: TextStyle(color: MColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          const Icon(Icons.explore_outlined, color: MColors.primary, size: 34),
        ],
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            gradient: selected ? MColors.redGradient : null,
            color: selected ? null : MColors.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: MColors.primary.withOpacity(selected ? 0 : 0.4),
            ),
            boxShadow: selected
                ? <BoxShadow>[
                    BoxShadow(
                      color: MColors.primary.withOpacity(0.3),
                      blurRadius: 12,
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : MColors.muted,
              fontSize: 12,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _chipGroup(String group) {
    final List<_Category> items = _categories
        .where((category) => category.group == group)
        .toList(growable: false);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SectionLabel(group),
          const SizedBox(height: 10),
          Wrap(
            children: items
                .map(
                  (category) => Padding(
                    padding: const EdgeInsets.only(right: 8, bottom: 8),
                    child: _chip(
                      category.label,
                      _selected?.label == category.label,
                      () => _select(category),
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        ],
      ),
    );
  }

  Widget _categoryChips() {
    return GlassPanel(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Expanded(child: SectionLabel('Browse by genre & mood')),
              const SizedBox(width: 8),
              _chip('All', _selected == null, () => _select(null)),
            ],
          ),
          const SizedBox(height: 14),
          _chipGroup('Arabic'),
          _chipGroup('International'),
          _chipGroup('Mood'),
        ],
      ),
    );
  }

  Widget _errorPanel(String message, VoidCallback onRetry) {
    return GlassPanel(
      color: MColors.darkRed.withOpacity(0.55),
      padding: const EdgeInsets.all(18),
      child: Row(
        children: <Widget>[
          const Icon(Icons.error_outline, color: MColors.bright, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  "Couldn't load music",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: MColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          GlowButton(
            label: 'Retry',
            icon: Icons.refresh,
            onPressed: onRetry,
            compact: true,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
      children: <Widget>[
        _header(),
        const SizedBox(height: 18),
        if (_featuredError != null && _trending.isEmpty && _artists.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: _errorPanel(_featuredError!, _loadFeatured),
          ),
        _categoryChips(),
        const SizedBox(height: 22),
        if (_selected != null) ...<Widget>[
          if (_categoryError != null && _categoryTracks.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _errorPanel(
                _categoryError!,
                () => _select(_selected),
              ),
            ),
          SectionCarousel(
            title: _selected!.label,
            tracks: _categoryTracks,
            loading: _categoryLoading,
            subtitle:
                _categoryError ?? 'No results for ${_selected!.label} right now.',
            onPlay: (Track track) => _play(_categoryTracks, track),
            onMore: (Track track) => _showTrackMenu(context, track),
          ),
          const SizedBox(height: 22),
        ] else
          Padding(
            padding: const EdgeInsets.only(bottom: 22),
            child: GlassPanel(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: const <Widget>[
                  Icon(Icons.touch_app_outlined, color: MColors.primary),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Pick a genre or mood above to load real YouTube music.',
                      style: TextStyle(color: MColors.muted, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        SectionCarousel(
          title: 'Trending Now',
          tracks: _trending,
          loading: _featuredLoading && _trending.isEmpty,
          subtitle: 'Trending music videos from YouTube.',
          onPlay: (Track track) => _play(_trending, track),
          onMore: (Track track) => _showTrackMenu(context, track),
        ),
        const SizedBox(height: 22),
        SectionCarousel(
          title: 'Popular Artists',
          tracks: _artists,
          loading: _featuredLoading && _artists.isEmpty,
          subtitle: 'Popular artists from YouTube.',
          onPlay: (Track track) => _play(_artists, track),
          onMore: (Track track) => _showTrackMenu(context, track),
        ),
      ],
    );
  }
}
