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
      currentArtworkProvider.value = null;
      return;
    }

    // ── Stage 1: synchronous, zero-latency publish from in-memory cache ──────
    // If the cache already holds this song's artwork, publish it NOW before
    // any await so that every listener (mini player, Now Playing, fullscreen
    // artwork, home widget) sees the correct image on the very same Dart
    // microtask turn as the song change — no visible blank frame.
    final cachedBytes = _artworkCache.getCachedArtworkSync(song.id);
    if (cachedBytes != null && cachedBytes.isNotEmpty) {
      currentArtwork.value = cachedBytes;
      currentArtworkProvider.value = MemoryImage(cachedBytes);
      _backgroundManager?.pushArtwork(cachedBytes, song);
      // With the current song covered, start warming up the next songs so
      // any subsequent skip is also instant.
      _prefetchUpcomingArtwork();
      return; // No async round-trip needed.
    }

    // Cache miss — clear stale artwork from the previous song so listeners
    // show a placeholder rather than the wrong image while we fetch.
    currentArtwork.value = null;
    currentArtworkProvider.value = null;

    try {
      // ── Stage 2: async fetch (MediaStore query via ArtworkCacheService) ──────
      final artwork = await _artworkCache.getArtwork(song.id);

      // Stale-update guard: if the user skipped while we were fetching,
      // discard this result entirely so we never show the wrong artwork.
      if (currentSong?.id != song.id) return;

      currentArtwork.value = artwork;
      currentArtworkProvider.value = (artwork != null && artwork.isNotEmpty)
          ? MemoryImage(artwork)
          : null;

      _backgroundManager?.pushArtwork(artwork, song);

      if (artwork != null && artwork.isNotEmpty) {
        unawaited(_homeWidgetService.updateSongInfo(
          title: song.title,
          artist: song.artist ?? 'Unknown Artist',
          isPlaying: isPlayingNotifier.value,
          artworkBytes: artwork,
        ));
      }

      // Pre-fetch the next few songs' artwork in the background so that the
      // next skip is served instantly from cache (Stage 1 path above).
      _prefetchUpcomingArtwork();
    } catch (e) {
      if (currentSong?.id != song.id) return;
      currentArtwork.value = null;
      currentArtworkProvider.value = null;
    }
  }

  /// Kicks off background pre-loading for the upcoming songs in the queue
  /// so their artwork is in cache before the user gets there.
  void _prefetchUpcomingArtwork() {
    final upcoming = upcomingQueue.take(3).toList();
    for (final s in upcoming) {
      unawaited(_artworkCache.preloadArtwork(s.id));
    }
  }

}
