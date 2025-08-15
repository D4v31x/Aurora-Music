import 'dart:collection';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../constants/app_config.dart';
import '../services/logging_service.dart';
import '../services/performance/performance_manager.dart';

/// Generic LRU cache implementation
/// Provides efficient caching with automatic eviction based on usage
class LRUCache<K, V> {
  final int maxSize;
  final LinkedHashMap<K, V> _cache = LinkedHashMap<K, V>();

  LRUCache({required this.maxSize});

  /// Gets a value from the cache and marks it as recently used
  V? get(K key) {
    final value = _cache.remove(key);
    if (value != null) {
      _cache[key] = value; // Move to end (most recent)
    }
    return value;
  }

  /// Puts a value in the cache
  void put(K key, V value) {
    if (_cache.containsKey(key)) {
      _cache.remove(key);
    } else if (_cache.length >= maxSize) {
      _cache.remove(_cache.keys.first); // Remove oldest
    }
    _cache[key] = value;
  }

  /// Removes a value from the cache
  V? remove(K key) {
    return _cache.remove(key);
  }

  /// Clears all cached values
  void clear() {
    _cache.clear();
  }

  /// Gets the current cache size
  int get length => _cache.length;

  /// Checks if the cache contains a key
  bool containsKey(K key) => _cache.containsKey(key);

  /// Gets all keys in the cache
  Iterable<K> get keys => _cache.keys;

  /// Gets all values in the cache
  Iterable<V> get values => _cache.values;
}

/// Centralized cache manager for all application caches
/// Provides unified cache management with performance monitoring
class CacheManager {
  static final CacheManager _instance = CacheManager._internal();
  factory CacheManager() => _instance;
  CacheManager._internal();

  // Individual caches
  late final LRUCache<String, Uint8List> _artworkCache;
  late final LRUCache<String, String> _lyricsCache;
  late final LRUCache<String, Map<String, dynamic>> _metadataCache;
  late final LRUCache<String, List<dynamic>> _queryCache;

  bool _isInitialized = false;

  /// Initializes all caches with configured sizes
  void initialize() {
    if (_isInitialized) return;

    _artworkCache = LRUCache<String, Uint8List>(maxSize: 100);
    _lyricsCache = LRUCache<String, String>(maxSize: 50);
    _metadataCache = LRUCache<String, Map<String, dynamic>>(maxSize: 200);
    _queryCache = LRUCache<String, List<dynamic>>(maxSize: 50);

    _isInitialized = true;
    LoggingService.info('Cache manager initialized', 'CacheManager');
  }

  /// Artwork cache methods
  Uint8List? getArtwork(String key) {
    final artwork = _artworkCache.get(key);
    if (artwork != null) {
      LoggingService.debug('Artwork cache hit: $key', 'CacheManager');
    }
    return artwork;
  }

  void putArtwork(String key, Uint8List artwork) {
    _artworkCache.put(key, artwork);
    LoggingService.debug('Artwork cached: $key', 'CacheManager');
  }

  void removeArtwork(String key) {
    _artworkCache.remove(key);
    LoggingService.debug('Artwork removed from cache: $key', 'CacheManager');
  }

  /// Lyrics cache methods
  String? getLyrics(String key) {
    final lyrics = _lyricsCache.get(key);
    if (lyrics != null) {
      LoggingService.debug('Lyrics cache hit: $key', 'CacheManager');
    }
    return lyrics;
  }

  void putLyrics(String key, String lyrics) {
    _lyricsCache.put(key, lyrics);
    LoggingService.debug('Lyrics cached: $key', 'CacheManager');
  }

  void removeLyrics(String key) {
    _lyricsCache.remove(key);
    LoggingService.debug('Lyrics removed from cache: $key', 'CacheManager');
  }

  /// Metadata cache methods
  Map<String, dynamic>? getMetadata(String key) {
    final metadata = _metadataCache.get(key);
    if (metadata != null) {
      LoggingService.debug('Metadata cache hit: $key', 'CacheManager');
    }
    return metadata;
  }

  void putMetadata(String key, Map<String, dynamic> metadata) {
    _metadataCache.put(key, metadata);
    LoggingService.debug('Metadata cached: $key', 'CacheManager');
  }

  void removeMetadata(String key) {
    _metadataCache.remove(key);
    LoggingService.debug('Metadata removed from cache: $key', 'CacheManager');
  }

  /// Query cache methods
  List<dynamic>? getQuery(String key) {
    final query = _queryCache.get(key);
    if (query != null) {
      LoggingService.debug('Query cache hit: $key', 'CacheManager');
    }
    return query;
  }

