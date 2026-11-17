# MEZOX MUSIC — Client

YouTube-only music player for Android APK and Windows EXE. No ads in playback, name-only sign up, and Listen Together over the internet **without owning a server**.

## What changed

The app no longer depends on a MEZOX backend. All multiplayer features now run over a free public MQTT relay (`broker.hivemq.com` by default):

- Sign up with a name only — the profile is stored on the device.
- Add friends by their username.
- Friend request → accept.
- Listen Together: request → accept → synced playback → Disconnect back to solo.
- Lyrics are fetched directly from LRCLIB / lyrics.ovh after 10 seconds — no AI key.
- Music comes from YouTube audio streams through `youtube_explode_dart`.

No Render, Fly.io, Cloud Run, domain, port forwarding, or public IP is needed.

## Relay

The relay can be changed from the sign-up screen (tap the `Relay:` line) or at build time:

```bash
flutter build apk --release --dart-define=MEZOX_API=broker.hivemq.com
```

Any public MQTT-over-WebSocket broker on port `8884` works. The default is HiveMQ's public broker, which needs no account.

## Build locally

```bash
flutter pub get
flutter build apk --release
flutter build windows --release
```

## Build on GitHub

Use the **Actions** tabs:

- `Build Android APK` → `mezox-music-app/actions/workflows/build-android.yml`
- `Build Windows EXE` → `mezox-music-app/actions/workflows/build-windows.yml`

Both workflows are `workflow_dispatch` with an optional relay host input; the default is `broker.hivemq.com`. Artifacts are attached to the successful run.

## Notes

- Both devices need internet access and must use the same relay host.
- Usernames are public on the relay; pick a name your friends will recognise.
- The server repo (`mezox-music-server`) is kept for optional self-hosted use, but the app does not require it.
