part of '../audio_player_service.dart';

extension AudioPlaybackControllerExtension on AudioPlayerService {
  // Playback Control
  Future<void> setPlaylist(
    List<SongModel> songs,
    int startIndex, {
    PlaybackSourceInfo? source,
  }) async {
    // Update playback source
    _playbackSource = source ?? PlaybackSourceInfo.unknown;

    try {
      if (songs.isEmpty || startIndex < 0 || startIndex >= songs.length) {
        debugPrint('Invalid playlist or start index');
        _errorController.add('Invalid playlist or start index');
        return;
      }

      // Reset loading flag when setting a new playlist
      _isLoading = false;

      _playlist = songs;
      _currentIndex = startIndex;

      // When shuffle is active, the new queue must also be shuffled.
      // Reset _originalPlaylist to the freshly loaded songs, then shuffle.
      if (_isShuffle) {
        _originalPlaylist = List<SongModel>.from(_playlist);
        final current = _playlist[_currentIndex];
        final rest = List<SongModel>.from(_playlist)..removeAt(_currentIndex);
        rest.shuffle(Random());
        _playlist = [current, ...rest];
        _currentIndex = 0;
      } else {
        _originalPlaylist = [];
      }

      _isSettingPlaylist = true; // Guard against currentIndexStream race

      debugPrint(
          'Setting playlist with ${songs.length} songs, starting at index $startIndex');

      if (_gaplessPlayback) {
        try {
          // Create lightweight MediaItems WITHOUT artwork for instant startup
          final lightMediaItems =
              _playlist.map((song) => _createMediaItemSync(song)).toList();
          // Only fetch artwork for the starting song (fast, usually cached)
          final startSong = _playlist[_currentIndex];
          final startMediaItem = await _createMediaItem(startSong);
          lightMediaItems[_currentIndex] = startMediaItem;

          // Update audio handler queue for notification
          audioHandler.updateNotificationQueue(lightMediaItems);

          final playlistSource = ConcatenatingAudioSource(
            children: _playlist.asMap().entries.map((entry) {
              final song = entry.value;
              final mediaItem = lightMediaItems[entry.key];
              final uri = song.uri ?? song.data;
              return AudioSource.uri(
                Uri.parse(uri),
                tag: mediaItem,
              );
            }).toList(),
          );

          // Suppress automatic mediaItem updates during source setup
          // to prevent intermediate index 0 from overriding the correct item
          audioHandler.suppressIndexUpdates();

          await _audioPlayer.setAudioSource(
            playlistSource,
            initialIndex: _currentIndex,
            initialPosition: Duration.zero,
          );

          // Apply current shuffle and loop settings to the player.
          // We manage shuffle ordering ourselves by reordering _playlist, so
          // just_audio's internal shuffle mode is always kept off.
          debugPrint(
              '🎵 [AUDIO_SOURCE] Applying loopMode: $_loopMode (shuffle managed in _playlist)');
          await _audioPlayer.setShuffleModeEnabled(false);
          await _audioPlayer.setLoopMode(_loopMode);

          // Resume automatic mediaItem updates
          audioHandler.resumeIndexUpdates();

          await _audioPlayer.play();

          // Sync _currentIndex with the player's actual index to prevent
          // stale currentIndexStream events from overriding it after the
          // guard is released.
          final actualIndex = _audioPlayer.currentIndex ?? _currentIndex;
          if (actualIndex >= 0 && actualIndex < _playlist.length) {
            _currentIndex = actualIndex;
          }

          // Update current media item in notification (after index sync)
          audioHandler.updateNotificationMediaItem(startMediaItem);

          // Batch all state updates
          _isPlaying = true;
          isPlayingNotifier.value = true;
          _incrementPlayCount(_playlist[_currentIndex]);
          _currentSongController.add(_playlist[_currentIndex]);
          currentSongNotifier.value = _playlist[_currentIndex];

          // Fire and forget UI updates
          unawaited(updateCurrentArtwork());
          unawaited(_updateBackgroundColors());

          // Load remaining artwork in background (non-blocking)
          unawaited(_loadRemainingArtworkInBackground(_playlist));

          // Release guard AFTER all state is consistent — this prevents
          // stale currentIndexStream events from overriding _currentIndex
          _isSettingPlaylist = false;

          // Single debounced notification
          _scheduleNotify();
          unawaited(saveQueueState());
        } catch (e) {
          _isSettingPlaylist = false; // Release guard on error
          audioHandler.resumeIndexUpdates(); // Resume notification updates
          // "Loading interrupted" is expected when rapidly changing songs - don't treat as error
          if (e.toString().contains('Loading interrupted')) {
            debugPrint('Audio load interrupted (new song selected)');
            return;
          }
          debugPrint('Error setting audio source: $e');
          _isPlaying = false;
          isPlayingNotifier.value = false;
          _scheduleNotify();
          rethrow;
        }
      } else {
        // For non-gapless playback, keep the guard active during play()
        // because play() calls setAudioSource for a single song which resets
        // the player's currentIndex to 0, but _currentIndex refers to the
        // position in the full _playlist.
        try {
          await play();
        } finally {
          _isSettingPlaylist = false;
        }
      }
    } catch (e) {
      _isSettingPlaylist = false; // Release guard on error
      audioHandler.resumeIndexUpdates(); // Resume notification updates
      // "Loading interrupted" is expected when rapidly changing songs - don't treat as error
      if (e.toString().contains('Loading interrupted')) {
        debugPrint('Audio load interrupted (new song selected)');
        return;
      }
      debugPrint('Failed to set playlist: $e');
      _errorController.add('Failed to set playlist: $e');
      _isPlaying = false;
      isPlayingNotifier.value = false;
      _isLoading = false;
      _scheduleNotify();
    }
  }

