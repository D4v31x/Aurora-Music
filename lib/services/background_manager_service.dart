import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:palette_generator/palette_generator.dart';
import 'dart:typed_data';

/// Service that manages background colors and gradients
/// Extracts colors from artwork or provides defaults
class BackgroundManagerService extends ChangeNotifier {
  List<Color> _currentColors = _getDefaultColors();
  bool _isDarkMode = true;
  int? _currentSongId; // Track current song for wave direction changes
  
  static const Color _defaultDarkPrimary = Color(0xFF1A237E);
  static const Color _defaultDarkSecondary = Color(0xFF311B92);
  static const Color _defaultDarkTertiary = Color(0xFF512DA8);
  static const Color _defaultDarkQuaternary = Color(0xFF7B1FA2);
  
  static const Color _defaultLightPrimary = Color(0xFFE3F2FD);
  static const Color _defaultLightSecondary = Color(0xFFBBDEFB);
  static const Color _defaultLightTertiary = Color(0xFF90CAF9);
  static const Color _defaultLightQuaternary = Color(0xFF64B5F6);

  List<Color> get currentColors => _currentColors;
  bool get isDarkMode => _isDarkMode;
  int? get currentSongId => _currentSongId;

  /// Set the theme mode
  void setDarkMode(bool darkMode) {
    if (_isDarkMode != darkMode) {
      _isDarkMode = darkMode;
      // If no artwork colors are set, use default colors for the new theme
      if (_isUsingDefaultColors()) {
        _currentColors = _getDefaultColors();
        notifyListeners();
      }
    }
  }

  /// Update colors based on artwork
  Future<void> updateColorsFromArtwork(Uint8List? artworkData) async {
    if (artworkData == null) {
      _useDefaultColors();
      return;
    }

    try {
      final imageProvider = MemoryImage(artworkData);
      final palette = await PaletteGenerator.fromImageProvider(
        imageProvider,
        maximumColorCount: 6,
      );

      final colors = _extractColorsFromPalette(palette);
      if (colors.length >= 2) {
        _currentColors = colors;
        notifyListeners();
      } else {
        _useDefaultColors();
      }
    } catch (e) {
      _useDefaultColors();
    }
  }

  /// Update colors from song model
  Future<void> updateColorsFromSong(SongModel? song) async {
    if (song == null) {
      _useDefaultColors();
      return;
    }

    // Update current song ID for wave direction tracking
    final newSongId = song.id;
    final songChanged = _currentSongId != newSongId;
    _currentSongId = newSongId;
    
    try {
      final artworkData = await OnAudioQuery().queryArtwork(
        song.id,
        ArtworkType.AUDIO,
        quality: 100,
        size: 200, // Small size for performance
      );
      
      await updateColorsFromArtwork(artworkData);
      
      // Always notify listeners when song changes, even if colors are the same
      // This ensures wave direction updates
      if (songChanged) {
        notifyListeners();
      }
    } catch (e) {
      _useDefaultColors();
      if (songChanged) {
        notifyListeners();
      }
    }
  }

  /// Extract colors from palette generator with enhanced variations for wave effects
  List<Color> _extractColorsFromPalette(PaletteGenerator palette) {
    final colors = <Color>[];

    // Primary color (dominant)
    if (palette.dominantColor?.color != null) {
      colors.add(palette.dominantColor!.color);
    }

    // Vibrant colors
    if (palette.vibrantColor?.color != null) {
      colors.add(palette.vibrantColor!.color);
    }
    
    if (palette.lightVibrantColor?.color != null) {
      colors.add(palette.lightVibrantColor!.color);
    }
    
    if (palette.darkVibrantColor?.color != null) {
      colors.add(palette.darkVibrantColor!.color);
    }

    // Muted colors as fallbacks
    if (palette.mutedColor?.color != null && colors.length < 4) {
      colors.add(palette.mutedColor!.color);
    }
    
    if (palette.lightMutedColor?.color != null && colors.length < 4) {
      colors.add(palette.lightMutedColor!.color);
    }

    // Enhanced color variations for dramatic wave effects
    if (colors.length < 2 && colors.isNotEmpty) {
      final baseColor = colors.first;
      colors.add(_adjustColorBrightness(baseColor, _isDarkMode ? 0.7 : 1.3));
    }
    
    // Add complementary and analogous colors for richer gradients
    if (colors.isNotEmpty) {
      final enhancedColors = _enhanceColorsForWaves(colors);
      return enhancedColors.take(6).toList(); // Allow up to 6 colors for richer gradients
    }

    return colors.take(4).toList();
  }

  /// Enhance colors for more dramatic wave effects
  List<Color> _enhanceColorsForWaves(List<Color> originalColors) {
    final enhancedColors = <Color>[];
    
    for (final color in originalColors) {
      enhancedColors.add(color);
      
      // Add HSV variations for each color
      final hsvColor = HSVColor.fromColor(color);
      
      // Create complementary hue shift (+/-60 degrees for triadic harmony)
      final complementaryHue = (hsvColor.hue + 120) % 360;
      final complementaryColor = hsvColor
          .withHue(complementaryHue)
          .withSaturation((hsvColor.saturation * 0.8).clamp(0.0, 1.0))
          .toColor();
      enhancedColors.add(complementaryColor);
      
      // Create analogous color variation (+/-30 degrees)
      final analogousHue = (hsvColor.hue + 60) % 360;
      final analogousColor = hsvColor
          .withHue(analogousHue)
          .withSaturation((hsvColor.saturation * 1.2).clamp(0.0, 1.0))
          .withValue((hsvColor.value * 0.9).clamp(0.0, 1.0))
          .toColor();
      enhancedColors.add(analogousColor);
      
      if (enhancedColors.length >= 6) break; // Limit to 6 colors
    }
    
    return enhancedColors;
  }

  /// Adjust color brightness
  Color _adjustColorBrightness(Color color, double factor) {
    final hsl = HSLColor.fromColor(color);
    final adjustedLightness = (hsl.lightness * factor).clamp(0.0, 1.0);
    return hsl.withLightness(adjustedLightness).toColor();
  }

  /// Use default colors
  void _useDefaultColors() {
    _currentColors = _getDefaultColors();
    notifyListeners();
  }

  /// Get default colors based on theme
  static List<Color> _getDefaultColors() {
    return [
      _defaultDarkPrimary,
      _defaultDarkSecondary,
      _defaultDarkTertiary,
      _defaultDarkQuaternary,
    ];
  }

  /// Check if currently using default colors
  bool _isUsingDefaultColors() {
    final defaultColors = _getDefaultColors();
    if (_currentColors.length != defaultColors.length) return false;
    
    for (int i = 0; i < _currentColors.length; i++) {
      if (_currentColors[i] != defaultColors[i]) return false;
    }
    return true;
  }

  /// Get colors suitable for light theme
  List<Color> getLightThemeColors() {
    return [
      _defaultLightPrimary,
      _defaultLightSecondary,
      _defaultLightTertiary,
      _defaultLightQuaternary,
    ];
  }

  /// Get colors suitable for dark theme
  List<Color> getDarkThemeColors() {
    return [
      _defaultDarkPrimary,
      _defaultDarkSecondary,
      _defaultDarkTertiary,
      _defaultDarkQuaternary,
    ];
  }
  
  /// Set custom colors directly for the mesh gradient
  /// This method allows setting colors from palette generators or other sources
  void setCustomColors(List<Color> colors) {
    if (colors.isEmpty) {
      _useDefaultColors();
      return;
    }
    
    // Take up to 9 colors for the mesh (3x3 grid)
    _currentColors = colors.take(9).toList();
    notifyListeners();
  }
}
