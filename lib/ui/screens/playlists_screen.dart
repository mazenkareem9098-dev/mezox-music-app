import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/album.dart';
import '../../models/track.dart';
import '../../services/audio_player_service.dart';
import '../../services/library_service.dart';
import '../../services/youtube_service.dart';
import '../../theme/m_theme.dart';
import '../widgets/track_tile.dart';

/// Bottom sheet: add [track] to any local playlist, or create one first.
void showAddToPlaylistSheet(BuildContext context, Track track) {
  final lib = context.read<LibraryService>();
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: MColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      side: BorderSide(color: MColors.glassBorder),
    ),
    builder: (sheetContext) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(sheetContext).size.height * 0.72,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            SectionLabel(
              'Add "${track.title}" to playlist',
              trailing: IconButton(
                icon: const Icon(Icons.close, color: MColors.muted),
                tooltip: 'Close',
                onPressed: () => Navigator.pop(sheetContext),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: lib.playlists.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No playlists yet. Create one below, then add this song.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: MColors.muted, fontSize: 12),
                      ),
                    )
                  : ListView.builder(
                      itemCount: lib.playlists.length,
                      itemBuilder: (_, i) {
                        final a = lib.playlists[i];
                        final already = a.tracks.any((t) => t.id == track.id);
                        return ListTile(
                          leading: const Icon(Icons.playlist_play, color: MColors.bright),
                          title: Text(
                            a.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                          ),
                          subtitle: Text(
                            '${a.tracks.length} songs',
                            style: const TextStyle(color: MColors.muted, fontSize: 11),
                          ),
                          trailing: Icon(
                            already ? Icons.check_circle : Icons.add_circle_outline,
                            color: already ? MColors.primary : MColors.muted,
                          ),
                          onTap: () async {
                            if (already) {
                              MToast.show(sheetContext, 'Already in ${a.name}');
                            } else {
                              await lib.addToPlaylist(a.id, track);
                              if (context.mounted) {
                                MToast.show(context, 'Added to ${a.name}');
                              }
                            }
                            if (sheetContext.mounted) Navigator.pop(sheetContext);
                          },
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: GlowButton(
                label: 'Create new playlist',
                icon: Icons.playlist_add,
                filled: true,
                onPressed: () async {
                  final ctrl = TextEditingController();
                  final name = await showDialog<String>(
                    context: sheetContext,
                    builder: (dialogContext) => AlertDialog(
                      backgroundColor: MColors.surface,
                      title: const Text('New playlist', style: TextStyle(color: Colors.white)),
                      content: TextField(
                        controller: ctrl,
                        autofocus: true,
                        decoration: const InputDecoration(hintText: 'Playlist name'),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: const Text('Cancel'),
                        ),
                        GlowButton(
                          label: 'Create',
                          icon: Icons.check,
                          compact: true,
                          filled: true,
                          onPressed: () => Navigator.pop(dialogContext, ctrl.text.trim()),
                        ),
                      ],
                    ),
                  );
                  if (name == null || name.isEmpty) return;
                  final created = await lib.createPlaylist(name);
                  await lib.addToPlaylist(created.id, track);
                  if (sheetContext.mounted) Navigator.pop(sheetContext);
                  if (context.mounted) {
                    MToast.show(context, 'Added to ${created.name}');
                  }
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Bottom sheet with the real actions available for a track.
void showTrackMoreSheet(BuildContext context, Track track) {
  final lib = context.read<LibraryService>();
  final player = context.read<MezoxPlayerController>();
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: MColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      side: BorderSide(color: MColors.glassBorder),
    ),
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              track.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 6),
          ListTile(
            leading: Icon(
              lib.isFavourite(track.id) ? Icons.favorite : Icons.favorite_border,
              color: MColors.bright,
            ),
            title: Text(
              lib.isFavourite(track.id)
                  ? 'Remove from Liked Songs'
                  : 'Add to Liked Songs',
            ),
            onTap: () async {
              await lib.toggleFavourite(track);
              if (sheetContext.mounted) Navigator.pop(sheetContext);
              if (context.mounted) {
                MToast.show(
                  context,
                  lib.isFavourite(track.id) ? 'Added to Liked Songs' : 'Removed from Liked Songs',
                );
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.playlist_add, color: MColors.bright),
            title: const Text('Add to playlist'),
            onTap: () {
              Navigator.pop(sheetContext);
              showAddToPlaylistSheet(context, track);
            },
          ),
          ListTile(
            leading: const Icon(Icons.queue_play_next, color: MColors.bright),
            title: const Text('Add to queue'),
            onTap: () {
              player.addToQueue(track);
              Navigator.pop(sheetContext);
              MToast.show(context, 'Added to queue');
            },
          ),
        ],
      ),
    ),
  );
}

