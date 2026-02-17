import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:path_provider/path_provider.dart';

/// Service responsible for updating the Android home screen widget
/// with current playback information (song title, artist, artwork, progress).
///
/// Uses the `home_widget` package to communicate with the native
/// [AuroraMusicWidgetProvider] via SharedPreferences.
class HomeScreenWidgetService {
  static const String _androidWidgetName = 'AuroraMusicWidgetProvider';
  static const String _appGroupId = 'com.aurorasoftware.music';

  // SharedPreferences keys (must match Kotlin side)
  static const String _keySongTitle = 'widget_song_title';
  static const String _keyArtistName = 'widget_artist_name';
  static const String _keyIsPlaying = 'widget_is_playing';
  static const String _keyArtworkPath = 'widget_artwork_path';
  static const String _keyProgress = 'widget_progress';
  static const String _keySource = 'widget_source';
  static const String _keyCurrentTime = 'widget_current_time';
  static const String _keyTotalTime = 'widget_total_time';
  // Color keys for dynamic theming
  static const String _keyBackgroundColor = 'widget_bg_color';
  static const String _keyTextColor = 'widget_text_color';
  static const String _keyProgressColor = 'widget_progress_color';
  // Queue keys for next 6 songs (with artwork)
  static const String _keyQueueSong1 = 'widget_queue_song_1';
  static const String _keyQueueArtist1 = 'widget_queue_artist_1';
  static const String _keyQueueArtwork1 = 'widget_queue_artwork_1';
  static const String _keyQueueSong2 = 'widget_queue_song_2';
  static const String _keyQueueArtist2 = 'widget_queue_artist_2';
  static const String _keyQueueArtwork2 = 'widget_queue_artwork_2';
  static const String _keyQueueSong3 = 'widget_queue_song_3';
  static const String _keyQueueArtist3 = 'widget_queue_artist_3';
  static const String _keyQueueArtwork3 = 'widget_queue_artwork_3';
  static const String _keyQueueSong4 = 'widget_queue_song_4';
  static const String _keyQueueArtist4 = 'widget_queue_artist_4';
  static const String _keyQueueArtwork4 = 'widget_queue_artwork_4';
  static const String _keyQueueSong5 = 'widget_queue_song_5';
  static const String _keyQueueArtist5 = 'widget_queue_artist_5';
  static const String _keyQueueArtwork5 = 'widget_queue_artwork_5';
  static const String _keyQueueSong6 = 'widget_queue_song_6';
  static const String _keyQueueArtist6 = 'widget_queue_artist_6';
  static const String _keyQueueArtwork6 = 'widget_queue_artwork_6';

  static final HomeScreenWidgetService _instance =
      HomeScreenWidgetService._internal();
  factory HomeScreenWidgetService() => _instance;
  HomeScreenWidgetService._internal();

  bool _initialized = false;
  Timer? _progressTimer;

  /// Initialize the home widget service.
  /// Call this once during app startup.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      // Set the app group ID for shared data
      await HomeWidget.setAppGroupId(_appGroupId);

