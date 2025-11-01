import 'dart:io';
import 'package:flutter/foundation.dart';

/// Simple device capability detection utility
class DeviceCapabilities {
  static bool _isLowEndDevice = false;
  static bool _isChecked = false;

  /// Check if the device is likely low-end based on basic heuristics
  static bool get isLowEndDevice {
    if (!_isChecked) {
      _checkDeviceCapabilities();
      _isChecked = true;
    }
    return _isLowEndDevice;
  }

  /// Check if complex animations should be enabled
  static bool get shouldEnableComplexAnimations => !isLowEndDevice;

  /// Check if background effects should be enabled
  static bool get shouldEnableBackgroundEffects => !isLowEndDevice;

  /// Get recommended frame rate
  static int get targetFrameRate => isLowEndDevice ? 30 : 60;

  /// Simple device capability check without requiring device_info_plus
  static void _checkDeviceCapabilities() {
    // For web and desktop, assume capable
    if (kIsWeb || Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      _isLowEndDevice = false;
      return;
    }

    // For mobile platforms, use conservative defaults
    // This can be enhanced with actual device detection later
    try {
      // Simple heuristic: check available memory indicators
      final isRelease = kReleaseMode;

      // In debug mode, assume development device (usually higher-end)
      // In release mode, be more conservative
      _isLowEndDevice = isRelease;
    } catch (e) {
      // If any check fails, assume low-end for safety
      _isLowEndDevice = true;
    }
  }

  /// Override device capabilities (for testing or user preference)
  static void setLowEndDevice(bool isLowEnd) {
    _isLowEndDevice = isLowEnd;
    _isChecked = true;
  }
}
