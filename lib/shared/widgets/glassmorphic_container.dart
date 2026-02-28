import 'package:flutter/material.dart';

/// Glassmorphic container using semi-transparent color + border + shadow.
/// No BackdropFilter — only the root background layer carries a blur.
class GlassmorphicContainer extends StatelessWidget {
  final Widget child;
  final double? width;
  final EdgeInsetsGeometry? padding;
  final BorderRadiusGeometry? borderRadius;

  /// Retained for API compatibility; no longer has any effect.
  final double blur;

  /// Retained for API compatibility; no longer has any effect.
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

    return Container(
      width: width,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: radius,
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Lightweight wrapper — blur removed; returns child unchanged.
/// Kept for backward compatibility.
class PerformanceBlur extends StatelessWidget {
  final Widget child;

  /// Retained for API compatibility; no longer has any effect.
  final double blur;

  /// Retained for API compatibility; no longer has any effect.
  final bool forceBlur;

  /// Retained for API compatibility; no longer has any effect.
  final BorderRadius? borderRadius;

  const PerformanceBlur({
    super.key,
    required this.child,
    this.blur = 10,
    this.forceBlur = false,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) => child;
}

/// Returns [child] unchanged — blur removed.
/// Kept for backward compatibility.
Widget buildPerformanceAwareBlur({
  required BuildContext context,
  required Widget child,
  double blur = 10,
  BorderRadius? borderRadius,
  bool forceBlur = false,
}) =>
    child;

/// Always returns false — blur is no longer applied at the widget level.
/// Kept for backward compatibility.
bool shouldEnableBlur(BuildContext context, {bool listen = false}) => false;

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
