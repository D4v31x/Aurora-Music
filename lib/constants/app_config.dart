/// Application-wide configuration constants
/// Centralizes all configuration values for better maintainability
class AppConfig {
  // Performance Configuration - Optimized for better memory usage
  static const int imageCacheMaxSize =
      150; // Reduced from 1024 for better performance
  static const int imageCacheMaxSizeBytes =
      100 * 1024 * 1024; // 100 MB (reduced from 200 MB)

  // Cache Configuration
  static const int maxCacheSize = 200;
  static const Duration cacheCleanupInterval = Duration(minutes: 5);

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

  // Timing Configuration
  static const Duration defaultAnimationDuration = Duration(milliseconds: 300);
  static const Duration fastAnimationDuration = Duration(milliseconds: 200);
  static const Duration slowAnimationDuration = Duration(milliseconds: 400);

  // List Performance Configuration
  /// Cache extent for lists - how much to preload beyond visible area
  static const double listCacheExtent = 500.0;

  /// Large list cache extent for very long scrollable content
  static const double largeListCacheExtent = 1000.0;

  // Blur Configuration for Performance
  /// Standard blur sigma for glassmorphic effects
  static const double standardBlurSigma = 10.0;

  /// Heavy blur sigma for backgrounds (e.g., now playing)
  static const double heavyBlurSigma = 20.0;

  /// Maximum blur sigma - higher values don't provide visible benefit
  static const double maxBlurSigma = 30.0;

  // Artwork Preloading Configuration
  /// Number of upcoming tracks to preload artwork for
  static const int artworkPreloadCount = 5;
}
