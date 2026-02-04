# Aurora Music Documentation

## App Overview
Aurora Music is an Android-focused Flutter music player that scans the device library, provides rich playback controls, and adds enhancements such as synced lyrics, smart recommendations, and dynamic UI theming based on album artwork. It focuses on on-device playback with background audio, notification controls, and a customizable home experience.

### Main Features
- Local library scanning (MediaStore via `on_audio_query`).
- Background playback with notification controls (`audio_service`, `just_audio`).
- Full player + mini player, shuffle/repeat, playback speed, and sleep timer.
- Synced lyrics (LRCLIB API) with full-screen lyrics view.
- Smart recommendations based on listening history.
- Search across songs, albums, and artists.
- Playlists, liked songs, and auto playlists (Most Played, Recently Added, Recently Played).
- Metadata editor with tag read/write and auto-tag suggestions.
- Dynamic theming via Material You and palette extraction.
- Bluetooth output monitoring and download progress notifications.

## Architecture
Aurora Music follows a feature-first Flutter architecture with shared services and providers.

### Folder Structure (lib/)
```
lib/
├── main.dart                    # App entry point, providers, initialization
├── core/constants/              # Configuration + style constants
├── features/                    # Feature modules (home, player, library, etc.)
├── shared/                      # Shared services, models, providers, widgets
└── l10n/                         # Localization and generated strings
```

### State Management & Patterns
- **Provider pattern** for app-wide state (`provider` package).
- **Service layer** (shared/services) encapsulates business logic and integration.
- **Feature-first UI** with screens and widgets grouped per feature.
- **Debounced updates** in services to reduce rebuilds and improve performance.

## Dependencies & Services
See [pubspec.yaml](../pubspec.yaml) for the complete list.

### Playback & Media
- `just_audio`, `audio_service`, `audio_session`: audio playback and background handling.
- `on_audio_query`: MediaStore access for device library.
- `audiotags`: metadata read/write.

### UI & Theming
- `dynamic_color`, `palette_generator`: Material You + artwork palette extraction.
- `miniplayer`, `blur`, `animations`, `flutter_staggered_animations`, `lottie`: UI effects.

### Data & Storage
- `shared_preferences`: settings persistence.
- `path_provider`: cache and file paths.
- `http`: lyrics and metadata API calls.

### Integrations & APIs
- **LRCLIB**: synced lyrics (see `LyricsService`).
- **Spotify**: optional artist imagery via `.env` credentials (keep `.env` untracked via `.gitignore` to avoid leaking credentials).
- **Clarity**: error tracking via `clarity_flutter`.

## Screens & UI Components
Screens live in `lib/features/*/screens`.

### Main Screens
- **Splash**: `features/splash/splash_screen.dart` – app warmup.
- **Onboarding/Permissions**: `features/onboarding` – permission flow.
- **Home**: `features/home/screens/home_screen.dart` – main hub and tabs.
- **Library**: `features/library/screens/*` – albums, artists, tracks, folders.
- **Player**: `features/player/screens/now_playing.dart` – full player UI.
- **Fullscreen Artwork/Lyrics**: `features/player/screens/fullscreen_*`.
- **Playlists**: `features/playlists/screens/*` – playlist list/detail.
- **Search**: `features/search` – fuzzy search across library.
- **Settings**: `features/settings/screens/*` – app preferences.

### Shared UI Components
- **ExpandingPlayer**: `shared/widgets/expanding_player.dart` – mini-to-full player.
- **AppBackground**: `shared/widgets/app_background.dart` – blurred artwork background.
- **OptimizedTiles**: `shared/widgets/optimized_list_tile.dart` – list tiles for media.
- **CommonScreenScaffold**: `shared/widgets/common_screen_scaffold.dart`.

## Data Flow
1. **Playback Flow**
   - UI → `AudioPlayerService` → `AuroraAudioHandler` → notification + UI updates.
2. **Lyrics Flow**
   - Track change → `LyricsService` → API fetch + cache → lyrics UI.
3. **Artwork/Theming Flow**
   - Artwork update → `BackgroundManagerService` → palette extraction → UI backgrounds.
4. **Play Count & Suggestions**
   - Track ends → `PlayCountService` → persistence → `SmartSuggestionsService`.
5. **Settings**
   - Settings updates → `SharedPreferences` → app state rebuild.

## Permissions & Features
From `android/app/src/main/AndroidManifest.xml`:
- **INTERNET / ACCESS_NETWORK_STATE**: lyrics, metadata, Spotify images.
- **READ_MEDIA_AUDIO / READ_EXTERNAL_STORAGE**: local music library access.
- **WRITE_EXTERNAL_STORAGE / MANAGE_EXTERNAL_STORAGE**: metadata editing. `MANAGE_EXTERNAL_STORAGE` is used for broad file access required by tag editing on modern Android; it may require additional Play Store review.
- **POST_NOTIFICATIONS**: playback and download notifications.
- **FOREGROUND_SERVICE / MEDIA_PLAYBACK**: background playback.
- **WAKE_LOCK**: keep playback alive when screen is off.
- **BLUETOOTH / BLUETOOTH_CONNECT / BLUETOOTH_SCAN**: Bluetooth output detection.

## Best Practices & Notes
- **Parallel startup initialization** in `main.dart` to reduce load time.
- **Performance tuning** via `core/constants/app_config.dart`.
- **Debounced updates** in services to reduce UI rebuild churn.
- **Error tracking** with `ErrorTrackingService` and Clarity.
- **Localization** via generated `AppLocalizations` in `lib/l10n`.
