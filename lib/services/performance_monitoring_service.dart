import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import '../constants/app_config.dart';
import '../services/logging_service.dart';
import '../services/cache_manager.dart';

/// Service for monitoring and optimizing application performance
class PerformanceMonitoringService {
  static final PerformanceMonitoringService _instance = PerformanceMonitoringService._internal();
  factory PerformanceMonitoringService() => _instance;
  PerformanceMonitoringService._internal();

  final CacheManager _cacheManager = CacheManager();
  Timer? _monitoringTimer;
  bool _isMonitoring = false;

  // Performance metrics
  final List<double> _frameRenderTimes = [];
  final List<int> _memoryUsageHistory = [];
  int _totalFramesRendered = 0;
  int _droppedFrames = 0;
  DateTime? _lastFrameTime;

  /// Starts performance monitoring
  void startMonitoring() {
    if (_isMonitoring) return;

    _isMonitoring = true;
    _setupFrameCallbacks();
    _startPeriodicMonitoring();
    
    LoggingService.info('Performance monitoring started', 'PerformanceMonitoring');
  }

  /// Stops performance monitoring
  void stopMonitoring() {
    if (!_isMonitoring) return;

    _isMonitoring = false;
    _monitoringTimer?.cancel();
    _monitoringTimer = null;
    
    LoggingService.info('Performance monitoring stopped', 'PerformanceMonitoring');
  }

  /// Sets up frame callbacks for FPS monitoring
  void _setupFrameCallbacks() {
    WidgetsBinding.instance.addPersistentFrameCallback((timeStamp) {
      if (!_isMonitoring) return;

      _totalFramesRendered++;
      
      if (_lastFrameTime != null) {
        final frameDuration = timeStamp.inMicroseconds - _lastFrameTime!.microsecondsSinceEpoch;
        final frameTimeMs = frameDuration / 1000.0;
        
        _frameRenderTimes.add(frameTimeMs);
        
        // Keep only recent frame times (last 60 frames)
        if (_frameRenderTimes.length > 60) {
          _frameRenderTimes.removeAt(0);
        }
        
        // Detect dropped frames (assuming 60 FPS target, 16.67ms per frame)
        if (frameTimeMs > 33.33) { // More than 2 frames worth of time
          _droppedFrames++;
        }
      }
      
      _lastFrameTime = DateTime.fromMicrosecondsSinceEpoch(timeStamp.inMicroseconds);
    });
  }

