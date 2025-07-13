import 'dart:collection';

/// Performance management service to prevent memory leaks and optimize caching
class PerformanceManager {
  static const int maxCacheSize = 200;  // Maximum cached items
  static const Duration cacheCleanupInterval = Duration(minutes: 5);
  
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

/// Enhanced LRU Cache implementation for better memory management
class LRUCache<K, V> {
  final int _maxSize;
  final LinkedHashMap<K, V> _cache = LinkedHashMap<K, V>();
  
  LRUCache(this._maxSize);
  
  V? get(K key) {
    final value = _cache.remove(key);
    if (value != null) {
      _cache[key] = value; // Move to end (most recent)
    }
    return value;
  }
  
  void put(K key, V value) {
    if (_cache.containsKey(key)) {
      _cache.remove(key);
    } else if (_cache.length >= _maxSize) {
      _cache.remove(_cache.keys.first);
    }
    _cache[key] = value;
  }
  
  bool containsKey(K key) => _cache.containsKey(key);
  
  void clear() => _cache.clear();
  
  int get length => _cache.length;
  
  bool get isEmpty => _cache.isEmpty;
}