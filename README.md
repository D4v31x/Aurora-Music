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

## Known Limitations (based on code)
- Lyrics are fetched from LRCLIB; if synced lyrics aren’t available for a track, no lyrics are shown.
- Spotify artist images are disabled unless `.env` contains valid Spotify credentials.
- Local library remains empty until media permissions are granted.
- Metadata editing on Android 11+ requires `MANAGE_EXTERNAL_STORAGE` permission.
- Search results lack a song options menu (see TODO in search tab).

## Roadmap / Future Improvements (from TODOs)
- Add song options menu in search results (TODO in search tab)
- Add proper release signing configuration in Gradle
- Review and finalize application ID and release settings in Gradle

## License
Aurora Music is licensed under GNU GPLv3. See [LICENSE](LICENSE).
