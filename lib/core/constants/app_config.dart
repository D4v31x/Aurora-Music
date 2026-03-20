/// Application-wide configuration constants
/// Centralizes all configuration values for better maintainability
class AppConfig {
  // Performance Configuration - Optimized for better memory usage
  static const int imageCacheMaxSize =
      100; // Reduced from 150 for better memory management
  static const int imageCacheMaxSizeBytes =
      80 * 1024 * 1024; // 80 MB (reduced from 100 MB for lower memory devices)

  // Cache Configuration
  static const int maxCacheSize = 150; // Reduced from 200
  static const Duration cacheCleanupInterval =
      Duration(minutes: 3); // More frequent cleanup

  // Audio Configuration
  static const String androidNotificationChannelId =
      'com.aurorasoftware.music.channel.audio';
  static const String androidNotificationChannelName = 'Audio playback';

  // Default Values
  static const String defaultLanguageCode = 'en';
  static const String appName = 'Aurora Music';

  // Error Tracking Configuration
  static const String errorStorageKey = 'pending_errors';
  static const int maxStoredErrors = 10;
  static const int maxErrorStringLength = 4900;
  static const int maxErrorMessageLength = 200;

  // UI Configuration
  static const double defaultBlurSigma = 5.0;
  static const double shaderWarmupSize = 100.0;

  // Timing Configuration - Optimized for smooth feel
  static const Duration defaultAnimationDuration =
      Duration(milliseconds: 250); // Faster default
  static const Duration fastAnimationDuration =
      Duration(milliseconds: 150); // Snappier
  static const Duration slowAnimationDuration =
      Duration(milliseconds: 350); // Slightly faster

  // List Performance Configuration
  /// Cache extent for lists - how much to preload beyond visible area
  static const double listCacheExtent = 400.0; // Reduced for lower memory usage

  /// Large list cache extent for very long scrollable content
  static const double largeListCacheExtent = 800.0; // Reduced from 1000

  /// Horizontal list cache extent - smaller for horizontal scrolling
  static const double horizontalListCacheExtent = 250.0; // Reduced from 300

  // Blur Configuration for Performance
  /// Standard blur sigma for glassmorphic effects
  static const double standardBlurSigma =
      8.0; // Reduced from 10 for performance

  /// Heavy blur sigma for backgrounds (e.g., now playing)
  static const double heavyBlurSigma = 15.0; // Reduced from 20 for performance

  /// Maximum blur sigma - higher values don't provide visible benefit
  static const double maxBlurSigma = 25.0; // Reduced from 30

  // Artwork Preloading Configuration
  /// Number of upcoming tracks to preload artwork for
  static const int artworkPreloadCount = 3; // Reduced from 5 for memory

  // Debounce Configuration
  /// Debounce duration for notifications to batch rapid updates
  static const Duration notifyDebounce = Duration(milliseconds: 16); // ~60fps

  /// Debounce duration for saving data to disk
  static const Duration saveDebounce = Duration(seconds: 2);

  /// Debounce duration for search input
  static const Duration searchDebounce = Duration(milliseconds: 300);

  // Scroll Physics Configuration
  /// Android-style scroll physics parameters
  static const double scrollFriction = 0.015; // Lower = more momentum
  static const double scrollVelocityScale = 1.0;

  // Image Loading Configuration
  /// Maximum concurrent image loads
  static const int maxConcurrentImageLoads = 4;

  /// Thumbnail size for list items
  static const int thumbnailSize = 200; // Reduced from 500 for faster loading

  /// High quality artwork size for now playing
  static const int highQualityArtworkSize = 500;
}
