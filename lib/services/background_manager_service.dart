import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:palette_generator/palette_generator.dart';
import 'dart:typed_data';
import 'dart:async';

/// Service that manages background colors and gradients
/// Extracts colors from artwork or provides defaults
class BackgroundManagerService extends ChangeNotifier {
  List<Color> _currentColors = _getDefaultColors();
  bool _isDarkMode = true;
  int? _lastUpdatedSongId; // Track last updated song to prevent redundant updates
  Timer? _updateDebounceTimer; // Debounce rapid updates
  
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

    // Prevent redundant updates for the same song
    if (_lastUpdatedSongId == song.id) {
      return;
    }

    // Debounce rapid updates
    _updateDebounceTimer?.cancel();
    _updateDebounceTimer = Timer(const Duration(milliseconds: 100), () async {
      if (!mounted) return; // Check if the service is still active
      
      try {
        final artworkData = await OnAudioQuery().queryArtwork(
          song.id,
          ArtworkType.AUDIO,
          quality: 100,
          size: 200, // Small size for performance
        );
        
        await updateColorsFromArtwork(artworkData);
        _lastUpdatedSongId = song.id;
      } catch (e) {
        _useDefaultColors();
      }
    });
  }

  /// Check if the service is still mounted/active
  bool get mounted => hasListeners;

  /// Extract colors from palette generator
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

    // Ensure we have at least 2 colors and max 4
    if (colors.length < 2 && colors.isNotEmpty) {
      final baseColor = colors.first;
      colors.add(_adjustColorBrightness(baseColor, _isDarkMode ? 0.7 : 1.3));
    }

    return colors.take(4).toList();
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

  @override
  void dispose() {
    _updateDebounceTimer?.cancel();
    super.dispose();
  }
}
