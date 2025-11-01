import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

/// A reusable pill-shaped button widget for consistent UI across the app
/// Supports both filled and outlined variants
class PillButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isPrimary;
  final bool isLoading;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double? width;
  final EdgeInsetsGeometry? padding;

  const PillButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isPrimary = true,
    this.isLoading = false,
    this.icon,
    this.backgroundColor,
    this.foregroundColor,
    this.width,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    final effectiveBackgroundColor = backgroundColor ??
        (isPrimary ? const Color(0xFF3B82F6) : Colors.transparent);

    final effectiveForegroundColor =
        foregroundColor ?? (isDark ? Colors.white : Colors.black);

    final outlinedBorderColor =
        isDark ? Colors.white.withOpacity(0.3) : Colors.black.withOpacity(0.3);

    final buttonStyle = isPrimary
        ? FilledButton.styleFrom(
            backgroundColor: effectiveBackgroundColor,
            foregroundColor: effectiveForegroundColor,
            padding: padding ??
                const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 32,
                ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(32), // Pill shape
            ),
            elevation: 0,
          )
        : OutlinedButton.styleFrom(
            foregroundColor: effectiveForegroundColor,
            side: BorderSide(
              color: outlinedBorderColor,
              width: 1.5,
            ),
            padding: padding ??
                const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 32,
                ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(32), // Pill shape
            ),
          );

    Widget buttonChild;

    if (isLoading) {
      buttonChild = SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: effectiveForegroundColor,
        ),
      );
    } else if (icon != null) {
      buttonChild = Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              fontFamily: 'Outfit',
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ],
      );
    } else {
      buttonChild = Text(
        text,
        style: const TextStyle(
          fontFamily: 'Outfit',
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      );
    }

    final button = isPrimary
        ? FilledButton(
            onPressed: isLoading ? null : onPressed,
            style: buttonStyle,
            child: buttonChild,
          )
        : OutlinedButton(
            onPressed: isLoading ? null : onPressed,
            style: buttonStyle,
            child: buttonChild,
          );

    if (width != null) {
      return SizedBox(
        width: width,
        child: button,
      );
    }

    return button;
  }
}

/// A pair of navigation buttons (Back + Continue) for onboarding flows
class PillNavigationButtons extends StatelessWidget {
  final VoidCallback? onBack;
  final VoidCallback? onContinue;
  final String backText;
  final String continueText;
  final bool isLoading;

  const PillNavigationButtons({
    super.key,
    this.onBack,
    this.onContinue,
    this.backText = 'Back',
    this.continueText = 'Continue',
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (onBack != null) ...[
          Expanded(
            child: PillButton(
              text: backText,
              onPressed: onBack,
              isPrimary: false,
            ),
          ),
          const SizedBox(width: 16),
        ],
        Expanded(
          child: PillButton(
            text: continueText,
            onPressed: onContinue,
            isPrimary: true,
            isLoading: isLoading,
          ),
        ),
      ],
    );
  }
}
