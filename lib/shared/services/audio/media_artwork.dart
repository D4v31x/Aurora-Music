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
    // Validate cached URI — the temp file may have been deleted by the OS
    if (_artworkUriCache.containsKey(songId)) {
      final cachedUri = _artworkUriCache[songId];
      if (cachedUri == null) return null;
      final cachedFile = File(cachedUri.toFilePath());
      if (await cachedFile.exists()) return cachedUri;
      // File was deleted; fall through to recreate it
      _artworkUriCache.remove(songId);
    }
    try {
      final artwork = await _artworkCache.getArtwork(songId);
      if (artwork == null || artwork.isEmpty) {
        _artworkUriCache[songId] = null;
        return null;
      }

      final tempDir = await getTemporaryDirectory();
      final artworkFile = File('${tempDir.path}/notification_art_$songId.jpg');

      await artworkFile.writeAsBytes(artwork);

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
    // Capture song now — currentSong is a getter that could change across awaits.
    final song = currentSong;
    if (song == null) {
      currentArtwork.value = null;
      return;
    }
    try {
      // Use cached artwork service for better performance
      final artwork = await _artworkCache.getArtwork(song.id);
      currentArtwork.value = artwork;

      // Push artwork directly to the background manager, bypassing all guards.
      // This is the primary mechanism for updating the background because this
      // function is confirmed to run on every song change.
      _backgroundManager?.pushArtwork(artwork, song);

      // Also push artwork to home screen widget
      if (artwork != null && artwork.isNotEmpty) {
        unawaited(_homeWidgetService.updateSongInfo(
          title: song.title,
          artist: song.artist ?? 'Unknown Artist',
          isPlaying: isPlayingNotifier.value,
          artworkBytes: artwork,
        ));
      }
    } catch (e) {
      currentArtwork.value = null;
    }
  }

}
