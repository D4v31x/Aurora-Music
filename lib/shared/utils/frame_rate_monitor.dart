import 'dart:async';
import 'package:flutter/foundation.dart';

/// Simple frame rate monitoring service for performance analysis
class FrameRateMonitor {
  static FrameRateMonitor? _instance;
  static FrameRateMonitor get instance {
    _instance ??= FrameRateMonitor._();
    return _instance!;
  }

  FrameRateMonitor._();

  final List<Duration> _frameTimes = [];
  Timer? _monitoringTimer;
  int _frameCount = 0;
  double _currentFps = 0.0;
  bool _isMonitoring = false;
  double get currentFps => _currentFps;
  bool get isMonitoring => _isMonitoring;
  void startMonitoring() {
    if (_isMonitoring) return;
    _isMonitoring = true;
    _frameCount = 0;
    _frameTimes.clear();
    _monitoringTimer =
        Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (_isMonitoring) {
        _onFrame();
      }
    });
  }

  /// Stop monitoring frame rate
  void stopMonitoring() {
    if (!_isMonitoring) return;

    _isMonitoring = false;
    _monitoringTimer?.cancel();
    _monitoringTimer = null;
  }

  void _onFrame() {
    if (!_isMonitoring) return;

    final now = Duration(microseconds: DateTime.now().microsecondsSinceEpoch);
    _frameCount++;
    _frameTimes.add(now);
    if (_frameTimes.length > 60) {
      _frameTimes.removeAt(0);
    }

    // Calculate FPS every few frames
    if (_frameTimes.length >= 2 && _frameCount % 10 == 0) {
      _calculateFps();
    }
  }

  void _calculateFps() {
    if (_frameTimes.length < 2) {
      _currentFps = 0.0;
      return;
    }

    // Calculate FPS based on frame times
    final Duration totalTime = _frameTimes.last - _frameTimes.first;
    final int frameSpan = _frameTimes.length - 1;

    if (totalTime.inMicroseconds > 0) {
      _currentFps = frameSpan * 1000000 / totalTime.inMicroseconds;
    } else {
      _currentFps = 0.0;
    }

    // Log FPS in debug mode
    if (kDebugMode) {
      debugPrint('FPS: ${_currentFps.toStringAsFixed(1)}');
    }
  }

  /// Get performance assessment based on current FPS
  PerformanceAssessment getPerformanceAssessment() {
    if (_currentFps >= 55) {
      return PerformanceAssessment.excellent;
    } else if (_currentFps >= 45) {
      return PerformanceAssessment.good;
    } else if (_currentFps >= 30) {
      return PerformanceAssessment.fair;
    } else {
      return PerformanceAssessment.poor;
    }
  }
  bool get isPerformanceAcceptable => _currentFps >= 30;
  bool get isPerformanceSmooth => _currentFps >= 55;
}

/// Performance assessment levels
enum PerformanceAssessment {
  excellent, // 55+ FPS
  good, // 45-54 FPS
  fair, // 30-44 FPS
  poor, // <30 FPS
}

extension PerformanceAssessmentExtension on PerformanceAssessment {
  String get displayName {
    switch (this) {
      case PerformanceAssessment.excellent:
        return 'Excellent';
      case PerformanceAssessment.good:
        return 'Good';
      case PerformanceAssessment.fair:
        return 'Fair';
      case PerformanceAssessment.poor:
        return 'Poor';
    }
  }

  String get description {
    switch (this) {
      case PerformanceAssessment.excellent:
        return 'Smooth 60 FPS performance';
      case PerformanceAssessment.good:
        return 'Good performance with minor frame drops';
      case PerformanceAssessment.fair:
        return 'Acceptable performance, some stuttering';
      case PerformanceAssessment.poor:
        return 'Poor performance, consider reducing graphics';
    }
  }
}