  /// Starts periodic monitoring for memory and other metrics
  void _startPeriodicMonitoring() {
    _monitoringTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _collectMemoryMetrics();
      _performMaintenance();
    });
  }

  /// Collects memory usage metrics
  void _collectMemoryMetrics() {
    if (Platform.isAndroid || Platform.isIOS) {
      SystemChannels.platform.invokeMethod('SystemNavigator.pop').catchError((_) {});
    }

    // Estimate memory usage from cache
    final estimatedMemory = _cacheManager.getEstimatedMemoryUsage();
    _memoryUsageHistory.add(estimatedMemory);

    // Keep only recent history (last 20 measurements)
    if (_memoryUsageHistory.length > 20) {
      _memoryUsageHistory.removeAt(0);
    }

    LoggingService.debug('Memory usage: ${estimatedMemory ~/ 1024}KB', 'PerformanceMonitoring');
  }

  /// Performs maintenance based on performance metrics
  void _performMaintenance() {
    // Check if FPS is consistently low
    if (_shouldReduceCacheSize()) {
      LoggingService.warning('Performance degradation detected, reducing cache size', 'PerformanceMonitoring');
      _cacheManager.handleMemoryPressure();
    }

    // Perform cache maintenance
    _cacheManager.performMaintenance();

    // Log performance summary periodically
    if (_totalFramesRendered % 300 == 0) { // Every ~5 seconds at 60 FPS
      _logPerformanceSummary();
    }
  }

  /// Checks if cache size should be reduced based on performance
  bool _shouldReduceCacheSize() {
    if (_frameRenderTimes.length < 30) return false;

    final averageFrameTime = _frameRenderTimes.reduce((a, b) => a + b) / _frameRenderTimes.length;
    final droppedFrameRate = _droppedFrames / _totalFramesRendered;

    // Reduce cache if average frame time > 20ms or dropped frame rate > 5%
    return averageFrameTime > 20.0 || droppedFrameRate > 0.05;
  }

  /// Logs a performance summary
  void _logPerformanceSummary() {
    final metrics = getPerformanceMetrics();
    LoggingService.info(
      'Performance Summary - FPS: ${metrics['averageFPS']?.toStringAsFixed(1)}, '
      'Memory: ${metrics['memoryUsageMB']?.toStringAsFixed(1)}MB, '
      'Dropped Frames: ${metrics['droppedFrameRate']?.toStringAsFixed(2)}%',
      'PerformanceMonitoring'
    );
  }

  /// Gets current performance metrics
  Map<String, dynamic> getPerformanceMetrics() {
    final averageFrameTime = _frameRenderTimes.isNotEmpty
        ? _frameRenderTimes.reduce((a, b) => a + b) / _frameRenderTimes.length
        : 0.0;
    
    final averageFPS = averageFrameTime > 0 ? 1000.0 / averageFrameTime : 0.0;
    
    final droppedFrameRate = _totalFramesRendered > 0
        ? (_droppedFrames / _totalFramesRendered) * 100
        : 0.0;

    final currentMemoryUsage = _memoryUsageHistory.isNotEmpty
        ? _memoryUsageHistory.last
        : 0;

    final averageMemoryUsage = _memoryUsageHistory.isNotEmpty
        ? _memoryUsageHistory.reduce((a, b) => a + b) / _memoryUsageHistory.length
        : 0.0;

    return {
      'averageFPS': averageFPS,
      'averageFrameTime': averageFrameTime,
      'totalFramesRendered': _totalFramesRendered,
      'droppedFrames': _droppedFrames,
      'droppedFrameRate': droppedFrameRate,
      'memoryUsageMB': currentMemoryUsage / (1024 * 1024),
      'averageMemoryUsageMB': averageMemoryUsage / (1024 * 1024),
      'cacheStats': _cacheManager.getCacheSizes(),
    };
  }

  /// Gets performance recommendations
  List<String> getPerformanceRecommendations() {
    final metrics = getPerformanceMetrics();
    final recommendations = <String>[];

    if (metrics['averageFPS'] < 30) {
      recommendations.add('Low FPS detected. Consider reducing visual effects or cache size.');
    }

    if (metrics['droppedFrameRate'] > 5) {
      recommendations.add('High dropped frame rate. Optimize heavy operations or reduce background tasks.');
    }

    if (metrics['memoryUsageMB'] > 100) {
      recommendations.add('High memory usage. Clear caches or reduce image quality.');
    }

    final cacheStats = metrics['cacheStats'] as Map<String, int>;
    if (cacheStats.values.any((size) => size > AppConfig.maxCacheSize * 0.9)) {
      recommendations.add('Cache sizes approaching limits. Perform cache cleanup.');
    }

    if (recommendations.isEmpty) {
      recommendations.add('Performance is optimal.');
    }

    return recommendations;
  }

  /// Forces garbage collection (where possible)
  void forceGarbageCollection() {
    if (kDebugMode) {
      // In debug mode, we can suggest GC but can't force it
      LoggingService.debug('Requesting garbage collection', 'PerformanceMonitoring');
    }
  }

  /// Optimizes performance based on current conditions
  void optimizePerformance() {
    final metrics = getPerformanceMetrics();
    
    // If performance is poor, reduce cache sizes
    if (metrics['averageFPS'] < 30 || metrics['droppedFrameRate'] > 5) {
      _cacheManager.handleMemoryPressure();
      LoggingService.info('Applied performance optimizations', 'PerformanceMonitoring');
    }

    // Clear old cache entries
    _cacheManager.performMaintenance();
  }

  /// Resets performance metrics
  void resetMetrics() {
    _frameRenderTimes.clear();
    _memoryUsageHistory.clear();
    _totalFramesRendered = 0;
    _droppedFrames = 0;
    _lastFrameTime = null;
    
    LoggingService.info('Performance metrics reset', 'PerformanceMonitoring');
  }

  /// Gets performance status
  PerformanceStatus getPerformanceStatus() {
    final metrics = getPerformanceMetrics();
    final fps = metrics['averageFPS'] as double;
    final droppedFrameRate = metrics['droppedFrameRate'] as double;
    final memoryUsage = metrics['memoryUsageMB'] as double;

    // Determine overall status
    if (fps >= 50 && droppedFrameRate <= 2 && memoryUsage <= 50) {
      return PerformanceStatus.excellent;
    } else if (fps >= 30 && droppedFrameRate <= 5 && memoryUsage <= 100) {
      return PerformanceStatus.good;
    } else if (fps >= 20 && droppedFrameRate <= 10 && memoryUsage <= 150) {
      return PerformanceStatus.fair;
    } else {
      return PerformanceStatus.poor;
    }
  }

  /// Exports performance data for analysis
  Map<String, dynamic> exportPerformanceData() {
    return {
      'metrics': getPerformanceMetrics(),
      'recommendations': getPerformanceRecommendations(),
      'status': getPerformanceStatus().toString(),
      'frameRenderTimes': List.from(_frameRenderTimes),
      'memoryUsageHistory': List.from(_memoryUsageHistory),
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Benchmarks a specific operation
  Future<Duration> benchmarkOperation(Future<void> Function() operation) async {
    final stopwatch = Stopwatch()..start();
    await operation();
    stopwatch.stop();
    
    LoggingService.debug('Operation completed in ${stopwatch.elapsedMilliseconds}ms', 'PerformanceMonitoring');
    return stopwatch.elapsed;
  }

  /// Checks if the app is running smoothly
  bool get isRunningSmooth {
    final status = getPerformanceStatus();
    return status == PerformanceStatus.excellent || status == PerformanceStatus.good;
  }

  @override
  String toString() {
    final metrics = getPerformanceMetrics();
    return 'PerformanceMonitoring(FPS: ${metrics['averageFPS']?.toStringAsFixed(1)}, '
           'Memory: ${metrics['memoryUsageMB']?.toStringAsFixed(1)}MB, '
           'Status: ${getPerformanceStatus()})';
  }
}

/// Enum for performance status levels
enum PerformanceStatus {
  excellent,
  good,
  fair,
  poor,
}

/// Extension for performance status descriptions
extension PerformanceStatusExtension on PerformanceStatus {
  String get description {
    switch (this) {
      case PerformanceStatus.excellent:
        return 'Excellent - App is running optimally';
      case PerformanceStatus.good:
        return 'Good - App is running well';
      case PerformanceStatus.fair:
        return 'Fair - App performance could be improved';
      case PerformanceStatus.poor:
        return 'Poor - App performance needs attention';
    }
  }

  Color get color {
    switch (this) {
      case PerformanceStatus.excellent:
        return const Color(0xFF4CAF50); // Green
      case PerformanceStatus.good:
        return const Color(0xFF8BC34A); // Light Green
      case PerformanceStatus.fair:
        return const Color(0xFFFF9800); // Orange
      case PerformanceStatus.poor:
        return const Color(0xFFF44336); // Red
    }
  }
}