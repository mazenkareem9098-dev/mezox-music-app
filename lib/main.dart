import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'services/api_service.dart';
import 'services/audio_player_service.dart';
import 'services/auth_service.dart';
import 'services/friends_service.dart';
import 'services/library_service.dart';
import 'services/lyrics_service.dart';
import 'services/youtube_service.dart';
import 'ui/app_shell.dart';
import 'ui/auth/login_screen.dart';

late MezoxAudioHandler audioHandler;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  audioHandler = await AudioService.init(
    builder: () => MezoxAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.mezox.music.channel.audio',
      androidNotificationChannelName: 'MEZOX MUSIC',
      androidNotificationOngoing: true,
    ),
  );
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
        ChangeNotifierProvider(create: (_) => YouTubeService()),
        ChangeNotifierProvider(create: (_) => LibraryService()..load()),
        ChangeNotifierProvider(create: (_) => LyricsService()),
        ChangeNotifierProxyProvider<ApiService, FriendsService>(
          create: (_) => FriendsService(),
          update: (_, api, friends) => friends!..attachApi(api),
        ),
        ChangeNotifierProxyProvider5<AuthService, YouTubeService, LibraryService,
            FriendsService, LyricsService, MezoxPlayerController>(
          create: (_) => MezoxPlayerController(audioHandler),
          update: (_, auth, yt, lib, friends, lyrics, ctrl) => ctrl!
            ..bind(auth: auth, yt: yt, library: lib, friends: friends, lyrics: lyrics),
        ),
      ],
      child: MaterialApp(
        title: 'MEZOX MUSIC',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF050505),
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFFE50914),
            secondary: Color(0xFFFF2D55),
            surface: Color(0xFF141414),
            error: Color(0xFFFF3B30),
          ),
          useMaterial3: true,
        ),
        home: Consumer<AuthService>(
          builder: (_, auth, __) =>
              auth.isLoggedIn ? const AppShell() : const LoginScreen(),
        ),
      ),
    );
  }
}
