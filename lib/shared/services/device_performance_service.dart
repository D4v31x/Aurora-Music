import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

/// Performance levels for different device capabilities
enum PerformanceLevel {
  /// High-end devices: flagship SoC, ample RAM, GPU capable of blur/animations
  high,

  /// Mid-range devices: decent performance, effects enabled but at reduced speed
  medium,

  /// Low-end or older devices: limited GPU/CPU — effects disabled for smooth UX
  low,
}

/// Service to detect device performance capabilities and recommend settings.
///
/// Detection strategy:
/// - Android: ABI (64-bit check) + brand-specific model-number heuristics +
///   Android SDK version as a final fallback.
/// - iOS: hardware machine identifier from utsname (e.g. "iPhone16,2") to
///   accurately resolve the exact device generation. The `model` field from
///   device_info_plus returns only "iPhone" / "iPad" and is NOT used for
///   classification.
class DevicePerformanceService {
  static DevicePerformanceService? _instance;
  static DevicePerformanceService get instance {
    _instance ??= DevicePerformanceService._();
    return _instance!;
  }

  DevicePerformanceService._();

  PerformanceLevel? _cachedLevel;

  /// Get the recommended performance level for the current device.
  Future<PerformanceLevel> getPerformanceLevel() async {
    if (_cachedLevel != null) return _cachedLevel!;

    // Web and desktop can always handle high-end effects.
    if (kIsWeb || Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      _cachedLevel = PerformanceLevel.high;
      return _cachedLevel!;
    }

    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final info = await deviceInfo.androidInfo;
        _cachedLevel = _evaluateAndroid(info);
      } else if (Platform.isIOS) {
        final info = await deviceInfo.iosInfo;
        _cachedLevel = _evaluateIOS(info);
      } else {
        _cachedLevel = PerformanceLevel.medium;
      }
    } catch (e) {
      debugPrint('[DevicePerformance] Detection failed: $e');
      _cachedLevel = PerformanceLevel.medium;
    }

    return _cachedLevel!;
  }

  // ─────────────────────────────────────────────────────────────────── Android

  PerformanceLevel _evaluateAndroid(AndroidDeviceInfo info) {
    final sdk = info.version.sdkInt;
    final brand = info.brand.toLowerCase();
    final model = info.model.toLowerCase();
    final abis = info.supportedAbis;

    // 32-bit-only chips are definitively low-end (pre-2015 era hardware).
    if (!abis.contains('arm64-v8a')) return PerformanceLevel.low;

    // Very old Android releases regardless of hardware.
    if (sdk < 21) return PerformanceLevel.low;

    switch (brand) {
      case 'samsung':
        return _evaluateSamsung(model, sdk);
      case 'google':
        return _evaluateGooglePixel(model, sdk);
      case 'oneplus':
        return _evaluateOnePlus(model, sdk);
      case 'xiaomi':
      case 'redmi':
      case 'poco':
        return _evaluateXiaomi(model, brand, sdk);
      case 'asus':
        return _evaluateAsus(model, sdk);
      case 'sony':
        return _evaluateSony(model, sdk);
      default:
        return _evaluateGenericAndroid(sdk);
    }
  }

  /// Samsung uses a well-defined model-number scheme via Build.MODEL:
  ///   SM-S = Galaxy S series (flagship)
  ///   SM-N = Galaxy Note series (flagship)
  ///   SM-F = Galaxy Z Fold / Flip (foldable flagship)
  ///   SM-A = Galaxy A series — first digit encodes tier (A5x+ = mid, below = low)
  ///   SM-M / SM-E = Galaxy M / F budget-mid
  ///   SM-G = legacy Galaxy S/J — use SDK as proxy
  PerformanceLevel _evaluateSamsung(String model, int sdk) {
    if (model.startsWith('sm-s') ||
        model.startsWith('sm-n') ||
        model.startsWith('sm-f')) {
      return PerformanceLevel.high;
    }

    if (model.startsWith('sm-a')) {
      // Galaxy A tier: digit immediately after "sm-a" encodes the quality tier.
      // A5x / A7x → mid-range. A0x-A4x → budget/low.
      final tierMatch = RegExp(r'sm-a(\d)').firstMatch(model);
      final tier = int.tryParse(tierMatch?.group(1) ?? '0') ?? 0;
      return tier >= 5 ? PerformanceLevel.medium : PerformanceLevel.low;
    }

    if (model.startsWith('sm-m') || model.startsWith('sm-e')) {
      return PerformanceLevel.medium;
    }

    // Legacy SM-G (older Galaxy S/J): modern SDK implies at least medium.
    return sdk >= 31 ? PerformanceLevel.medium : PerformanceLevel.low;
  }

  /// Google Pixel model names are user-friendly ("Pixel 9 Pro", "Pixel 6a").
  /// Pixel 6+ use Google Tensor chips → flagship tier.
  /// Pixel 4/5 use Snapdragon 765G/855 → mid-range.
  PerformanceLevel _evaluateGooglePixel(String model, int sdk) {
    final match = RegExp(r'pixel\s*(\d+)').firstMatch(model);
    if (match != null) {
      final gen = int.tryParse(match.group(1) ?? '0') ?? 0;
      if (gen >= 6) return PerformanceLevel.high;
      if (gen >= 4) return PerformanceLevel.medium;
      return PerformanceLevel.low;
    }
    return _evaluateGenericAndroid(sdk);
  }

  /// OnePlus uses opaque model codes (e.g. CPH2449 for OnePlus 11).
  /// Nord/CE/N-series keywords identify mid-range lines; otherwise SDK proxy.
  PerformanceLevel _evaluateOnePlus(String model, int sdk) {
    if (model.contains('nord') ||
        model.contains(' ce') ||
        RegExp(r'\bn\d').hasMatch(model)) {
      return PerformanceLevel.medium;
    }
    // OnePlus ships rapid Android updates only to flagships; SDK 33+ is a
    // strong signal the underlying hardware is premium.
    if (sdk >= 33) return PerformanceLevel.high;
    if (sdk >= 29) return PerformanceLevel.medium;
    return PerformanceLevel.low;
  }

  /// Xiaomi / Redmi / POCO have mixed naming conventions (friendly names and
  /// opaque codes).  Match known flagship/mid-range strings; fall back to SDK.
  PerformanceLevel _evaluateXiaomi(String model, String brand, int sdk) {
    if (brand == 'xiaomi') {
      // Xiaomi numeric flagship lines (Mi 10/11, Xiaomi 12/13/14/15) and Mix.
      if (RegExp(r'xiaomi\s*1[0-9]').hasMatch(model) ||
          RegExp(r'\bmi\s*1[0-9]\b').hasMatch(model) ||
          model.contains('mix') ||
          model.contains('ultra')) {
        return PerformanceLevel.high;
      }
    }
    if (brand == 'redmi') {
      if (model.contains('note') &&
          (model.contains('pro') || model.contains('ultra'))) {
        return PerformanceLevel.medium;
      }
      if (model.contains('note')) return PerformanceLevel.medium;
      return PerformanceLevel.low;
    }
    if (brand == 'poco') {
      if (model.contains('poco f') || model.contains('poco x')) {
        return PerformanceLevel.medium;
      }
    }
    return _evaluateGenericAndroid(sdk);
  }

  /// ASUS ROG Phone and top ZenFone models are gaming flagships.
  PerformanceLevel _evaluateAsus(String model, int sdk) {
    if (model.contains('rog')) return PerformanceLevel.high;
    if (RegExp(r'zenfone\s*(9|10|11)').hasMatch(model)) {
      return PerformanceLevel.high;
    }
    return _evaluateGenericAndroid(sdk);
  }

  /// Sony Xperia 1/5 lines are flagships; Xperia 10 is mid-range.
  PerformanceLevel _evaluateSony(String model, int sdk) {
    if (model.contains('xperia 1') || model.contains('xperia 5')) {
      return PerformanceLevel.high;
    }
    if (model.contains('xperia 10')) return PerformanceLevel.medium;
    return _evaluateGenericAndroid(sdk);
  }

  /// Fallback for unknown brands.  Android 10+ (SDK 29) devices are generally
  /// capable enough for the medium effect set (blur enabled).
  PerformanceLevel _evaluateGenericAndroid(int sdk) {
    if (sdk >= 29) return PerformanceLevel.medium;
    return PerformanceLevel.low;
  }

  // ──────────────────────────────────────────────────────────────────────── iOS

  /// iOS detection uses `utsname.machine` (e.g. "iPhone16,2") rather than
  /// `model` (which returns only the generic type string "iPhone"/"iPad" and
  /// cannot distinguish generations).
  ///
  /// iPhone hardware-major mapping (approximate):
  ///   ≥ 13 → iPhone 12 era (A14 Bionic+) → high
  ///   ≥ 10 → iPhone 8/X era (A11–A13)    → medium
  ///   <  10 → older                        → low
  ///
  /// iPad hardware-major mapping (approximate):
  ///   ≥ 13 → iPad Pro M1+, iPad Air 5+, iPad 10th gen+ → high
  ///   ≥  6 → iPad Pro 2017+, iPad 6th gen+              → medium
  ///   <  6 → older iPads                                → low
  PerformanceLevel _evaluateIOS(IosDeviceInfo info) {
    final machine = info.utsname.machine.toLowerCase();

    if (machine.startsWith('iphone')) {
      final match = RegExp(r'iphone(\d+),').firstMatch(machine);
      if (match != null) {
        final hw = int.tryParse(match.group(1) ?? '0') ?? 0;
        if (hw >= 13) return PerformanceLevel.high;
        if (hw >= 10) return PerformanceLevel.medium;
        return PerformanceLevel.low;
      }
    } else if (machine.startsWith('ipad')) {
      final match = RegExp(r'ipad(\d+),').firstMatch(machine);
      if (match != null) {
        final hw = int.tryParse(match.group(1) ?? '0') ?? 0;
        if (hw >= 13) return PerformanceLevel.high;
        if (hw >= 6) return PerformanceLevel.medium;
        return PerformanceLevel.low;
      }
    }

    // Fallback: iOS version as a rough proxy when machine string is unexpected.
    final iosMajor =
        int.tryParse(info.systemVersion.split('.').first) ?? 0;
    if (iosMajor >= 17) return PerformanceLevel.high;
    if (iosMajor >= 15) return PerformanceLevel.medium;
    return PerformanceLevel.low;
  }

  // ──────────────────────────────────────────────────────────────── Animation

  /// Get recommended animation settings for the detected performance level.
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
