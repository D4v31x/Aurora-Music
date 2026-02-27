part of '../audio_player_service.dart';

extension AudioMediaArtworkExtension on AudioPlayerService {
  /// Update background colors based on current song
  Future<void> _updateBackgroundColors() async {
    if (_backgroundManager != null && currentSong != null) {
      if (kDebugMode) {
        debugPrint(
            '🎨 [BG_SYNC] Request background update for song: "${currentSong!.title}" (id: ${currentSong!.id})');
      }
      await _backgroundManager!.updateColorsFromSong(currentSong);
      if (kDebugMode) {
        debugPrint(
            '🎨 [BG_SYNC] Background update call completed for song id: ${currentSong!.id}');
      }
    }
  }

  /// Get artwork URI for media notification
  /// Saves artwork to a temp file and returns the file URI.
  /// Results are cached to avoid redundant disk writes.
  Future<Uri?> _getArtworkUri(int songId) async {
    // Return cached URI if available
    if (_artworkUriCache.containsKey(songId)) {
      return _artworkUriCache[songId];
    }
    try {
      final artwork = await _artworkCache.getArtwork(songId);
      if (artwork == null || artwork.isEmpty) {
        _artworkUriCache[songId] = null;
        return null;
      }

      final tempDir = await getTemporaryDirectory();
      final artworkFile = File('${tempDir.path}/notification_art_$songId.jpg');

      // Only write if file doesn't already exist
      if (!await artworkFile.exists()) {
        await artworkFile.writeAsBytes(artwork);
      }

      final uri = Uri.parse('file://${artworkFile.path}');
      _artworkUriCache[songId] = uri;
      return uri;
    } catch (e) {
      debugPrint('Error getting artwork URI: $e');
      _artworkUriCache[songId] = null;
      return null;
    }
  }

  /// Create a lightweight MediaItem WITHOUT artwork (instant, no I/O)
  MediaItem _createMediaItemSync(SongModel song) {
    return MediaItem(
      id: song.id.toString(),
      album: song.album ?? 'Unknown Album',
      title: song.title,
      artist: splitArtists(song.artist ?? 'Unknown Artist').join(', '),
      duration: Duration(milliseconds: song.duration ?? 0),
    );
  }

  /// Create MediaItem with artwork for a song (async, involves I/O)
  Future<MediaItem> _createMediaItem(SongModel song) async {
    final artUri = await _getArtworkUri(song.id);
    return MediaItem(
      id: song.id.toString(),
      album: song.album ?? 'Unknown Album',
      title: song.title,
      artist: splitArtists(song.artist ?? 'Unknown Artist').join(', '),
      duration: Duration(milliseconds: song.duration ?? 0),
      artUri: artUri,
    );
  }

  /// Load artwork for remaining songs in background and update notification queue
  Future<void> _loadRemainingArtworkInBackground(List<SongModel> songs) async {
    try {
      // Process in small batches to avoid blocking
      const batchSize = 5;
      for (var i = 0; i < songs.length; i += batchSize) {
        final end = (i + batchSize).clamp(0, songs.length);
        final batch = songs.sublist(i, end);
        await Future.wait(batch.map((song) => _getArtworkUri(song.id)));
      }

      // Update notification queue with full artwork after loading
      if (_playlist.isNotEmpty && _currentIndex >= 0) {
        final mediaItems = await Future.wait(
          _playlist.map((song) => _createMediaItem(song)),
        );
        audioHandler.updateNotificationQueue(mediaItems);
        // Update current item's notification with artwork
        if (_currentIndex < mediaItems.length) {
          audioHandler.updateNotificationMediaItem(mediaItems[_currentIndex]);
        }
      }
    } catch (e) {
      debugPrint('Error loading background artwork: $e');
    }
  }

  Future<Uint8List?> getCurrentSongArtwork() async {
    if (currentSong == null) return null;
    try {
      // Use cached artwork service instead of querying directly
      return await _artworkCache.getArtwork(currentSong!.id);
    } catch (e) {
      return null;
    }
  }

  Future<void> updateCurrentArtwork() async {
    if (currentSong == null) {
      currentArtwork.value = null;
      return;
    }
    try {
      // Use cached artwork service for better performance
      final artwork = await _artworkCache.getArtwork(currentSong!.id);
      currentArtwork.value = artwork;

      // Also push artwork to home screen widget
      if (artwork != null && artwork.isNotEmpty) {
        _homeWidgetService.updateSongInfo(
          title: currentSong!.title,
          artist: currentSong!.artist ?? 'Unknown Artist',
          isPlaying: isPlayingNotifier.value,
          artworkBytes: artwork,
        );
      }
    } catch (e) {
      currentArtwork.value = null;
    }
  }

}
