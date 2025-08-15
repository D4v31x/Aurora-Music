import 'dart:collection';
import 'package:aurora_music_v01/constants/app_config.dart';

/// Performance management service to prevent memory leaks and optimize caching
class PerformanceManager {
  static const int maxCacheSize = AppConfig.maxCacheSize;
  static const Duration cacheCleanupInterval = AppConfig.cacheCleanupInterval;
  
  /// Clean up oversized caches by removing oldest entries
  static void cleanupCache<K, V>(Map<K, V> cache, {int? maxSize}) {
    final limit = maxSize ?? maxCacheSize;
    if (cache.length > limit) {
      final keysToRemove = cache.keys.take(cache.length - limit).toList();
      for (final key in keysToRemove) {
        cache.remove(key);
      }
    }
  }
  
  /// Clean up caches that use LRU-like behavior  
  static void cleanupLRUCache<K, V>(LinkedHashMap<K, V> cache, {int? maxSize}) {
    final limit = maxSize ?? maxCacheSize;
    while (cache.length > limit) {
      cache.remove(cache.keys.first);
    }
  }
  
  /// Check if a cache is getting too large
  static bool shouldCleanup(Map cache) {
    return cache.length > maxCacheSize * 0.8; // Clean when 80% full
  }
}