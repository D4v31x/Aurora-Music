/// Performance optimization constants for Aurora Music
/// This file centralizes all performance-related configurations
class PerformanceConfig {
  PerformanceConfig._(); // Private constructor to prevent instantiation

  // Image cache configuration
  static const int imageCacheMaxSize = 150; // Maximum number of images in cache
  static const int imageCacheMaxSizeBytes = 100 << 20; // 100 MB in bytes

  // List view optimization
  static const double listItemCacheExtent = 500; // Pixels to cache ahead
  static const int maxVisibleListItems = 20; // Max items to render at once

  // Animation durations
  static const Duration shortAnimationDuration = Duration(milliseconds: 200);
  static const Duration mediumAnimationDuration = Duration(milliseconds: 300);
  static const Duration longAnimationDuration = Duration(milliseconds: 500);

  // Debounce timings
  static const Duration searchDebounce = Duration(milliseconds: 300);
  static const Duration scrollDebounce = Duration(milliseconds: 100);

  // Widget rebuild optimization
  static const bool enableRepaintBoundaries = true;
  static const bool enableAutomaticKeepAlives = false; // Disable for lists

  // Background task optimization
  static const int maxConcurrentImageLoads = 3;
  static const int maxConcurrentArtworkQueries = 5;

  // Memory management
  static const int lowMemoryThresholdMB = 100;
  static const bool aggressiveMemoryManagement = true;

  // Scroll physics
  static const bool useBouncingScrollPhysics = true;
  static const double scrollVelocityThreshold = 8000.0;

  // Frame budget (16ms for 60fps, 33ms for 30fps)
  static const Duration targetFrameTime = Duration(milliseconds: 16);
  static const Duration maxFrameTime = Duration(milliseconds: 33);
}
