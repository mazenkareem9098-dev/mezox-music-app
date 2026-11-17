import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import '../services/audio_player_service.dart';
import '../services/auth_service.dart';
import '../services/friends_service.dart';
import 'screens/home_screen.dart';
import 'screens/search_screen.dart';
import 'screens/library_screen.dart';
import 'screens/friends_screen.dart';
import 'widgets/player_bar.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  bool _socketReady = false;

  static bool get _isDesktop =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_socketReady) {
      final auth = context.read<AuthService>();
      final friends = context.read<FriendsService>();
      final player = context.read<MezoxPlayerController>();
      if (auth.user != null) {
        friends.connectSocket(auth.user!.token, (track) {
          player.playTrack(track, fromSync: true);
        });
        friends.fetchFriends();
        friends.fetchInvites();
        _socketReady = true;
      }
    }
  }

  Widget _customTitleBar() {
    return Container(
      height: 38,
      color: const Color(0xFF0A0A0A),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Image.asset('assets/logo.png', height: 24, width: 24),
          ),
          const SizedBox(width: 8),
          const Text(
            'MEZOX MUSIC',
            style: TextStyle(color: Colors.white70, fontSize: 12, letterSpacing: 1.2),
          ),
          const Expanded(child: DragToMoveArea(child: SizedBox.expand())),
          SizedBox(
            width: 38,
            height: 38,
            child: IconButton(
              tooltip: 'Minimize',
              icon: const Icon(Icons.remove, size: 18),
              onPressed: () => windowManager.minimize(),
            ),
          ),
          SizedBox(
            width: 38,
            height: 38,
            child: IconButton(
              tooltip: 'Maximize',
              icon: const Icon(Icons.crop_square, size: 16),
              onPressed: () => windowManager.maximizeOrRestore(),
            ),
          ),
          SizedBox(
            width: 38,
            height: 38,
            child: IconButton(
              tooltip: 'Close',
              icon: const Icon(Icons.close, size: 18),
              onPressed: () => windowManager.close(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _logoutButton() {
    return IconButton(
      icon: const Icon(Icons.logout),
      tooltip: 'Logout',
      onPressed: () {
        final friends = context.read<FriendsService>();
        friends.leaveListenTogether();
        friends.disconnectSocket();
        context.read<AuthService>().logout();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = const [HomeScreen(), SearchScreen(), LibraryScreen(), FriendsScreen()];
    final body = Column(
      children: [
        if (_isDesktop) _customTitleBar(),
        Expanded(child: pages[_index]),
        const PlayerBar(),
      ],
    );
    return Scaffold(
      appBar: _isDesktop
          ? null
          : AppBar(
              title: const Text('MEZOX MUSIC',
                  style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5)),
              actions: [_logoutButton()],
            ),
      floatingActionButton: _isDesktop
          ? Padding(
              padding: const EdgeInsets.only(bottom: 84),
              child: _logoutButton(),
            )
          : null,
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.search), label: 'Search'),
          NavigationDestination(icon: Icon(Icons.library_music), label: 'Library'),
          NavigationDestination(icon: Icon(Icons.people), label: 'Friends'),
        ],
      ),
    );
  }
}