/// Bottom sheet with rename / delete for a playlist.
void showPlaylistActionsSheet(
  BuildContext context,
  Album album, {
  VoidCallback? onDeleted,
}) {
  final lib = context.read<LibraryService>();
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: MColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      side: BorderSide(color: MColors.glassBorder),
    ),
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              album.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 6),
          ListTile(
            leading: const Icon(Icons.edit, color: MColors.bright),
            title: const Text('Rename playlist'),
            onTap: () async {
              Navigator.pop(sheetContext);
              final ctrl = TextEditingController(text: album.name);
              final name = await showDialog<String>(
                context: context,
                builder: (_) => AlertDialog(
                  backgroundColor: MColors.surface,
                  title: const Text('Rename playlist', style: TextStyle(color: Colors.white)),
                  content: TextField(
                    controller: ctrl,
                    autofocus: true,
                    decoration: const InputDecoration(hintText: 'New name'),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    GlowButton(
                      label: 'Save',
                      icon: Icons.check,
                      compact: true,
                      filled: true,
                      onPressed: () => Navigator.pop(context, ctrl.text.trim()),
                    ),
                  ],
                ),
              );
              if (name != null && name.isNotEmpty) {
                await lib.renameAlbum(album.id, name);
                if (context.mounted) MToast.show(context, 'Playlist renamed');
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: MColors.bright),
            title: const Text('Delete playlist', style: TextStyle(color: MColors.bright)),
            onTap: () async {
              Navigator.pop(sheetContext);
              final ok = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  backgroundColor: MColors.surface,
                  title: const Text('Delete playlist?', style: TextStyle(color: Colors.white)),
                  content: Text(
                    '${album.name} will be removed from your library.',
                    style: const TextStyle(color: MColors.muted),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    GlowButton(
                      label: 'Delete',
                      icon: Icons.delete,
                      compact: true,
                      filled: true,
                      onPressed: () => Navigator.pop(context, true),
                    ),
                  ],
                ),
              );
              if (ok == true) {
                await lib.deleteAlbum(album.id);
                onDeleted?.call();
                if (context.mounted) MToast.show(context, 'Playlist deleted');
              }
            },
          ),
        ],
      ),
    ),
  );
}

/// Real artwork for a playlist: its cover, else its first song's art.
Widget playlistCover(Album album, {double size = 120}) {
  final url = album.coverUrl.isNotEmpty
      ? album.coverUrl
      : (album.tracks.isEmpty ? '' : album.tracks.first.artworkUrl);
  return ClipRRect(
    borderRadius: BorderRadius.circular(size / 7),
    child: url.isEmpty
        ? Container(
            width: size,
            height: size,
            color: MColors.darkRed,
            alignment: Alignment.center,
            child: Icon(Icons.playlist_play, color: Colors.white70, size: size / 3),
          )
        : Image.network(
            url,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              width: size,
              height: size,
              color: MColors.darkRed,
              alignment: Alignment.center,
              child: Icon(Icons.playlist_play, color: Colors.white70, size: size / 3),
            ),
          ),
  );
}

/// Grid card used on the playlists and library pages.
class PlaylistCard extends StatelessWidget {
  const PlaylistCard({
    super.key,
    required this.album,
    required this.onTap,
    this.onMore,
  });

