import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

/// Performance levels for different device capabilities
enum PerformanceLevel {
  /// High-end devices with powerful GPUs and plenty of RAM
  high,
  /// Mid-range devices with decent performance
  medium, 
  /// Low-end or older devices with limited performance
  low,
}

/// Service to detect device performance capabilities and recommend settings
class DevicePerformanceService {
  static DevicePerformanceService? _instance;
  static DevicePerformanceService get instance {
    _instance ??= DevicePerformanceService._();
    return _instance!;
  }
  
  DevicePerformanceService._();
  
  PerformanceLevel? _cachedLevel;
  
  /// Get the recommended performance level for the current device
  Future<PerformanceLevel> getPerformanceLevel() async {
    if (_cachedLevel != null) return _cachedLevel!;
    
    // For web and desktop, assume high performance
    if (kIsWeb || Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      _cachedLevel = PerformanceLevel.high;
      return _cachedLevel!;
    }
    
    try {
      final deviceInfo = DeviceInfoPlugin();
      
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        _cachedLevel = _evaluateAndroidPerformance(androidInfo);
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        _cachedLevel = _evaluateIOSPerformance(iosInfo);
      } else {
        // Fallback to medium performance for unknown platforms
        _cachedLevel = PerformanceLevel.medium;
      }
    } catch (e) {
      // If device detection fails, default to medium performance
      _cachedLevel = PerformanceLevel.medium;
    }
    
    return _cachedLevel!;
  }
  
  /// Evaluate Android device performance based on hardware specs
  PerformanceLevel _evaluateAndroidPerformance(AndroidDeviceInfo info) {
    // Check Android version (newer versions generally perform better)
    final androidVersion = info.version.sdkInt;
    
    // Get RAM information if available
    // Note: Physical RAM is not directly available, so we use heuristics
    
    // High-end device indicators
    if (androidVersion >= 31) { // Android 12+
      // Newer devices with recent Android versions
      if (_isHighEndDevice(info)) {
        return PerformanceLevel.high;
      }
    }
    
    // Mid-range device indicators
    if (androidVersion >= 26) { // Android 8.0+
      if (_isMidRangeDevice(info)) {
        return PerformanceLevel.medium;
      }
    }
    
    // Low-end device indicators
    return PerformanceLevel.low;
  }
  
  /// Evaluate iOS device performance based on device model
  PerformanceLevel _evaluateIOSPerformance(IosDeviceInfo info) {
    final model = info.model.toLowerCase();
    final osVersion = info.systemVersion;
    
    // Parse iOS version
    final versionParts = osVersion.split('.');
    final majorVersion = int.tryParse(versionParts.first) ?? 0;
    
    // High-end iOS devices (iPhone 12+ series, iPad Pro, etc.)
    if (model.contains('iphone')) {
      if (_isHighEndIPhone(model) && majorVersion >= 14) {
        return PerformanceLevel.high;
      } else if (_isMidRangeIPhone(model) && majorVersion >= 13) {
        return PerformanceLevel.medium;
      }
    } else if (model.contains('ipad')) {
      if (model.contains('pro') || majorVersion >= 14) {
        return PerformanceLevel.high;
      } else if (majorVersion >= 13) {
        return PerformanceLevel.medium;
      }
    }
    
    return PerformanceLevel.low;
  }
  
  /// Check if Android device has high-end characteristics
  bool _isHighEndDevice(AndroidDeviceInfo info) {
    final brand = info.brand.toLowerCase();
    final model = info.model.toLowerCase();
    
    // High-end device patterns
    final highEndPatterns = [
      'flagship', 'pro', 'plus', 'ultra', 'note',
      'pixel 6', 'pixel 7', 'pixel 8',
      'galaxy s2', 'galaxy s3', 'galaxy note',
      'oneplus 9', 'oneplus 10', 'oneplus 11',
      'xiaomi 12', 'xiaomi 13',
    ];
    
    for (final pattern in highEndPatterns) {
      if (model.contains(pattern)) return true;
    }
    
    // Premium brands typically have better performance
    if (['google', 'samsung'].contains(brand) && 
        info.version.sdkInt >= 30) {
      return true;
    }
    
    return false;
  }
  
  /// Check if Android device has mid-range characteristics
  bool _isMidRangeDevice(AndroidDeviceInfo info) {
    final brand = info.brand.toLowerCase();
    final model = info.model.toLowerCase();
    
    // Mid-range device patterns
    final midRangePatterns = [
      'lite', 'se', 'a5', 'a7', 'a8', 'redmi',
      'poco', 'nord', 'realme',
    ];
    
    for (final pattern in midRangePatterns) {
      if (model.contains(pattern)) return true;
    }
    
    // Reasonable Android version indicates decent performance
    return info.version.sdkInt >= 28; // Android 9+
  }
  
  /// Check if iPhone model is high-end
  bool _isHighEndIPhone(String model) {
    final highEndPatterns = [
      'iphone 12', 'iphone 13', 'iphone 14', 'iphone 15',
      'pro', 'pro max',
    ];
    
    return highEndPatterns.any((pattern) => model.contains(pattern));
  }
  
  /// Check if iPhone model is mid-range
  bool _isMidRangeIPhone(String model) {
    final midRangePatterns = [
      'iphone 10', 'iphone 11', 'iphone se',
    ];
    
    return midRangePatterns.any((pattern) => model.contains(pattern));
  }
  
  /// Get recommended animation settings for the device
  AnimationSettings getAnimationSettings(PerformanceLevel level) {
    switch (level) {
      case PerformanceLevel.high:
        return const AnimationSettings(
          enableMeshBackground: true,
          meshAnimationSpeed: 2.5,
          meshAnimationDuration: Duration(seconds: 3),
          enableComplexAnimations: true,
          frameRate: 60,
          enableBlur: true,
        );
      case PerformanceLevel.medium:
        return const AnimationSettings(
          enableMeshBackground: true,
          meshAnimationSpeed: 1.5,
          meshAnimationDuration: Duration(seconds: 5),
          enableComplexAnimations: true,
          frameRate: 60,
          enableBlur: true,
        );
      case PerformanceLevel.low:
        return const AnimationSettings(
          enableMeshBackground: false,
          meshAnimationSpeed: 1.0,
          meshAnimationDuration: Duration(seconds: 8),
          enableComplexAnimations: false,
          frameRate: 30,
          enableBlur: false,
        );
    }
  }
}

/// Animation settings based on device performance
class AnimationSettings {
  final bool enableMeshBackground;
  final double meshAnimationSpeed;
  final Duration meshAnimationDuration;
  final bool enableComplexAnimations;
  final int frameRate;
  final bool enableBlur;
  
  const AnimationSettings({
    required this.enableMeshBackground,
    required this.meshAnimationSpeed,
    required this.meshAnimationDuration,
    required this.enableComplexAnimations,
    required this.frameRate,
    required this.enableBlur,
  });
}