  Future<void> updatePlaylist(List<SongModel> newSongs) async {
    try {
      if (_gaplessPlayback &&
          _audioPlayer.audioSource is ConcatenatingAudioSource) {
        // Use lightweight MediaItems for instant rebuild
        final mediaItems =
            newSongs.map((song) => _createMediaItemSync(song)).toList();

        final newSource = ConcatenatingAudioSource(
          children: newSongs
              .asMap()
              .entries
              .map((entry) => AudioSource.uri(
                    Uri.parse(entry.value.uri ?? entry.value.data),
                    tag: mediaItems[entry.key],
                  ))
              .toList(),
        );

        // Preserve current playback position
        final currentPosition = _audioPlayer.position;
        final currentIndex = _audioPlayer.currentIndex ?? _currentIndex;

        await _audioPlayer.setAudioSource(
          newSource,
          initialIndex: currentIndex,
          initialPosition: currentPosition,
        );

        _playlist = newSongs;
        _currentIndex = currentIndex;

        // Load artwork in background
        unawaited(_loadRemainingArtworkInBackground(newSongs));

        _scheduleNotify();
      } else {
        _playlist = newSongs;
        _currentIndex = 0;
        await setPlaylist(newSongs, 0);
      }
    } catch (e) {
      _errorController.add('Failed to update playlist: $e');
      _scheduleNotify();
    }
  }

  Future<void> play({int? index}) async {
    // If an explicit index is provided (user selected a song), allow it
    // even if a previous load is in progress — the user's intent takes priority.
    if (index != null) {
      _isLoading = false;
    }

    // Prevent concurrent play calls
    if (_isLoading) {
      debugPrint('Already loading, ignoring play request');
      return;
    }

    _isLoading = true;

    try {
      if (index != null) {
        _currentIndex = index;
      }

      debugPrint(
          'Play called with index: $index, current index: $_currentIndex, playlist length: ${_playlist.length}');

      if (_currentIndex >= 0 && _currentIndex < _playlist.length) {
        final song = _playlist[_currentIndex];
        debugPrint('Playing song: ${song.title} by ${song.artist}');

        if (_gaplessPlayback) {
          debugPrint(
              'Using gapless playback, seeking to index: $_currentIndex');
          await _audioPlayer.seek(Duration.zero, index: _currentIndex);
          await _audioPlayer.play();

          // Update notification with current media item
          final mediaItem = await _createMediaItem(song);
          audioHandler.updateNotificationMediaItem(mediaItem);
        } else {
          final url = song.uri ?? song.data;
          debugPrint('Non-gapless playback, loading URL: $url');

          final mediaItem = await _createMediaItem(song);

          // Update notification
          audioHandler.updateNotificationMediaItem(mediaItem);

          // Suppress index stream events during setAudioSource — loading a
          // single song resets the player index to 0, but _currentIndex
          // refers to the position in the full _playlist.
          final wasSettingPlaylist = _isSettingPlaylist;
          _isSettingPlaylist = true;
          audioHandler.suppressIndexUpdates();
          try {
            await _audioPlayer.setAudioSource(
              AudioSource.uri(Uri.parse(url), tag: mediaItem),
            );
          } finally {
            _isSettingPlaylist = wasSettingPlaylist;
            audioHandler.resumeIndexUpdates();
          }
          await _audioPlayer.play();
        }

        // Batch all state updates after playback starts
        _isPlaying = true;
        isPlayingNotifier.value = true;
        _incrementPlayCount(song);
        _currentSongController.add(song);
        currentSongNotifier.value = song;

        // Fire and forget - don't await these UI updates
        unawaited(updateCurrentArtwork());
        unawaited(_updateBackgroundColors());

        // Single notification at the end
        _scheduleNotify();
      } else {
        debugPrint('Invalid index or empty playlist');
      }
    } catch (e, stackTrace) {
      debugPrint('Failed to play song: $e');
      debugPrint('Stack trace: $stackTrace');
      _isPlaying = false;
      isPlayingNotifier.value = false;
      _currentSongController.addError('Failed to play song: $e');
      _scheduleNotify();
    } finally {
      _isLoading = false;
    }
  }

  void setSpotifyPlaylist(List<SpotifySongModel> playlist, int initialIndex) {
    _spotifyPlaylist = playlist;
    _currentSpotifyIndex = initialIndex;
    _setAudioSource();
  }

