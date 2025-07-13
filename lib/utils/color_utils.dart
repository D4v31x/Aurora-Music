import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';

/// Utility class for calculating adaptive text colors based on background brightness
class ColorUtils {
  /// Calculates whether a color is light or dark based on relative luminance
  static bool isLightColor(Color color) {
    // Calculate relative luminance according to WCAG 2.0
    double luminance = (0.299 * color.red + 
                       0.587 * color.green + 
                       0.114 * color.blue) / 255;
    
    return luminance > 0.5;
  }

  /// Returns an appropriate text color (black or white) based on background color
  static Color getAdaptiveTextColor(Color backgroundColor) {
    return isLightColor(backgroundColor) ? Colors.black : Colors.white;
  }

  /// Returns an adaptive text color with opacity based on background
  static Color getAdaptiveTextColorWithOpacity(Color backgroundColor, double opacity) {
    final baseColor = getAdaptiveTextColor(backgroundColor);
    return baseColor.withOpacity(opacity);
  }

  /// Calculates the dominant color from an image with caching support
  static Future<Color?> getDominantColor(ImageProvider imageProvider, {Size? size}) async {
    try {
      final paletteGenerator = await PaletteGenerator.fromImageProvider(
        imageProvider,
        size: size ?? const Size(50, 50),
      );
      return paletteGenerator.dominantColor?.color;
    } catch (e) {
      return null;
    }
  }

  /// Gets a contrasting color for text overlay on an image
  static Future<Color> getContrastingTextColor(ImageProvider imageProvider) async {
    final dominantColor = await getDominantColor(imageProvider);
    if (dominantColor != null) {
      return getAdaptiveTextColor(dominantColor);
    }
    return Colors.white; // Default fallback
  }

  /// Blends two colors with a given ratio
  static Color blendColors(Color color1, Color color2, double ratio) {
    return Color.lerp(color1, color2, ratio) ?? color1;
  }

  /// Creates a semi-transparent overlay color that works well with the background
  static Color getOverlayColor(Color backgroundColor, {double opacity = 0.8}) {
    if (isLightColor(backgroundColor)) {
      return Colors.white.withOpacity(opacity);
    } else {
      return Colors.black.withOpacity(opacity);
    }
  }
}