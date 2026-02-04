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
Aurora Music follows a feature-first Flutter architecture with shared services and providers. The codebase centers around a service layer that owns business logic (playback, caching, metadata, suggestions) and a UI layer that is split into feature modules.

### Folder Structure (lib/)
```
lib/
├── main.dart                    # App entry point, providers, initialization
├── core/constants/              # Configuration + style constants
├── features/                    # Feature modules (home, player, library, etc.)
├── shared/                      # Shared services, models, providers, widgets
└── l10n/                         # Localization and generated strings
```

### Core Services (shared/services)
The following services are used across the app:
- **AudioPlayerService**: playback queue, shuffle/repeat, play counts, and now-playing state.
- **AuroraAudioHandler**: connects the player to Android background notification controls.
- **AudioSettingsService**: stores playback-related preferences (speed, pitch, etc.).
- **ArtworkCacheService**: caches album/artist artwork for lists and backgrounds.
- **BackgroundManagerService**: palette extraction + mesh gradient colors for UI backgrounds.
- **PlayCountService**: tracks plays for songs/albums/artists/playlists.
- **SmartSuggestionsService**: computes listening recommendations.
- **LyricsService**: fetches and caches synced lyrics from LRCLIB.
- **MetadataService**: queries Deezer/iTunes for tag suggestions + cover art.
- **PlaylistPersistenceService**: saves user playlists.
- **LikedSongsService**: liked songs playlist management.
- **HomeLayoutService**: persistent home section ordering.
- **ArtistSeparatorService**: artist string parsing and separators.
- **BluetoothService**: Bluetooth output detection.
- **BatchDownloadService**: bulk lyrics/artwork downloads.
- **NotificationManager**: playback/download notifications.
- **ErrorTrackingService**: error reporting with Clarity.
- **ShaderWarmupService**: warm up shaders on startup.

### State Management & Patterns
- **Provider pattern** for app-wide state (`provider` package).
- **Service layer** (shared/services) encapsulates business logic and integration.
- **Feature-first UI** with screens and widgets grouped per feature.
- **Debounced updates** in services to reduce rebuilds and improve performance.

## Dependencies & Services
See [pubspec.yaml](../pubspec.yaml) for the complete list.

### Full Package List (with usage)
- **just_audio**: playback engine in `audio_player_service.dart` and `fullscreen_artwork.dart`.
- **audio_service**: background playback + notifications in `audio_handler.dart`.
- **audio_session**: Android audio focus setup in player init.
- **on_audio_query**: MediaStore queries in library screens, artwork cache.
- **permission_handler**: permission flow in onboarding + metadata editing.
- **http**: lyrics and metadata API calls in `lyrics_service.dart` + `metadata_service.dart`.
- **shared_preferences**: persisted settings, onboarding, layout preferences.
- **provider**: global state management across all features.
- **path_provider**: storage paths for cache, downloads.
- **package_info_plus**: app version details (about/changelog dialogs).
- **url_launcher**: external links (donation, about).
- **version** + **pub_semver**: version comparisons in `version_service.dart`.
- **share_plus**: sharing songs/playlists from player UI.
- **blur**: glassmorphic containers, background blur.
- **palette_generator**: dominant color extraction for album/artist detail screens.
- **spotify**: optional artist imagery and metadata via API.
- **flutter_dotenv**: load `.env` credentials (keep untracked).
- **html**: parse metadata/lyrics HTML when needed.
- **crypto**: hashing for caching keys.
- **lottie**: splash animation.
- **mesh**: mesh gradient backgrounds in UI.
- **dynamic_color**: Material You dynamic theme.
- **miniplayer**: collapsible mini player.
- **audiotags**: read/write metadata tags in metadata editor.
- **clarity_flutter**: error tracking.
- **flutter_hooks**: onboarding screen hooks.
- **flutter_staggered_animations**: list/grid animations in library.
- **animations**: transitions in onboarding.
- **device_info_plus**: device capability checks in performance service.
- **intl**: localization formatting.

