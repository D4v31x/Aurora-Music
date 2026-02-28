import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:palette_generator/palette_generator.dart';
import 'artwork_cache_service.dart';
import '../utils/performance_optimizations.dart';

/// Service that manages background colors and artwork
/// Provides artwork data for blurred backgrounds across the app
///
/// Performance optimizations:
/// - Cached color extraction to avoid redundant palette generation
/// - Throttled updates to prevent excessive rebuilds
/// - Batch notifications to reduce listener calls
class BackgroundManagerService extends ChangeNotifier {
  static const Duration _artworkRetryDelay = Duration(milliseconds: 450);

  final ArtworkCacheService _artworkCache = ArtworkCacheService();

  List<Color> _currentColors = _getDefaultColors();
  bool _isDarkMode = true;

  // Artwork data for blurred background
  Uint8List? _currentArtwork;
  Uint8List? _previousArtwork;
  bool _isTransitioning = false;
  SongModel? _currentSong;
  bool _isUpdating = false; // Prevent concurrent updates
  int _updateCounter = 0; // Track update sequence
  // Prevent duplicate delayed artwork retries for the same song.
  int? _retryScheduledForSongId;
  Timer? _artworkRetryTimer;

  // Performance optimizations
  final Map<int, List<Color>> _colorCache = {}; // Cache colors by song ID
  final Throttler _updateThrottler =
      Throttler(interval: const Duration(milliseconds: 300));
  final Memoizer<List<Color>> _colorMemoizer = Memoizer<List<Color>>();

  static const Color _defaultDarkPrimary = Color(0xFF1A237E);
  static const Color _defaultDarkSecondary = Color(0xFF311B92);
  static const Color _defaultDarkTertiary = Color(0xFF512DA8);
  static const Color _defaultDarkQuaternary = Color(0xFF7B1FA2);

  static const Color _defaultLightPrimary = Color(0xFFE3F2FD);
  static const Color _defaultLightSecondary = Color(0xFFBBDEFB);
  static const Color _defaultLightTertiary = Color(0xFF90CAF9);
  static const Color _defaultLightQuaternary = Color(0xFF64B5F6);

  // Getters
  List<Color> get currentColors => _currentColors;
  bool get isDarkMode => _isDarkMode;
  Uint8List? get currentArtwork => _currentArtwork;
  Uint8List? get previousArtwork => _previousArtwork;
  bool get isTransitioning => _isTransitioning;
  bool get hasArtwork => _currentArtwork != null && _currentArtwork!.isNotEmpty;
  SongModel? get currentSong => _currentSong;