  final Album album;
  final VoidCallback onTap;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      onTap: onTap,
      padding: const EdgeInsets.all(10),
      margin: const EdgeInsets.only(right: 12, bottom: 12),
      radius: 18,
      child: SizedBox(
        width: 164,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                playlistCover(album, size: 144),
                Positioned(
                  right: 6,
                  bottom: 6,
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: MColors.redGradient,
                    ),
                    child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              album.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${album.tracks.length} songs',
                    style: const TextStyle(color: MColors.muted, fontSize: 11),
                  ),
                ),
                if (onMore != null)
                  InkWell(
                    onTap: onMore,
                    child: const Padding(
                      padding: EdgeInsets.all(2),
                      child: Icon(Icons.more_vert, color: MColors.muted, size: 17),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact row version of [PlaylistCard].
class PlaylistListTile extends StatelessWidget {
  const PlaylistListTile({
    super.key,
    required this.album,
    required this.onTap,
    this.onMore,
  });

  final Album album;
  final VoidCallback onTap;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      margin: const EdgeInsets.symmetric(vertical: 4),
      radius: 14,
      child: Row(
        children: [
          playlistCover(album, size: 48),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  album.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 3),
                Text(
                  '${album.tracks.length} songs · ${formatDuration(album.totalDuration)}',
                  style: const TextStyle(color: MColors.muted, fontSize: 11),
                ),
              ],
            ),
          ),
          if (onMore != null)
            IconButton(
              icon: const Icon(Icons.more_vert, color: MColors.muted, size: 18),
              tooltip: 'Playlist actions',
              onPressed: onMore,
            ),
        ],
      ),
    );
  }
}

class PlaylistsScreen extends StatefulWidget {
  const PlaylistsScreen({super.key});

  @override
  State<PlaylistsScreen> createState() => _PlaylistsScreenState();
}

class _PlaylistsScreenState extends State<PlaylistsScreen> {
  bool _grid = true;

