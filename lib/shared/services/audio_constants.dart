/// Audio player constants.
///
/// Contains all constant values used across the audio player services.
library;

// MARK: - Playlist Constants

/// The constant ID for the liked songs playlist.
const String kLikedSongsPlaylistId = 'liked_songs';

/// The constant ID for the most played playlist.
const String kMostPlayedPlaylistId = 'most_played';

/// The constant ID for the recently added playlist.
const String kRecentlyAddedPlaylistId = 'recently_added';

// MARK: - File Names

/// Filename for storing play counts.
const String kPlayCountsFileName = 'play_counts.json';

/// Filename for storing playlists.
const String kPlaylistsFileName = 'playlists.json';

/// Filename for storing library data.
const String kLibraryFileName = 'library.json';

/// Filename for storing liked songs.
const String kLikedSongsFileName = 'liked_songs.json';

/// Filename for storing queue state (current queue, index, position, shuffle/repeat).
const String kQueueStateFileName = 'queue_state.json';

// MARK: - Playback Thresholds

/// How many seconds must have elapsed before the "previous" control restarts
/// the current track instead of jumping to the previous one.
const int kPreviousThresholdSeconds = 3;

// MARK: - Debounce Timers

/// Debounce delay for batch notifications (milliseconds).
const int kNotifyDebounceMs = 100;

/// Debounce delay for saving data to disk (milliseconds).
const int kSaveDebounceMs = 2000;

// MARK: - Cache Settings

/// Default cache size in MB.
const int kDefaultCacheSize = 200;

/// Cache cleanup interval in hours.
const int kCacheCleanupIntervalHours = 24;

// MARK: - Query Limits

/// Default number of items for "top" queries (most played, recently added).
const int kDefaultTopItemCount = 10;

/// Number of items for "recently played" preview.
const int kRecentlyPlayedPreviewCount = 3;

/// Number of playlists for preview.
const int kPlaylistPreviewCount = 3;

/// Number of folders for preview.
const int kFolderPreviewCount = 3;

// MARK: - Audio Session Settings

/// Whether to pause playback when audio is ducked.
const bool kPauseWhenDucked = true;

// MARK: - Path Validation

/// Path patterns that are not allowed to prevent directory traversal.
const List<String> kForbiddenPathPatterns = ['..', '~', r'$'];

/// Maximum path length allowed.
const int kMaxPathLength = 4096;

// MARK: - URL Validation

/// Allowed audio file extensions.
const List<String> kAllowedAudioExtensions = [
  '.mp3',
  '.m4a',
  '.aac',
  '.wav',
  '.flac',
  '.ogg',
  '.opus',
  '.wma',
];

/// Allowed URI schemes for audio loading.
const List<String> kAllowedUriSchemes = [
  'file',
  'content',
  'asset',
  'http',
  'https',
];

// MARK: - Error Messages

/// Error message for invalid playlist.
const String kErrorInvalidPlaylist = 'Invalid playlist or start index';

/// Error message for permission denied.
const String kErrorPermissionDenied = 'Storage permission denied';

/// Error message for audio load failure.
const String kErrorAudioLoadFailed = 'Failed to load audio file';

/// Error message for invalid file path.
const String kErrorInvalidPath = 'Invalid file path';
