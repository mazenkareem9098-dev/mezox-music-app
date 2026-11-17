import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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

  @override
  Widget build(BuildContext context) {
    final pages = const [HomeScreen(), SearchScreen(), LibraryScreen(), FriendsScreen()];
    return Scaffold(
      appBar: AppBar(
        title: const Text('MEZOX MUSIC', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () {
              final friends = context.read<FriendsService>();
              friends.leaveListenTogether();
              friends.disconnectSocket();
              context.read<AuthService>().logout();
            },
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(child: pages[_index]),
          const PlayerBar(),
        ],
      ),
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
