import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'dart:io';
import '../../services/artwork_cache_service.dart';

/// A mixin that provides common artwork and color extraction functionality.
///
/// This mixin handles:
/// - Loading artwork with caching
/// - Extracting dominant colors for theming
/// - Background gradient generation
///
/// Usage:
/// ```dart
/// class _MyScreenState extends State<MyScreen> with ArtworkMixin {
///   @override
///   ArtworkCacheService get artworkService => _artworkService;
///
///   @override
///   void onDominantColorChanged(Color color) {
///     setState(() => _dominantColor = color);
///   }
/// }
/// ```
mixin ArtworkMixin<T extends StatefulWidget> on State<T> {
  /// The artwork cache service instance. Must be implemented.
  ArtworkCacheService get artworkService;

  /// Called when the dominant color is extracted. Must be implemented.
  void onDominantColorChanged(Color color);

  /// Called when colors are extracted for mesh gradients. Override if needed.
  void onColorsExtracted(List<Color> colors) {}

  /// The default color to use when no artwork is available.
  Color get defaultColor => Colors.deepPurple.shade900;

  /// Extract the dominant color from a song's artwork.
  Future<void> extractColorFromSong(SongModel song) async {
    try {
      final artwork = await artworkService.getArtwork(song.id);
      if (artwork != null && mounted) {
        await _extractColorsFromBytes(artwork);
      } else if (mounted) {
        onDominantColorChanged(defaultColor);
      }
    } catch (e) {
      debugPrint('Error extracting color from song: $e');
      if (mounted) {
        onDominantColorChanged(defaultColor);
      }
    }
  }

  /// Extract the dominant color from a file path.
  Future<void> extractColorFromFile(String? filePath) async {
    if (filePath == null) {
      onDominantColorChanged(defaultColor);
      return;
    }

    try {
      final paletteGenerator = await PaletteGenerator.fromImageProvider(
        FileImage(File(filePath)),
        maximumColorCount: 8,
        size: const Size(100, 100),
      );

      if (!mounted) return;

      _processColors(paletteGenerator);
    } catch (e) {
      debugPrint('Error extracting color from file: $e');
      if (mounted) {
        onDominantColorChanged(defaultColor);
      }
    }
  }

  /// Extract colors from raw bytes.
  Future<void> _extractColorsFromBytes(dynamic artwork) async {
    try {
      final paletteGenerator = await PaletteGenerator.fromImageProvider(
        MemoryImage(artwork),
        maximumColorCount: 8,
      );

      if (!mounted) return;

      _processColors(paletteGenerator);
    } catch (e) {
      debugPrint('Error extracting colors: $e');
      if (mounted) {
        onDominantColorChanged(defaultColor);
      }
    }
  }

  void _processColors(PaletteGenerator paletteGenerator) {
    // Set dominant color
    final dominantColor = paletteGenerator.dominantColor?.color ?? defaultColor;
    onDominantColorChanged(dominantColor);

    // Extract all colors for gradients
    final List<Color> colors = [];

    if (paletteGenerator.dominantColor?.color != null) {
      colors.add(paletteGenerator.dominantColor!.color);
    }
    if (paletteGenerator.vibrantColor?.color != null) {
      colors.add(paletteGenerator.vibrantColor!.color);
    }
    if (paletteGenerator.lightVibrantColor?.color != null) {
      colors.add(paletteGenerator.lightVibrantColor!.color);
    }
    if (paletteGenerator.darkVibrantColor?.color != null) {
      colors.add(paletteGenerator.darkVibrantColor!.color);
    }
    if (paletteGenerator.mutedColor?.color != null) {
      colors.add(paletteGenerator.mutedColor!.color);
    }
    if (paletteGenerator.lightMutedColor?.color != null) {
      colors.add(paletteGenerator.lightMutedColor!.color);
    }
    if (paletteGenerator.darkMutedColor?.color != null) {
      colors.add(paletteGenerator.darkMutedColor!.color);
    }

    if (colors.isNotEmpty) {
      onColorsExtracted(colors);
    }
  }

  /// Build a cached artwork widget for a song.
  Widget buildSongArtwork(int songId, {double size = 50}) {
    return artworkService.buildCachedArtwork(songId, size: size);
  }

  /// Build a cached artwork widget for an album.
  Widget buildAlbumArtwork(int albumId, {double size = 50}) {
    return artworkService.buildCachedAlbumArtwork(albumId, size: size);
  }

  /// Get the cached image provider for a song.
  Future<ImageProvider> getCachedArtwork(int songId) async {
    return artworkService.getCachedImageProvider(songId);
  }
}
