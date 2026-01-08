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

  // Image Sizes for Performance (avoids oversized bitmaps)
  static const double thumbnailSize = 60.0;
  static const double cardArtworkSize = 130.0;
  static const double gridArtworkSize = 150.0;
  static const double largeArtworkSize = 400.0;
  
  // List Performance Settings
  static const double listItemHeight = 76.0; // For itemExtent in ListView.builder
}