  Future<void> _createPlaylist(BuildContext context) async {
    final lib = context.read<LibraryService>();
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: MColors.surface,
        title: const Text('New playlist', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Playlist name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          GlowButton(
            label: 'Create',
            icon: Icons.check,
            filled: true,
            compact: true,
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    await lib.createPlaylist(name);
    if (context.mounted) MToast.show(context, 'Playlist "$name" created');
  }

  void _openDetail(Album album) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PlaylistDetailPage(playlistId: album.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lib = context.watch<LibraryService>();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
          child: Row(
            children: [
              Expanded(
                child: SectionLabel(
                  'Playlists',
                  trailing: Text(
                    '${lib.playlists.length}',
                    style: const TextStyle(color: MColors.muted, fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GlowButton(
                label: 'New playlist',
                icon: Icons.playlist_add,
                filled: true,
                compact: true,
                onPressed: () => _createPlaylist(context),
              ),
              const SizedBox(width: 6),
              IconButton(
                icon: Icon(_grid ? Icons.view_list : Icons.grid_view),
                color: MColors.muted,
                tooltip: _grid ? 'List view' : 'Grid view',
                onPressed: () => setState(() => _grid = !_grid),
              ),
            ],
          ),
        ),
        Expanded(
          child: lib.playlists.isEmpty
              ? Center(
                  child: GlassPanel(
                    margin: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.playlist_play, color: MColors.primary, size: 44),
                        const SizedBox(height: 12),
                        const Text(
                          'No playlists yet.',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Create one and add songs from Search or Liked Songs.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: MColors.muted, fontSize: 12),
                        ),
                        const SizedBox(height: 16),
                        GlowButton(
                          label: 'Create playlist',
                          icon: Icons.add,
                          filled: true,
                          onPressed: () => _createPlaylist(context),
                        ),
                      ],
                    ),
                  ),
                )
              : _grid
                  ? GridView.builder(
                      padding: const EdgeInsets.fromLTRB(18, 4, 6, 24),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 190,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childAspectRatio: 0.62,
                      ),
                      itemCount: lib.playlists.length,
                      itemBuilder: (_, i) {
                        final a = lib.playlists[i];
                        return PlaylistCard(
                          album: a,
                          onTap: () => _openDetail(a),
                          onMore: () => showPlaylistActionsSheet(context, a),
                        );
                      },
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
                      itemCount: lib.playlists.length,
                      itemBuilder: (_, i) {
                        final a = lib.playlists[i];
                        return PlaylistListTile(
                          album: a,
                          onTap: () => _openDetail(a),
                          onMore: () => showPlaylistActionsSheet(context, a),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

/// Full detail view for one playlist — cover, actions and ordered song list.
class PlaylistDetailPage extends StatefulWidget {
  const PlaylistDetailPage({super.key, required this.playlistId});

  final String playlistId;

  @override
  State<PlaylistDetailPage> createState() => _PlaylistDetailPageState();
}

class _PlaylistDetailPageState extends State<PlaylistDetailPage> {
  Future<void> _rename(BuildContext context, Album album) async {
    final lib = context.read<LibraryService>();
    final ctrl = TextEditingController(text: album.name);
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: MColors.surface,
        title: const Text('Rename playlist', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'New name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          GlowButton(
            label: 'Save',
            icon: Icons.check,
            filled: true,
            compact: true,
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    await lib.renameAlbum(album.id, name);
    if (context.mounted) MToast.show(context, 'Playlist renamed');
  }

  Future<void> _editDetails(BuildContext context, Album album) async {
    final lib = context.read<LibraryService>();
    final nameCtrl = TextEditingController(text: album.name);
    final descCtrl = TextEditingController(text: album.description);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: MColors.surface,
        title: const Text('Edit playlist', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(hintText: 'Name'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: descCtrl,
              maxLines: 3,
              decoration: const InputDecoration(hintText: 'Description'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          GlowButton(
            label: 'Save',
            icon: Icons.check,
            filled: true,
            compact: true,
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await lib.updatePlaylist(
      album.id,
      name: nameCtrl.text.trim(),
      description: descCtrl.text.trim(),
    );
    if (context.mounted) MToast.show(context, 'Playlist updated');
  }

  Future<void> _delete(BuildContext context, Album album) async {
    final lib = context.read<LibraryService>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: MColors.surface,
        title: const Text('Delete playlist?', style: TextStyle(color: Colors.white)),
        content: Text(
          '${album.name} will be removed from your library.',
          style: const TextStyle(color: MColors.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          GlowButton(
            label: 'Delete',
            icon: Icons.delete,
            filled: true,
            compact: true,
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await lib.deleteAlbum(album.id);
    if (context.mounted) Navigator.of(context).pop();
  }

  void _openAddSongs(BuildContext context, Album album) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AddSongsPage(playlistId: album.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lib = context.watch<LibraryService>();
    final player = context.read<MezoxPlayerController>();

    Album? found;
    for (final a in lib.playlists) {
      if (a.id == widget.playlistId) {
        found = a;
        break;
      }
    }

    if (found == null) {
      return Scaffold(
        backgroundColor: MColors.background,
        appBar: AppBar(title: const Text('Playlist')),
        body: Center(
          child: GlassPanel(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'This playlist no longer exists.',
                  style: TextStyle(color: MColors.muted),
                ),
                const SizedBox(height: 14),
                GlowButton(
                  label: 'Back',
                  icon: Icons.arrow_back,
                  filled: true,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final album = found;
    return Scaffold(
      backgroundColor: MColors.background,
      appBar: AppBar(
        title: Text(album.name),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  playlistCover(album, size: 124),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          album.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          album.description.isEmpty ? 'No description' : album.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: MColors.muted, fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${album.tracks.length} songs · ${formatDuration(album.totalDuration)}',
                          style: const TextStyle(color: MColors.bright, fontSize: 12),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            GlowButton(
                              label: 'Play all',
                              icon: Icons.play_arrow_rounded,
                              filled: true,
                              compact: true,
                              onPressed: () => player.playPlaylist(album),
                            ),
                            GlowButton(
                              label: 'Shuffle',
                              icon: Icons.shuffle,
                              compact: true,
                              onPressed: () => player.playPlaylist(album, shuffled: true),
                            ),
                            GlowButton(
                              label: 'Add songs',
                              icon: Icons.add,
                              compact: true,
                              onPressed: () => _openAddSongs(context, album),
                            ),
                            GlowButton(
                              label: 'Rename',
                              icon: Icons.edit,
                              compact: true,
                              onPressed: () => _rename(context, album),
                            ),
                            GlowButton(
                              label: 'Edit details',
                              icon: Icons.description,
                              compact: true,
                              onPressed: () => _editDetails(context, album),
                            ),
                            GlowButton(
                              label: 'Delete',
                              icon: Icons.delete_outline,
                              compact: true,
                              onPressed: () => _delete(context, album),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: SectionLabel(
                'Songs',
                trailing: Text(
                  'drag to reorder',
                  style: TextStyle(color: MColors.muted, fontSize: 11),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: album.tracks.isEmpty
                  ? Center(
                      child: GlassPanel(
                        margin: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'This playlist is empty.',
                              style: TextStyle(color: MColors.muted),
                            ),
                            const SizedBox(height: 14),
                            GlowButton(
                              label: 'Add songs',
                              icon: Icons.add,
                              filled: true,
                              onPressed: () => _openAddSongs(context, album),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ReorderableListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                      itemCount: album.tracks.length,
                      onReorder: (oldIndex, newIndex) =>
                          lib.reorderPlaylist(album.id, oldIndex, newIndex),
                      itemBuilder: (itemContext, i) {
                        final t = album.tracks[i];
                        return KeyedSubtree(
                          key: ValueKey<String>('${album.id}_${t.id}_$i'),
                          child: TrackTile(
                            track: t,
                            index: i,
                            onPlay: () => player.playQueue(album.tracks, i),
                            trailing: IconButton(
                              icon: const Icon(
                                Icons.remove_circle_outline,
                                color: MColors.bright,
                                size: 19,
                              ),
                              tooltip: 'Remove from playlist',
                              onPressed: () async {
                                await lib.removeFromPlaylist(album.id, t.id);
                                if (itemContext.mounted) {
                                  MToast.show(itemContext, 'Removed ${t.title}');
                                }
                              },
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Search YouTube and add real results to a playlist.
class AddSongsPage extends StatefulWidget {
  const AddSongsPage({super.key, required this.playlistId});

  final String playlistId;

  @override
  State<AddSongsPage> createState() => _AddSongsPageState();
}

class _AddSongsPageState extends State<AddSongsPage> {
  final _ctrl = TextEditingController();
  Timer? _debounce;
  List<Track> _results = <Track>[];
  bool _loading = false;
  bool _searched = false;
  String? _error;

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() {
        _results = <Track>[];
        _searched = false;
        _error = null;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 420), _search);
  }

  Future<void> _search() async {
    _debounce?.cancel();
    final q = _ctrl.text.trim();
    if (q.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final yt = context.read<YouTubeService>();
    try {
      final tracks = await yt.search(q, limit: 40);
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

  Future<void> _add(Track track) async {
    final lib = context.read<LibraryService>();
    Album? album;
    for (final a in lib.playlists) {
      if (a.id == widget.playlistId) {
        album = a;
        break;
      }
    }
    final already = album?.tracks.any((t) => t.id == track.id) ?? false;
    await lib.addToPlaylist(widget.playlistId, track);
    if (mounted) {
      MToast.show(context, already ? 'Already in playlist' : 'Added ${track.title}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MColors.background,
      appBar: AppBar(
        title: const Text('Add songs'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      autofocus: true,
                      onChanged: _onChanged,
                      onSubmitted: (_) => _search(),
                      decoration: const InputDecoration(
                        hintText: 'Search songs to add... / ابحث عن أغنية',
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GlowButton(
                    label: 'Search',
                    icon: Icons.search,
                    filled: true,
                    compact: true,
                    onPressed: _search,
                  ),
                ],
              ),
            ),
            if (_loading) const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: _loading && _results.isEmpty
                  ? const Center(
                      child: CircularProgressIndicator(color: MColors.primary),
                    )
                  : _error != null
                      ? Center(
                          child: GlassPanel(
                            margin: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _error!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: MColors.bright, fontSize: 12),
                                ),
                                const SizedBox(height: 12),
                                GlowButton(
                                  label: 'Retry',
                                  icon: Icons.refresh,
                                  filled: true,
                                  onPressed: _search,
                                ),
                              ],
                            ),
                          ),
                        )
                  : !_searched
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'Type a song or artist name to find tracks to add.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: MColors.muted, fontSize: 12),
                            ),
                          ),
                        )
                      : _results.isEmpty
                          ? const Center(
                              child: Text(
                                'No tracks found for that search.',
                                style: TextStyle(color: MColors.muted, fontSize: 12),
                              ),
                            )
                          : ListView.builder(
                              itemCount: _results.length,
                              itemBuilder: (_, i) {
                                final t = _results[i];
                                return TrackTile(
                                  track: t,
                                  index: i,
                                  onPlay: () => _add(t),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.add_circle_outline, color: MColors.bright),
                                    tooltip: 'Add to playlist',
                                    onPressed: () => _add(t),
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