  void _setAudioSource() {
    if (_spotifyPlaylist.isEmpty) return;

    final playlist = ConcatenatingAudioSource(
      children: _spotifyPlaylist
          .map((song) =>
              AudioSource.uri(Uri.parse(song.uri), tag: song.toMediaItem()))
          .toList(),
    );

    audioPlayer.setAudioSource(playlist, initialIndex: _currentSpotifyIndex);
  }

  Future<void> pause() async {
    await _audioPlayer.pause();
    _isPlaying = false;
    isPlayingNotifier.value = false;
    // No need for notifyListeners - ValueNotifier handles UI updates
  }

  Future<void> resume() async {
    if (_audioPlayer.playing) return;
    await _audioPlayer.play();
    _isPlaying = true;
    isPlayingNotifier.value = true;
    // No need for notifyListeners - ValueNotifier handles UI updates
  }

  Future<void> stop() async {
    await _audioPlayer.stop();
    _isPlaying = false;
    isPlayingNotifier.value = false;
    // No need for notifyListeners - ValueNotifier handles UI updates
  }

  /// Sync the internal playing state with the actual audio player state.
  /// Call this when the app comes back to foreground to ensure UI reflects
  /// any changes made via lock screen or notification controls.
  /// Always forces a UI refresh since stream events may have been missed
  /// while the Flutter engine was paused in the background.
  void syncPlaybackState() {
    final actuallyPlaying = _audioPlayer.playing;
    _isPlaying = actuallyPlaying;
    // Unconditionally assign the value. If it differs, ValueNotifier fires
    // normally. If it is the same, we still call _scheduleNotify() below to
    // refresh any Provider-based consumers that may be stale.
    isPlayingNotifier.value = actuallyPlaying;
    // Force Provider listeners (e.g. Selector, Consumer) to re-evaluate even
    // when ValueNotifier did not fire (value unchanged).
    _scheduleNotify();
  }

  void skip() async {
    _isLoading = false; // Reset loading flag to allow new song to play

    debugPrint(
        '⏭️ [SKIP] Called - hasNext: ${_audioPlayer.hasNext}, currentIndex: $_currentIndex, shuffle: $_isShuffle, loopMode: $_loopMode');

    if (_loopMode == LoopMode.one) {
      // Repeat ONE: restart the current track.
      debugPrint('⏭️ [SKIP] Repeat ONE — restarting current track');
      await _audioPlayer.seek(Duration.zero);
      return;
    }

    if (_audioPlayer.hasNext) {
      // Normal case: advance to the next track.
      debugPrint('⏭️ [SKIP] Seeking to next track');
      await _audioPlayer.seekToNext();
    } else {
      // Last song in the queue.
      if (_loopMode == LoopMode.all) {
        debugPrint('⏭️ [SKIP] At end of queue, wrapping to start (repeat ALL)');
        await _audioPlayer.seek(Duration.zero, index: 0);
        await _audioPlayer.play();
      } else {
        // Repeat OFF: stop playback.
        debugPrint('⏭️ [SKIP] At end of queue, stopping (repeat OFF)');
        await _audioPlayer.pause();
        await _audioPlayer.seek(Duration.zero);
        _isPlaying = false;
        isPlayingNotifier.value = false;
        _scheduleNotify();
      }
    }
  }

  void back() async {
    _isLoading = false; // Reset loading flag to allow new song to play

    final currentPosition = _audioPlayer.position;

    // If more than 3 seconds have elapsed, restart the current track.
    if (currentPosition > const Duration(seconds: kPreviousThresholdSeconds)) {
      debugPrint(
          '⏮️ [BACK] Past 3s — restarting current song (position: ${currentPosition.inSeconds}s)');
      await _audioPlayer.seek(Duration.zero);
      return;
    }

    // Within 3 seconds: move to the previous track.
    if (_audioPlayer.hasPrevious) {
      debugPrint('⏮️ [BACK] Within 3s and has previous — seeking to previous');
      await _audioPlayer.seekToPrevious();
    } else {
      // At the very first track in the queue.
      if (_loopMode == LoopMode.all && _playlist.isNotEmpty) {
        // Repeat ALL: jump to the last track.
        debugPrint('⏮️ [BACK] At first track, repeat ALL — jumping to last');
        await _audioPlayer.seek(Duration.zero, index: _playlist.length - 1);
      } else {
        // Repeat OFF / ONE at first track: restart.
        debugPrint(
            '⏮️ [BACK] At first track (position: ${currentPosition.inSeconds}s) — restarting');
        await _audioPlayer.seek(Duration.zero);
      }
    }
  }

  void _sortPlaylist() {
    switch (_defaultSortOrder) {
      case 'title':
        _playlist.sort((a, b) => (a.title).compareTo(b.title));
        break;
      case 'artist':
        _playlist.sort((a, b) => (a.artist ?? '').compareTo(b.artist ?? ''));
        break;
      case 'album':
        _playlist.sort((a, b) => (a.album ?? '').compareTo(b.album ?? ''));
        break;
      case 'date_added':
        // Implement date added sorting if you track this information
        break;
    }
  }
}
