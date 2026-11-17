import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import '../services/api_service.dart';
import '../services/audio_player_service.dart';
import '../services/auth_service.dart';
import '../services/friends_service.dart';
import '../services/library_service.dart';
import '../services/search_query_service.dart';
import '../theme/m_theme.dart';
import 'screens/about_screen.dart';
import 'screens/albums_screen.dart';
import 'screens/artists_screen.dart';
import 'screens/explore_screen.dart';
import 'screens/friends_screen.dart';
import 'screens/history_screen.dart';
import 'screens/home_screen.dart';
import 'screens/library_screen.dart';
import 'screens/liked_songs_screen.dart';
import 'screens/playlists_screen.dart';
import 'screens/podcasts_screen.dart';
import 'screens/premium_screen.dart';
import 'screens/search_screen.dart';
import 'screens/settings_screen.dart';
import 'widgets/bottom_player_bar.dart';
import 'widgets/full_screen_player.dart';
import 'widgets/now_playing_panel.dart';

enum MMainPage {
  home,
  explore,
  search,
  library,
  liked,
  playlists,
  artists,
  albums,
  podcasts,
  history,
  settings,
  premium,
  about,
}

class MNavItem {
  const MNavItem(this.page, this.label, this.icon);

  final MMainPage page;
  final String label;
  final IconData icon;
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with SingleTickerProviderStateMixin {
  MMainPage _page = MMainPage.home;
  bool _socketReady = false;
  bool _showQueue = false;
  bool _fullscreen = false;
  bool _windowFull = false;
  bool _settingsLoaded = false;
  final _titleSearch = TextEditingController();

  static const List<MNavItem> _nav = <MNavItem>[
    MNavItem(MMainPage.home, 'HOME', Icons.home_rounded),
    MNavItem(MMainPage.explore, 'EXPLORE', Icons.explore_outlined),
    MNavItem(MMainPage.search, 'SEARCH', Icons.search_rounded),
    MNavItem(MMainPage.library, 'YOUR LIBRARY', Icons.library_music_outlined),
    MNavItem(MMainPage.liked, 'LIKED SONGS', Icons.favorite_border),
    MNavItem(MMainPage.playlists, 'PLAYLISTS', Icons.playlist_play),
    MNavItem(MMainPage.artists, 'ARTISTS', Icons.mic_none),
    MNavItem(MMainPage.albums, 'ALBUMS', Icons.album_outlined),
    MNavItem(MMainPage.podcasts, 'PODCASTS', Icons.podcasts_outlined),
    MNavItem(MMainPage.history, 'HISTORY', Icons.history),
    MNavItem(MMainPage.settings, 'SETTINGS', Icons.settings_outlined),
    MNavItem(MMainPage.premium, 'PREMIUM', Icons.workspace_premium_outlined),
    MNavItem(MMainPage.about, 'ABOUT', Icons.info_outline),
  ];

  static bool get _isDesktop =>
      Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final search = context.read<SearchQueryService>();
      search.addListener(() {
        if (!mounted || search.query.isEmpty) return;
        setState(() => _page = MMainPage.search);
      });
      final library = context.read<LibraryService>();
      library.addListener(_applySettings);
      _applySettings();
    });
  }

  void _applySettings() {
    if (_settingsLoaded || !mounted) return;
    final library = context.read<LibraryService>();
    if (library.favourites.isEmpty &&
        library.playlists.isEmpty &&
        library.searchHistory.isEmpty &&
        library.youtubeApiKey.isEmpty) {
      // SharedPreferences may still be loading; check once more on next frame.
      return;
    }
    _settingsLoaded = true;
    final volume = library.getSetting<double>('volume', 0.8);
    context
        .read<MezoxPlayerController>()
        .setVolume(volume.clamp(0.0, 1.0).toDouble());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_socketReady) {
      final auth = context.read<AuthService>();
      final api = context.read<ApiService>();
      final friends = context.read<FriendsService>();
      final player = context.read<MezoxPlayerController>();
      if (auth.user != null) {
        friends.attachApi(api);
        friends.connectSocket(auth.user!.token, (track) {
          player.playTrack(track, fromSync: true);
        });
        friends.fetchFriends();
        friends.fetchInvites();
        _socketReady = true;
      }
    }
  }

  @override
  void dispose() {
    _titleSearch.dispose();
    super.dispose();
  }

  void _go(MMainPage page) {
    setState(() {
      _page = page;
      _showQueue = false;
    });
  }

  Future<void> _toggleWindowFullscreen() async {
    if (!_isDesktop) return;
    _windowFull = !_windowFull;
    await windowManager.setFullScreen(_windowFull);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final focused = FocusManager.instance.primaryFocus?.runtimeType.toString() ?? '';
    if (focused.contains('EditableText')) return KeyEventResult.ignored;
    final player = context.read<MezoxPlayerController>();
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.space) {
      player.togglePlayPause();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      player.nextTrack();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      player.previousTrack();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyM) {
      player.toggleMute();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyF) {
      if (_fullscreen) {
        setState(() => _fullscreen = false);
      } else {
        _toggleWindowFullscreen();
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      if (_fullscreen) {
        setState(() => _fullscreen = false);
      } else if (_showQueue) {
        setState(() => _showQueue = false);
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Widget _buildPages() {
    switch (_page) {
      case MMainPage.home:
        return const HomeScreen();
      case MMainPage.explore:
        return const ExploreScreen();
      case MMainPage.search:
        return const SearchScreen();
      case MMainPage.library:
        return const LibraryScreen();
      case MMainPage.liked:
        return const LikedSongsScreen();
      case MMainPage.playlists:
        return const PlaylistsScreen();
      case MMainPage.artists:
        return const ArtistsScreen();
      case MMainPage.albums:
        return const AlbumsScreen();
      case MMainPage.podcasts:
        return const PodcastsScreen();
      case MMainPage.history:
        return const HistoryScreen();
      case MMainPage.settings:
        return const SettingsScreen();
      case MMainPage.premium:
        return const PremiumScreen();
      case MMainPage.about:
        return const AboutScreen();
    }
  }

  Widget _titleBar(BuildContext context) {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: const Color(0xFF0A0506),
        border: Border(bottom: BorderSide(color: MColors.primary.withOpacity(0.18))),
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          const MLogo(size: 26),
          const SizedBox(width: 10),
          const Text(
            'M MUSIC',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 2.2, fontSize: 13),
          ),
          const Expanded(child: DragToMoveArea(child: SizedBox.expand())),
          SizedBox(
            width: 320,
            height: 32,
            child: TextField(
              controller: _titleSearch,
              onSubmitted: (v) {
                context.read<SearchQueryService>().submit(v);
                _go(MMainPage.search);
              },
              decoration: const InputDecoration(
                hintText: 'Search songs, artists, albums...',
                prefixIcon: Icon(Icons.search, size: 18),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ),
          const Expanded(child: DragToMoveArea(child: SizedBox.expand())),
          IconButton(
            icon: const Icon(Icons.notifications_none, color: MColors.muted, size: 19),
            tooltip: 'Notifications',
            onPressed: () => MToast.show(context, 'No new notifications'),
          ),
          PopupMenuButton<String>(
            tooltip: 'Profile',
            color: MColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: MColors.primary.withOpacity(0.4)),
            ),
            onSelected: (value) async {
              if (value == 'friends') {
                showDialog(
                  context: context,
                  builder: (_) => Dialog(
                    backgroundColor: MColors.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(color: MColors.primary.withOpacity(0.4)),
                    ),
                    child: SizedBox(
                      width: 620,
                      height: 520,
                      child: const Scaffold(
                        backgroundColor: Colors.transparent,
                        body: FriendsScreen(),
                      ),
                    ),
                  ),
                );
              } else if (value == 'logout') {
                final friends = context.read<FriendsService>();
                friends.leaveListenTogether();
                friends.disconnectSocket();
                await context.read<AuthService>().logout();
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'profile',
                enabled: false,
                child: Text(
                  '@${context.read<AuthService>().user?.username ?? 'listener'}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              const PopupMenuItem(
                value: 'friends',
                child: Text('Friends & Listen Together', style: TextStyle(color: MColors.muted)),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: Text('Sign out', style: TextStyle(color: MColors.muted)),
              ),
            ],
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: MColors.redGradient,
                boxShadow: [BoxShadow(color: MColors.primary.withOpacity(0.5), blurRadius: 12)],
              ),
              child: const Icon(Icons.person, color: Colors.white, size: 18),
            ),
          ),
          const SizedBox(width: 8),
          _winButton(Icons.remove, 'Minimize', () => windowManager.minimize()),
          _winButton(Icons.crop_square, 'Maximize / Restore', () async {
            if (await windowManager.isMaximized()) {
              await windowManager.unmaximize();
            } else {
              await windowManager.maximize();
            }
          }),
          _winButton(Icons.close, 'Close', () => windowManager.close()),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _winButton(IconData icon, String tooltip, VoidCallback onPressed) {
    return SizedBox(
      width: 40,
      height: 46,
      child: IconButton(
        icon: Icon(icon, color: MColors.muted, size: 17),
        tooltip: tooltip,
        onPressed: onPressed,
      ),
    );
  }

  Widget _sidebar() {
    return Container(
      width: 222,
      decoration: BoxDecoration(
        color: const Color(0x99100809),
        border: Border(right: BorderSide(color: MColors.primary.withOpacity(0.16))),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
            child: Row(
              children: [
                const MLogo(size: 34),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'M MUSIC',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1.8),
                    ),
                    Text(
                      'Listen. Enjoy. Repeat.',
                      style: TextStyle(color: MColors.muted.withOpacity(0.8), fontSize: 9),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              itemCount: _nav.length,
              itemBuilder: (_, i) {
                final item = _nav[i];
                final selected = item.page == _page;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  margin: const EdgeInsets.symmetric(vertical: 2),
                  decoration: BoxDecoration(
                    color: selected ? MColors.primary.withOpacity(0.22) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: selected
                        ? Border.all(color: MColors.primary.withOpacity(0.55))
                        : null,
                    boxShadow: selected
                        ? [BoxShadow(color: MColors.primary.withOpacity(0.25), blurRadius: 14)]
                        : null,
                  ),
                  child: ListTile(
                    dense: true,
                    leading: Icon(
                      item.icon,
                      color: selected ? MColors.bright : MColors.muted,
                      size: 19,
                    ),
                    title: Text(
                      item.label,
                      style: TextStyle(
                        color: selected ? Colors.white : MColors.muted,
                        fontSize: 11,
                        fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                        letterSpacing: 0.6,
                      ),
                    ),
                    onTap: () => _go(item.page),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: GlassPanel(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionLabel('Now streaming'),
                  const SizedBox(height: 8),
                  Text(
                    '${context.watch<LibraryService>().favourites.length} liked songs',
                    style: const TextStyle(color: MColors.muted, fontSize: 11),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${context.watch<LibraryService>().playlists.length} playlists',
                    style: const TextStyle(color: MColors.muted, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mobileTopBar() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: const Color(0xFF0A0506),
        border: Border(bottom: BorderSide(color: MColors.primary.withOpacity(0.18))),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
          const MLogo(size: 26),
          const SizedBox(width: 8),
          const Text(
            'M MUSIC',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1.8),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: () => _go(MMainPage.search),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final showSidePanel = width >= 1180;
    final player = context.watch<MezoxPlayerController>();

    return Focus(
      autofocus: true,
      onKeyEvent: _onKey,
      child: Stack(
        children: [
          AnimatedRedBackdrop(
            child: Scaffold(
              backgroundColor: Colors.transparent,
              drawer: _isDesktop
                  ? null
                  : Drawer(
                      backgroundColor: MColors.surface,
                      child: _sidebar(),
                    ),
              body: SafeArea(
                child: Column(
                  children: [
                    if (_isDesktop) _titleBar(context) else _mobileTopBar(),
                    Expanded(
                      child: Row(
                        children: [
                          if (_isDesktop) _sidebar(),
                          Expanded(child: _buildPages()),
                          if (showSidePanel)
                            NowPlayingPanel(
                              showQueue: _showQueue,
                              onCloseQueue: () => setState(() => _showQueue = false),
                            ),
                        ],
                      ),
                    ),
                    BottomPlayerBar(
                      onToggleQueue: () => setState(() {
                        _showQueue = !_showQueue;
                        if (!showSidePanel && _showQueue) {
                          MToast.show(context, 'Queue is available in the Now Playing panel on wide screens');
                        }
                      }),
                      onOpenFullscreen: () {
                        player.setFullscreen(true);
                        setState(() => _fullscreen = true);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Official YouTube IFrame player — kept mounted but invisible.
          Positioned(
            left: 0,
            top: 0,
            width: 1,
            height: 1,
            child: IgnorePointer(
              child: Opacity(opacity: 0.01, child: player.buildVideoView()),
            ),
          ),
          if (_fullscreen)
            Positioned.fill(
              child: FullScreenPlayer(onClose: () => setState(() => _fullscreen = false)),
            ),
        ],
      ),
    );
  }
}