      // Register the background callback for handling widget button taps
      await HomeWidget.registerInteractivityCallback(widgetBackgroundCallback);
    } catch (e) {
      debugPrint('HomeScreenWidgetService: Failed to initialize - $e');
    }
  }

  /// Update the widget with current song information.
  Future<void> updateSongInfo({
    required String title,
    required String artist,
    required bool isPlaying,
    int? songId,
    Uint8List? artworkBytes,
    String? source,
    Duration? currentPosition,
    Duration? totalDuration,
  }) async {
    try {
      // Save song data to SharedPreferences
      await Future.wait([
        HomeWidget.saveWidgetData<String>(_keySongTitle, title),
        HomeWidget.saveWidgetData<String>(_keyArtistName, artist),
        HomeWidget.saveWidgetData<bool>(_keyIsPlaying, isPlaying),
        HomeWidget.saveWidgetData<String>(_keySource, source ?? 'Aurora Music'),
      ]);

      // Handle time display
      if (currentPosition != null && totalDuration != null) {
        await _saveTimeInfo(currentPosition, totalDuration);
      }

      // Handle artwork and extract colors
      if (artworkBytes != null && artworkBytes.isNotEmpty) {
        await _saveArtwork(artworkBytes);
        await _extractAndSaveColors(artworkBytes);
      } else if (songId != null) {
        await _saveArtworkFromQuery(songId);
      } else {
        // Clear artwork and reset to default colors
        await Future.wait([
          HomeWidget.saveWidgetData<String?>(_keyArtworkPath, null),
          HomeWidget.saveWidgetData<int>(
              _keyBackgroundColor, 0xFFD8B4FE), // Light purple default
          HomeWidget.saveWidgetData<int>(
              _keyTextColor, 0xFF000000), // Black text
          HomeWidget.saveWidgetData<int>(
              _keyProgressColor, 0xFF000000), // Black progress
        ]);
      }

      // Trigger native widget update
      await _updateWidget();
    } catch (e) {
      debugPrint('HomeScreenWidgetService: Failed to update song info - $e');
    }
  }

  /// Update only the playing state (for quick play/pause toggles).
  Future<void> updatePlayingState(bool isPlaying) async {
    try {
      await HomeWidget.saveWidgetData<bool>(_keyIsPlaying, isPlaying);
      await _updateWidget();
    } catch (e) {
      debugPrint(
          'HomeScreenWidgetService: Failed to update playing state - $e');
    }
  }

  /// Update the progress bar (0-1000 range).
  Future<void> updateProgress(double progressFraction) async {
    try {
      final progressInt = (progressFraction.clamp(0.0, 1.0) * 1000).round();
      await HomeWidget.saveWidgetData<int>(_keyProgress, progressInt);
      await _updateWidget();
    } catch (e) {
      debugPrint('HomeScreenWidgetService: Failed to update progress - $e');
    }
  }

  /// Start periodic progress updates.
  /// Call this when playback starts.
  void startProgressUpdates({
    required Duration Function() getCurrentPosition,
    required Duration Function() getTotalDuration,
  }) {
    stopProgressUpdates();
    _progressTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      final current = getCurrentPosition();
      final total = getTotalDuration();
      if (total.inMilliseconds > 0) {
        final fraction = current.inMilliseconds / total.inMilliseconds;
        updateProgress(fraction);
      }
    });
  }

  /// Stop periodic progress updates.
  /// Call this when playback pauses or stops.
  void stopProgressUpdates() {
    _progressTimer?.cancel();
    _progressTimer = null;
  }

  /// Clear the widget (show "Not Playing" state).
  Future<void> clearWidget() async {
    try {
      stopProgressUpdates();
      await Future.wait([
        HomeWidget.saveWidgetData<String>(_keySongTitle, 'Not Playing'),
        HomeWidget.saveWidgetData<String>(
            _keyArtistName, 'Tap to open Aurora Music'),
        HomeWidget.saveWidgetData<bool>(_keyIsPlaying, false),
        HomeWidget.saveWidgetData<String?>(_keyArtworkPath, null),
        HomeWidget.saveWidgetData<int>(_keyProgress, 0),
        HomeWidget.saveWidgetData<String>(_keySource, 'Aurora Music'),
        // Clear queue
        HomeWidget.saveWidgetData<String>(_keyQueueSong1, ''),
        HomeWidget.saveWidgetData<String>(_keyQueueArtist1, ''),
        HomeWidget.saveWidgetData<String?>(_keyQueueArtwork1, null),
        HomeWidget.saveWidgetData<String>(_keyQueueSong2, ''),
        HomeWidget.saveWidgetData<String>(_keyQueueArtist2, ''),
        HomeWidget.saveWidgetData<String?>(_keyQueueArtwork2, null),
        HomeWidget.saveWidgetData<String>(_keyQueueSong3, ''),
        HomeWidget.saveWidgetData<String>(_keyQueueArtist3, ''),
        HomeWidget.saveWidgetData<String?>(_keyQueueArtwork3, null),
        HomeWidget.saveWidgetData<String>(_keyQueueSong4, ''),
        HomeWidget.saveWidgetData<String>(_keyQueueArtist4, ''),
        HomeWidget.saveWidgetData<String?>(_keyQueueArtwork4, null),
        HomeWidget.saveWidgetData<String>(_keyQueueSong5, ''),
        HomeWidget.saveWidgetData<String>(_keyQueueArtist5, ''),
        HomeWidget.saveWidgetData<String?>(_keyQueueArtwork5, null),
        HomeWidget.saveWidgetData<String>(_keyQueueSong6, ''),
        HomeWidget.saveWidgetData<String>(_keyQueueArtist6, ''),
        HomeWidget.saveWidgetData<String?>(_keyQueueArtwork6, null),
      ]);
      await _updateWidget();
    } catch (e) {
      debugPrint('HomeScreenWidgetService: Failed to clear widget - $e');
    }
  }

  /// Update the queue (next 6 songs) displayed in the widget.
  Future<void> updateQueue(List<dynamic> upcomingQueue) async {
    try {
      // Update up to 6 queue items
      for (int i = 0; i < 6; i++) {
        final songKey = 'widget_queue_song_${i + 1}';
        final artistKey = 'widget_queue_artist_${i + 1}';
        final artworkKey = 'widget_queue_artwork_${i + 1}';

        if (i < upcomingQueue.length) {
          final song = upcomingQueue[i];
          final songTitle = _getSongTitle(song);
          final artistName = _getArtistName(song);

          await HomeWidget.saveWidgetData<String>(songKey, songTitle);
          await HomeWidget.saveWidgetData<String>(artistKey, artistName);

          // Save queue artwork
          final songId = _getSongId(song);
          if (songId != null) {
            await _saveQueueArtwork(songId, i + 1);
          } else {
            await HomeWidget.saveWidgetData<String?>(artworkKey, null);
          }
        } else {
          await HomeWidget.saveWidgetData<String>(songKey, '');
          await HomeWidget.saveWidgetData<String>(artistKey, '');
          await HomeWidget.saveWidgetData<String?>(artworkKey, null);
        }
      }

      await _updateWidget();
    } catch (e) {
      debugPrint('HomeScreenWidgetService: Failed to update queue - $e');
    }
  }

  /// Get song ID from song object.
  int? _getSongId(dynamic song) {
    if (song == null) return null;
    try {
      return song.id as int?;
    } catch (e) {
      return null;
    }
  }

  /// Save queue artwork to a file for the widget.
  Future<void> _saveQueueArtwork(int songId, int queueIndex) async {
    try {
      final artwork = await OnAudioQuery().queryArtwork(
        songId,
        ArtworkType.AUDIO,
        format: ArtworkFormat.PNG,
        size: 100,
        quality: 60,
      );
      if (artwork != null && artwork.isNotEmpty) {
        final directory = await getApplicationDocumentsDirectory();
        final artworkFile =
            File('${directory.path}/widget_queue_art_$queueIndex.png');
        await artworkFile.writeAsBytes(artwork, flush: true);
        if (await artworkFile.exists() && await artworkFile.length() > 0) {
          await HomeWidget.saveWidgetData<String>(
              'widget_queue_artwork_$queueIndex', artworkFile.path);
        }
      } else {
        await HomeWidget.saveWidgetData<String?>(
            'widget_queue_artwork_$queueIndex', null);
      }
    } catch (e) {
      await HomeWidget.saveWidgetData<String?>(
          'widget_queue_artwork_$queueIndex', null);
    }
  }

  /// Extract song title from song object (handles both SongModel and SpotifySongModel).
  String _getSongTitle(dynamic song) {
    if (song == null) return '';
    try {
      // Try accessing title property (works for both models)
      return song.title?.toString() ?? song.name?.toString() ?? 'Unknown';
    } catch (e) {
      return 'Unknown';
    }
  }

  /// Extract artist name from song object (handles both SongModel and SpotifySongModel).
  String _getArtistName(dynamic song) {
    if (song == null) return '';
    try {
      // Try accessing artist property
      if (song.artist != null) return song.artist.toString();
      // Try artists list (Spotify model)
      if (song.artists != null && song.artists.isNotEmpty) {
        return song.artists.first.name?.toString() ?? 'Unknown Artist';
      }
      return 'Unknown Artist';
    } catch (e) {
      return 'Unknown Artist';
    }
  }

  /// Save artwork bytes to a file and store the path.
  Future<void> _saveArtwork(Uint8List artworkBytes) async {
    try {
      if (artworkBytes.isEmpty) {
        debugPrint('Widget: Cannot save empty artwork');
        return;
      }

      final directory = await getApplicationDocumentsDirectory();
      final artworkFile = File('${directory.path}/widget_artwork.png');

      // Write artwork with proper error handling
      await artworkFile.writeAsBytes(artworkBytes, flush: true);

      // Verify file was written correctly
      if (await artworkFile.exists() && await artworkFile.length() > 0) {
        await HomeWidget.saveWidgetData<String>(
            _keyArtworkPath, artworkFile.path);
        debugPrint(
            'Widget: Artwork saved to ${artworkFile.path} (${artworkBytes.length} bytes)');
      } else {
        debugPrint('Widget: Artwork file write failed');
      }
    } catch (e) {
      debugPrint('HomeScreenWidgetService: Failed to save artwork - $e');
      // Clear artwork path on error
      await HomeWidget.saveWidgetData<String?>(_keyArtworkPath, null);
    }
  }

  /// Query artwork from device media store by song ID.
  Future<void> _saveArtworkFromQuery(int songId) async {
    try {
      final artwork = await OnAudioQuery().queryArtwork(
        songId,
        ArtworkType.AUDIO,
        format: ArtworkFormat.PNG,
        size: 300,
        quality: 80,
      );
      if (artwork != null && artwork.isNotEmpty) {
        await _saveArtwork(artwork);
        await _extractAndSaveColors(artwork);
      } else {
        await HomeWidget.saveWidgetData<String?>(_keyArtworkPath, null);
        await _setDefaultColors();
      }
    } catch (e) {
      debugPrint('HomeScreenWidgetService: Failed to query artwork - $e');
    }
  }

  /// Extract dominant color from artwork and calculate readable text color.
  Future<void> _extractAndSaveColors(Uint8List artworkBytes) async {
    try {
      // Validate artwork bytes
      if (artworkBytes.isEmpty) {
        debugPrint('Widget: Empty artwork bytes, using defaults');
        await _setDefaultColors();
        return;
      }

      debugPrint('Widget: Extracting colors from ${artworkBytes.length} bytes');

      // Generate color palette from image bytes with timeout protection
      final palette = await PaletteGenerator.fromImageProvider(
        MemoryImage(artworkBytes),
        size: const Size(100, 100), // Downscale for faster processing
        maximumColorCount: 16,
      ).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          debugPrint('Widget: Color extraction timed out');
          throw Exception('Color extraction timed out');
        },
      );

      // Get dominant color (fallback to vibrant or first available)
      Color backgroundColor = palette.dominantColor?.color ??
          palette.vibrantColor?.color ??
          palette.lightVibrantColor?.color ??
          const Color(0xFFD8B4FE); // Light purple fallback

      // Calculate luminance to determine if we need dark or light text
      final luminance = backgroundColor.computeLuminance();
      final textColor = luminance > 0.5 ? Colors.black : Colors.white;
      final progressColor = luminance > 0.5 ? Colors.black : Colors.white;

      debugPrint(
          'Widget colors: bg=${backgroundColor.value.toRadixString(16)}, text=${textColor.value.toRadixString(16)}, luminance=$luminance');

      // Save colors as int values (ARGB format)
      await Future.wait([
        HomeWidget.saveWidgetData<int>(
            _keyBackgroundColor, backgroundColor.value),
        HomeWidget.saveWidgetData<int>(_keyTextColor, textColor.value),
        HomeWidget.saveWidgetData<int>(_keyProgressColor, progressColor.value),
      ]);

      debugPrint(
          'Widget colors: bg=${backgroundColor.value.toRadixString(16)}, text=${textColor.value.toRadixString(16)}');
    } catch (e) {
      debugPrint('HomeScreenWidgetService: Failed to extract colors - $e');
      await _setDefaultColors();
    }
  }

  /// Set default colors when no artwork is available.
  Future<void> _setDefaultColors() async {
    await Future.wait([
      HomeWidget.saveWidgetData<int>(
          _keyBackgroundColor, 0xFFD8B4FE), // Light purple
      HomeWidget.saveWidgetData<int>(_keyTextColor, 0xFF000000), // Black
      HomeWidget.saveWidgetData<int>(_keyProgressColor, 0xFF000000), // Black
    ]);
  }

  /// Save formatted time information.
  Future<void> _saveTimeInfo(Duration current, Duration total) async {
    final currentStr = _formatDuration(current);
    final totalStr = _formatDuration(total);

    await Future.wait([
      HomeWidget.saveWidgetData<String>(_keyCurrentTime, currentStr),
      HomeWidget.saveWidgetData<String>(_keyTotalTime, totalStr),
    ]);
  }

  /// Format duration as M:SS or H:MM:SS.
  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '$minutes:${seconds.toString().padLeft(2, '0')}';
    }
  }

  /// Trigger native widget refresh.
  Future<void> _updateWidget() async {
    try {
      await HomeWidget.updateWidget(
        androidName: _androidWidgetName,
        qualifiedAndroidName: 'com.aurorasoftware.music.$_androidWidgetName',
      );
    } catch (e) {
      debugPrint('HomeScreenWidgetService: Failed to update widget - $e');
    }
  }

  /// Dispose the service.
  void dispose() {
    stopProgressUpdates();
  }
}

/// Background callback for handling widget button taps.
/// This function is called by the home_widget package when a user
/// taps a button on the widget, even if the app is not running.
///
/// It must be a top-level function (not a class method).
@pragma('vm:entry-point')
Future<void> widgetBackgroundCallback(Uri? uri) async {
  if (uri == null) return;

  final command = uri.queryParameters['command'];
  if (command == null) return;

  debugPrint(
      'HomeScreenWidgetService: Background callback received command: $command');

  // The commands will be handled by AudioPlayerService when the app is running.
  // When the app is in the background, audio_service handles media commands.
  // We rely on the MediaSession integration for background playback control.
}
