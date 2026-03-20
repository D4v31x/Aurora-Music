/// Application-wide configuration constants
class AppConfig {
  // Performance Configuration 
  static const int imageCacheMaxSize = 100;
  static const int imageCacheMaxSizeBytes = 80 * 1024 * 1024; // 80 MB

  // Cache Configuration
  static const int maxCacheSize = 150;
  static const Duration cacheCleanupInterval = Duration(minutes: 3); 

  // Audio Configuration
  static const String androidNotificationChannelId = 'com.aurorasoftware.music.channel.audio';
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
  static const Duration defaultAnimationDuration =
      Duration(milliseconds: 250);
  static const Duration fastAnimationDuration =
      Duration(milliseconds: 150);
  static const Duration slowAnimationDuration =
      Duration(milliseconds: 350);

  /// Cache extent for lists
  static const double listCacheExtent = 400.0;
  static const double largeListCacheExtent = 800.0;
  static const double horizontalListCacheExtent = 250.0;

  /// Blur sigmas for glassmorphic effects
  static const double standardBlurSigma = 8.0;
  static const double heavyBlurSigma = 15.0;
  static const double maxBlurSigma = 25.0;

  /// Number of upcoming tracks to preload artwork for
  static const int artworkPreloadCount = 3;

  static const Duration notifyDebounce = Duration(milliseconds: 16);
  static const Duration saveDebounce = Duration(seconds: 2);
  static const Duration searchDebounce = Duration(milliseconds: 300);

  static const double scrollFriction = 0.015;
  static const double scrollVelocityScale = 1.0;

  static const int maxConcurrentImageLoads = 4;
  static const int thumbnailSize = 200;
  static const int highQualityArtworkSize = 500;
}
