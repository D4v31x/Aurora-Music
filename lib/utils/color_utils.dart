import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';

/// Utility class for color operations and adaptive text color calculations
class ColorUtils {
  /// Cache for color calculations to avoid repeated computation
  static final Map<int, Color> _adaptiveTextColorCache = {};
  
  /// Calculates optimal text color based on background color for best contrast
  /// Following WCAG 2.0 guidelines for accessibility
  static Color getOptimalTextColor(Color backgroundColor) {
    final int colorKey = backgroundColor.value;
    
    // Check cache first
    if (_adaptiveTextColorCache.containsKey(colorKey)) {
      return _adaptiveTextColorCache[colorKey]!;
    }
    
    // Calculate relative luminance according to WCAG 2.0
    final double luminance = backgroundColor.computeLuminance();
    
    // Use black text for light backgrounds, white for dark
    final Color textColor = luminance > 0.5 ? Colors.black87 : Colors.white;
    
    // Cache the result
    _adaptiveTextColorCache[colorKey] = textColor;
    
    // Clean up cache if it gets too large (keep last 50 entries)
    if (_adaptiveTextColorCache.length > 50) {
      final entries = _adaptiveTextColorCache.entries.toList();
      _adaptiveTextColorCache.clear();
      _adaptiveTextColorCache.addAll(Map.fromEntries(entries.skip(25)));
    }
    
    return textColor;
  }
  
  /// Extracts dominant color from image data and returns optimal text color
  static Future<Color> getOptimalTextColorFromArtwork(MemoryImage image) async {
    try {
      final paletteGenerator = await PaletteGenerator.fromImageProvider(
        image,
        size: const Size(50, 50), // Small size for performance
      );
      
      final dominantColor = paletteGenerator.dominantColor?.color ?? Colors.black;
      return getOptimalTextColor(dominantColor);
    } catch (e) {
      // Fallback to white text if extraction fails
      return Colors.white;
    }
  }
  
  /// Creates a smooth color transition animation
  static Color lerpColors(Color from, Color to, double t) {
    return Color.lerp(from, to, t) ?? from;
  }
  
  /// Clears the adaptive text color cache
  static void clearCache() {
    _adaptiveTextColorCache.clear();
  }
}