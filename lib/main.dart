import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import 'services/api_service.dart';
import 'services/audio_player_service.dart';
import 'services/auth_service.dart';
import 'services/friends_service.dart';
import 'services/library_service.dart';
import 'services/lyrics_service.dart';
import 'services/search_query_service.dart';
import 'services/youtube_player_service.dart';
import 'services/youtube_service.dart';
import 'theme/m_theme.dart';
import 'ui/app_shell.dart';
import 'ui/auth/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();
    await windowManager.waitUntilReadyToShow(
      const WindowOptions(
        size: Size(1280, 820),
        minimumSize: Size(900, 600),
        center: true,
        title: 'M MUSIC',
        backgroundColor: Color(0xFF080808),
      ),
      () async {
        await windowManager.setAsFrameless();
        await windowManager.setResizable(true);
        await windowManager.show();
        await windowManager.focus();
      },
    );
  }

  runApp(const MezoxApp());
}

class MezoxApp extends StatelessWidget {
  const MezoxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ApiService()),
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => LibraryService()..load()),
        ChangeNotifierProxyProvider<LibraryService, YouTubeService>(
          create: (_) => YouTubeService(),
          update: (_, library, yt) => yt!..setApiKey(library.youtubeApiKey),
        ),
        ChangeNotifierProvider(create: (_) => LyricsService()),
        ChangeNotifierProvider(create: (_) => SearchQueryService()),
        ChangeNotifierProxyProvider<ApiService, FriendsService>(
          create: (_) => FriendsService(),
          update: (_, api, friends) => friends!..attachApi(api),
        ),
        ChangeNotifierProvider(create: (_) => YouTubePlayerService()),
        ChangeNotifierProxyProvider5<AuthService, LibraryService, FriendsService,
            LyricsService, YouTubePlayerService, MezoxPlayerController>(
          create: (context) => MezoxPlayerController(
                context.read<YouTubePlayerService>(),
              )
                ..attach()
                ..bind(
                  auth: context.read<AuthService>(),
                  library: context.read<LibraryService>(),
                  friends: context.read<FriendsService>(),
                  lyrics: context.read<LyricsService>(),
                ),
          update: (_, auth, library, friends, lyrics, player, controller) =>
              controller!
                ..bind(
                  auth: auth,
                  library: library,
                  friends: friends,
                  lyrics: lyrics,
                ),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'M MUSIC',
        theme: MTheme.dark,
        home: Consumer<AuthService>(
          builder: (context, auth, _) =>
              auth.isLoggedIn ? const AppShell() : const LoginScreen(),
        ),
      ),
    );
  }
}
