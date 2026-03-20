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

  static bool get shouldEnableComplexAnimations => !isLowEndDevice;
  static bool get shouldEnableBackgroundEffects => !isLowEndDevice;
  static int get targetFrameRate => isLowEndDevice ? 30 : 60;
  static void _checkDeviceCapabilities() {
    if (kIsWeb || Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      _isLowEndDevice = false;
      return;
    }
    try {
      const isRelease = kReleaseMode;
      _isLowEndDevice = isRelease;
    } catch (e) {
      _isLowEndDevice = true;
    }
  }
  static void setLowEndDevice(bool isLowEnd) {
    _isLowEndDevice = isLowEnd;
    _isChecked = true;
  }
}
