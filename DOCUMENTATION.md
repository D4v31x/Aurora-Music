# Aurora Music - Complete Documentation

## Table of Contents

1. [App Overview](#app-overview)
2. [Architecture](#architecture)
3. [Dependencies & Services](#dependencies--services)
4. [Screens & UI Components](#screens--ui-components)
5. [Data Flow](#data-flow)
6. [Permissions & Features](#permissions--features)
7. [Best Practices & Notes](#best-practices--notes)
8. [Routing & Navigation Logic](#routing--navigation-logic)
9. [Error States & Edge Cases](#error-states--edge-cases)
10. [Persistence & Storage Schema](#persistence--storage-schema)
11. [Lifecycle & Background Behavior](#lifecycle--background-behavior)
12. [Accessibility & UX Decisions](#accessibility--ux-decisions)
13. [Release & Distribution Strategy](#release--distribution-strategy)
14. [Non-Goals](#non-goals)

---

## App Overview

### What is Aurora Music?

Aurora Music is a modern, beautiful music player for Android built with Flutter. It features Material You design, synced lyrics support, and intelligent playback features. The app focuses on local audio playback with a polished, animated user interface.

### Core Purpose

The primary purpose of Aurora Music is to provide a premium music listening experience for locally stored audio files on Android devices. Unlike streaming apps, Aurora Music focuses on:
- Local library management and playback
- Enhanced user experience through visual and functional polish
- Intelligent features that learn from listening patterns

### Main Features

| Feature | Description |
|---------|-------------|
| **Local Library Scanning** | Scans device storage for audio files using Android MediaStore via `on_audio_query` |
| **Background Playback** | Full background audio support with media notification controls using `audio_service` + `just_audio` |
| **Mini Player + Full Now Playing** | Expandable player UI with shuffle, repeat, gapless playback, speed control, and sleep timer |
| **Synced Lyrics** | Fetches and caches timed lyrics from LRCLIB API with sync offset controls and fullscreen view |
| **Smart Suggestions** | Personalized recommendations based on time-of-day and day-of-week listening patterns |
| **Search** | Fuzzy search across songs, albums, and artists with intelligent scoring |
| **Playlists** | User-created playlists, liked songs, and auto-playlists (Most Played, Recently Added, Recently Played) |
| **Metadata Editor** | Read and write audio file tags with auto-tag suggestions from Deezer/iTunes |
| **Dynamic Theming** | Material You color extraction and artwork-based palette generation |
| **Home Customization** | Reorderable and hideable home screen sections |
| **Bluetooth Detection** | Monitors Bluetooth audio output device connections |
| **Batch Downloads** | Tool for downloading lyrics and artwork for entire library with progress notifications |
| **Localization** | Multi-language support via Flutter's localization system |
| **Analytics** | Optional error tracking and analytics via `clarity_flutter` |

### Supported Android Versions

- **Minimum SDK**: 29 (Android 10)
- **Target SDK**: 35 (Android 15)
- **Compile SDK**: 36

---

## Architecture

### Design Pattern

Aurora Music follows a **Provider + Services architecture** with clear separation between:
- **UI Layer**: Screens and reusable widgets
- **State Management**: Provider-based global state
- **Business Logic**: Singleton services
- **Data Layer**: Models and local persistence

### Folder Structure

```
lib/
├── main.dart                      # App entry point, providers setup, theme initialization
├── core/
│   └── constants/
│       ├── app_config.dart        # App-wide configuration values
│       ├── animation_constants.dart  # Animation timing constants
│       └── font_constants.dart    # Font family definitions
├── features/
│   ├── features.dart              # Feature barrel exports
│   ├── home/
│   │   ├── home.dart              # Home feature exports
│   │   ├── home_feature.dart      # Feature definition
│   │   ├── screens/
│   │   │   └── home_screen.dart   # Main home screen with tabs
│   │   └── widgets/
│   │       ├── home_tab.dart      # Home tab content
│   │       ├── library_tab.dart   # Library browser tab
│   │       ├── for_you_section.dart     # Smart suggestions section
│   │       ├── most_played_section.dart # Most played tracks section
│   │       ├── recently_added_section.dart # Recent additions
│   │       ├── recently_played_section.dart # Recent plays
│   │       ├── suggested_artists_section.dart # Artist suggestions
│   │       ├── music_stats_card.dart    # Statistics display
│   │       └── listening_history_card.dart # History visualization
│   ├── library/
│   │   ├── library.dart
│   │   └── screens/
│   │       ├── albums_screen.dart       # Album grid view
│   │       ├── album_detail_screen.dart # Single album view
│   │       ├── artists_screen.dart      # Artists grid view
│   │       ├── artist_detail_screen.dart # Single artist view
│   │       ├── tracks_screen.dart       # All tracks list
│   │       ├── folders_screen.dart      # Folder browser
│   │       └── folder_detail_screen.dart # Folder contents
│   ├── player/
│   │   ├── player.dart
│   │   ├── controllers/
│   │   │   └── now_playing_controller.dart # Player state controller
│   │   ├── screens/
│   │   │   ├── now_playing.dart         # Full now playing screen
│   │   │   ├── fullscreen_lyrics.dart   # Immersive lyrics view
│   │   │   └── fullscreen_artwork.dart  # Full artwork view
│   │   └── widgets/
│   │       ├── player_controls.dart     # Play/pause/skip buttons
│   │       ├── player_progress_bar.dart # Seek bar
│   │       ├── lyrics_section.dart      # Lyrics display widget
│   │       ├── album_section.dart       # Album info in player
│   │       ├── artist_section.dart      # Artist info in player
│   │       ├── song_like_button.dart    # Like/unlike button
│   │       ├── player_menu.dart         # More options menu
│   │       ├── player_dialogs.dart      # Player-related dialogs
│   │       └── sleep_timer_widgets.dart # Sleep timer UI
│   ├── playlists/
│   │   └── screens/
│   │       ├── playlists_screen.dart    # Playlist list
│   │       └── playlist_detail_screen.dart # Playlist contents
│   ├── search/
│   │   └── widgets/
│   │       └── search_tab.dart          # Search interface
│   ├── settings/
│   │   ├── screens/
│   │   │   ├── home_layout_settings.dart    # Home customization
│   │   │   ├── artist_separator_settings.dart # Artist name parsing
│   │   │   └── metadata_detail_screen.dart  # Metadata editor
│   │   └── widgets/
│   │       └── settings_tab.dart        # Settings panel
│   ├── onboarding/
│   │   ├── screens/
│   │   │   └── onboarding_screen.dart   # Onboarding flow
│   │   └── pages/
│   │       ├── welcome_page.dart        # Welcome screen
│   │       ├── permissions_page.dart    # Permission request
│   │       ├── language_selection_page.dart # Language picker
│   │       ├── theme_selection_page.dart    # Theme selection
│   │       ├── asset_download_page.dart     # Initial downloads
│   │       ├── internet_usage_page.dart     # Network usage info
│   │       ├── donation_page.dart           # Support the developer
│   │       ├── app_info_page.dart           # About the app
│   │       ├── beta_welcome_page.dart       # Beta notice
│   │       └── completion_page.dart         # Setup complete
│   └── splash/
│       └── splash_screen.dart          # Animated splash screen
├── shared/
│   ├── services/                       # Business logic services
│   ├── providers/                      # State management
│   ├── models/                         # Data models
│   ├── widgets/                        # Reusable UI components
│   ├── utils/                          # Utility functions
│   └── mixins/                         # Shared behavior mixins
├── l10n/
│   ├── app_localizations.dart          # Localization setup
│   ├── locale_provider.dart            # Locale state
│   ├── app_en.arb                      # English strings
│   └── app_cs.arb                      # Czech strings
└── assets/
    ├── animations/                     # Lottie animations
    ├── fonts/                          # Custom fonts (Questrial)
    └── images/                         # App images and icons
```

### State Management

The app uses **Provider** for global state management with the following key providers:

| Provider | Purpose |
|----------|---------|
| `AudioPlayerService` | Core audio playback state and controls |
| `ThemeProvider` | Theme configuration and dynamic colors |
| `PerformanceModeProvider` | Performance optimization settings |
| `BackgroundManagerService` | Animated background gradient colors |
| `SleepTimerController` | Sleep timer state |
| `HomeLayoutService` | Home screen section visibility and order |
| `ErrorTrackingService` | Error logging and reporting |

### Key Design Patterns

1. **Singleton Services**: Most services use singleton pattern for efficient resource sharing
2. **ValueNotifier**: Used for fine-grained UI updates without full rebuilds
3. **StreamController**: For reactive data streams (current song, errors, downloads)
4. **Memoization**: Performance optimization for expensive computations
5. **LRU Cache**: Memory management for artwork caching
6. **Debouncing**: Prevents excessive operations (search, save, notifications)

---

## Dependencies & Services

### Core Dependencies

#### Audio & Playback

| Package | Version | Purpose |
|---------|---------|---------|
| `just_audio` | ^0.10.4 | Audio playback engine |
| `audio_service` | ^0.18.15 | Background audio and notification controls |
| `audio_session` | any | Audio focus management |
| `on_audio_query` | ^2.9.0 | Local audio library access via MediaStore |
| `audiotags` | ^1.4.5 | Audio metadata reading/writing |

#### State & Storage

| Package | Version | Purpose |
|---------|---------|---------|
| `provider` | ^6.1.2 | State management |
| `shared_preferences` | ^2.3.4 | Local key-value storage |
| `path_provider` | ^2.1.3 | File system paths |

#### UI & Theming

| Package | Version | Purpose |
|---------|---------|---------|
| `dynamic_color` | ^1.7.0 | Material You dynamic colors |
| `palette_generator` | ^0.3.3+4 | Color extraction from images |
| `blur` | ^4.0.0 | Blur effects |
| `flutter_staggered_animations` | ^1.1.1 | List animations |
| `animations` | ^2.0.11 | Page transition animations |
| `lottie` | ^3.2.0 | Lottie animation support |
| `mesh` | ^0.5.0 | Mesh gradient backgrounds |
| `miniplayer` | ^1.0.1 | Expandable mini player widget |

#### Networking & APIs

| Package | Version | Purpose |
|---------|---------|---------|
| `http` | ^1.2.1 | HTTP requests |
| `spotify` | ^0.13.7 | Spotify Web API (artist images) |
| `flutter_dotenv` | ^5.1.0 | Environment variables |
| `html` | ^0.15.4 | HTML parsing |
| `crypto` | ^3.0.6 | MD5 hashing for cache keys |

#### Device & Platform

| Package | Version | Purpose |
|---------|---------|---------|
| `permission_handler` | ^12.0.0+1 | Runtime permissions |
| `device_info_plus` | ^11.4.0 | Device information |
| `package_info_plus` | ^8.0.0 | App version info |
| `url_launcher` | ^6.2.6 | Opening URLs |
| `share_plus` | ^10.0.3 | Sharing functionality |

#### Utilities

| Package | Version | Purpose |
|---------|---------|---------|
| `version` | ^3.0.2 | Semantic versioning |
| `pub_semver` | ^2.1.4 | Version comparison |
| `intl` | any | Internationalization |
| `flutter_hooks` | ^0.21.3+1 | Hook-based widgets |

#### Analytics

| Package | Version | Purpose |
|---------|---------|---------|
| `clarity_flutter` | ^1.6.0 | Microsoft Clarity analytics |

---

### Services Documentation

#### AudioPlayerService (`audio_player_service.dart`)

The core service managing audio playback, queue, and state.

**Key Responsibilities:**
- Audio playback control (play, pause, skip, seek)
- Queue management (shuffle, repeat modes)
- Playlist management (create, edit, delete)
- Play count tracking
- Sleep timer functionality
- Gapless playback support
- Playback speed control

**Key Properties:**
```dart
AudioPlayer get audioPlayer          // Access to just_audio player
List<SongModel> get playlist         // Current playback queue
SongModel? get currentSong           // Currently playing song
bool get isPlaying                   // Playback state
bool get isShuffle                   // Shuffle mode state
LoopMode get loopMode                // Loop mode (off, all, one)
PlaybackSourceInfo get playbackSource // Where playback started from
```

**Key Methods:**
```dart
Future<void> playFromSongList(List<SongModel> songs, {int index = 0})
Future<void> togglePlayPause()
Future<void> skipToNext()
Future<void> skipToPrevious()
Future<void> seekTo(Duration position)
void toggleShuffle()
void cycleLoopMode()
Future<void> addToPlaylist(Playlist playlist, SongModel song)
```

**Playback Source Tracking:**
```dart
enum PlaybackSource {
  forYou,         // Smart suggestions
  recentlyPlayed, // Recently played section
  recentlyAdded,  // Recently added section
  mostPlayed,     // Most played section
  album,          // Album detail screen
  artist,         // Artist detail screen
  playlist,       // User playlist
  folder,         // Folder browser
  search,         // Search results
  library,        // All tracks view
  unknown         // Default/unknown source
}
```

---

#### AuroraAudioHandler (`audio_handler.dart`)

Custom audio handler for background playback with notification controls.

**Key Features:**
- Provides only 3 notification controls: Previous, Play/Pause, Next (no stop button)
- Broadcasts playback state to system notification
- Handles media button events
- Manages audio queue for notification display

**Methods:**
```dart
Future<void> play()
Future<void> pause()
Future<void> seek(Duration position)
Future<void> skipToNext()
Future<void> skipToPrevious()
Future<void> skipToQueueItem(int index)
Future<void> setSpeed(double speed)
Future<void> setAudioSource(AudioSource source, {int initialIndex})
void updateNotificationMediaItem(MediaItem item)
void updateNotificationQueue(List<MediaItem> items)
```

---

#### TimedLyricsService (`lyrics_service.dart`)

Fetches and caches synchronized lyrics from LRCLIB API.

**API Details:**
- Base URL: `https://lrclib.net/api`
- Timeout: 5 seconds
- User-Agent: `AuroraMusic v0.0.85`

**Key Features:**
- Direct and search API endpoints for finding lyrics
- LRC format parsing with timestamp extraction
- Duration validation to ensure correct lyrics match
- In-memory cache (max 50 entries) + file-based persistence
- Artist similarity scoring for better match selection

**Methods:**
```dart
List<TimedLyric>? getCachedLyrics(String artist, String title)
Future<void> preloadLyricsToMemory(String artist, String title)
Future<List<TimedLyric>?> fetchTimedLyrics(
  String artist,
  String title, {
  Duration? songDuration,
  void Function(String)? onLog,
  Future<Map<String, dynamic>?> Function(List<Map<String, dynamic>>)? onMultipleResults,
})
Future<List<TimedLyric>?> loadLyricsFromFile(String artist, String title)
List<TimedLyric> parseLrcContent(String lrcContent)
Future<void> saveLyricsToCache(String artist, String title, String content)
```

**Cache Location:** `{app_documents}/lyrics/{md5_hash}.lrc`

---

#### SmartSuggestionsService (`smart_suggestions_service.dart`)

Analyzes listening patterns to provide personalized recommendations.

**Tracking Data:**
- Listening history with timestamps (max 1000 events)
- Hourly track/artist/genre counts (24 hour buckets)
- Day-of-week patterns (7 day buckets)
- Overall play counts
- Skip patterns (tracks frequently skipped)
- Recently played tracking

**Scoring Algorithm:**
```dart
// Score factors:
1. Time-of-day relevance (3x weight)
2. Adjacent hours relevance (1.5x weight)
3. Day-of-week relevance (2x weight)
4. Overall play count (sqrt for diminishing returns)
5. Genre matching current time (0.5x weight)
6. Artist preference at this time (2x weight)
7. Penalty for recently played (30-100% reduction)
8. Penalty for frequently skipped tracks
9. Random factor for variety (5%)
```

**Methods:**
```dart
Future<void> initialize()
Future<void> recordPlay(SongModel song, {bool wasSkipped, int listenDurationMs})
Future<List<SongModel>> getSuggestedTracks({int count = 3})
Future<List<String>> getSuggestedArtists({int count = 3})
String getTimeContext()  // Returns 'morning', 'afternoon', 'evening', 'night'
bool hasListeningHistory()
```

**Cache Duration:** Suggestions cached for 5 minutes

---

#### ArtworkCacheService (`artwork_cache_service.dart`)

Manages artwork loading and caching with LRU eviction.

**Cache Limits:**
- Max artwork cache: 80 entries
- Max artist cache: 40 entries
- Thumbnail quality: 80%
- Thumbnail size: 200px
- High quality size: 1500px (for Now Playing)

**Key Features:**
- LRU (Least Recently Used) cache eviction
- Sync and async artwork retrieval
- Separate caches for songs, artists, and albums
- Spotify artist image integration

**Methods:**
```dart
Future<void> initialize()
Future<ImageProvider<Object>> getCachedImageProvider(int id, {bool highQuality})
ImageProvider<Object>? getCachedImageProviderSync(int id)
Future<Uint8List?> getArtwork(int id)
Future<void> preloadArtwork(int id)
Widget buildCachedArtwork(int id, {double size})
Widget buildCachedArtistArtwork(int id, {double size, bool circular})
Widget buildCachedAlbumArtwork(int albumId, {double size})
Future<String?> getArtistImageByName(String artistName)  // Spotify API
void clearCache()
```

---

#### LocalCachingArtistService (`local_caching_service.dart`)

Fetches and caches artist images from Spotify API.

**Configuration:**
Requires `.env` file with:
```
SPOTIFY_CLIENT_ID=your_client_id
SPOTIFY_CLIENT_SECRET=your_client_secret
```

**Features:**
- Spotify OAuth client credentials flow
- Automatic token refresh on 401 responses
- File-based image caching
- Deduplication of concurrent requests

**Cache Location:** `{app_documents}/artist_images/{artist_name}.jpg`

---

#### MetadataService (`metadata_service.dart`)

Searches for metadata from Deezer and iTunes APIs.

**APIs Used:**
- Deezer Search: `https://api.deezer.com/search?q={query}`
- iTunes Search: `https://itunes.apple.com/search?term={query}&entity=album`

**Methods:**
```dart
Future<List<Map<String, dynamic>>> searchMetadata(String query)
Future<String?> fetchCoverArt(String query)  // Returns high-res (600x600) URL
Future<List<int>?> downloadImage(String url)
```

---

#### BatchDownloadService (`batch_download_service.dart`)

Downloads lyrics and/or artwork for entire music library.

**Features:**
- Concurrent downloads (10 items at a time)
- Progress streaming
- Skip already cached items
- Statistics gathering

**Methods:**
```dart
Future<void> startBatchDownload({required bool downloadLyrics, required bool downloadArtwork})
Future<Map<String, int>> getCacheStatistics()
Stream<DownloadProgress> get progressStream
bool get isDownloading
```

---

#### BluetoothService (`bluetooth_service.dart`)

Monitors Bluetooth audio device connections.

**Features:**
- Permission checking (Android 12+ vs earlier versions)
- Audio session device monitoring
- Periodic connectivity checks (every 5 seconds)

**Methods:**
```dart
Future<void> initialize()
Future<bool> requestBluetoothPermission()
bool get isBluetoothConnected
String get connectedDeviceName
bool get hasBluetoothPermission
```

---

#### MusicSearchService (`music_search_service.dart`)

Provides fuzzy search across music library.

**Scoring Algorithm:**
```dart
// Exact match: +100 (title), +80 (artist), +60 (album)
// Starts with: +50 (title), +40 (artist), +30 (album)
// Contains: +30 (title), +25 (artist), +20 (album)
// Word match: +15 (exact), +10 (starts with)
// Levenshtein distance bonus (up to +25)
```

**Methods:**
```dart
static List<SongModel> searchSongs(List<SongModel> songs, String query, {int limit, double minScore})
static List<ArtistModel> searchArtists(List<ArtistModel> artists, String query, {int limit})
static List<SeparatedArtist> searchSeparatedArtists(List<SeparatedArtist> artists, String query, {int limit})
static List<AlbumModel> searchAlbums(List<AlbumModel> albums, String query, {int limit})
```

---

#### VersionService (`version_service.dart`)

Checks for app updates from GitHub releases.

**GitHub API:** `https://api.github.com/repos/D4v31x/Aurora-Music/releases/latest`

**Methods:**
```dart
static Future<VersionCheckResult> checkForNewVersion()
static Future<String> getCurrentVersion()
static Future<bool> shouldShowChangelog()
static Future<void> resetChangelog()
```

---

#### ThemeProvider (`theme_provider.dart`)

Manages app theming with Material You support.

**Features:**
- Dark mode only (no light theme)
- Dynamic color support
- Gradient colors for backgrounds
- Glassmorphic UI components

**Default Dark Gradient:**
```dart
const [
  Color(0xFF1A0B2E),  // Deep purple
  Color(0xFF2D1B4E),  // Rich purple
  Color(0xFF16213E),  // Dark blue
  Color(0xFF0F3460),  // Deep teal blue
]
```

---

#### HomeLayoutService (`home_layout_service.dart`)

Manages home screen section visibility and order.

**Features:**
- Persist section order
- Toggle section visibility
- Drag-to-reorder support

---

#### Additional Services

| Service | File | Purpose |
|---------|------|---------|
| BackgroundManagerService | `background_manager_service.dart` | Animated mesh gradient colors |
| SleepTimerController | `sleep_timer_controller.dart` | Sleep timer state and countdown |
| ArtistSeparatorService | `artist_separator_service.dart` | Parse multi-artist strings |
| ArtistAggregatorService | `artist_aggregator_service.dart` | Aggregate artists from songs |
| PlayCountService | `play_count_service.dart` | Track play statistics |
| LikedSongsService | `liked_songs_service.dart` | Favorite songs management |
| PlaylistPersistenceService | `playlist_persistence_service.dart` | Save/load playlists |
| CacheManager | `cache_manager.dart` | General cache management |
| DevicePerformanceService | `device_performance_service.dart` | Device capability detection |
| ShaderWarmupService | `shader_warmup_service.dart` | Pre-compile shaders |
| NotificationManager | `notification_manager.dart` | Toast notifications |
| DownloadProgressMonitor | `download_progress_monitor.dart` | Track download progress |
| ErrorTrackingService | `error_tracking_service.dart` | Error logging |
| LoggingService | `logging_service.dart` | Debug logging |
| AudioSettingsService | `audio_settings_service.dart` | Audio configuration |
| DonationService | `donation_service.dart` | Support links |
| FeedbackReminderService | `feedback_reminder_service.dart` | Prompt for feedback |
| UserPreferences | `user_preferences.dart` | User settings |

---

## Screens & UI Components

### Feature Screens

#### SplashScreen (`splash_screen.dart`)

**Purpose:** Animated app launch experience with initialization.

**Components:**
- Lottie animation (`Splash.json`)
- Progress indicator showing initialization tasks
- Version and codename display
- Warning display for connectivity issues

**Initialization Tasks:**
1. Warming shaders
2. Initializing services
3. Loading library
4. Caching artwork
5. Final preparations

**Navigation:** Routes to OnboardingScreen (first launch) or HomeScreen (returning user)

---

#### HomeScreen (`home_screen.dart`)

**Purpose:** Main app hub with tabbed navigation.

**Tabs:**
1. **Home Tab** - Smart suggestions and sections
2. **Library Tab** - Browse by category
3. **Search Tab** - Search all content
4. **Settings Tab** - App configuration

**Features:**
- Pull-to-refresh on home tab
- Tab indicator animation
- Mini player integration
- Bluetooth status indicator
- Download progress monitoring
- Welcome toast on first load
- Feedback reminder system

---

#### HomeTab Sections

| Section | Widget | Description |
|---------|--------|-------------|
| For You | `for_you_section.dart` | Smart suggestions based on time and patterns |
| Recently Played | `recently_played_section.dart` | Last played tracks |
| Recently Added | `recently_added_section.dart` | Newest tracks in library |
| Most Played | `most_played_section.dart` | Tracks with highest play counts |
| Suggested Artists | `suggested_artists_section.dart` | Artist recommendations |
| Music Stats | `music_stats_card.dart` | Library statistics |
| Listening History | `listening_history_card.dart` | Visual history |

---

#### Library Screens

| Screen | Purpose |
|--------|---------|
| TracksScreen | All songs in library |
| AlbumsScreen | Grid of all albums |
| AlbumDetailScreen | Single album with track list |
| ArtistsScreen | Grid of all artists |
| ArtistDetailScreen | Single artist with songs and albums |
| FoldersScreen | Folder hierarchy browser |
| FolderDetailScreen | Contents of a folder |

---

#### Player Screens

| Screen | Purpose |
|--------|---------|
| NowPlayingScreen | Full player with controls, lyrics, artwork |
| FullscreenLyricsScreen | Immersive synced lyrics view |
| FullscreenArtworkScreen | Full-screen album art display |

---

#### Playlist Screens

| Screen | Purpose |
|--------|---------|
| PlaylistsScreen | List all playlists (user + auto) |
| PlaylistDetailScreen | Playlist contents with management |

---

#### Settings Screens

| Screen | Purpose |
|--------|---------|
| SettingsTab | Main settings panel |
| HomeLayoutSettings | Reorder/hide home sections |
| ArtistSeparatorSettings | Configure artist name parsing |
| MetadataDetailScreen | Edit song tags |

---

#### Onboarding Screens

| Page | Purpose |
|------|---------|
| WelcomePage | App introduction |
| PermissionsPage | Request required permissions |
| LanguageSelectionPage | Choose app language |
| ThemeSelectionPage | Theme preferences |
| AssetDownloadPage | Download initial assets |
| InternetUsagePage | Explain network features |
| DonationPage | Support options |
| AppInfoPage | About the app |
| BetaWelcomePage | Beta program info |
| CompletionPage | Setup complete |

---

### Reusable Widgets

#### Player Widgets

| Widget | Purpose |
|--------|---------|
| PlayerControls | Play/pause, skip, shuffle, repeat buttons |
| PlayerProgressBar | Seek bar with time display |
| LyricsSection | Scrolling synced lyrics display |
| AlbumSection | Album info card |
| ArtistSection | Artist info card |
| SongLikeButton | Like/unlike toggle |
| SleepTimerIndicator | Timer countdown display |
| PlayerMoreOptionsMenu | Context menu with actions |
| PlayingFromHeader | "Playing from" label |
| TrackInfoDisplay | Song title and artist |

---

#### Common Widgets

| Widget | File | Purpose |
|--------|------|---------|
| ExpandingPlayer | `expanding_player.dart` | Mini player that expands to full |
| AlbumCard | `album_card.dart` | Album thumbnail with info |
| ArtistCard | `artist_card.dart` | Artist thumbnail with info |
| GlassmorphicContainer | `glassmorphic_container.dart` | Frosted glass effect container |
| GlassmorphicCard | `glassmorphic_card.dart` | Card with glass effect |
| GlassmorphicDialog | `glassmorphic_dialog.dart` | Dialog with glass effect |
| BlurDialog | `blur_dialog.dart` | Blurred background dialog |
| AppBackground | `app_background.dart` | Animated gradient background |
| AnimatedArtworkBackground | `animated_artwork_background.dart` | Artwork-based background |
| AutoScrollText | `auto_scroll_text.dart` | Text that scrolls when long |
| ScrollingText | `common/scrolling_text.dart` | Horizontal scrolling text |
| AnimatedProgressLine | `animated_progress_line.dart` | Animated progress indicator |
| ShimmerLoading | `shimmer_loading.dart` | Shimmer placeholder effect |
| PillButton | `pill_button.dart` | Rounded button style |
| OutlineIndicator | `outline_indicator.dart` | Tab indicator style |
| ToastNotification | `toast_notification.dart` | Toast message display |
| SongPickerSheet | `song_picker_sheet.dart` | Bottom sheet song selector |
| AboutDialog | `about_dialog.dart` | App about dialog |
| ChangelogDialog | `changelog_dialog.dart` | Version changelog |
| PackagesDialog | `packages_dialog.dart` | Third-party licenses |
| FeedbackReminderDialog | `feedback_reminder_dialog.dart` | Feedback prompt |
| MusicMetadataWidget | `music_metadata_widget.dart` | Metadata display |
| OptimizedTiles | `optimized_tiles.dart` | Performance-optimized list tiles |
| PerformanceDebugOverlay | `performance_debug_overlay.dart` | FPS counter overlay |
| GrainyGradientBackground | `grainy_gradient_background.dart` | Textured gradient |

---

### Mixins

| Mixin | Purpose |
|-------|---------|
| ArtworkMixin | Artwork loading helpers |
| PlaybackMixin | Playback control helpers |
| SearchMixin | Search functionality helpers |
| LazyLoadingMixin | Lazy list loading |
| DetailScreenMixin | Detail screen common behavior |

---

## Data Flow

### Audio Playback Flow

```
User Tap → AudioPlayerService.playFromSongList()
    │
    ├── Create ConcatenatingAudioSource
    ├── Set audio source on just_audio player
    ├── Update notification queue via AuroraAudioHandler
    ├── Start playback
    ├── Record play in SmartSuggestionsService
    └── Notify listeners (UI updates)
    
Position Updates:
just_audio.positionStream → UI Progress Bar
                         → Lyrics sync (TimedLyricsService)
                         → Background color updates

Song Complete:
just_audio.onComplete → Auto-advance to next track
                     → Update notification
                     → Update play counts
```

### Lyrics Flow

```
Song Change → Now Playing Screen
    │
    ├── Check memory cache (instant)
    ├── Check file cache (fast)
    │
    └── If not cached:
        ├── API: LRCLIB direct lookup
        ├── API: LRCLIB search query
        ├── Parse LRC format
        ├── Validate duration match
        ├── Save to file cache
        └── Add to memory cache

During Playback:
Position Stream → Calculate current lyric index
               → Update UI with current line
               → Auto-scroll to visible line
```

### Smart Suggestions Flow

```
App Launch → SmartSuggestionsService.initialize()
    │
    └── Load saved data from JSON file

Song Play → SmartSuggestionsService.recordPlay()
    │
    ├── Add to listening history
    ├── Update hourly counts
    ├── Update weekday counts
    ├── Update overall counts
    └── Debounced save to disk

Get Suggestions → getSuggestedTracks()
    │
    ├── Check cache (5 minute TTL)
    ├── Query all songs
    ├── Calculate score for each song
    ├── Sort by score
    ├── Apply diversity (slight shuffle)
    └── Return top N tracks
```

### Search Flow

```
User Input → SearchTab
    │
    └── Debounce (300ms)
        │
        └── MusicSearchService.searchSongs()
            │
            ├── Calculate score for each song
            │   ├── Exact match bonus
            │   ├── Starts-with bonus
            │   ├── Contains bonus
            │   ├── Word match bonus
            │   └── Fuzzy match (Levenshtein)
            │
            ├── Filter by minimum score
            └── Return top 50 results
```

### Artwork Loading Flow

```
Widget needs artwork → ArtworkCacheService
    │
    ├── Check sync memory cache (instant)
    │
    └── If not cached:
        ├── Check if LRU eviction needed
        ├── Query MediaStore for artwork
        ├── Store in memory cache
        └── Return ImageProvider
        
For Artist Images (Spotify):
    ├── Check memory cache
    ├── Check file cache
    │
    └── If not cached:
        ├── Authenticate with Spotify
        ├── Search for artist
        ├── Download image
        ├── Save to file
        └── Return file path
```

### State Update Flow

```
User Action → AudioPlayerService method
    │
    ├── Update internal state
    ├── Update audio_service notification
    └── notifyListeners()
        │
        └── Provider rebuilds listening widgets
            │
            └── UI updates (play button, progress, etc.)
```

---

## Permissions & Features

### Required Permissions

| Permission | Android Version | Purpose | Usage |
|------------|-----------------|---------|-------|
| `INTERNET` | All | Network access | Lyrics, metadata lookups, Spotify images, version checks |
| `ACCESS_NETWORK_STATE` | All | Network status | Check connectivity before network calls |
| `READ_MEDIA_AUDIO` | Android 13+ (SDK 33+) | Read audio files | Access local music library |
| `READ_EXTERNAL_STORAGE` | Android 12- (SDK ≤32) | Read audio files | Legacy storage access |
| `WRITE_EXTERNAL_STORAGE` | Android ≤10 (SDK ≤29) | Write files | Metadata editing |
| `MANAGE_EXTERNAL_STORAGE` | Android 11+ | Full storage | Metadata file updates |
| `POST_NOTIFICATIONS` | Android 13+ | Notifications | Playback controls, download status |
| `FOREGROUND_SERVICE` | All | Background service | Background audio playback |
| `FOREGROUND_SERVICE_MEDIA_PLAYBACK` | Android 14+ | Media service | Specific foreground type |
| `WAKE_LOCK` | All | Keep awake | Prevent sleep during playback |
| `BLUETOOTH` | Android ≤11 | Bluetooth access | Detect audio devices |
| `BLUETOOTH_ADMIN` | Android ≤11 | Bluetooth admin | Bluetooth configuration |
| `BLUETOOTH_CONNECT` | Android 12+ | Bluetooth connect | Connect to audio devices |
| `BLUETOOTH_SCAN` | Android 12+ | Bluetooth scan | Discover devices (no location) |

### Permission Request Flow

```dart
// Onboarding flow requests permissions
1. READ_MEDIA_AUDIO / READ_EXTERNAL_STORAGE
2. POST_NOTIFICATIONS
3. BLUETOOTH_CONNECT (optional)

// Runtime permission checking
PermissionsPage → permission_handler → Grant/Deny
```

### App Features by Permission

| Feature | Required Permission | Fallback if Denied |
|---------|--------------------|--------------------|
| Music playback | Storage access | App cannot function |
| Background playback | FOREGROUND_SERVICE | Audio stops when backgrounded |
| Playback notification | POST_NOTIFICATIONS | No notification controls |
| Lyrics fetching | INTERNET | No lyrics available |
| Artist images | INTERNET | Default placeholder |
| Version updates | INTERNET | No update checks |
| Bluetooth indicator | BLUETOOTH_CONNECT | Feature disabled |
| Metadata editing | WRITE storage | Read-only mode |

### Hardware Features

| Feature | Required | Usage |
|---------|----------|-------|
| Internet | Optional | Lyrics, images, updates |
| Bluetooth | Optional | Device indicator |
| Storage | Required | Music library |
| Audio | Required | Playback |

---

## Best Practices & Notes

### Performance Optimizations

1. **Image Caching**
   - LRU cache with configurable limits (80 artworks, 40 artists)
   - Thumbnail size (200px) for lists, high quality (1500px) for player
   - Memory-based sync cache for instant access
   - Background preloading for upcoming tracks

2. **List Performance**
   - `RepaintBoundary` around list items
   - `const` constructors where possible
   - `ValueKey` for efficient rebuilds
   - Lazy loading with cache extent
   - Staggered animations for visual polish

3. **Notification Debouncing**
   - 16ms debounce (~60fps) for rapid updates
   - 2 second debounce for disk saves
   - 300ms debounce for search input

4. **Shader Pre-compilation**
   - Warmup on app launch
   - Pre-draw common effects (gradients, blur)

5. **Memory Management**
   - ImageCache size limits (100 images, 80MB)
   - Periodic cache cleanup (every 3 minutes)
   - LRU eviction for artwork caches

### Architecture Decisions

1. **Singleton Services**
   - Shared state across app
   - Single instance for resource-intensive services
   - Factory constructor pattern

2. **Provider for State**
   - ChangeNotifier for observable state
   - Lazy initialization for non-critical services
   - Scoped providers where appropriate

3. **Hero Animations**
   - Smooth transitions between mini player and full player
   - Album artwork hero for visual continuity

4. **Dark Mode Only**
   - Simplified theming logic
   - Consistent visual identity
   - Better for music/media apps

5. **Feature-based Organization**
   - Each feature in its own folder
   - Co-located screens, widgets, controllers
   - Shared code in `shared/` directory

### Coding Patterns

1. **Null Safety**
   - All code uses Dart null safety
   - Null checks with `?.` and `??`
   - Type-safe model classes

2. **Async/Await**
   - Consistent use of Future-based APIs
   - Error handling with try-catch
   - Parallel initialization with `Future.wait()`

3. **Stream Usage**
   - Broadcast streams for multiple listeners
   - StreamSubscription cleanup in dispose
   - ValueNotifier for simple reactive values

4. **Error Handling**
   - Global error handler in main()
   - Service-level try-catch blocks
   - User-friendly error messages

### API Integration Notes

1. **LRCLIB API**
   - No authentication required
   - Rate limiting not documented
   - UTF-8 encoding for special characters
   - Duration matching for accuracy

2. **Spotify API**
   - Requires client credentials
   - 401 triggers token refresh
   - Images cached locally
   - Optional feature (graceful degradation)

3. **Deezer/iTunes APIs**
   - Public APIs, no auth
   - Used for metadata suggestions
   - Cover art from iTunes (600x600)

### Localization

1. **Supported Languages**
   - English (en) - Default
   - Czech (cs)

2. **ARB Files**
   - Located in `lib/l10n/`
   - Generated localizations
   - Key-based string lookup

3. **Usage**
   ```dart
   AppLocalizations.of(context).translate('key_name')
   ```

### Testing Considerations

1. **Unit Tests**
   - Service logic can be unit tested
   - Mock audio_query responses
   - Test scoring algorithms

2. **Widget Tests**
   - Provider mocking required
   - Test UI interactions

3. **Integration Tests**
   - Requires device/emulator
   - Permission handling testing
   - Real audio file playback

### Known Limitations

1. **Platform Support**
   - Android only (iOS code exists but untested)
   - Windows partial support (no audio query)
   - No web support

2. **API Dependencies**
   - Lyrics require internet
   - Artist images require Spotify credentials
   - Version checks require GitHub access

3. **Storage**
   - Large libraries may have slow initial scan
   - Artwork caching requires storage space
   - Lyrics cache grows over time

### Security Considerations

1. **API Keys**
   - Spotify credentials in `.env` file
   - Not committed to version control
   - Optional feature if not provided

2. **Permissions**
   - Minimum required permissions
   - Runtime permission requests
   - Graceful degradation if denied

3. **Data Storage**
   - Local storage only (no cloud)
   - JSON files for persistence
   - No encryption (user data on device)

### Future Improvements

The codebase has TODOs and areas for potential enhancement:

1. Proper release signing configuration
2. Additional language translations
3. iOS platform testing and fixes
4. Cloud backup/sync options
5. Equalizer integration
6. Crossfade between tracks
7. Queue editing interface
8. Smart playlist rules

---

## Configuration Reference

### AppConfig Constants

```dart
// Performance Configuration
imageCacheMaxSize = 100
imageCacheMaxSizeBytes = 80 MB
maxCacheSize = 150
cacheCleanupInterval = 3 minutes

// Audio Configuration
androidNotificationChannelId = 'com.aurorasoftware.music.channel.audio'
androidNotificationChannelName = 'Audio playback'

// Animation Timing
defaultAnimationDuration = 250ms
fastAnimationDuration = 150ms
slowAnimationDuration = 350ms

// List Performance
listCacheExtent = 400.0
largeListCacheExtent = 800.0
horizontalListCacheExtent = 250.0

// Blur Configuration
standardBlurSigma = 8.0
heavyBlurSigma = 15.0
maxBlurSigma = 25.0

// Debounce Timing
notifyDebounce = 16ms
saveDebounce = 2 seconds
searchDebounce = 300ms

// Image Loading
maxConcurrentImageLoads = 4
thumbnailSize = 200
highQualityArtworkSize = 500
```

---

## Environment Setup

### Prerequisites

- Flutter SDK (Dart >= 3.3.3)
- Android SDK with build tools 35.0.0
- JDK for Android builds

### Optional Configuration

Create `.env` file in project root:
```env
SPOTIFY_CLIENT_ID=your_spotify_client_id
SPOTIFY_CLIENT_SECRET=your_spotify_client_secret
CODE_NAME=optional_release_codename
```

### Build Commands

```bash
# Install dependencies
flutter pub get

# Debug build
flutter run

# Release APK
flutter build apk --release

# Analyze code
flutter analyze
```

---

## Routing & Navigation Logic

### Navigation System

Aurora Music uses **Navigator 1.0** (imperative navigation) exclusively. This was chosen for its simplicity and predictability in a single-screen-flow application.

**Global Navigator Key:**
```dart
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
```

The global navigator key is defined in `main.dart` and used throughout the app to enable navigation from non-widget contexts (e.g., notification click handlers, services).

### Route Types

| Route Type | Usage | Examples |
|------------|-------|----------|
| **MaterialPageRoute** | Standard full-screen push navigation | Album detail, Artist detail, Folder contents |
| **PageRouteBuilder** | Custom animated transitions | Now Playing screen (fade + slide) |
| **pushReplacement** | Replace current route entirely | Splash → Home/Onboarding transition |
| **showDialog** | Modal dialogs | Settings dialogs, confirmations, sleep timer |
| **showModalBottomSheet** | Bottom sheets | Song picker, add to playlist |
| **pop** | Standard back navigation | Close screens, dismiss dialogs |

### Screen Navigation Map

```
SplashScreen
    ├── (pushReplacement) → OnboardingScreen (first launch)
    │                           └── (pushReplacement) → HomeScreen
    └── (pushReplacement) → HomeScreen (returning user)

HomeScreen (TabBarView with 4 tabs)
    ├── HomeTab
    │   ├── (push) → AlbumDetailScreen
    │   ├── (push) → ArtistDetailScreen
    │   └── (push) → PlaylistDetailScreen
    ├── LibraryTab
    │   ├── (push) → TracksScreen → (dialog) MetadataDetailScreen
    │   ├── (push) → AlbumsScreen → (push) AlbumDetailScreen
    │   ├── (push) → ArtistsScreen → (push) ArtistDetailScreen
    │   ├── (push) → FoldersScreen → (push) FolderDetailScreen
    │   └── (push) → PlaylistsScreen → (push) PlaylistDetailScreen
    ├── SearchTab
    │   ├── (push) → AlbumDetailScreen
    │   ├── (push) → ArtistDetailScreen
    │   └── (push) → FolderDetailScreen
    └── SettingsTab
        ├── (push) → HomeLayoutSettings
        ├── (push) → ArtistSeparatorSettings
        └── (dialog) → Various settings dialogs

ExpandingPlayer (global overlay)
    └── (push via PageRouteBuilder) → NowPlayingScreen
        ├── (push) → FullscreenLyricsScreen
        ├── (push) → FullscreenArtworkScreen
        ├── (push) → ArtistDetailScreen
        ├── (push) → AlbumDetailScreen
        └── (dialog) → Queue, Song Info, Add to Playlist
```

### Special Navigation Patterns

#### Mini Player → Now Playing

The `ExpandingPlayer` widget manages navigation to the Now Playing screen. It uses a **static state holder** pattern to enable expanding from anywhere:

```dart
// From anywhere in the app:
ExpandingPlayer.expand();   // Opens Now Playing
ExpandingPlayer.minimize(); // Closes Now Playing

// State tracking:
ExpandingPlayer.isOpenNotifier  // ValueNotifier<bool> for UI updates
```

The Now Playing screen uses a **PageRouteBuilder** with a custom fade + slide-up transition:

```dart
PageRouteBuilder<void>(
  transitionsBuilder: (context, animation, secondaryAnimation, child) {
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.1),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        )),
        child: child,
      ),
    );
  },
  reverseTransitionDuration: const Duration(milliseconds: 250),
)
```

#### Notification Click Handling

When a user taps the playback notification, the app expands the mini player:

```dart
// In main.dart
AudioService.notificationClicked.listen((clicked) {
  if (clicked) {
    ExpandingPlayer.expand();
  }
});
```

### Deep Links

**Current Status:** Deep linking is **not implemented**.

**Implications for Future Implementation:**
- Would require migration to Navigator 2.0 (GoRouter) or custom deep link handler
- Current route structure (imperative) makes deep linking difficult
- Potential deep link targets: specific albums, artists, playlists, or songs

### Testing Implications

- All navigation is testable via widget tests using `Navigator.push/pop`
- No named routes means no route-name-based testing
- PageRouteBuilder transitions can be tested via integration tests
- Global navigator key enables service-level navigation testing

### Future Refactoring Considerations

1. **Named Routes Migration:** Could add named routes for better testability and potential deep linking
2. **GoRouter Migration:** For declarative routing, deep links, and URL-based navigation
3. **Route Guards:** Currently no authentication guards needed (offline-only app)

---

## Error States & Edge Cases

### Error Handling Strategy

Aurora Music follows a **fail-gracefully** philosophy:
- User-facing errors show brief toast notifications
- Technical errors are logged to `ErrorTrackingService`
- Silent failures for non-critical operations
- Fallback UI states for missing data

### API Error Handling

#### LRCLIB API (Lyrics)

| Error State | Behavior | User Feedback |
|-------------|----------|---------------|
| Network timeout (5s) | Return `null` | No lyrics shown, silent fail |
| HTTP 408 (timeout) | Fall back to file cache | Uses cached lyrics if available |
| HTTP 404 (not found) | Return `null` | "No lyrics available" in UI |
| Invalid LRC format | Parse gracefully, skip malformed lines | Partial lyrics displayed |
| Duration mismatch >10% | Continue with best match | Lyrics may be out of sync |
| UTF-8 decoding error | Use `allowMalformed: true` | Some characters may show as `?` |

**LRC Parsing Edge Cases:**
```dart
// Empty lines are skipped
// Metadata tags [ti:], [ar:], [al:] are skipped
// Invalid timestamps are skipped
// Multiple timestamps per line are supported
// Non-UTF-8 characters are replaced with empty string
```

#### Spotify API (Artist Images)

| Error State | Behavior | User Feedback |
|-------------|----------|---------------|
| Missing credentials | `_spotifyEnabled = false` | Default person icon shown |
| HTTP 401 (auth failed) | Auto-refresh token and retry once | Silent retry |
| HTTP 429 (rate limit) | Return `null`, use cache | Cached image or default icon |
| Network error | Return `null` | Default person icon shown |
| Artist not found | Cache `null` result | Default person icon shown |
| Empty `images` array | Return `null` | Default person icon shown |

**Spotify Token Management:**
```dart
// Token is refreshed on 401 response
if (response.statusCode == 401) {
  await _getSpotifyAccessToken();
  return _getArtistImageFromSpotify(artistName);  // Retry once
}
```

#### Deezer/iTunes API (Metadata)

| Error State | Behavior | User Feedback |
|-------------|----------|---------------|
| Network timeout (10s) | Return empty list | "No suggestions found" |
| HTTP error | Return empty list | Suggestions unavailable |
| Empty results | Return empty list | User can edit manually |

### MediaStore/Audio Query Errors

| Error State | Behavior | User Feedback |
|-------------|----------|---------------|
| Permission denied | Return `false` from permission check | Permission request UI shown |
| Empty MediaStore | Return empty song list | "No music found" message |
| Corrupted audio file | Skip file in query | File doesn't appear in library |
| Permission revoked at runtime | Catch error, return cached data | May show stale library |

**Permission Revocation Handling:**
```dart
Future<bool> _checkPermissionStatus() async {
  try {
    return await _audioQuery.permissionsStatus();
  } catch (e) {
    debugPrint('Permission check error: $e');
    return false;  // Safe fallback
  }
}
```

### Audio Playback Errors

| Error State | Behavior | User Feedback |
|-------------|----------|---------------|
| Invalid file path | Skip song, try next | Brief toast "Couldn't play song" |
| Corrupted audio file | Skip song, try next | Brief toast |
| Audio focus lost | Pause playback | Playback pauses silently |
| Bluetooth disconnected | Continue playing through speaker | Audio switches output |
| Headphones unplugged | Pause playback | `becomingNoisyEventStream` triggers pause |

**Audio Session Configuration:**
```dart
// Handles audio focus automatically
await session.configure(const AudioSessionConfiguration(
  avAudioSessionCategory: AVAudioSessionCategory.playback,
  androidWillPauseWhenDucked: true,
));
```

### UI Fallback States

| Component | Empty/Error State | Fallback UI |
|-----------|-------------------|-------------|
| Song artwork | No embedded art | Default `default_art.png` |
| Artist image | No Spotify image | Person icon |
| Album artwork | No art found | Album icon |
| Lyrics | Not available | "No lyrics available" message |
| Search results | No matches | "No results found" |
| Playlists | Empty list | "Create your first playlist" |
| Recently Played | No history | Section hidden |
| For You suggestions | No listening history | Random songs shown |

### Silent Failure Scenarios

These operations fail silently to avoid disrupting user experience:

1. **Artwork preloading** - Missing artwork doesn't affect playback
2. **Smart suggestions save** - Debounced, non-critical
3. **Play count save** - Cached, retried on next opportunity
4. **Lyrics caching** - Falls back to re-fetching
5. **Clarity analytics** - Optional, doesn't affect app function

### Error Logging

All errors are captured via `ErrorTrackingService`:

```dart
FlutterError.onError = (FlutterErrorDetails details) async {
  FlutterError.dumpErrorToConsole(details);
  await errorTracker.recordError(details.exception, details.stack);
};
```

Errors are stored in SharedPreferences (max 10) and can be reviewed for debugging.

---

## Persistence & Storage Schema

### Storage Overview

Aurora Music uses local storage exclusively. No cloud storage or server-side persistence.

| Storage Type | Location | Format | Purpose |
|--------------|----------|--------|---------|
| SharedPreferences | System default | Key-value pairs | Settings, first-run flag, error logs |
| JSON files | `getApplicationDocumentsDirectory()` | JSON | Playlists, play counts, smart suggestions |
| LRC files | `{docs}/lyrics/` | Plain text (LRC format) | Cached synced lyrics |
| Image files | `{docs}/artist_images/` | JPEG | Cached artist images from Spotify |
| Temp files | `getTemporaryDirectory()` | JPEG | Notification artwork |

### JSON Data Schemas

#### 1. Playlists (`playlists.json`)

```json
[
  {
    "id": "1706745600000",
    "name": "My Favorites",
    "songs": [
      {
        "id": 12345,
        "title": "Song Name",
        "artist": "Artist Name",
        "album": "Album Name",
        "albumId": 67890,
        "duration": 234000,
        "uri": "content://media/external/audio/media/12345",
        "data": "/storage/emulated/0/Music/song.mp3"
      }
    ]
  }
]
```

**Notes:**
- `id` is generated from `DateTime.now().millisecondsSinceEpoch.toString()`
- Special playlist IDs: `liked_songs`, `most_played`, `recently_added`
- Songs are stored with full metadata to avoid re-querying MediaStore

#### 2. Play Counts (`play_counts.json`)

```json
{
  "tracks": {
    "12345": 42,
    "67890": 18
  },
  "albums": {
    "album_id_1": 60,
    "album_id_2": 25
  },
  "artists": {
    "Artist Name": 78,
    "Another Artist": 33
  },
  "playlists": {
    "playlist_id_1": 15
  },
  "folders": {
    "/storage/emulated/0/Music": 120
  }
}
```

**Notes:**
- All keys are string-formatted IDs or names
- Values are integer counts
- Saved with 2-second debouncing to reduce disk I/O

#### 3. Smart Suggestions (`smart_suggestions.json`)

```json
{
  "listeningHistory": [
    {
      "trackId": "12345",
      "artists": ["Artist 1", "Artist 2"],
      "genre": "Pop",
      "timestamp": "2024-02-01T14:30:00.000Z",
      "wasSkipped": false,
      "listenDurationMs": 180000,
      "totalDurationMs": 210000
    }
  ],
  "hourlyTrackCounts": {
    "14": {
      "12345": 5,
      "67890": 3
    }
  },
  "hourlyArtistCounts": {
    "14": {
      "Artist Name": 8
    }
  },
  "hourlyGenreCounts": {
    "14": {
      "Pop": 12
    }
  },
  "weekdayTrackCounts": {
    "3": {
      "12345": 2
    }
  },
  "weekdayArtistCounts": {
    "3": {
      "Artist Name": 5
    }
  },
  "trackPlayCounts": {
    "12345": 42
  },
  "artistPlayCounts": {
    "Artist Name": 78
  },
  "genrePlayCounts": {
    "Pop": 156
  },
  "trackSkipCounts": {
    "99999": 5
  },
  "recentlyPlayedTrackIds": ["12345", "67890"],
  "recentlyPlayedArtists": ["Artist 1", "Artist 2"]
}
```

**Notes:**
- `listeningHistory` limited to 1000 events
- `recentlyPlayedTrackIds` limited to 50 items
- `recentlyPlayedArtists` limited to 30 items
- Hourly keys: 0-23 (hours)
- Weekday keys: 0-6 (Monday=0, Sunday=6)

#### 4. Liked Songs (`liked_songs.json`)

```json
{
  "liked": ["12345", "67890", "11111"]
}
```

**Notes:**
- Simple array of song ID strings
- Stored separately from playlists for quick access

#### 5. Library Cache (`library.json`)

```json
{
  "songs": [
    {
      "id": 12345,
      "title": "Song Name",
      ...
    }
  ],
  "lastUpdated": "2024-02-01T12:00:00.000Z"
}
```

### SharedPreferences Keys

| Key | Type | Purpose |
|-----|------|---------|
| `isFirstTime` | bool | First-run detection for onboarding |
| `languageCode` | String | User's selected language ("en", "cs") |
| `last_version` | String | For changelog display after update |
| `use_dynamic_color` | bool | Material You color toggle |
| `pending_errors` | String (JSON) | Cached error logs |
| `home_section_order` | String (JSON) | Home tab section order |
| `home_section_visibility` | String (JSON) | Which sections are visible |
| `artist_separators` | String (JSON) | Custom artist name separators |
| `feedbackReminderLastShown` | int | Timestamp for feedback reminder |
| `feedbackReminderCount` | int | Number of reminders shown |

### File Cache Management

**Lyrics Cache:**
- Location: `{docs}/lyrics/{md5_hash}.lrc`
- No automatic expiration (lyrics don't change)
- User can delete manually via system settings

**Artist Images:**
- Location: `{docs}/artist_images/{sanitized_name}.jpg`
- No automatic expiration
- Images downloaded once per artist

**Memory Caches:**
- Lyrics: Max 50 entries in memory (`_memoryCache`)
- Artwork: Max 80 entries (`_maxArtworkCacheSize`)
- Artist images: Max 40 entries (`_maxArtistCacheSize`)
- LRU eviction when limits reached

### Data Versioning Strategy

**Current Strategy:** No explicit versioning.

**Migration Handling:**
- JSON parsing uses nullable types and defaults
- Missing fields default to empty/zero values
- Unknown fields are ignored (forward compatible)

```dart
// Example: graceful loading with defaults
_trackPlayCounts = Map<String, int>.from(data['trackPlayCounts'] ?? {});
_listeningHistory = (data['listeningHistory'] as List?)
    ?.map((e) => ListeningEvent.fromJson(e))
    .toList() ?? [];
```

### Corrupted File Handling

| Scenario | Behavior |
|----------|----------|
| JSON parse error | Log error, return empty/default data |
| Missing file | Return empty/default data, file created on first save |
| Incomplete write | Will fail to parse, treated as corrupted |
| Disk full | Save fails silently, data retained in memory |

### App Update Behavior

- Data files are preserved across app updates
- No automatic migration between versions
- Settings preserved unless explicitly cleared
- Cache directory may be cleared by system

---

## Lifecycle & Background Behavior

### App Lifecycle States

Aurora Music responds to Flutter's `AppLifecycleState` events:

```dart
@override
void didChangeAppLifecycleState(AppLifecycleState state) {
  if (state == AppLifecycleState.resumed) {
    // Sync playback state when returning to foreground
    audioService.syncPlaybackState();
  }
  
  if (state == AppLifecycleState.detached) {
    // Clean up when app is swiped closed
    _cleanupAndExit();
  }
}
```

### State Transitions

| From | To | Behavior |
|------|-----|----------|
| Active | Paused | Audio continues playing (background) |
| Paused | Active | UI syncs with current playback state |
| Paused | Detached | Audio stops, resources released |
| Active | Inactive | Brief pause (e.g., phone call incoming) - audio continues |

### Background Playback

**Architecture:**
```
AudioService + just_audio + AuroraAudioHandler
         │
         ▼
┌────────────────────────────────────┐
│ Foreground Service (Android)       │
│ - Keeps app alive in background    │
│ - Shows persistent notification    │
│ - Handles media button events      │
└────────────────────────────────────┘
```

**Notification Controls:**
- Previous track
- Play/Pause
- Next track
- **(No Stop button - intentional UX decision)**

**Media Session Events:**
- Lock screen controls work via `audio_service`
- Bluetooth media buttons supported
- Android Auto (headunit display) supported via MediaBrowserService

### Process Kill Scenarios

| Scenario | Playback State | Queue Restoration |
|----------|----------------|-------------------|
| User swipe-close from recents | Audio stops immediately | Not restored |
| System kills for memory | Audio stops | Not restored |
| Device reboot | N/A | Nothing persisted |
| Force stop in settings | Audio stops | Nothing persisted |

**Important:** Aurora Music does **not** persist playback queue across restarts. This is intentional:
- Simplifies architecture
- Avoids playing unexpected audio on app launch
- Queue is session-based

### Audio Focus Handling

```dart
// Configuration in audio_player_service.dart
final session = await AudioSession.instance;
await session.configure(const AudioSessionConfiguration(
  avAudioSessionCategory: AVAudioSessionCategory.playback,
  androidAudioAttributes: AndroidAudioAttributes(
    contentType: AndroidAudioContentType.music,
    usage: AndroidAudioUsage.media,
  ),
  androidWillPauseWhenDucked: true,
));
```

| Event | Behavior |
|-------|----------|
| Phone call | Audio pauses, resumes after call |
| Other app plays audio | Aurora pauses (loses focus) |
| Navigation voice | Aurora ducks volume temporarily |
| Notification sound | Brief duck, continues playing |

### Notification ↔ UI Sync

When the app is backgrounded:

1. User controls via notification → `just_audio` state changes
2. `playbackEventStream` and `playingStream` emit updates
3. `AuroraAudioHandler._broadcastState()` updates notification
4. UI syncs via `AudioPlayerService` listeners when resumed

```dart
// Sync when returning to foreground
void syncPlaybackState() {
  _isPlaying = audioHandler.player.playing;
  isPlayingNotifier.value = _isPlaying;
  notifyListeners();
}
```

### Memory Pressure

When system is low on memory:

1. Background service may be terminated (audio stops)
2. Image caches are cleared by system
3. App may be fully killed

**Mitigation:**
- ImageCache limits: 100 images, 80MB max
- LRU eviction for artwork caches
- Periodic cache cleanup every 3 minutes

### Headphone/Bluetooth Handling

**Headphone Unplug (Becoming Noisy):**
```dart
session.becomingNoisyEventStream.listen((_) {
  // Pause to prevent audio blasting through speaker
  player.pause();
});
```

**Bluetooth State Changes:**
```dart
session.devicesChangedEventStream.listen((_) async {
  final devices = await session.getDevices();
  // Update Bluetooth indicator in UI
  updateBluetoothStatus(isConnected, deviceName);
});
```

---

## Accessibility & UX Decisions

### Font & Text Scaling

**Implementation:**
- Single font family: Questrial (clean, readable sans-serif)
- No hardcoded text sizes that ignore system scaling
- Uses relative sizing throughout
- Respects system font scale via `MediaQuery.textScaleFactor`

**Font Sizes:**
| Element | Size | Context |
|---------|------|---------|
| App bar titles | 20sp | Screen headers |
| Section headers | 18-22sp | Home sections |
| List item titles | 15-16sp | Songs, albums |
| Subtitles | 13-14sp | Artists, duration |
| Small text | 11-12sp | Metadata, version |

### Color & Contrast

**Dark-Only Design:**
Aurora Music is intentionally dark-mode only. Rationale:
- Music apps are often used in low-light environments
- Dark backgrounds make album artwork "pop"
- OLED battery savings
- Consistent, focused visual identity

**Color Sources:**
1. **Material You (Dynamic Color):** System wallpaper-derived colors when enabled
2. **Fallback Scheme:** Deep purple seed color
3. **Artwork-Based:** Now Playing screen extracts colors from album art

**Contrast Considerations:**
- White text on semi-transparent backgrounds
- Glassmorphic elements use blur + overlay for readability
- Critical controls (play/pause) are always high contrast
- Disabled states use reduced opacity (0.5-0.6)

### Screen Reader Support

**Current Status:** Basic support via Flutter's built-in semantics.

**Implemented:**
- All buttons have implicit accessibility labels
- List items are navigable
- Standard Flutter widgets provide basic TalkBack/VoiceOver support

**Not Implemented:**
- Custom `Semantics` widgets
- Explicit accessibility labels for complex widgets
- Live region announcements for playback changes

### Touch Targets

| Element | Size | Notes |
|---------|------|-------|
| Tab bar items | 48dp+ | Standard material size |
| List items | 56dp+ height | Full-width tap target |
| Icon buttons | 40dp+ | Settings, close, etc. |
| Player controls | 56dp+ | Play/pause, skip |
| Mini player | 72dp | Large tap area |

### Key UX Decisions

#### No Stop Button

The playback notification shows only: Previous | Play/Pause | Next

**Rationale:**
- Stop is rarely needed (pause is sufficient)
- Reduces accidental tap termination
- Follows modern streaming app patterns
- If user wants to stop: pause + swipe away notification

#### Limited Notification Actions

Only 3 compact actions are shown:
```dart
androidCompactActionIndices: const [0, 1, 2],  // All 3 visible
```

**Rationale:**
- Android limits compact view to 3 actions
- Most important controls are always visible
- Expanded notification adds seek bar automatically

#### Dark Mode Only

**Rationale:**
- Simplifies theming code (single theme)
- Music apps benefit from dark UI
- Reduces testing surface (no light mode bugs)
- Allows artwork to be the visual focus

#### Mini Player Always Visible

When a song is loaded, mini player appears at bottom of all screens.

**Rationale:**
- Quick access to playback controls
- Song context always visible
- Tap to expand to full Now Playing
- Follows pattern of Spotify, Apple Music

#### No Swipe-to-Delete

Playlists and songs require explicit delete via context menu.

**Rationale:**
- Prevents accidental data loss
- Consistent with careful, intentional UX
- Delete is destructive, should be deliberate

### Motion & Animation

**Philosophy:** Smooth, purposeful animations that enhance UX without being distracting.

| Animation | Duration | Curve |
|-----------|----------|-------|
| Page transitions | 250-350ms | easeOutCubic |
| Mini player expand | 300ms | easeInOutCubic |
| Tab indicator | 200ms | linear |
| List item stagger | 50ms offset | easeOutQuint |
| Splash → Home | 900ms | easeOutCubic |

**Reduced Motion:** Not explicitly implemented. Could be added by respecting `MediaQuery.disableAnimations`.

---

## Release & Distribution Strategy

### Version Format

Aurora Music follows a modified **SemVer** format:

```
v{MAJOR}.{MINOR}.{PATCH}+{BUILD}
Example: v0.1.25+7
```

| Component | Meaning |
|-----------|---------|
| MAJOR | Breaking changes, major rewrites (currently 0 = beta) |
| MINOR | New features, significant improvements |
| PATCH | Bug fixes, small improvements |
| BUILD | Android `versionCode`, increments with each release |

### Beta vs Stable

**Current Phase:** Beta (v0.x.x)

| Aspect | Beta | Stable (Future) |
|--------|------|-----------------|
| Version | 0.x.x | 1.x.x+ |
| Distribution | GitHub Releases | GitHub + potentially Play Store |
| Stability | Some rough edges | Production-ready |
| Features | Rapidly evolving | Feature-complete core |
| Support | Best-effort | Committed |

### Build Configuration

**Debug Build:**
```bash
flutter run
```
- Enabled assertions
- Debug banner visible
- Hot reload available

**Release Build:**
```bash
flutter build apk --release
flutter build appbundle --release  # For Play Store
```

**Current Signing:** Debug keystore (development)

### Release Criteria ("Release-Ready")

Before tagging a release:

1. **No Critical Bugs:** App doesn't crash during normal use
2. **Playback Functional:** Play, pause, skip, repeat, shuffle all work
3. **Library Loads:** Songs are discovered and displayed
4. **Lyrics Work:** At least some songs get lyrics
5. **Performance:** No major jank or memory leaks
6. **Build Succeeds:** `flutter build apk --release` completes

### Release Process

1. Update version in `pubspec.yaml`:
   ```yaml
   version: 0.1.26+8  # Increment as appropriate
   ```

2. Update changelog (if maintained)

3. Build release APK:
   ```bash
   flutter build apk --release
   ```

4. Test on real device

5. Create GitHub Release:
   - Tag: `v0.1.26`
   - Title: `Aurora Music v0.1.26`
   - Attach APK file
   - Write release notes

### Distribution Channels

| Channel | Status | Notes |
|---------|--------|-------|
| GitHub Releases | Active | Primary distribution |
| Google Play Store | Not yet | Would require signing setup |
| F-Droid | Not yet | Would need open-source compliance |
| Direct APK | Available | Via GitHub releases |

### Code Name

Optional code name stored in `.env`:
```env
CODE_NAME=Aurora
```
Displayed on splash screen for development/beta identification.

---

## Non-Goals

Aurora Music is intentionally scoped to be a focused, local music player. The following features are **explicitly out of scope**:

### No Cloud Storage/Sync

**What's Excluded:**
- Cloud backup of playlists
- Syncing listening history across devices
- Online library storage

**Rationale:**
- Keeps app simple and offline-capable
- Avoids privacy concerns with user data
- No ongoing server costs
- Users own their data locally

### No User Accounts

**What's Excluded:**
- Login/signup flows
- User profiles
- Social features (following, sharing playlists)

**Rationale:**
- Music player doesn't need accounts
- Avoids authentication complexity
- Protects user privacy
- No need for backend infrastructure

### No Streaming

**What's Excluded:**
- Spotify integration (playback)
- Apple Music integration
- YouTube Music
- Any online audio streaming

**Rationale:**
- Focus on local files is core identity
- Streaming requires licensing agreements
- Existing apps handle streaming well
- Keeps app lean and independent

### No Podcast Support

**What's Excluded:**
- Podcast discovery
- RSS feed subscription
- Episode management
- Variable speed playback presets for podcasts

**Rationale:**
- Different UX requirements than music
- Dedicated podcast apps exist
- Would dilute music focus
- Playback speed is available if needed

### No Equalizer

**What's Excluded:**
- Built-in audio equalizer
- Bass boost, virtualizer
- Audio effects

**Rationale:**
- Android system EQ available via other apps
- Complexity vs. value tradeoff
- Most users don't adjust EQ
- Could be added in future if demand exists

### No Lyrics Editing

**What's Excluded:**
- Create/edit LRC files
- Sync lyrics manually
- Upload to LRCLIB

**Rationale:**
- Complex feature with niche audience
- Dedicated tools exist (e.g., LRC editors)
- Focus on consumption, not creation

### No Social/Community Features

**What's Excluded:**
- Sharing to social media
- Public profiles
- Listening activity feed
- Collaborative playlists

**Rationale:**
- Privacy-focused design
- Social features require accounts
- Keeps app simple and personal

### No Android Auto / CarPlay (Limited)

**Current Status:** Basic MediaBrowserService support exists (inherited from `audio_service`), but no dedicated car UI.

**What's Explicitly Not Built:**
- Custom Android Auto UI
- CarPlay support
- Voice control integration

**Rationale:**
- Basic media controls work via system
- Full car UI is significant effort
- Could be added in future

### No Wear OS / Watch Support

**What's Excluded:**
- Wear OS companion app
- Watch face complications
- Watch-based playback control

**Rationale:**
- Niche user base
- Notification controls work from watch
- Significant development effort

### Summary Table

| Feature | Status | Reason |
|---------|--------|--------|
| Cloud sync | ❌ Not planned | Privacy, simplicity |
| User accounts | ❌ Not planned | Not needed |
| Streaming | ❌ Not planned | Core scope |
| Podcasts | ❌ Not planned | Different UX |
| Equalizer | ⏸ Maybe future | System EQ exists |
| Lyrics editing | ❌ Not planned | Niche use case |
| Social features | ❌ Not planned | Privacy |
| Full Android Auto UI | ⏸ Maybe future | Effort vs. value |
| Wear OS | ❌ Not planned | Niche user base |

---

*Documentation generated for Aurora Music v0.1.25+7*
*Last updated: February 2026*
