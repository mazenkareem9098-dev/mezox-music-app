import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/track.dart';
import '../../services/audio_player_service.dart';
import '../../services/library_service.dart';
import '../../services/youtube_service.dart';
import '../../theme/m_theme.dart';
import '../widgets/section_carousel.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const String _madeKey = 'made';
  static const String _trendingKey = 'trending';
  static const String _recommendedKey = 'recommended';
  static const String _artistsKey = 'artists';
  static const String _newKey = 'new';

  final Map<String, List<Track>> _sections = <String, List<Track>>{
    _madeKey: <Track>[],
    _trendingKey: <Track>[],
    _recommendedKey: <Track>[],
    _artistsKey: <Track>[],
    _newKey: <Track>[],
  };
  final ScrollController _scroll = ScrollController();
  final GlobalKey _discoveryKey = GlobalKey(debugLabel: 'home-discovery');

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<List<Track>> _collect(YouTubeService yt, List<String> queries) async {
    final seen = <String>{};
    final out = <Track>[];
    for (final q in queries) {
      final batch = await yt.category(q, limit: 24);
      for (final t in batch) {
        if (seen.add(t.sourceId)) out.add(t);
      }
      if (out.length >= 20) break;
    }
    final limited = out.length > 24 ? out.sublist(0, 24) : out;
    return limited;
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    final YouTubeService yt = context.read<YouTubeService>();
    final LibraryService lib = context.read<LibraryService>();
    final Track? seed = lib.recentlyPlayed.isNotEmpty
        ? lib.recentlyPlayed.first
        : (lib.favourites.isNotEmpty ? lib.favourites.first : null);
    final String madeQuery =
        seed == null ? 'top music hits' : '${seed.artist} music';
    final String recommendedQuery = seed == null
        ? 'popular music mix'
        : '${seed.title} ${seed.artist}';

    try {
      final List<List<Track>> results = await Future.wait<List<Track>>(
        <Future<List<Track>>>[
          _collect(yt, <String>[
            madeQuery,
            'top music hits 2026',
            'popular arabic and english songs',
          ]),
          _collect(yt, <String>[
            'trending music videos',
            'top 50 songs',
            'most played songs now',
          ]),
          _collect(yt, <String>[
            recommendedQuery,
            'popular music mix',
            'chill playlist songs',
          ]),
          _collect(yt, <String>[
            'popular music artists',
            'top singers hits',
            'famous bands songs',
          ]),
          _collect(yt, <String>[
            'new music releases 2026',
            'latest music videos',
            'new arabic songs',
          ]),
        ],
      );
      if (!mounted) return;
      setState(() {
        _sections[_madeKey] = results[0].isNotEmpty
            ? results[0]
            : <Track>[...lib.favourites, ...lib.recentlyPlayed];
        _sections[_trendingKey] = results[1];
        _sections[_recommendedKey] = results[2].isNotEmpty
            ? results[2]
            : results[0];
        _sections[_artistsKey] = results[3];
        _sections[_newKey] = results[4];
        final bool any = _sections.values.any((list) => list.isNotEmpty);
        if (!any && yt.lastError != null) _error = yt.lastError;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = "Couldn't reach YouTube: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _playList(List<Track> tracks, Track track) {
    final int index = tracks.indexOf(track);
    context
        .read<MezoxPlayerController>()
        .playQueue(tracks, index < 0 ? 0 : index);
    MToast.show(context, 'Playing ${track.title}');
  }

  void _playNow() {
    final LibraryService lib = context.read<LibraryService>();
    List<Track> tracks = _sections[_trendingKey] ?? <Track>[];
    if (tracks.isEmpty) tracks = _sections[_madeKey] ?? <Track>[];
    if (tracks.isEmpty) tracks = lib.recentlyPlayed;
    if (tracks.isEmpty) {
      MToast.show(context, 'Music is still loading — tap Play Now in a moment');
      return;
    }
    context.read<MezoxPlayerController>().playQueue(tracks, 0);
    MToast.show(context, 'Playing ${tracks.first.title}');
  }

  void _explore() {
    final BuildContext? anchor = _discoveryKey.currentContext;
    if (anchor != null) {
      Scrollable.ensureVisible(
        anchor,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOut,
      );
    }
    MToast.show(context, 'Explore — more music is right below');
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

  Widget _hero(BuildContext context, LibraryService lib) {
    return SizedBox(
      height: 320,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              gradient: const LinearGradient(
                colors: <Color>[
                  Color(0xFF2A0006),
                  Color(0xFF0B0506),
                  Color(0xFF450000),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: MColors.primary.withOpacity(0.45)),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: MColors.primary.withOpacity(0.22),
                  blurRadius: 38,
                ),
              ],
            ),
          ),
          Positioned(
            right: -50,
            top: -60,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: <Color>[
                    MColors.primary.withOpacity(0.35),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(26),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: const <Widget>[
                    MLogo(size: 42),
                    SizedBox(width: 12),
                    Text(
                      'M MUSIC',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.4,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                const Text(
                  'YOUR MUSIC,\nYOUR MOOD',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 38,
                    height: 1.05,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.2,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Listen. Enjoy. Repeat.',
                  style: TextStyle(color: MColors.muted, fontSize: 14),
                ),
                const SizedBox(height: 6),
                Text(
                  '${lib.favourites.length} liked songs  ·  ${lib.recentlyPlayed.length} recently played',
                  style: TextStyle(
                    color: MColors.muted.withOpacity(0.75),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: <Widget>[
                    GlowButton(
                      label: 'Play Now',
                      icon: Icons.play_arrow_rounded,
                      onPressed: _playNow,
                      filled: true,
                    ),
                    const SizedBox(width: 12),
                    GlowButton(
                      label: 'Explore',
                      icon: Icons.explore_outlined,
                      onPressed: _explore,
                    ),
                  ],
                ),
              ],
            ),
          ),
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

  Widget _section(String title, String key, {String? subtitle}) {
    final List<Track> tracks = _sections[key] ?? <Track>[];
    return SectionCarousel(
      title: title,
      tracks: tracks,
      loading: _loading && tracks.isEmpty,
      subtitle: subtitle,
      onPlay: (Track track) => _playList(tracks, track),
      onMore: (Track track) => _showTrackMenu(context, track),
    );
  }

  @override
  Widget build(BuildContext context) {
    final LibraryService lib = context.watch<LibraryService>();
    final List<Track> recent = lib.recentlyPlayed;
    final bool hasAny =
        recent.isNotEmpty || _sections.values.any((list) => list.isNotEmpty);

    return ListView(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
      children: <Widget>[
        _hero(context, lib),
        const SizedBox(height: 26),
        if (_error != null && !hasAny) ...<Widget>[
          _errorPanel(_error!, _load),
          const SizedBox(height: 22),
        ],
        Container(key: _discoveryKey, child: const SizedBox.shrink()),
        _section(
          'Made For You',
          _madeKey,
          subtitle: 'Picked from your library and YouTube.',
        ),
        const SizedBox(height: 22),
        _section('Trending Now', _trendingKey),
        const SizedBox(height: 22),
        SectionCarousel(
          title: 'Recently Played',
          tracks: recent,
          loading: _loading && recent.isEmpty,
          subtitle: 'Nothing played yet — jump into Trending Now.',
          onPlay: (Track track) => _playList(recent, track),
          onMore: (Track track) => _showTrackMenu(context, track),
        ),
        const SizedBox(height: 22),
        _section('Recommended For You', _recommendedKey),
        const SizedBox(height: 22),
        _section('Popular Artists', _artistsKey),
        const SizedBox(height: 22),
        _section('New Releases', _newKey),
      ],
    );
  }
}
