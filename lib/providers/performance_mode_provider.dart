import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'device_performance_service.dart';

/// Global performance mode provider that manages performance settings across the app
class PerformanceModeProvider extends ChangeNotifier {
  static const String _performanceModeKey = 'performance_mode';
  static const String _autoDetectKey = 'auto_detect_performance';
  
  PerformanceLevel _currentMode = PerformanceLevel.medium;
  bool _autoDetect = true;
  bool _isInitialized = false;
  AnimationSettings? _currentSettings;
  
  /// Current performance mode
  PerformanceLevel get currentMode => _currentMode;
  
  /// Whether auto-detection is enabled
  bool get autoDetect => _autoDetect;
  
  /// Whether the provider has been initialized
  bool get isInitialized => _isInitialized;
  
  /// Current animation settings based on performance mode
  AnimationSettings get animationSettings {
    _currentSettings ??= DevicePerformanceService.instance.getAnimationSettings(_currentMode);
    return _currentSettings!;
  }
  
  /// Initialize the performance provider
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Load saved settings
      _autoDetect = prefs.getBool(_autoDetectKey) ?? true;
      
      if (_autoDetect) {
        // Auto-detect performance level
        _currentMode = await DevicePerformanceService.instance.getPerformanceLevel();
      } else {
        // Load manual setting
        final savedMode = prefs.getInt(_performanceModeKey);
        if (savedMode != null && savedMode < PerformanceLevel.values.length) {
          _currentMode = PerformanceLevel.values[savedMode];
        }
      }
      
      _currentSettings = DevicePerformanceService.instance.getAnimationSettings(_currentMode);
      _isInitialized = true;
      
      notifyListeners();
    } catch (e) {
      // If initialization fails, use default medium performance
      _currentMode = PerformanceLevel.medium;
      _currentSettings = DevicePerformanceService.instance.getAnimationSettings(_currentMode);
      _isInitialized = true;
      notifyListeners();
    }
  }
  
  /// Set performance mode manually
  Future<void> setPerformanceMode(PerformanceLevel mode, {bool saveToPrefs = true}) async {
    if (_currentMode == mode) return;
    
    _currentMode = mode;
    _autoDetect = false;
    _currentSettings = DevicePerformanceService.instance.getAnimationSettings(_currentMode);
    
    if (saveToPrefs) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_performanceModeKey, mode.index);
        await prefs.setBool(_autoDetectKey, false);
      } catch (e) {
        // Ignore preference save errors
      }
    }
    
    notifyListeners();
  }
  
  /// Enable auto-detection of performance mode
  Future<void> enableAutoDetect({bool saveToPrefs = true}) async {
    if (_autoDetect) return;
    
    _autoDetect = true;
    _currentMode = await DevicePerformanceService.instance.getPerformanceLevel();
    _currentSettings = DevicePerformanceService.instance.getAnimationSettings(_currentMode);
    
    if (saveToPrefs) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_autoDetectKey, true);
      } catch (e) {
        // Ignore preference save errors
      }
    }
    
    notifyListeners();
  }
  
  /// Check if complex animations should be enabled
  bool get shouldEnableComplexAnimations => animationSettings.enableComplexAnimations;
  
  /// Check if mesh background should be enabled
  bool get shouldEnableMeshBackground => animationSettings.enableMeshBackground;
  
  /// Check if blur effects should be enabled
  bool get shouldEnableBlur => animationSettings.enableBlur;
  
  /// Get the recommended frame rate
  int get targetFrameRate => animationSettings.frameRate;
  
  /// Get performance mode display name
  String getPerformanceModeDisplayName(PerformanceLevel mode) {
    switch (mode) {
      case PerformanceLevel.high:
        return 'High Performance';
      case PerformanceLevel.medium:
        return 'Balanced';
      case PerformanceLevel.low:
        return 'Battery Saver';
    }
  }
  
  /// Get current performance mode display name
  String get currentModeDisplayName => getPerformanceModeDisplayName(_currentMode);
  
  /// Get performance mode description
  String getPerformanceModeDescription(PerformanceLevel mode) {
    switch (mode) {
      case PerformanceLevel.high:
        return 'All visual effects enabled. Best for flagship devices.';
      case PerformanceLevel.medium:
        return 'Balanced performance and visual quality. Good for most devices.';
      case PerformanceLevel.low:
        return 'Reduced animations for better performance. Ideal for older devices.';
    }
  }
}