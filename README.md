# Aurora Music

A modern, beautiful local music player for Android (and iOS), built with Flutter. Aurora Music focuses on a polished Material You experience, buttery-smooth performance across low-to-high end devices, synced lyrics, and a rich set of "smart" listening features — all while playing music straight from your device's local library.

**Current version:** 1.4.5+27

---

## What it does

Aurora Music scans and indexes the audio files already on your phone (via `on_audio_query`) and gives you a fast, gesture-friendly way to browse, organize, and play them — with a fully custom now-playing experience, background playback, lock-screen/notification controls, synced lyrics, an equalizer, playlists, and detailed listening statistics.

---

## Core Features

### Playback
- Local audio playback powered by `just_audio` + `audio_service` (background playback, lock screen & notification controls, media-button/Bluetooth support).
- Gapless queue management: play, pause, skip, shuffle, repeat (off/one/all), and queue reordering.
- Sleep timer with configurable duration and fade-out.
- Custom equalizer with presets and manual band control.
- ReplayGain-aware volume normalization (reads embedded ReplayGain tags).
- Bluetooth-aware playback handling (auto pause/resume on device connect/disconnect).
- Cross-fade / smooth track transitions and fire-and-forget playback calls tuned to avoid audio-interrupt glitches.

### Now Playing
- Custom "Now Playing" screen with animated, palette-driven backgrounds generated from the current track's artwork (via `palette_generator`).
- Expanding mini-player that morphs into the full now-playing screen with Hero animations.
- Fullscreen artwork view and a fullscreen lyrics view.
- Music visualizer screen.
- Synced (time-stamped) lyrics with an in-app lyrics editor, plus lyrics translation support.

### Library
- Browse by Tracks, Albums, Artists, and Folders, with dedicated detail screens for each.
- Artist aggregation/separation tools to clean up multi-artist tag strings (e.g. "Artist A feat. Artist B").
- Folder filtering to include/exclude specific directories from your library.
- Metadata viewer/editor for track details (title, artist, album, duration, bitrate, etc.).
- Cached artwork with an LRU artwork cache service for fast scrolling.

### Playlists
- Create, edit, and manage custom playlists.
- Import/export playlists via M3U file support.
- "Liked songs" as a first-class favorites list.

### Search
- Fast in-app search across tracks, albums, artists, and playlists.

### Smart Suggestions & Listening Insights
- Play-count tracking and "most played" / "recently played" / "recently added" smart lists.
- Listening Insights screen: all-time stats — top tracks, artists, genres, skip counts, listening-time-by-hour/weekday, most active listening periods, total listening time.
- Listening Recap screen: a periodic (7/30-day) wrapped-style summary of recent listening activity.
- Smart suggestions engine that learns from play/skip behavior.

### Personalization & Theming
- Material You / dynamic color support (`dynamic_color`), following the system wallpaper palette on supported devices.
- Custom light/dark theme system with a dedicated `ThemeProvider`.
- Adaptive performance mode: automatically detects device tier (low/medium/high) and scales down animations/effects (e.g. disables heavy blur/mesh gradients) on weaker hardware to keep the UI smooth.
- Animated mesh-gradient backgrounds and glassmorphic UI elements.
- Customizable home screen layout (choose which sections/cards appear).
- Home-screen widget support (`home_widget`) for quick access from the Android launcher.

### Onboarding & Settings
- First-run onboarding flow (permissions, initial preferences, language selection).
- Extensive settings: appearance, playback, equalizer, home layout, folder filters, artist separator rules, insights, storage/cache management, and about/app-info screens.
- Storage settings with cache management and batch download utilities.

### Internationalization
- Fully localized UI (English and Czech shipped; community-translatable via Crowdin, with a simple ARB-file-based system for adding new languages).

### Reliability & Diagnostics
- Crash reporting and performance monitoring via Sentry and Firebase Crashlytics/Analytics/Performance.
- In-app update checks (`in_app_update`, `upgrader`) and version/changelog awareness.
- User feedback flow (email-based feedback + periodic feedback reminders) and a donation/support entry point.
- Centralized logging and error-tracking services.

---

## Tech Stack

- **Framework:** Flutter (Dart SDK ^3.3.3)
- **State management:** Provider (`ChangeNotifier`, `Selector`, `ValueNotifier`) for high-frequency state like playback position/song changes.
- **Audio:** `just_audio`, `audio_service`, `audio_session`, `audiotags` (tag reading), custom ReplayGain reader.
- **Media library access:** `on_audio_query`, `sqflite_android`.
- **Visuals:** `palette_generator` (artwork-driven color palettes), `mesh` (animated gradients), `lottie` (splash animation), `flutter_staggered_animations`, `mini_music_visualizer`, `dynamic_color`.
- **Platform integration:** `home_widget`, `device_info_plus`, `connectivity_plus`, `permission_handler`, `share_plus`, `url_launcher`, `file_picker`.
- **Diagnostics/telemetry:** `sentry_flutter`, `firebase_core`/`crashlytics`/`analytics`/`performance`.
- **Updates:** `in_app_update`, `upgrader`, `package_info_plus`, `version`/`pub_semver`.
- **Persistence:** `shared_preferences`, `path_provider`.

---

## Project Structure

```
lib/
  core/               # Constants, theming primitives
  features/
    home/              # Home screen, listening insights & recap
    library/            # Tracks, albums, artists, folders
    onboarding/          # First-run setup flow
    player/              # Now Playing, lyrics, visualizer, fullscreen artwork
    playlists/           # Playlist management
    search/              # In-app search
    settings/             # All settings & preferences screens
    splash/               # Splash screen
  l10n/               # Localization (ARB files + generated AppLocalizations)
  shared/
    mixins/            # Shared widget mixins (e.g. artwork/dominant color)
    models/            # Data models
    providers/          # ThemeProvider, PerformanceModeProvider
    services/           # Audio engine, caching, metadata, insights, etc.
    utils/             # Helpers
    widgets/            # Shared UI (mini/expanding player, glassmorphic UI, etc.)
```

---

## Platforms

- **Android** — primary target (Material You dynamic color, home-screen widget, Spotify App Remote AAR present in `android/spotify-app-remote`).
- **iOS** — supported via Flutter's iOS target (`ios/Runner`), with a custom `AudioSessionHandler.swift` for audio session management.

## Building & Running

```bash
flutter pub get
flutter run --release
```

