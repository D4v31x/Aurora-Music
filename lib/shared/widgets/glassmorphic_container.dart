import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:ui';
import '../providers/performance_mode_provider.dart';

/// Performance-aware glassmorphic container that respects the device's performance mode.
/// On low-performance devices, blur effects are disabled for better performance.
class GlassmorphicContainer extends StatelessWidget {
  final Widget child;
  final double? width;
  final EdgeInsetsGeometry? padding;
  final BorderRadiusGeometry? borderRadius;
  final double blur;

  /// If true, always applies blur regardless of performance mode.
  /// Use sparingly for critical UI elements only.
  final bool forceBlur;

  const GlassmorphicContainer({
    super.key,
    required this.child,
    this.width,
    this.padding,
    this.borderRadius,
    this.blur = 10,
    this.forceBlur = false,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(15);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final performanceProvider = context.watch<PerformanceModeProvider>();
    final isHighEnd = !performanceProvider.isLowEndDevice;

    if (isHighEnd) {
      // High-end: glassmorphic blur style
      return RepaintBoundary(
        child: ClipRRect(
          borderRadius: radius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
            child: Container(
              width: width,
              padding: padding,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.08)
                    : Colors.white.withOpacity(0.45),
                borderRadius: radius,
                border: Border.all(
                  color: isDark
                      ? Colors.white.withOpacity(0.12)
                      : Colors.white.withOpacity(0.5),
                  width: 1,
                ),
              ),
              child: child,
            ),
          ),
        ),
      );
    }

    // Low-end: Material You solid surface styling — no blur
    final solidDecoration = BoxDecoration(
      color: isDark
          ? colorScheme.surfaceContainerHigh
          : colorScheme.surfaceContainerHighest,
      borderRadius: radius,
      border: Border.all(
        color: isDark ? colorScheme.outlineVariant : colorScheme.outline,
        width: 1,
      ),
    );

    return RepaintBoundary(
      child: Container(
        width: width,
        padding: padding,
        decoration: solidDecoration,
        child: child,
      ),
    );
  }
}

/// Lightweight blur wrapper that respects performance mode.
/// Use this for wrapping existing widgets with optional blur effect.
class PerformanceBlur extends StatelessWidget {
  final Widget child;
  final double blur;
  final bool forceBlur;
  final BorderRadius? borderRadius;

  const PerformanceBlur({
    super.key,
    required this.child,
    this.blur = 10,
    this.forceBlur = false,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final performanceProvider = context.watch<PerformanceModeProvider>();
    final shouldBlur = forceBlur || performanceProvider.shouldEnableBlur;

    if (!shouldBlur) {
      return child;
    }

    final blurWidget = BackdropFilter(
      filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
      child: child,
    );

    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius!,
        child: blurWidget,
      );
    }

    return blurWidget;
  }
}

/// A utility function to build performance-aware blur effect.
/// Returns a widget that applies blur only when device performance allows.
///
/// Use this function when you need to wrap existing widgets with blur
/// and can't use [GlassmorphicContainer].
///
/// Example:
/// ```dart
/// buildPerformanceAwareBlur(
///   context: context,
///   blur: 20,
///   borderRadius: BorderRadius.circular(24),
///   child: myWidget,
/// )
/// ```
Widget buildPerformanceAwareBlur({
  required BuildContext context,
  required Widget child,
  double blur = 10,
  BorderRadius? borderRadius,
  bool forceBlur = false,
}) {
  final performanceProvider =
      Provider.of<PerformanceModeProvider>(context, listen: false);
  final shouldBlur = forceBlur || performanceProvider.shouldEnableBlur;

  if (!shouldBlur) {
    return child;
  }

  Widget blurWidget = BackdropFilter(
    filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
    child: child,
  );

  if (borderRadius != null) {
    blurWidget = ClipRRect(
      borderRadius: borderRadius,
      child: blurWidget,
    );
  }

  return blurWidget;
}

/// Check if blur should be enabled based on performance mode.
/// Use this for one-time sync checks (e.g., in build methods).
bool shouldEnableBlur(BuildContext context, {bool listen = false}) {
  final performanceProvider = listen
      ? Provider.of<PerformanceModeProvider>(context)
      : Provider.of<PerformanceModeProvider>(context, listen: false);
  return performanceProvider.shouldEnableBlur;
}

// Keep the function for backward compatibility but mark as deprecated
@Deprecated('Use GlassmorphicContainer class instead')
Widget glassmorphicContainer({
  required Widget child,
  double? width,
  EdgeInsetsGeometry? padding,
}) {
  return GlassmorphicContainer(
    width: width,
    padding: padding,
    child: child,
  );
}
