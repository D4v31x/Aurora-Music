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
  /// Create a lightweight MediaItem WITHOUT artwork I/O.
  /// Uses the public MediaStore content URI so Android Auto can load it.
  MediaItem _createMediaItemSync(SongModel song) {
    return MediaItem(
      id: song.id.toString(),
      album: song.album ?? 'Unknown Album',
      title: song.title,
      artist: splitArtists(song.artist ?? 'Unknown Artist').join(', '),
      duration: Duration(milliseconds: song.duration ?? 0),
      artUri: song.albumId != null
          ? Uri.parse(
              'content://media/external/audio/albumart/${song.albumId}')
          : null,
    );
  }

  /// Create MediaItem with artwork for a song.
  /// Uses the public MediaStore content URI so Android Auto can load it.
  Future<MediaItem> _createMediaItem(SongModel song) async {
    return MediaItem(
      id: song.id.toString(),
      album: song.album ?? 'Unknown Album',
      title: song.title,
      artist: splitArtists(song.artist ?? 'Unknown Artist').join(', '),
      duration: Duration(milliseconds: song.duration ?? 0),
      artUri: song.albumId != null
          ? Uri.parse(
              'content://media/external/audio/albumart/${song.albumId}')
          : null,
    );
  }

  /// Update notification queue with full artwork for all songs in the playlist.
  ///
  /// Previously this also pre-fetched artwork bytes and wrote every song's art
  /// to a temp file, but [_createMediaItem] uses content:// URIs from the
  /// system MediaStore, so those file writes were never consumed and caused
  /// significant unnecessary I/O (100 + disk writes on every queue change).
  Future<void> _loadRemainingArtworkInBackground(List<SongModel> songs) async {
    try {
      if (_playlist.isNotEmpty && _currentIndex >= 0) {
        final mediaItems =
            _playlist.map((song) => _createMediaItemSync(song)).toList();
        audioHandler.updateNotificationQueue(mediaItems);
        if (_currentIndex < mediaItems.length) {
          audioHandler.updateNotificationMediaItem(mediaItems[_currentIndex]);
        }
      }
    } catch (e) {
      debugPrint('Error updating notification queue: $e');
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
      debugPrint('🎨 [ARTWORK] updateCurrentArtwork called but currentSong is null (playlist: ${_playlist.length} songs, index: $_currentIndex)');
      currentArtwork.value = null;
      return;
    }
    debugPrint('🎨 [ARTWORK] Fetching artwork for "${song.title}" (id: ${song.id})');
    try {
      // Use cached artwork service for better performance
      final artwork = await _artworkCache.getArtwork(song.id);
      if (artwork != null && artwork.isNotEmpty) {
        debugPrint('🎨 [ARTWORK] Artwork loaded: ${artwork.length} bytes for "${song.title}"');
      } else {
        debugPrint('🎨 [ARTWORK] No artwork found for "${song.title}" (id: ${song.id})');
      }
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
      debugPrint('🎨 [ARTWORK] Error fetching artwork for "${song.title}": $e');
      currentArtwork.value = null;
    }
  }

}