  /// Force refresh artwork for current song
  Future<void> refreshArtwork() async {
    if (_currentSong != null) {
      final artwork = await _artworkCache.getArtwork(_currentSong!.id);
      if (artwork != null && artwork.isNotEmpty) {
        _currentArtwork = artwork;
        notifyListeners();
        await updateColorsFromArtwork(artwork);
      }
    }
  }

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
    // Throttle updates to prevent excessive rebuilds
    _updateThrottler.call(() async {
      await _updateColorsFromArtworkSilent(artworkData);
      notifyListeners();
    });
  }

  /// Update colors without notifying listeners (internal use)
  Future<void> _updateColorsFromArtworkSilent(Uint8List? artworkData) async {
    if (artworkData == null) {
      _currentColors = _getDefaultColors();
      return;
    }

    // Check cache first
    final artworkHash = artworkData.hashCode;
    if (_colorCache.containsKey(artworkHash)) {
      _currentColors = _colorCache[artworkHash]!;
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
        // Cache the extracted colors
        _colorCache[artworkHash] = colors;

        // Limit cache size to prevent memory leaks
        if (_colorCache.length > 50) {
          // Remove oldest entries (first keys)
          final keysToRemove =
              _colorCache.keys.take(_colorCache.length - 50).toList();
          for (final key in keysToRemove) {
            _colorCache.remove(key);
          }
        }
      } else {
        _currentColors = _getDefaultColors();
      }
    } catch (e) {
      _currentColors = _getDefaultColors();
    }
  }

  /// Extract and update colors from song artwork
  /// Also updates the artwork for blurred background
  Future<void> updateColorsFromSong(SongModel? song) async {
    if (song == null) {
      if (kDebugMode) {
        debugPrint('🎨 [BG_MGR] Song is null, clearing artwork/background');
      }
      _clearArtwork();
      _useDefaultColors();
      return;
    }

    // Skip if same song AND we already have artwork
    if (_currentSong?.id == song.id && _currentArtwork != null) {
      if (kDebugMode) {
        debugPrint(
            '🎨 [BG_MGR] Skip update for same song id ${song.id}, artwork already available (${_currentArtwork?.length ?? 0} bytes)');
      }
      return;
    }

    // Prevent concurrent updates
    if (_isUpdating) {
      if (kDebugMode) {
        debugPrint(
            '🎨 [BG_MGR] Update already running, skipping song id ${song.id}');
      }
      return;
    }

    try {
      _isUpdating = true;
      _currentSong = song;
      final currentUpdateId = ++_updateCounter;
      if (kDebugMode) {
        debugPrint(
            '🎨 [BG_MGR] Start background update #$currentUpdateId for "${song.title}" (id: ${song.id})');
      }

      // Start transition animation
      _previousArtwork = _currentArtwork;
      _isTransitioning = true;

      // Try to get artwork with multiple retries and increasing delays
      Uint8List? artworkData;
      for (int attempt = 1; attempt <= 3; attempt++) {
        if (kDebugMode) {
          debugPrint(
              '🎨 [BG_MGR] Fetch artwork attempt $attempt/3 for song id ${song.id}');
        }
        artworkData = await _artworkCache.getArtwork(song.id);

        if (artworkData != null && artworkData.isNotEmpty) {
          if (kDebugMode) {
            debugPrint(
                '🎨 [BG_MGR] Artwork fetched for song id ${song.id} (${artworkData.length} bytes)');
          }
          break;
        }
        if (kDebugMode) {
          debugPrint(
              '🎨 [BG_MGR] Artwork not available yet for song id ${song.id}');
        }

        if (attempt < 3) {
          // Shorter delays: 100ms, 200ms
          await Future.delayed(Duration(milliseconds: 100 * attempt));
        }
      }

      // Check if this update is still current
      if (currentUpdateId != _updateCounter || _currentSong?.id != song.id) {
        if (kDebugMode) {
          debugPrint(
              '🎨 [BG_MGR] Discard stale update #$currentUpdateId for song id ${song.id}');
        }
        _isUpdating = false;
        return;
      }

      // Update artwork for blurred background (only if valid)
      if (artworkData != null && artworkData.isNotEmpty) {
        _currentArtwork = artworkData;
        _retryScheduledForSongId = null;
        _artworkRetryTimer?.cancel();
        if (kDebugMode) {
          debugPrint(
              '🎨 [BG_MGR] Apply artwork to background for song id ${song.id} (${artworkData.length} bytes)');
        }
      } else {
        _currentArtwork = null;
        if (kDebugMode) {
          debugPrint(
              '🎨 [BG_MGR] No artwork resolved for song id ${song.id}, using fallback/background colors');
        }
        _artworkRetryTimer?.cancel();
        if (_retryScheduledForSongId != song.id) {
          final songId = song.id;
          _retryScheduledForSongId = songId;
          if (kDebugMode) {
            debugPrint(
                '🎨 [BG_MGR] Schedule delayed retry in ${_artworkRetryDelay.inMilliseconds}ms for song id $songId');
          }
          _artworkRetryTimer = Timer(_artworkRetryDelay, () {
            final currentSong = _currentSong;
            if (_retryScheduledForSongId == songId &&
                currentSong?.id == songId &&
                !_isUpdating) {
              if (kDebugMode) {
                debugPrint('🎨 [BG_MGR] Run delayed retry for song id $songId');
              }
              updateColorsFromSong(currentSong!);
            }
          });
        }
      }

      // Update colors WITHOUT notifying yet
      await _updateColorsFromArtworkSilent(artworkData);

      // Single notify after everything is ready
      if (kDebugMode) {
        debugPrint(
            '🎨 [BG_MGR] Notify listeners for song id ${song.id} (hasArtwork: ${_currentArtwork != null})');
      }
      notifyListeners();

      // Clean up transition state after animation (no notify needed - internal state only)
      Future.delayed(const Duration(milliseconds: 500), () {
        if (currentUpdateId == _updateCounter && _currentSong?.id == song.id) {
          _isTransitioning = false;
          _previousArtwork = null;
        }
      });
    } catch (e) {
      debugPrint('BackgroundManager error: $e');
      _clearArtwork();
      _useDefaultColors();
    } finally {
      _isUpdating = false;
    }
  }

  /// Clear artwork data
  void _clearArtwork() {
    _previousArtwork = _currentArtwork;
    _currentArtwork = null;
    _currentSong = null;
    _isTransitioning = true;
    final clearUpdateId = ++_updateCounter;
    notifyListeners();

    // Clean up transition state after animation (no notify needed - internal state only)
    Future.delayed(const Duration(milliseconds: 500), () {
      if (clearUpdateId == _updateCounter && _currentArtwork == null) {
        _isTransitioning = false;
        _previousArtwork = null;
      }
    });
  }

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
    _artworkRetryTimer?.cancel();
    _updateThrottler.dispose();
    _colorCache.clear();
    super.dispose();
  }
}