  void putQuery(String key, List<dynamic> query) {
    _queryCache.put(key, query);
    LoggingService.debug('Query cached: $key', 'CacheManager');
  }

  void removeQuery(String key) {
    _queryCache.remove(key);
    LoggingService.debug('Query removed from cache: $key', 'CacheManager');
  }

  /// Cache management methods
  void clearAllCaches() {
    _artworkCache.clear();
    _lyricsCache.clear();
    _metadataCache.clear();
    _queryCache.clear();
    LoggingService.info('All caches cleared', 'CacheManager');
  }

  void clearArtworkCache() {
    _artworkCache.clear();
    LoggingService.info('Artwork cache cleared', 'CacheManager');
  }

  void clearLyricsCache() {
    _lyricsCache.clear();
    LoggingService.info('Lyrics cache cleared', 'CacheManager');
  }

  void clearMetadataCache() {
    _metadataCache.clear();
    LoggingService.info('Metadata cache cleared', 'CacheManager');
  }

  void clearQueryCache() {
    _queryCache.clear();
    LoggingService.info('Query cache cleared', 'CacheManager');
  }

  /// Performance monitoring methods
  Map<String, int> getCacheSizes() {
    return {
      'artwork': _artworkCache.length,
      'lyrics': _lyricsCache.length,
      'metadata': _metadataCache.length,
      'query': _queryCache.length,
    };
  }

  Map<String, double> getCacheHitRates() {
    // This would require implementing hit/miss tracking
    // For now, returning placeholder values
    return {
      'artwork': 0.0,
      'lyrics': 0.0,
      'metadata': 0.0,
      'query': 0.0,
    };
  }

  /// Memory pressure handling
  void handleMemoryPressure() {
    LoggingService.warning('Handling memory pressure - reducing cache sizes', 'CacheManager');
    
    // Reduce cache sizes by 50%
    final artworkEntries = _artworkCache._cache.entries.toList();
    _artworkCache.clear();
    for (int i = artworkEntries.length ~/ 2; i < artworkEntries.length; i++) {
      _artworkCache.put(artworkEntries[i].key, artworkEntries[i].value);
    }

    final lyricsEntries = _lyricsCache._cache.entries.toList();
    _lyricsCache.clear();
    for (int i = lyricsEntries.length ~/ 2; i < lyricsEntries.length; i++) {
      _lyricsCache.put(lyricsEntries[i].key, lyricsEntries[i].value);
    }

    final metadataEntries = _metadataCache._cache.entries.toList();
    _metadataCache.clear();
    for (int i = metadataEntries.length ~/ 2; i < metadataEntries.length; i++) {
      _metadataCache.put(metadataEntries[i].key, metadataEntries[i].value);
    }

    final queryEntries = _queryCache._cache.entries.toList();
    _queryCache.clear();
    for (int i = queryEntries.length ~/ 2; i < queryEntries.length; i++) {
      _queryCache.put(queryEntries[i].key, queryEntries[i].value);
    }
  }

  /// Cleanup old entries based on a predicate
  void cleanupCache<K, V>(LRUCache<K, V> cache, bool Function(K key, V value) shouldRemove) {
    final keysToRemove = <K>[];
    
    for (final entry in cache._cache.entries) {
      if (shouldRemove(entry.key, entry.value)) {
        keysToRemove.add(entry.key);
      }
    }
    
    for (final key in keysToRemove) {
      cache.remove(key);
    }
    
    LoggingService.debug('Cleaned up ${keysToRemove.length} cache entries', 'CacheManager');
  }

  /// Periodic maintenance task
  void performMaintenance() {
    LoggingService.debug('Performing cache maintenance', 'CacheManager');
    
    // Log current cache sizes
    final sizes = getCacheSizes();
    LoggingService.debug('Cache sizes: $sizes', 'CacheManager');
    
    // Check if we need to perform cleanup
    if (sizes.values.any((size) => size > AppConfig.maxCacheSize * 0.8)) {
      LoggingService.info('Cache approaching limits, performing cleanup', 'CacheManager');
      // Could implement more sophisticated cleanup logic here
    }
  }

  /// Gets memory usage estimate (rough calculation)
  int getEstimatedMemoryUsage() {
    int total = 0;
    
    // Estimate artwork cache memory (assuming average 50KB per image)
    total += _artworkCache.length * 50 * 1024;
    
    // Estimate lyrics cache memory (assuming average 5KB per lyrics)
    total += _lyricsCache.length * 5 * 1024;
    
    // Estimate metadata cache memory (assuming average 1KB per metadata)
    total += _metadataCache.length * 1024;
    
    // Estimate query cache memory (assuming average 10KB per query)
    total += _queryCache.length * 10 * 1024;
    
    return total;
  }
}