import 'dart:async';
import 'dart:collection';
import 'package:flutter/scheduler.dart';
import 'package:aurora_music_v01/constants/app_config.dart';

/// Performance management service to prevent memory leaks and optimize caching
class PerformanceManager {
  static const int maxCacheSize = AppConfig.maxCacheSize;
  static const Duration cacheCleanupInterval = AppConfig.cacheCleanupInterval;

  static PerformanceManager? _instance;
  static PerformanceManager get instance {
    _instance ??= PerformanceManager._();
    return _instance!;
  }

  PerformanceManager._();

  Timer? _cleanupTimer;
  final List<Map> _registeredCaches = [];
  final List<VoidCallback> _cleanupCallbacks = [];

  // Frame rate monitoring
  int _frameCount = 0;
  DateTime? _fpsStartTime;
  double _currentFps = 60.0;

  /// Current measured FPS
  double get currentFps => _currentFps;

  /// Whether the app is experiencing performance issues (low FPS)
  bool get isPerformanceIssue => _currentFps < 30.0;

  /// Start automatic cache cleanup scheduling
  void startAutomaticCleanup() {
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(cacheCleanupInterval, (_) {
      _performScheduledCleanup();
    });
  }

  /// Stop automatic cache cleanup
  void stopAutomaticCleanup() {
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
  }

  /// Register a cache for automatic cleanup
  void registerCache(Map cache, {int? maxSize}) {
    _registeredCaches.add(cache);
  }

  /// Register a cleanup callback for custom cleanup logic
  void registerCleanupCallback(VoidCallback callback) {
    _cleanupCallbacks.add(callback);
  }

  /// Unregister a cache from automatic cleanup
  void unregisterCache(Map cache) {
    _registeredCaches.remove(cache);
  }

  /// Perform scheduled cleanup on all registered caches
  void _performScheduledCleanup() {
    for (final cache in _registeredCaches) {
      cleanupCache(cache);
    }
    for (final callback in _cleanupCallbacks) {
      try {
        callback();
      } catch (e) {
        // Ignore cleanup callback errors
      }
    }
  }

  /// Start FPS monitoring
  void startFpsMonitoring() {
    _fpsStartTime = DateTime.now();
    _frameCount = 0;
    SchedulerBinding.instance.addPostFrameCallback(_onFrame);
  }

  void _onFrame(Duration timestamp) {
    _frameCount++;

    final now = DateTime.now();
    if (_fpsStartTime != null) {
      final elapsed = now.difference(_fpsStartTime!).inMilliseconds;
      if (elapsed >= 1000) {
        _currentFps = (_frameCount * 1000) / elapsed;
        _frameCount = 0;
        _fpsStartTime = now;
      }
    }

    // Continue monitoring
    SchedulerBinding.instance.addPostFrameCallback(_onFrame);
  }

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

  /// Force garbage collection hint (does not guarantee GC)
  static void requestGarbageCollection() {
    // This is just a hint to the VM, it may or may not trigger GC
    // The VM decides based on memory pressure
  }

  /// Get memory usage information (approximate)
  static Map<String, dynamic> getMemoryInfo() {
    return {
      'cacheMaxSize': maxCacheSize,
      'cleanupInterval': cacheCleanupInterval.inMinutes,
    };
  }

  /// Dispose the performance manager
  void dispose() {
    stopAutomaticCleanup();
    _registeredCaches.clear();
    _cleanupCallbacks.clear();
  }
}
