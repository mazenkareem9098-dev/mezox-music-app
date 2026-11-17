# M MUSIC

**Listen. Enjoy. Repeat.**

A red & black glassmorphism music streaming client for Windows and Android, built with Flutter and powered by YouTube.

## Features

- Custom frameless desktop title bar with working minimize / maximize / close.
- Fixed glass sidebar: Home, Explore, Search, Library, Liked Songs, Playlists, Artists, Albums, Podcasts, History, Settings, Premium, About.
- Cinematic home dashboard with real YouTube-backed sections: Made For You, Trending Now, Recently Played, Recommended, Popular Artists, New Releases.
- Live search suggestions and category filters for songs, videos, artists, playlists and albums.
- Official YouTube IFrame Player API playback — no direct stream extraction, no ad removal.
- Now Playing glass panel with visualizer, lyrics, like, playlist add and reorderable queue.
- Permanent bottom player with shuffle, previous, play/pause, next, repeat, progress, volume, mini player, full screen and queue.
- Full-screen immersive player.
- Local playlists, favourites, history, search history and preferences via SharedPreferences.
- Listen Together over a public MQTT relay (name-only sign up, no private server).
- Keyboard shortcuts: Space, ←, →, M, F, Esc.

## Build

Android:

```bash
flutter pub get
flutter build apk --release --dart-define=MEZOX_API=broker.hivemq.com
```

Windows:

```bash
flutter config --enable-windows-desktop
flutter pub get
flutter build windows --release --dart-define=MEZOX_API=broker.hivemq.com
```

GitHub Actions builds both platforms on every push to `main`.

## YouTube Data API (optional)

Open Settings and enter a YouTube Data API v3 key for higher-quality metadata and durations. Without a key the app uses public metadata frontends. Playback always uses YouTube's official IFrame player.