## Screens & UI Components
Screens live in `lib/features/*/screens` and onboarding pages under `lib/features/onboarding/pages`.

### Main Screens (Detailed)
- **SplashScreen** (`features/splash/splash_screen.dart`): Launch animation (Lottie), shader warmup, and bootstrap handoff to onboarding/home.
- **OnboardingScreen** (`features/onboarding/screens/onboarding_screen.dart`): 10-step flow with animated transitions and skip-to-permissions shortcut.
  - **WelcomePage**: introduction and “continue”.
  - **LanguageSelectionPage**: localization selection stored in preferences.
  - **BetaWelcomePage**: beta messaging and app expectations.
  - **AppInfoPage**: feature overview and app notes.
  - **PermissionsPage**: requests storage/media/Bluetooth permissions.
  - **ThemeSelectionPage**: theme preferences and dynamic colors.
  - **InternetUsagePage**: explains network usage for lyrics/metadata.
  - **AssetDownloadPage**: optional asset download for improved experience.
  - **DonationPage**: support prompt and external links.
  - **CompletionPage**: final confirmation + transition to Home.
- **HomeScreen** (`features/home/screens/home_screen.dart`): Tabbed hub (Home, Library, Search, Settings) with Bluetooth monitoring, notifications, pull-to-refresh, and smart suggestions.
- **TracksScreen** (`features/library/screens/tracks_screen.dart`): paginated song list with search, optional playlist editing, and optimized tiles.
- **AlbumsScreen** (`features/library/screens/albums_screen.dart`): grid/list albums, sort options, and album search.
- **AlbumDetailScreen** (`features/library/screens/album_detail_screen.dart`): album overview, dominant color extraction, lazy song list, related albums.
- **ArtistsScreen** (`features/library/screens/artists_screen.dart`): artist list with search/sort, grid/list toggle, cached artist images.
- **ArtistDetailsScreen** (`features/library/screens/artist_detail_screen.dart`): artist stats, songs/albums tabs, dominant color from artist image.
- **FoldersScreen** (`features/library/screens/folders_screen.dart`): filesystem folder browser with animation.
- **FolderDetailScreen** (`features/library/screens/folder_detail_screen.dart`): songs filtered by folder with lazy loading.
- **NowPlayingScreen** (`features/player/screens/now_playing.dart`): main player view with artwork, metadata, lyrics preview, and playback controls.
- **FullscreenArtworkScreen** (`features/player/screens/fullscreen_artwork.dart`): edge-to-edge artwork with auto-hiding controls and gesture toggles.
- **FullscreenLyricsScreen** (`features/player/screens/fullscreen_lyrics.dart`): synced lyrics view with font-size + sync-offset adjustments.
- **PlaylistsScreen** (`features/playlists/screens/playlists_screen.dart`): liked songs, auto playlists, and user playlist management.
- **PlaylistDetailScreen** (`features/playlists/screens/playlist_detail_screen.dart`): playlist header, actions, lazy song list, edit/delete.
- **HomeLayoutSettingsScreen** (`features/settings/screens/home_layout_settings.dart`): reorder home sections and toggle visibility.
- **MetadataDetailScreen** (`features/settings/screens/metadata_detail_screen.dart`): tag editing, artwork replacement, quality stats.
- **ArtistSeparatorSettingsScreen** (`features/settings/screens/artist_separator_settings.dart`): configure artist separators and exclusions.

### Shared UI Components (Highlights)
- **ExpandingPlayer**: `shared/widgets/expanding_player.dart` – mini-to-full player.
- **AppBackground**: `shared/widgets/app_background.dart` – blurred artwork background.
- **OptimizedTiles**: `shared/widgets/optimized_tiles.dart` – list tiles for media.
- **CommonScreenScaffold**: `shared/widgets/common_screen_scaffold.dart`.
- **GlassmorphicCard/Container/Dialog**: frosted UI components.
- **ShimmerLoading**: skeleton loading states.
- **AnimatedProgressLine**: playback progress UI.

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
