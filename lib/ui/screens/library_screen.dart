import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/album.dart';
import '../../models/track.dart';
import '../../services/audio_player_service.dart';
import '../../services/library_service.dart';
import '../../theme/m_theme.dart';
import '../widgets/music_card.dart';
import '../widgets/track_tile.dart';
import 'playlists_screen.dart';

const List<String> _tabs = <String>[
  'Playlists',
  'Liked Songs',
  'Artists',
  'Albums',
  'Recently Played',
];

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final _searchCtrl = TextEditingController();
  int _tab = 0;
  bool _grid = true;
  bool _alpha = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _openDetail(Album album) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PlaylistDetailPage(playlistId: album.id),
      ),
    );
  }

  bool _matches(Track t, String q) {
    if (q.isEmpty) return true;
    return t.title.toLowerCase().contains(q) ||
        t.artist.toLowerCase().contains(q);
  }

  List<Track> _tracksFor(LibraryService lib) {
    switch (_tab) {
      case 1:
        return lib.favourites;
      case 4:
        return lib.recentlyPlayed;
      default:
        return const <Track>[];
    }
  }

  List<Track> _visibleTracks(LibraryService lib) {
    final q = _searchCtrl.text.trim().toLowerCase();
    final list = _tracksFor(lib).where((t) => _matches(t, q)).toList();
    if (_alpha) {
      list.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    }
    return list;
  }

  List<Album> _visibleAlbums(LibraryService lib) {
    final q = _searchCtrl.text.trim().toLowerCase();
    final list = lib.playlists.where((a) {
      if (q.isEmpty) return true;
      return a.name.toLowerCase().contains(q) ||
          a.description.toLowerCase().contains(q) ||
          a.tracks.any((t) => _matches(t, q));
    }).toList();
    if (_alpha) {
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    } else {
      list.sort((a, b) => (b.createdAtMs ?? 0).compareTo(a.createdAtMs ?? 0));
    }
    return list;
  }

  List<MapEntry<String, List<Track>>> _visibleArtists(LibraryService lib) {
    final q = _searchCtrl.text.trim().toLowerCase();
    final all = <Track>[...lib.favourites, ...lib.recentlyPlayed];
    for (final a in lib.playlists) {
      all.addAll(a.tracks);
    }
    final groups = <String, List<Track>>{};
    for (final t in all) {
      final name = t.artist.trim().isEmpty ? 'Unknown artist' : t.artist;
      if (q.isNotEmpty && !name.toLowerCase().contains(q)) continue;
      groups.putIfAbsent(name, () => <Track>[]).add(t);
    }
    final entries = groups.entries.toList();
    if (_alpha) {
      entries.sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));
    }
    return entries;
  }

  void _playTracks(List<Track> tracks, int index, BuildContext context) {
    if (tracks.isEmpty || index < 0 || index >= tracks.length) return;
    context.read<MezoxPlayerController>().playQueue(tracks, index);
  }

  Widget _albumGrid(List<Album> albums) {
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
          onTap: () => _openDetail(a),
          onMore: () => showPlaylistActionsSheet(context, a),
        );
      },
    );
  }

  Widget _albumList(List<Album> albums) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
      itemCount: albums.length,
      itemBuilder: (_, i) {
        final a = albums[i];
        return PlaylistListTile(
          album: a,
          onTap: () => _openDetail(a),
          onMore: () => showPlaylistActionsSheet(context, a),
        );
      },
    );
  }

  Widget _trackGrid(List<Track> tracks) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 4, 6, 24),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 186,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
        childAspectRatio: 0.66,
      ),
      itemCount: tracks.length,
      itemBuilder: (_, i) {
        final t = tracks[i];
        return MusicCard(
          track: t,
          width: 172,
          onPlay: () => _playTracks(tracks, i, context),
          onMore: () => showTrackMoreSheet(context, t),
        );
      },
    );
  }

  Widget _trackList(List<Track> tracks, {bool showUnlike = false}) {
    final lib = context.read<LibraryService>();
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
      itemCount: tracks.length,
      itemBuilder: (_, i) {
        final t = tracks[i];
        return TrackTile(
          track: t,
          index: i,
          onPlay: () => _playTracks(tracks, i, context),
          onMore: () => showTrackMoreSheet(context, t),
          trailing: showUnlike
              ? IconButton(
                  icon: const Icon(Icons.favorite, color: MColors.bright, size: 18),
                  tooltip: 'Unlike',
                  onPressed: () async {
                    await lib.removeFavourite(t.id);
                    if (mounted) MToast.show(context, 'Removed from Liked Songs');
                  },
                )
              : null,
        );
      },
    );
  }

  Widget _artistGrid(List<MapEntry<String, List<Track>>> groups) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.15,
      ),
      itemCount: groups.length,
      itemBuilder: (_, i) {
        final entry = groups[i];
        final first = entry.value.first;
        return GlassPanel(
          onTap: () => _playTracks(entry.value, 0, context),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ClipOval(
                child: first.artworkUrl.isEmpty
                    ? Container(
                        width: 72,
                        height: 72,
                        color: MColors.darkRed,
                        child: const Icon(Icons.person, color: Colors.white70, size: 34),
                      )
                    : Image.network(
                        first.artworkUrl,
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 72,
                          height: 72,
                          color: MColors.darkRed,
                          child: const Icon(Icons.person, color: Colors.white70, size: 34),
                        ),
                      ),
              ),
              const SizedBox(height: 10),
              Text(
                entry.key,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${entry.value.length} songs',
                style: const TextStyle(color: MColors.muted, fontSize: 10),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _artistList(List<MapEntry<String, List<Track>>> groups) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
      itemCount: groups.length,
      itemBuilder: (_, i) {
        final entry = groups[i];
        final first = entry.value.first;
        return GlassPanel(
          onTap: () => _playTracks(entry.value, 0, context),
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          radius: 14,
          child: Row(
            children: [
              ClipOval(
                child: first.artworkUrl.isEmpty
                    ? Container(
                        width: 48,
                        height: 48,
                        color: MColors.darkRed,
                        child: const Icon(Icons.person, color: Colors.white70),
                      )
                    : Image.network(
                        first.artworkUrl,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 48,
                          height: 48,
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
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${entry.value.length} songs',
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

  Widget _empty(String message) {
    return Center(
      child: GlassPanel(
        margin: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.library_music_outlined, color: MColors.primary, size: 40),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: MColors.muted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lib = context.watch<LibraryService>();
    final player = context.read<MezoxPlayerController>();

    final Widget body;
    switch (_tab) {
      case 0:
      case 3:
        final albums = _visibleAlbums(lib);
        body = albums.isEmpty
            ? _empty('No playlists here yet. Create one on the Playlists page.')
            : (_grid ? _albumGrid(albums) : _albumList(albums));
        break;
      case 1:
        final tracks = _visibleTracks(lib);
        body = tracks.isEmpty
            ? _empty(lib.favourites.isEmpty
                ? 'No liked songs yet. Tap the heart on any track.'
                : 'No liked songs match your search.')
            : (_grid ? _trackGrid(tracks) : _trackList(tracks, showUnlike: true));
        break;
      case 2:
        final groups = _visibleArtists(lib);
        body = groups.isEmpty
            ? _empty('No artists in your library yet.')
            : (_grid ? _artistGrid(groups) : _artistList(groups));
        break;
      case 4:
        final tracks = _visibleTracks(lib);
        body = tracks.isEmpty
            ? _empty(lib.recentlyPlayed.isEmpty
                ? 'Nothing played yet. Start a song from Search.'
                : 'No recently played tracks match your search.')
            : (_grid ? _trackGrid(tracks) : _trackList(tracks));
        break;
      default:
        body = _empty('Nothing here.');
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          child: GlassPanel(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Search this library / ابحث في مكتبتك',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchCtrl.text.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close, color: MColors.muted),
                              tooltip: 'Clear library search',
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() {});
                              },
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  icon: Icon(_grid ? Icons.view_list : Icons.grid_view),
                  color: MColors.muted,
                  tooltip: _grid ? 'List view' : 'Grid view',
                  onPressed: () => setState(() => _grid = !_grid),
                ),
                PopupMenuButton<String>(
                  initialValue: _alpha ? 'A–Z' : 'Recently added',
                  color: MColors.surface,
                  tooltip: 'Sort',
                  onSelected: (v) => setState(() => _alpha = v == 'A–Z'),
                  itemBuilder: (_) => const [
                    PopupMenuItem<String>(value: 'Recently added', child: Text('Recently added')),
                    PopupMenuItem<String>(value: 'A–Z', child: Text('Alphabetical A–Z')),
                  ],
                  child: const Icon(Icons.sort, color: MColors.muted),
                ),
              ],
            ),
          ),
        ),
        SizedBox(
          height: 42,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _tabs.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) => GlowButton(
              label: _tabs[i],
              icon: i == 0
                  ? Icons.playlist_play
                  : i == 1
                      ? Icons.favorite_border
                      : i == 2
                          ? Icons.person_outline
                          : i == 3
                              ? Icons.album_outlined
                              : Icons.history,
              compact: true,
              filled: _tab == i,
              onPressed: () => setState(() => _tab = i),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 2),
          child: SectionLabel(
            _tabs[_tab],
            trailing: _tab == 4 && lib.recentlyPlayed.isNotEmpty
                ? GlowButton(
                    label: 'Clear',
                    icon: Icons.delete_sweep_outlined,
                    compact: true,
                    onPressed: () async {
                      await lib.clearRecentlyPlayed();
                      if (context.mounted) {
                        MToast.show(context, 'Recently played cleared');
                      }
                    },
                  )
                : _tab == 1 && lib.favourites.isNotEmpty
                    ? GlowButton(
                        label: 'Play all',
                        icon: Icons.play_arrow_rounded,
                        compact: true,
                        filled: true,
                        onPressed: () {
                          final tracks = _visibleTracks(lib);
                          if (tracks.isNotEmpty) {
                            player.playQueue(tracks, 0);
                          }
                        },
                      )
                    : null,
          ),
        ),
        Expanded(child: body),
      ],
    );
  }
}
