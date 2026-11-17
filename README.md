# MEZOX MUSIC (Client)

Flutter app — **Android APK** and **Windows EXE** from one codebase (YouTube-only, no in-player ads).

## Features
- Search & play any song on YouTube via direct audio stream (`youtube_explode_dart` + `just_audio`).
- Repeat one / repeat all.
- Volume boost 100%–300% (Android loudness enhancer; Windows follows system/mixer headroom).
- Favourites (♥) and albums (create/add/remove/delete).
- Friends by username: invite/accept + listen-together real-time sync (Socket.IO).
- Song lyrics appear ~10s after playback starts (fetched from lyrics sources via server, no AI key required).
- Sign up: write your name only; the app creates/reuses an account on the server. Account name is used to add friends and listen together over the internet. No password or external login.

## Prepare project (if platform folders missing)
```bash
cd mezox_app
# If android/ios/windows folders are missing, generate Flutter scaffolding:
flutter create --project-name mezox_music --org com.mezox .
# Then keep this repo's lib/, pubspec.yaml, and android/app/src/main/AndroidManifest.xml overrides.
flutter pub get
```

## Run & build
```bash
# Android APK
flutter build apk --release --dart-define=MEZOX_API=https://your-server-host
# -> build/app/outputs/flutter-apk/app-release.apk

# Windows EXE (on Windows with VS 2022 "Desktop development with C++")
flutter config --enable-windows-desktop
flutter build windows --release --dart-define=MEZOX_API=https://your-server-host
# -> build/windows/x64/runner/Release/ (ship the entire folder)
```

## Branding
- Android: `applicationId "com.mezox.music"` in `android/app/build.gradle`, label/icon in manifest & mipmaps.
- Windows: set window title `L"MEZOX MUSIC"` in `windows/runner/main.cpp`, ProductName/FileDescription in `Runner.rc`, icon in `windows/runner/resources/app_icon.ico`.
