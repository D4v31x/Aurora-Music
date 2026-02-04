![banner](https://github.com/user-attachments/assets/98b65d61-c230-4452-9997-cd10c93b0a22)

# Aurora Music
Aurora Music is an Android-focused Flutter music player that scans the local library, delivers rich playback controls, and adds intelligent enhancements like timed lyrics, smart recommendations, and dynamic UI theming based on album art.

## Project Overview
Aurora Music targets on-device playback with a modern, animated UI. The app integrates with Android media services for background playback and notifications, supports permissions-aware library scanning, and augments the experience with synced lyrics, metadata tools, and optional Spotify-powered artist imagery.

## Core Features (from code)
- Local library scanning and playback (MediaStore via `on_audio_query`)
- Background playback with media notification controls (`audio_service` + `just_audio`)
- Mini player + full Now Playing view with shuffle/repeat, gapless playback, playback speed, and sleep timer
- Synced lyrics fetching and caching (LRCLIB API) with full-screen lyrics view and sync offset controls
- Smart suggestions based on listening history (time-of-day and day-of-week patterns)
- Search across songs, albums, artists with fuzzy scoring
- Playlists, liked songs, and auto playlists (Most Played, Recently Added, Recently Played)
- Metadata editor (tag reading/writing) with auto-tag suggestions (Deezer/iTunes search)
- Artwork caching, blurred backgrounds, and dynamic color theming (Material You + palette extraction)
- Home screen layout customization (reorder/visibility of sections)
- Bluetooth output detection and status monitoring
- Batch download tool for lyrics and artwork with progress notifications
- Localization support via generated `AppLocalizations`
- Optional analytics/error tracking (`clarity_flutter` and custom error logging)

## Supported Android Versions
From [android/app/build.gradle](android/app/build.gradle):
- minSdk: 29 (Android 10)
- targetSdk: 35 (Android 15)
- compileSdk: 36

## Tech Stack & Key Dependencies
- Flutter + Dart (SDK >= 3.3.3)
- `just_audio` / `audio_service` / `audio_session`: playback engine, background audio, audio focus
- `on_audio_query`: local media library access (songs, albums, artists)
- `permission_handler`: runtime permission handling (media, notifications, Bluetooth, storage)
- `provider`: app-wide state management
- `shared_preferences`: settings and user preferences
- `dynamic_color` + `palette_generator`: dynamic theming and artwork-based palettes
- `http`: network calls for lyrics and metadata providers
- `flutter_dotenv`: `.env` support (Spotify API credentials)
- `spotify`: Spotify Web API (artist imagery)
- `audiotags`: read/write audio metadata tags
- `lottie`: animated splash screen
- `share_plus` / `url_launcher`: sharing and external links
- `device_info_plus` / `package_info_plus`: device and app version info

## Architecture & Folder Structure
The app follows a Provider + Services architecture with UI split into screens and reusable widgets.

- [lib/main.dart](lib/main.dart): app bootstrap, providers, theme/localization setup
- [lib/services](lib/services): business logic (audio, lyrics, caching, suggestions, metadata, bluetooth)
- [lib/providers](lib/providers): global state (theme, performance mode)
- [lib/screens](lib/screens): high-level UI flows (home, onboarding, player, library, settings)
- [lib/widgets](lib/widgets): reusable UI components (player, cards, dialogs, tabs)
- [lib/models](lib/models): data models (playlists, timed lyrics, utilities)
- [lib/localization](lib/localization) + [lib/l10n](lib/l10n): i18n setup
- [lib/constants](lib/constants): configuration and style constants
- [assets](assets): fonts, UI images, and animations

## State Management & Data Flow
Aurora Music uses `provider` for app-wide state and service orchestration. The app bootstraps core services in [`lib/main.dart`](lib/main.dart) and wires them into the widget tree via `MultiProvider`. Most data flows from user actions to service updates and then back to UI through `notifyListeners`.

### Core Providers & Services
- `AudioPlayerService` ([lib/shared/services/audio_player_service.dart](lib/shared/services/audio_player_service.dart)): playback queue, shuffle/repeat, play counts, and now-playing state.
- `ThemeProvider` ([lib/shared/providers/theme_provider.dart](lib/shared/providers/theme_provider.dart)): theme settings and Material You dynamic color integration.
- `BackgroundManagerService` ([lib/shared/services/background_manager_service.dart](lib/shared/services/background_manager_service.dart)): artwork palette extraction and cached gradients for UI backgrounds.
- `SleepTimerController` ([lib/shared/services/sleep_timer_controller.dart](lib/shared/services/sleep_timer_controller.dart)): sleep timer state.
- `HomeLayoutService` ([lib/shared/services/home_layout_service.dart](lib/shared/services/home_layout_service.dart)): persisted home section ordering/visibility.
- `LocaleProvider` ([lib/l10n/locale_provider.dart](lib/l10n/locale_provider.dart)): localization selection.

### Data Flow Highlights
1. **Playback:** UI action → `AudioPlayerService` → `AuroraAudioHandler` ([lib/shared/services/audio_handler.dart](lib/shared/services/audio_handler.dart)) → background notification + UI updates.
2. **Lyrics:** Track change → `LyricsService` ([lib/shared/services/lyrics_service.dart](lib/shared/services/lyrics_service.dart)) → API fetch + cache → synced lyrics UI.
3. **Artwork & Theming:** New artwork → `BackgroundManagerService` → palette extraction → cached gradients → background widgets update.
4. **Play Count & Suggestions:** `PlayCountService` ([lib/shared/services/play_count_service.dart](lib/shared/services/play_count_service.dart)) → save to disk → `SmartSuggestionsService` ([lib/shared/services/smart_suggestions_service.dart](lib/shared/services/smart_suggestions_service.dart)).
5. **Preferences:** Settings updates → `SharedPreferences` (used throughout services like `HomeLayoutService`, `ThemeProvider`, `AudioPlayerService`) → persisted state → UI rebuild.

## Setup & Build
### Prerequisites
- Flutter SDK (Dart >= 3.3.3)
- Android SDK with build tools 35.0.0

### Environment Variables (Optional)
Spotify artist imagery is enabled only if `.env` contains:
- `SPOTIFY_CLIENT_ID`
- `SPOTIFY_CLIENT_SECRET`

### Debug Build
1. Install dependencies: `flutter pub get`
2. Run on device/emulator: `flutter run`

### Release Build
1. `flutter pub get`
2. `flutter build apk --release`

Note: [android/app/build.gradle](android/app/build.gradle) currently uses debug signing for release and includes a TODO to add a proper signing configuration.

## Permissions & Why They’re Used
From [android/app/src/main/AndroidManifest.xml](android/app/src/main/AndroidManifest.xml):
- `INTERNET` / `ACCESS_NETWORK_STATE`: lyrics, metadata lookups, Spotify artist images, version checks
- `READ_MEDIA_AUDIO` / `READ_EXTERNAL_STORAGE`: read local audio library (Android 13+ / 12-)
- `WRITE_EXTERNAL_STORAGE` (maxSdk 29) / `MANAGE_EXTERNAL_STORAGE`: metadata editing and file updates
- `POST_NOTIFICATIONS`: playback and download status notifications
- `FOREGROUND_SERVICE` / `FOREGROUND_SERVICE_MEDIA_PLAYBACK`: background audio playback
- `WAKE_LOCK`: keep playback active when the screen is off
- `BLUETOOTH`, `BLUETOOTH_ADMIN`, `BLUETOOTH_CONNECT`, `BLUETOOTH_SCAN`: detect Bluetooth output devices

## Dependencies & External Services
The app relies on Flutter + Dart and several key packages. See [pubspec.yaml](pubspec.yaml) for the full list.

### Playback & Media
- `just_audio`, `audio_service`, `audio_session`: core playback engine and background audio handling.
- `on_audio_query`: MediaStore access for songs, albums, and artists.
- `audiotags`: read/write tags for metadata editing.

### UI & Theming
- `dynamic_color`, `palette_generator`: dynamic Material You colors + palette extraction from artwork.
- `animations`, `flutter_staggered_animations`, `lottie`: animations and motion.
- `miniplayer`, `blur`: mini player and blur effects.

### Data & Persistence
- `shared_preferences`: persisted settings and usage stats.
- `path_provider`: storage paths for caches.
- `http`: lyrics and metadata network calls.

### Integrations
- **LRCLIB**: timed lyrics API via `LyricsService`.
- **Spotify**: optional artist imagery using `spotify` and credentials in `.env` (see `SPOTIFY_CLIENT_ID`, `SPOTIFY_CLIENT_SECRET`).
- **Clarity**: error tracking via `clarity_flutter` and `ErrorTrackingService`.

## Screens & UI Components
Screens are organized under [`lib/features`](lib/features) and share reusable UI widgets from [`lib/shared/widgets`](lib/shared/widgets).

### Main Screens
- **Splash**: [lib/features/splash/splash_screen.dart](lib/features/splash/splash_screen.dart) – app startup + warmup.
- **Onboarding/Permissions**: [lib/features/onboarding](lib/features/onboarding) – permission requests and setup.
- **Home**: [lib/features/home/screens/home_screen.dart](lib/features/home/screens/home_screen.dart) – main hub with customizable sections.
- **Library**: [lib/features/library/screens](lib/features/library/screens) – albums, artists, tracks, folders, categories, detail views.
- **Player**: [lib/features/player/screens/now_playing.dart](lib/features/player/screens/now_playing.dart) – full player, queue, controls.
- **Fullscreen Artwork/Lyrics**: [lib/features/player/screens/fullscreen_artwork.dart](lib/features/player/screens/fullscreen_artwork.dart), [lib/features/player/screens/fullscreen_lyrics.dart](lib/features/player/screens/fullscreen_lyrics.dart).
- **Playlists**: [lib/features/playlists/screens](lib/features/playlists/screens) – playlists list and detail view.
- **Search**: [lib/features/search](lib/features/search) – search across songs, albums, and artists.
- **Settings**: [lib/features/settings/screens](lib/features/settings/screens) – theme, metadata, and home layout settings.

### Shared UI Components
- **ExpandingPlayer** ([lib/shared/widgets/expanding_player.dart](lib/shared/widgets/expanding_player.dart)): mini player that expands into the full player.
- **AppBackground** ([lib/shared/widgets/app_background.dart](lib/shared/widgets/app_background.dart)): blurred artwork background.
- **Optimized Tiles** ([lib/shared/widgets/optimized_list_tile.dart](lib/shared/widgets/optimized_list_tile.dart)): high-performance list tiles for songs and albums.
- **Common Screen Scaffolds** ([lib/shared/widgets/common_screen_scaffold.dart](lib/shared/widgets/common_screen_scaffold.dart)): shared layouts across screens.

## Best Practices & Notes
- **Parallel startup work:** [lib/main.dart](lib/main.dart) initializes dotenv, preferences, and services in parallel to reduce startup time.
- **Performance tuning:** [lib/core/constants/app_config.dart](lib/core/constants/app_config.dart) defines cache limits, debounce intervals, and preload values.
- **Debounced notifications:** `AudioPlayerService` batches state updates to reduce rebuilds and animation jitter.
- **Error tracking:** `ErrorTrackingService` captures errors globally and sends them to Clarity.
- **Localization:** app strings are generated in [lib/l10n](lib/l10n) via Flutter’s localization tooling.

## License
Aurora Music is licensed under GNU GPLv3. See [LICENSE](LICENSE).

