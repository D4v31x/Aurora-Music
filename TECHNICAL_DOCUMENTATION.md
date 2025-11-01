# Aurora Music - Technical Documentation

**Version**: 0.1.0+1  
**Last Updated**: November 1, 2025  
**Platform**: Flutter 3.3.3+  
**Target**: Android 10+ (API 29+), iOS 13+, Windows 10+

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Project Structure](#project-structure)
3. [Core Services](#core-services)
4. [Screens & Navigation](#screens--navigation)
5. [Widgets & UI Components](#widgets--ui-components)
6. [State Management](#state-management)
7. [API Integrations](#api-integrations)
8. [Data Models](#data-models)
9. [Localization](#localization)
10. [Performance Optimizations](#performance-optimizations)
11. [Build & Deployment](#build--deployment)

---

## Architecture Overview

### Design Pattern
Aurora Music follows a **Service-Oriented Architecture** with **Provider** for state management.

```
┌─────────────────────────────────────────────────┐
│              Presentation Layer                  │
│  (Screens, Widgets, UI Components)              │
└─────────────────┬───────────────────────────────┘
                  │
┌─────────────────▼───────────────────────────────┐
│           State Management Layer                 │
│  (Providers: Theme, Audio, Performance, etc.)   │
└─────────────────┬───────────────────────────────┘
                  │
┌─────────────────▼───────────────────────────────┐
│              Business Logic Layer                │
│  (Services: Audio, Lyrics, Cache, etc.)         │
└─────────────────┬───────────────────────────────┘
                  │
┌─────────────────▼───────────────────────────────┐
│               Data Layer                         │
│  (Local Storage, API Calls, File System)        │
└─────────────────────────────────────────────────┘
```

### Key Principles
- **Separation of Concerns**: UI, business logic, and data are clearly separated
- **Singleton Pattern**: Services use singleton pattern for global access
- **Provider Pattern**: State management using Provider package
- **Reactive Programming**: StreamControllers and ValueNotifiers for real-time updates
- **Performance First**: Optimized rendering, caching, and memory management

---

## Project Structure

```
lib/
├── main.dart                          # Application entry point
├── constants/                         # Application-wide constants
│   ├── animation_constants.dart       # Animation durations & configs
│   ├── app_config.dart               # App configuration values
│   └── performance_constants.dart     # Performance thresholds
├── localization/                      # Internationalization
│   ├── app_localizations.dart        # Localization manager
│   └── locale_provider.dart          # Locale state management
├── models/                            # Data models
│   ├── playlist_model.dart           # Playlist data structure
│   ├── timed_lyrics.dart             # Synced lyrics model
│   ├── utils.dart                    # Spotify & music models
│   └── version_check_result.dart     # Version checking model
├── providers/                         # State management
│   ├── performance_mode_provider.dart # Performance optimization
│   └── theme_provider.dart           # Theme & color management
├── screens/                           # Application screens
│   ├── splash_screen.dart            # Initial splash/loading
│   ├── home_screen.dart              # Main app interface
│   ├── now_playing.dart              # Full-screen player
│   ├── fullscreen_lyrics.dart        # Fullscreen lyrics view
│   ├── AlbumDetailScreen.dart        # Album details
│   ├── Artist_screen.dart            # Artists list
│   ├── PlaylistDetail_screen.dart    # Playlist details
│   ├── Playlist_screen.dart          # Playlists list
│   ├── FolderDetail_screen.dart      # Folder contents
│   ├── categories.dart               # Category browsing
│   ├── tracks_screen.dart            # All tracks view
│   └── onboarding/                   # First-time setup
│       ├── onboarding_screen.dart    # Onboarding flow manager
│       └── pages/                    # Individual onboarding pages
│           ├── welcome_page.dart
│           ├── app_info_page.dart
│           ├── language_selection_page.dart
│           ├── theme_selection_page.dart
│           ├── permissions_page.dart
│           ├── internet_usage_page.dart
│           ├── asset_download_page.dart
│           ├── download_choice_page.dart
│           ├── download_progress_page.dart
│           └── completion_page.dart
├── services/                          # Business logic services
│   ├── audio_player_service.dart     # Core audio playback
│   ├── audio_session_service.dart    # Audio session management
│   ├── artwork_cache_service.dart    # Album art caching
│   ├── background_manager_service.dart # Background gradient
│   ├── batch_download_service.dart   # Bulk downloads
│   ├── bluetooth_service.dart        # Bluetooth detection
│   ├── cache_manager.dart            # General caching
│   ├── device_performance_service.dart # Device capabilities
│   ├── download_progress_monitor.dart # Download tracking
│   ├── error_tracking_service.dart   # Error logging
│   ├── expandable_player_controller.dart # Player expansion
│   ├── image_loading_service.dart    # Optimized image loading
│   ├── local_caching_service.dart    # Local data cache
│   ├── logging_service.dart          # Debug logging
│   ├── lyrics_service.dart           # Lyrics fetching
│   ├── music_search_service.dart     # Search functionality
│   ├── notification_manager.dart     # System notifications
│   ├── performance_monitoring_service.dart # Performance tracking
│   ├── play_count_service.dart       # Play statistics
│   ├── playlist_service.dart         # Playlist management
│   ├── settings_service.dart         # App settings
│   ├── shader_warmup_service.dart    # Shader optimization
│   ├── sleep_timer_controller.dart   # Sleep timer
│   ├── user_preferences.dart         # User preferences
│   ├── version_service.dart          # Version checking
│   └── performance/                  # Performance optimizations
│       ├── performance_manager.dart
│       └── single_background_manager.dart
├── utils/                             # Utility functions
│   ├── artwork_color_utils.dart      # Color extraction
│   ├── changelog_content.dart        # Version changelog
│   ├── device_capabilities.dart      # Device detection
│   ├── file_utils.dart               # File operations
│   ├── frame_rate_monitor.dart       # FPS monitoring
│   ├── responsive_utils.dart         # Responsive design
│   ├── theme_utils.dart              # Theme creation
│   └── validation_utils.dart         # Input validation
└── widgets/                           # Reusable UI components
    ├── about_dialog.dart             # About app dialog
    ├── animated_mesh_background.dart # Animated backgrounds
    ├── animated_mesh_gradient.dart   # Mesh gradient animation
    ├── app_background.dart           # App-wide background
    ├── artist_card.dart              # Artist display card
    ├── artwork_mesh_background.dart  # Artwork-based background
    ├── auto_scroll_text.dart         # Auto-scrolling text
    ├── background_builder.dart       # Background generator
    ├── changelog_dialog.dart         # Changelog display
    ├── expandable_bottom.dart        # Expandable player sheet
    ├── glassmorphic_container.dart   # Glassmorphism effect
    ├── grainy_gradient_background.dart # Grainy gradient
    ├── library_tab.dart              # Library tab content
    ├── mesh_background.dart          # Mesh gradient
    ├── mini_player.dart              # Mini player bar
    ├── music_metadata_widget.dart    # Song metadata display
    ├── music_player_widgets.dart     # Player controls
    ├── onboarding_language_switcher.dart # Language selector
    ├── optimized_tiles.dart          # Performance-optimized tiles
    ├── outline_indicator.dart        # Tab indicator
    ├── performance_debug_overlay.dart # Debug overlay
    ├── pill_button.dart              # Rounded button component
    └── home/                         # Home screen widgets
        ├── home_tab.dart
        ├── search_tab.dart
        ├── settings_tab.dart
        ├── quick_access_section.dart
        ├── suggested_artists_section.dart
        └── suggested_tracks_section.dart
```

---

## Core Services

### 1. AudioPlayerService

**Location**: `lib/services/audio_player_service.dart`

**Purpose**: Core audio playback engine using `just_audio` package.

**Key Features**:
- Audio playback (play, pause, seek, skip)
- Playlist management
- Shuffle & repeat modes
- Background playback support
- Audio session management
- Sleep timer
- Play count tracking
- Volume normalization
- Gapless playback
- Playback speed control

**Key Methods**:
```dart
// Playback Control
Future<void> play()
Future<void> pause()
Future<void> seek(Duration position)
Future<void> skipNext()
Future<void> skipPrevious()

// Playlist Management
void setPlaylist(List<SongModel> songs, int startIndex)
void addToQueue(SongModel song)
void removeFromQueue(int index)

// Settings
void toggleShuffle()
void toggleRepeat()
void setPlaybackSpeed(double speed)
void setVolumeNormalization(bool enabled)

// Library Access
List<SongModel> get songs
List<AlbumModel> get albums
List<ArtistModel> get artists
List<Playlist> get playlists
```

**State Notifiers**:
- `isPlayingNotifier`: Current playback state
- `currentSongNotifier`: Currently playing song
- `playlistsNotifier`: Available playlists
- `isShuffleNotifier`: Shuffle mode
- `isRepeatNotifier`: Repeat mode

**Dependencies**:
- `just_audio`: Audio playback engine
- `audio_session`: Audio session management
- `just_audio_background`: Background playback
- `on_audio_query`: Media library access

---

### 2. LyricsService (TimedLyricsService)

**Location**: `lib/services/lyrics_service.dart`

**Purpose**: Fetches and manages synchronized lyrics from LRCLib API.

**Key Features**:
- Synchronized lyrics fetching
- Local caching (file-based and memory)
- Multi-result handling
- Duration validation
- Automatic retry logic
- Fuzzy matching for song titles

**API Integration**:
```
Base URL: https://lrclib.net/api
Endpoints:
  - GET /get (direct search)
  - GET /search (fuzzy search)
```

**Key Methods**:
```dart
// Fetch lyrics from API or cache
Future<List<TimedLyric>?> fetchTimedLyrics(
  String artist,
  String title, {
  Duration? songDuration,
  Function(String)? onLog,
  Function(List<Map<String, dynamic>>)? onMultipleResults,
})

// Load from local cache
Future<List<TimedLyric>?> loadLyricsFromFile(String artist, String title)

// Save to local cache
Future<void> saveLyricsToFile(String artist, String title, List<TimedLyric> lyrics)

// Memory cache for instant access
List<TimedLyric>? getCachedLyrics(String artist, String title)
Future<void> preloadLyricsToMemory(String artist, String title)
```

**Cache Strategy**:
1. **Memory Cache**: Up to 50 most recently accessed lyrics
2. **File Cache**: Persistent storage in app documents directory
3. **API Fallback**: If not cached, fetch from LRCLib API

**Data Model**:
```dart
class TimedLyric {
  final Duration timestamp;
  final String text;
}
```

---

### 3. ArtworkCacheService

**Location**: `lib/services/artwork_cache_service.dart`

**Purpose**: Manages album artwork with multi-source fallback.

**Sources** (in order of priority):
1. Local embedded artwork (from audio file)
2. Local file system cache
3. Deezer API
4. Spotify API (if configured)
5. Default placeholder image

**Key Methods**:
```dart
// Get cached or fetch artwork
Future<ImageProvider> getCachedImageProvider(int songId)

// Preload artwork for performance
Future<void> preloadArtwork(int songId)

// Clear cache
Future<void> clearCache()
```

**Cache Location**: `{appDocumentsDir}/artwork_cache/`

---

### 4. PlaylistService

**Location**: `lib/services/playlist_service.dart`

**Purpose**: Manages user-created and system playlists.

**Features**:
- Create/delete playlists
- Add/remove songs
- Playlist persistence (JSON file)
- "Liked Songs" system playlist
- Play count integration

**Key Methods**:
```dart
// CRUD operations
Future<void> createPlaylist(String name)
Future<void> deletePlaylist(String playlistId)
Future<void> addSongToPlaylist(String playlistId, SongModel song)
Future<void> removeSongFromPlaylist(String playlistId, int songId)

// Persistence
Future<void> savePlaylists(List<Playlist> playlists)
Future<List<Playlist>> loadPlaylists()
```

**Storage**: `{appDocumentsDir}/playlists.json`

---

### 5. BackgroundManagerService

**Location**: `lib/services/background_manager_service.dart`

**Purpose**: Manages dynamic gradient backgrounds based on album artwork.

**Features**:
- Extract dominant colors from artwork
- Generate smooth gradients
- Animate color transitions
- Performance optimization (debouncing, caching)

**Key Methods**:
```dart
// Update background based on artwork
void updateColors(List<Color> colors)

// Get current gradient
LinearGradient getCurrentGradient()

// Animation control
void enableAnimations(bool enabled)
```

---

### 6. BatchDownloadService

**Location**: `lib/services/batch_download_service.dart`

**Purpose**: Bulk download lyrics and artwork for entire library.

**Features**:
- Concurrent downloads (max 10 at a time)
- Progress tracking
- Error handling
- Cache statistics
- Resume capability

**Key Methods**:
```dart
// Start batch download
Future<void> startBatchDownload({
  required bool downloadLyrics,
  required bool downloadArtwork,
})

// Monitor progress
Stream<DownloadProgress> get progressStream

// Get cache stats
Future<Map<String, int>> getCacheStatistics()
```

**Progress Model**:
```dart
class DownloadProgress {
  final int total;
  final int completed;
  final int failed;
  final int inProgress;
  final bool isDownloading;
  final String? currentStatus;
  
  double get percentage
  bool get isComplete
}
```

---

### 7. ErrorTrackingService

**Location**: `lib/services/error_tracking_service.dart`

**Purpose**: Centralized error logging and tracking.

**Features**:
- Error recording with stack traces
- Persistent error storage
- Error categorization
- Rate limiting to prevent spam

**Key Methods**:
```dart
// Record an error
Future<void> recordError(dynamic error, StackTrace? stackTrace)

// Get error history
List<ErrorRecord> getRecentErrors()

// Clear errors
Future<void> clearErrors()
```

---

### 8. SleepTimerController

**Location**: `lib/services/sleep_timer_controller.dart`

**Purpose**: Sleep timer with fade-out functionality.

**Features**:
- Customizable duration
- Volume fade-out
- Auto-pause playback
- Progress notifications

**Key Methods**:
```dart
// Set sleep timer
void setSleepTimer(Duration duration)

// Cancel timer
void cancelSleepTimer()

// Get remaining time
Duration? get remainingTime
```

---

### 9. PerformanceMonitoringService

**Location**: `lib/services/performance_monitoring_service.dart`

**Purpose**: Monitor app performance and FPS.

**Features**:
- Frame rate monitoring
- Performance metrics collection
- Automatic optimization triggers
- Debug overlay integration

---

### 10. BluetoothService

**Location**: `lib/services/bluetooth_service.dart`

**Purpose**: Detect Bluetooth device connections.

**Features**:
- Bluetooth connection monitoring
- Status notifications
- UI updates on connection changes

---

## Screens & Navigation

### Screen Hierarchy

```
SplashScreen (Entry Point)
    ↓
    ├→ OnboardingScreen (First Time Users)
    │   └→ PageView with 10 pages:
    │       1. WelcomePage
    │       2. AppInfoPage
    │       3. LanguageSelectionPage
    │       4. ThemeSelectionPage
    │       5. PermissionsPage
    │       6. InternetUsagePage
    │       7. AssetDownloadPage
    │       8. DownloadChoicePage
    │       9. DownloadProgressPage
    │       10. CompletionPage
    │
    └→ HomeScreen (Returning Users)
        ├→ Tab 1: HomeTab
        ├→ Tab 2: SearchTab
        ├→ Tab 3: LibraryTab
        └→ Tab 4: SettingsTab
        
        Navigation Options:
        ├→ NowPlayingScreen (Full player)
        ├→ FullscreenLyricsScreen
        ├→ AlbumDetailScreen
        ├→ ArtistDetailsScreen
        ├→ PlaylistDetailScreen
        ├→ FolderDetailScreen
        ├→ TracksScreen
        ├→ ArtistsScreen
        ├→ AlbumsScreen
        ├→ PlaylistsScreenList
        └→ FoldersScreen
```

### Screen Details

#### 1. SplashScreen

**File**: `lib/screens/splash_screen.dart`

**Purpose**: Initial loading screen with app initialization.

**Responsibilities**:
- Load environment variables (.env)
- Initialize services
- Warmup shaders
- Check permissions
- Preload images
- Navigate to appropriate screen

**Animation**: Lottie animation with fade transitions

**Tasks**:
1. Warming shaders
2. Initializing Services
3. Loading Library
4. Caching Artwork
5. Final Preparations

**Transition**: Zoom-in crossfade to next screen (900ms)

---

#### 2. OnboardingScreen

**File**: `lib/screens/onboarding/onboarding_screen.dart`

**Purpose**: First-time user experience and setup.

**Flow**:
```
Welcome → App Info → Language → Theme → Permissions → 
Internet → Download Assets → Download Choice → Progress → Complete
```

**Features**:
- Smooth page transitions
- Progress tracking
- Exit animations
- State preservation
- Skip functionality

**Pages**:

##### WelcomePage
- Welcome message
- App branding
- "Get Started" button
- Fade & slide animations

##### AppInfoPage
- App features overview
- Key capabilities
- Material You design showcase

##### LanguageSelectionPage
- Language selection (English, Czech)
- Real-time preview
- Persistent selection

##### ThemeSelectionPage
- Light/Dark/System theme
- Dynamic color toggle
- Material You integration
- Live preview

##### PermissionsPage
- Required permissions:
  - Storage (required)
  - Audio library access (required)
  - Notifications (optional)
  - Bluetooth (optional)
- Permission request handling
- Grant status display

##### InternetUsagePage
- Internet usage preferences
- Data saving options
- Wi-Fi only mode

##### AssetDownloadPage
- Asset download preferences
- Lyrics download toggle
- Artwork download toggle

##### DownloadChoicePage
- Choose what to download
- Lyrics + Artwork options

##### DownloadProgressPage
- Real-time progress bar
- Current item display
- Completed/Failed count
- Skip option
- Completion detection

##### CompletionPage
- Setup complete message
- "Start Listening" button
- Celebration animation

---

#### 3. HomeScreen

**File**: `lib/screens/home_screen.dart`

**Purpose**: Main application interface with 4 tabs.

**Structure**:
```dart
Scaffold
├── AppBar (Custom with Bluetooth status)
├── TabBarView
│   ├── HomeTab
│   ├── SearchTab
│   ├── LibraryTab
│   └── SettingsTab
└── ExpandableBottomSheet (Mini Player)
```

**Features**:
- Tab navigation with custom indicator
- Collapsible app bar
- Bluetooth connection status
- Download progress notifications
- Version checking
- Changelog display
- Permission handling
- Back button handling (collapse player or exit)

**Tabs**:

##### HomeTab
**File**: `lib/widgets/home/home_tab.dart`

**Content**:
- Welcome message
- Quick access section (Recently played, Liked songs)
- Suggested tracks (3 featured songs)
- Suggested artists (3 featured artists)
- Animated list items

##### SearchTab
**File**: `lib/widgets/home/search_tab.dart`

**Features**:
- Real-time search
- Search by: Songs, Artists, Albums
- Debounced search (300ms)
- Recent searches
- Search suggestions
- Empty state handling

##### LibraryTab
**File**: `lib/widgets/library_tab.dart`

**Sections**:
- Songs (most played)
- Albums (most played)
- Playlists (top 3)
- Artists (most played)
- Folders (top 3)
- "See All" navigation for each section

##### SettingsTab
**File**: `lib/widgets/home/settings_tab.dart`

**Categories**:

**Playback Settings**:
- Gapless playback
- Volume normalization
- Playback speed

**Library Settings**:
- Default sort order
- Auto-generated playlists
- Cache size

**Interface Settings**:
- Theme selection
- Language selection
- Dynamic colors

**About**:
- App version
- Changelog
- About dialog
- Credits
- GitHub repository link

---

#### 4. NowPlayingScreen

**File**: `lib/screens/now_playing.dart`

**Purpose**: Full-screen player with lyrics.

**Layout**:
```
┌─────────────────────────────────┐
│   < Back    Title    Menu       │
├─────────────────────────────────┤
│                                 │
│      Album Artwork (Large)      │
│      with Mesh Background       │
│                                 │
├─────────────────────────────────┤
│    Song Title                   │
│    Artist Name                  │
├─────────────────────────────────┤
│  Synced Lyrics Display          │
│  (Auto-scroll, Animated)        │
├─────────────────────────────────┤
│    Progress Bar                 │
│    0:00          3:45           │
├─────────────────────────────────┤
│  [Prev] [Play/Pause] [Next]     │
│  [Shuffle] [Repeat] [Sleep]     │
└─────────────────────────────────┘
```

**Features**:
- Full-screen album artwork
- Animated mesh gradient background
- Synced lyrics with auto-scroll
- Current line highlighting
- Tap to seek (lyrics)
- Expand to fullscreen lyrics
- Playback controls
- Queue management
- Like/Unlike song
- Add to playlist
- Sleep timer
- Share song

**Lyrics Display**:
- 5 lines visible (current ± 2)
- Smooth scroll animation
- Opacity gradient for non-current lines
- Tap lyric to seek to that timestamp

**Gestures**:
- Swipe down: Close player
- Tap lyrics: Expand to fullscreen
- Tap artwork: Focus/unfocus

---

#### 5. FullscreenLyricsScreen

**File**: `lib/screens/fullscreen_lyrics.dart`

**Purpose**: Dedicated fullscreen lyrics view.

**Features**:
- Large, readable text
- Auto-scroll
- Manual scroll with auto-resume
- Seek by tapping lines
- Blur background
- Minimal UI

---

#### 6. Detail Screens

##### AlbumDetailScreen
**File**: `lib/screens/AlbumDetailScreen.dart`
- Album artwork
- Album info (name, artist, year)
- Track listing
- Play all / Shuffle
- Track count

##### ArtistDetailsScreen
**File**: `lib/screens/Artist_screen.dart`
- Artist name
- Song count
- All songs by artist
- Play all / Shuffle
- Sort options

##### PlaylistDetailScreen
**File**: `lib/screens/PlaylistDetail_screen.dart`
- Playlist name
- Edit playlist (rename, delete)
- Track listing with reorder
- Remove tracks
- Play all / Shuffle

##### FolderDetailScreen
**File**: `lib/screens/FolderDetail_screen.dart`
- Folder path
- Files in folder
- Subfolder navigation
- Play all

---

## Widgets & UI Components

### Core UI Components

#### 1. ExpandableBottomSheet

**File**: `lib/widgets/expandable_bottom.dart`

**Purpose**: Expandable mini player that grows to full-screen player.

**States**:
- **Collapsed**: Mini player bar
- **Expanded**: Full NowPlayingScreen

**Features**:
- Smooth drag animation
- Snap to positions
- Backdrop blur
- Gesture handling
- Scroll physics

**Controller**: `ExpandablePlayerController`

---

#### 2. MiniPlayer

**File**: `lib/widgets/mini_player.dart`

**Purpose**: Compact player bar at bottom of screen.

**Display**:
```
[Artwork] Song Title - Artist    [Play/Pause] [Next]
```

**Features**:
- Auto-scrolling text for long titles
- Tap to expand
- Quick controls (play/pause, skip)
- Progress indicator

---

#### 3. PillButton

**File**: `lib/widgets/pill_button.dart`

**Purpose**: Consistent button component across app.

**Variants**:
- Primary (filled)
- Outlined

**Features**:
- Loading state
- Disabled state
- Icon support
- Custom width
- Consistent 32px border radius

**Usage**:
```dart
PillButton(
  text: 'Continue',
  onPressed: () => handleContinue(),
  isPrimary: true,
  icon: Icons.arrow_forward,
  isLoading: isProcessing,
)
```

---

#### 4. GlassmorphicContainer

**File**: `lib/widgets/glassmorphic_container.dart`

**Purpose**: Frosted glass effect container.

**Features**:
- Backdrop blur
- Semi-transparent background
- Border styling
- Customizable blur intensity

---

#### 5. AutoScrollText

**File**: `lib/widgets/auto_scroll_text.dart`

**Purpose**: Horizontally scrolling text for overflow.

**Features**:
- Automatic scroll on overflow
- Smooth animation
- Pause on end
- Loop support

---

#### 6. ArtistCard

**File**: `lib/widgets/artist_card.dart`

**Purpose**: Display artist with circular avatar.

**Features**:
- Circular artwork
- Artist name
- Song count
- Tap to navigate

---

#### 7. Background Components

##### AnimatedMeshGradient
**File**: `lib/widgets/animated_mesh_gradient.dart`
- Smooth color transitions
- Multiple color stops
- Animation controller

##### ArtworkMeshBackground
**File**: `lib/widgets/artwork_mesh_background.dart`
- Extract colors from artwork
- Generate mesh gradient
- Cache for performance

##### GrainyGradientBackground
**File**: `lib/widgets/grainy_gradient_background.dart`
- Gradient with grain texture
- Subtle noise overlay

---

#### 8. OptimizedTiles

**File**: `lib/widgets/optimized_tiles.dart`

**Purpose**: Performance-optimized list tiles.

**Features**:
- Lazy loading
- Image caching
- Repaint boundaries
- Debounced callbacks

---

#### 9. PerformanceDebugOverlay

**File**: `lib/widgets/performance_debug_overlay.dart`

**Purpose**: Development tool for performance monitoring.

**Display**:
- FPS counter
- Memory usage
- Frame build time
- Jank detection

---

## State Management

### Provider Architecture

#### Providers in Use

1. **AudioPlayerService** (ChangeNotifier)
   - Manages: Audio playback state
   - Notifies on: Song change, play/pause, playlist updates

2. **ThemeProvider** (ChangeNotifier)
   - Manages: Theme mode, dynamic colors
   - Notifies on: Theme changes

3. **ExpandablePlayerController** (ChangeNotifier)
   - Manages: Player expansion state
   - Notifies on: Expand/collapse

4. **PerformanceModeProvider** (ChangeNotifier)
   - Manages: Performance optimization settings
   - Notifies on: Performance mode changes

5. **BackgroundManagerService** (ChangeNotifier)
   - Manages: Background gradient colors
   - Notifies on: Color updates

6. **SleepTimerController** (ChangeNotifier)
   - Manages: Sleep timer state
   - Notifies on: Timer updates

7. **ErrorTrackingService** (Provider)
   - Singleton service for error tracking

### ValueNotifiers

Used for granular reactive updates:

```dart
// Audio Player
ValueNotifier<bool> isPlayingNotifier
ValueNotifier<SongModel?> currentSongNotifier
ValueNotifier<Uint8List?> currentArtwork
ValueNotifier<List<Playlist>> playlistsNotifier

// Sleep Timer
ValueNotifier<Duration?> sleepTimerDurationNotifier

// Shuffle/Repeat
ValueNotifier<bool> isShuffleNotifier
ValueNotifier<bool> isRepeatNotifier
```

### StreamControllers

For event-based updates:

```dart
// Audio Player
StreamController<SongModel?> currentSongStream
StreamController<String> errorStream

// Lyrics
StreamController<List<TimedLyric>> lyricsStream

// Downloads
StreamController<DownloadProgress> progressStream
StreamController<String> downloadStatusStream
```

---

## API Integrations

### 1. LRCLib API

**Base URL**: `https://lrclib.net/api`

**Purpose**: Synchronized lyrics fetching

**Endpoints**:

#### GET /get
Get lyrics by exact match.

**Query Parameters**:
- `artist_name` (string): Artist name
- `track_name` (string): Song title
- `album_name` (string, optional): Album name
- `duration` (int, optional): Song duration in seconds

**Response**:
```json
{
  "id": 123,
  "trackName": "Song Title",
  "artistName": "Artist Name",
  "albumName": "Album Name",
  "duration": 180,
  "plainLyrics": "Line 1\nLine 2\n...",
  "syncedLyrics": "[00:00.00] Line 1\n[00:05.50] Line 2\n..."
}
```

#### GET /search
Search lyrics by fuzzy match.

**Query Parameters**:
- `q` (string): Search query
- `artist_name` (string, optional): Filter by artist
- `track_name` (string, optional): Filter by track

**Response**: Array of matches

**Rate Limiting**: None specified (be respectful)

**Caching Strategy**:
1. Check memory cache
2. Check file cache
3. API request
4. Save to caches

---

### 2. Deezer API

**Base URL**: `https://api.deezer.com`

**Purpose**: Album artwork fetching

**Endpoint**:

#### GET /search
Search for albums/tracks.

**Query Parameters**:
- `q` (string): Search query (format: "artist:Artist track:Title")

**Response**:
```json
{
  "data": [
    {
      "id": 123,
      "title": "Song Title",
      "artist": {
        "name": "Artist Name"
      },
      "album": {
        "cover": "https://...",
        "cover_small": "https://...",
        "cover_medium": "https://...",
        "cover_big": "https://...",
        "cover_xl": "https://..."
      }
    }
  ]
}
```

**Usage**:
- Fallback when local artwork not available
- Cached after first fetch

---

### 3. Spotify API (Optional)

**Base URL**: `https://api.spotify.com/v1`

**Purpose**: Enhanced metadata, artwork

**Configuration**: Requires client ID and secret in `.env`

**Status**: Optional, not enabled by default

---

## Data Models

### 1. SongModel

**Source**: `on_audio_query` package

**Properties**:
```dart
class SongModel {
  int id
  String title
  String? artist
  String? album
  int? duration
  String? data (file path)
  int? size
  String? displayName
  String? composer
  int? dateAdded
  int? dateModified
  int? year
  int? bookmark
  int? track
  // ... more properties
}
```

---

### 2. Playlist

**File**: `lib/models/playlist_model.dart`

**Properties**:
```dart
class Playlist {
  String id
  String name
  List<int> songIds
  DateTime createdAt
  DateTime? lastModified
  int playCount
  
  // Methods
  Map<String, dynamic> toJson()
  static Playlist fromJson(Map<String, dynamic> json)
}
```

---

### 3. TimedLyric

**File**: `lib/models/timed_lyrics.dart`

**Properties**:
```dart
class TimedLyric {
  Duration timestamp
  String text
  
  // Methods
  Map<String, dynamic> toJson()
  static TimedLyric fromJson(Map<String, dynamic> json)
  static TimedLyric fromLRC(String line)
}
```

**LRC Format**:
```
[mm:ss.xx] Lyric text
Example: [00:12.50] Hello world
```

---

### 4. SpotifySongModel

**File**: `lib/models/utils.dart`

**Properties**:
```dart
class SpotifySongModel {
  String name
  String artist
  String? albumArt
  String? previewUrl
  String spotifyId
}
```

---

### 5. VersionCheckResult

**File**: `lib/models/version_check_result.dart`

**Properties**:
```dart
class VersionCheckResult {
  String currentVersion
  String latestVersion
  bool hasUpdate
  String? changelogUrl
  bool isRequired
}
```

---

## Localization

### Supported Languages
- **English** (en) - Default
- **Czech** (cs)

### Files
- `assets/translations/en.json`
- `assets/translations/cs.json`

### Usage

```dart
// In any widget
AppLocalizations.of(context).translate('key')

// Available keys (examples):
- 'home'
- 'search'
- 'library'
- 'settings'
- 'now_playing'
- 'play'
- 'pause'
- 'next'
- 'previous'
- 'shuffle'
- 'repeat'
// ... 100+ keys
```

### Adding Translations

1. Add key-value to both JSON files
2. Use via `translate()` method
3. Rebuild app

### Language Switching

```dart
// Get locale provider
final localeProvider = LocaleProvider.of(context);

// Change language
localeProvider.setLocale(Locale('cs'));
```

**Persistence**: Saved to SharedPreferences

---

## Performance Optimizations

### 1. Image Caching

**Configuration** (in main.dart):
```dart
ImageCache().maximumSize = 1024
ImageCache().maximumSizeBytes = 200 * 1024 * 1024 // 200 MB
```

**Strategies**:
- Artwork pre-caching
- Thumbnail generation
- Memory limits
- Disk caching

---

### 2. Shader Warmup

**Service**: `ShaderWarmupService`

**Purpose**: Pre-compile shaders to prevent jank.

**Shaders Warmed**:
- Gradients
- Blurs
- Opacity
- Transforms

**Timing**: During splash screen

---

### 3. Repaint Boundaries

Used extensively on:
- List tiles
- Album artwork
- Player controls
- Tab content

**Effect**: Isolates repainting to specific widgets

---

### 4. Lazy Loading

**Implemented in**:
- Song lists (virtualized scrolling)
- Album grids
- Artist lists
- Search results

---

### 5. Debouncing

**Search**: 300ms debounce
**Background updates**: 500ms debounce
**Scroll events**: 100ms debounce

---

### 6. Performance Monitoring

**Service**: `PerformanceMonitoringService`

**Metrics**:
- FPS (target: 60)
- Frame build time
- Jank detection (>16ms frames)
- Memory usage

**Auto-optimization**:
- Reduce animations on low FPS
- Lower blur quality
- Simplify backgrounds

---

### 7. Background Management

**Strategies**:
- Single background instance
- Color transition caching
- Reduced gradient complexity
- Conditional rendering based on device

---

## Build & Deployment

### Development Build

```bash
# Get dependencies
flutter pub get

# Run in debug mode
flutter run

# Run on specific device
flutter run -d <device-id>
```

### Production Build

#### Android APK
```bash
# Build release APK
flutter build apk --release

# Build App Bundle (for Play Store)
flutter build appbundle --release

# Build split APKs (smaller size)
flutter build apk --split-per-abi --release
```

**Output**: `build/app/outputs/flutter-apk/`

#### iOS
```bash
# Build iOS app
flutter build ios --release
```

**Note**: Requires macOS and Xcode

#### Windows
```bash
# Build Windows executable
flutter build windows --release
```

**Output**: `build/windows/runner/Release/`

---

### Environment Variables

**File**: `.env` (copy from `.env.example`)

```bash
# Optional API keys
SPOTIFY_CLIENT_ID=your_client_id
SPOTIFY_CLIENT_SECRET=your_secret
LASTFM_API_KEY=your_key

# Feature flags
ENABLE_CLOUD_SYNC=false
ENABLE_SOCIAL_FEATURES=false

# Build config
FLAVOR=production
```

---

### Signing (Android)

**Location**: `android/key.properties`

```properties
storePassword=<password>
keyPassword=<password>
keyAlias=<alias>
storeFile=<path-to-keystore>
```

**Generate Keystore**:
```bash
keytool -genkey -v -keystore ~/upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload
```

---

### Version Management

**File**: `pubspec.yaml`

```yaml
version: 0.1.0+1
#         │ │ │  │
#         │ │ │  └─ Build number (Android: versionCode)
#         │ │ └──── Patch version
#         │ └────── Minor version
#         └──────── Major version
```

**Update Version**:
1. Edit `pubspec.yaml`
2. Update `CHANGELOG.md`
3. Rebuild app

---

### Dependencies

#### Core
- `flutter`: Framework
- `provider`: State management
- `shared_preferences`: Local storage

#### Audio
- `just_audio`: Audio playback
- `just_audio_background`: Background playback
- `audio_session`: Session management
- `on_audio_query`: Media library access
- `audio_service`: Background service

#### UI/UX
- `flutter_animate`: Animations
- `animations`: Material animations
- `lottie`: Lottie animations
- `flutter_staggered_animations`: Staggered lists
- `dynamic_color`: Material You colors

#### Network
- `http`: HTTP requests
- `url_launcher`: Open URLs

#### Utilities
- `permission_handler`: Runtime permissions
- `package_info_plus`: App version info
- `path_provider`: File system paths
- `device_info_plus`: Device information
- `share_plus`: Share functionality

#### API/Data
- `spotify`: Spotify SDK (optional)
- `palette_generator`: Color extraction
- `html`: HTML parsing (lyrics)
- `crypto`: Hashing (cache keys)

#### Dev Tools
- `flutter_test`: Testing
- `flutter_lints`: Linting
- `logger`: Debug logging
- `dependency_validator`: Dependency checking

---

### Testing

```bash
# Run all tests
flutter test

# Run with coverage
flutter test --coverage

# Run specific test
flutter test test/widget_test.dart
```

**Test Location**: `test/`

---

### Code Quality

```bash
# Analyze code
flutter analyze

# Fix common issues
dart fix --apply

# Format code
dart format lib/
```

---

## Architecture Decisions

### Why Provider?
- Simple and performant
- Official Flutter recommendation
- Good for medium-complexity apps
- Easy to debug

### Why just_audio?
- Best audio plugin for Flutter
- Gapless playback
- Background support
- Active maintenance

### Why Singleton Services?
- Global state (audio, settings)
- Resource efficiency
- Easy access from any widget

### Why File-based Cache?
- Persistence across sessions
- No dependency on external DB
- Fast access
- Easy to manage/clear

---

## Security Considerations

### API Keys
- Stored in `.env` (not committed)
- Not required for core functionality
- Only for optional features

### Permissions
- Request only when needed
- Explain why in UI
- Handle denials gracefully

### Data Privacy
- All data stored locally
- No analytics by default
- No user tracking
- No internet required (except lyrics/artwork)

---

## Future Enhancements

### Planned Features
- [ ] Cloud backup/sync
- [ ] Equalizer
- [ ] Crossfade
- [ ] Smart playlists
- [ ] Gesture controls
- [ ] Widget support
- [ ] Android Auto
- [ ] CarPlay (iOS)
- [ ] Scrobbling (Last.fm)
- [ ] Queue management
- [ ] Folder browsing improvements

### Performance
- [ ] Native UI rendering
- [ ] Reduce app size
- [ ] Faster startup
- [ ] Better memory management

### UI/UX
- [ ] More themes
- [ ] Custom accent colors
- [ ] Tablet optimization
- [ ] Landscape mode
- [ ] Accessibility improvements

---

## Troubleshooting

### Common Issues

#### 1. Lyrics Not Loading
- Check internet connection
- Verify song metadata (artist/title)
- Clear lyrics cache
- Check API availability

#### 2. Artwork Not Showing
- Check permissions
- Verify internet (for external sources)
- Clear artwork cache
- Check embedded artwork

#### 3. Audio Not Playing
- Check permissions
- Verify file exists
- Check audio format support
- Restart app

#### 4. App Crashes
- Check error logs
- Verify permissions
- Update dependencies
- Clear app data

---

## Contributing

### Code Style
- Follow Dart style guide
- Use `dart format`
- Add doc comments
- Keep functions small

### Commit Messages
```
type(scope): subject

body

footer
```

**Types**: feat, fix, docs, style, refactor, test, chore

### Pull Requests
1. Fork repository
2. Create feature branch
3. Make changes
4. Add tests
5. Submit PR

---

## License

**License**: MIT (or your preferred license)

---

## Credits

### Developer
- David (D4v31x)

### Dependencies
See `pubspec.yaml` for full list

### APIs
- LRCLib.net (Lyrics)
- Deezer API (Artwork)

### Fonts
- Product Sans (Google)
- Outfit (Google Fonts)

---

## Contact

- **GitHub**: https://github.com/D4v31x/Aurora-Music
- **Issues**: https://github.com/D4v31x/Aurora-Music/issues

---

**Document Version**: 1.0  
**Last Updated**: November 1, 2025  
**App Version**: 0.1.0+1
