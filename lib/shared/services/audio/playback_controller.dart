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

      // Slice the song list to start at [startIndex] — songs before the
      // selected track are excluded from the queue so "playing from the
      // middle" shows only the current song and the ones after it.
      _playlist = List<SongModel>.from(songs.sublist(startIndex));
      _currentIndex = 0;
      _queueCount = 0; // No user-queued songs when starting fresh

      // When shuffle is active, the new queue must also be shuffled.
      // Reset _originalPlaylist to the freshly loaded songs, then shuffle.
      if (_isShuffle) {
        _originalPlaylist = List<SongModel>.from(_playlist);
        final current = _playlist[0];
        final rest = List<SongModel>.from(_playlist)..removeAt(0);
        rest.shuffle(Random());
        _playlist = [current, ...rest];
        _currentIndex = 0;
      } else {
        _originalPlaylist = [];
      }

      _isSettingPlaylist = true; // Guard against currentIndexStream race

      final startSongInfo = songs[startIndex];
      debugPrint(
          '🎵 [PLAYBACK] setPlaylist: ${songs.length} songs, starting at index $startIndex — "${startSongInfo.title}" by ${startSongInfo.artist ?? 'Unknown'}');

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

          // Suppress automatic mediaItem updates during source setup
          // to prevent intermediate index 0 from overriding the correct item
          audioHandler.suppressIndexUpdates();

          await _audioPlayer.setAudioSources(
            _playlist.asMap().entries.map((entry) {
              final song = entry.value;
              final mediaItem = lightMediaItems[entry.key];
              final uri = song.uri ?? song.data;
              return AudioSource.uri(
                Uri.parse(uri),
                tag: mediaItem,
              );
            }).toList(),
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

          // Sync _currentIndex with the player's actual index BEFORE play().
          // just_audio sets currentIndex when setAudioSources is called, so
          // this is already correct here.
          final actualIndex = _audioPlayer.currentIndex ?? _currentIndex;
          if (actualIndex >= 0 && actualIndex < _playlist.length) {
            _currentIndex = actualIndex;
          }

          // Update current media item in notification
          audioHandler.updateNotificationMediaItem(startMediaItem);

          // Batch all state updates BEFORE play() — in just_audio ^0.10.x,
          // play() returns a Future that completes only when playback is
          // *interrupted* (paused/stopped/error), not when it starts.
          // Awaiting it would block all code below for the song's entire
          // duration, so we must fire it without awaiting.
          _isPlaying = true;
          isPlayingNotifier.value = true;
          _incrementPlayCount(_playlist[_currentIndex]);
          _currentSongController.add(_playlist[_currentIndex]);
          currentSongNotifier.value = _playlist[_currentIndex];

          // Release guard before firing play() so index-stream events that
          // arrive during/after the play command are handled correctly.
          _isSettingPlaylist = false;

          debugPrint('🎵 [PLAYBACK] ▶️ Starting playback: "${_playlist[_currentIndex].title}" by ${_playlist[_currentIndex].artist ?? 'Unknown'} (id: ${_playlist[_currentIndex].id})');
          // Fire and forget — do NOT await; see comment above.
          unawaited(_audioPlayer.play());

          // Fire and forget UI updates
          unawaited(updateCurrentArtwork());
          unawaited(_updateBackgroundColors());

          // Load remaining artwork in background (non-blocking)
          unawaited(_loadRemainingArtworkInBackground(_playlist));

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
      if (_gaplessPlayback) {
        // Use lightweight MediaItems for instant rebuild
        final mediaItems =
            newSongs.map((song) => _createMediaItemSync(song)).toList();

        // Preserve current playback position
        final currentPosition = _audioPlayer.position;
        final currentIndex = _audioPlayer.currentIndex ?? _currentIndex;

        await _audioPlayer.setAudioSources(
          newSongs
              .asMap()
              .entries
              .map((entry) => AudioSource.uri(
                    Uri.parse(entry.value.uri ?? entry.value.data),
                    tag: mediaItems[entry.key],
                  ))
              .toList(),
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
        final oldIndex = _currentIndex;
        _currentIndex = index;
        _updateQueueCountForIndexChange(oldIndex, index);
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

          // Update notification with current media item
          final mediaItem = await _createMediaItem(song);
          audioHandler.updateNotificationMediaItem(mediaItem);

          // Set state BEFORE firing play() — play() in just_audio ^0.10.x
          // completes only when playback is interrupted, not when it starts.
          _isPlaying = true;
          isPlayingNotifier.value = true;
          _incrementPlayCount(song);
          _currentSongController.add(song);
          currentSongNotifier.value = song;

          unawaited(_audioPlayer.play()); // fire-and-forget
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

          // Set state BEFORE firing play() — same reason as gapless path.
          _isPlaying = true;
          isPlayingNotifier.value = true;
          _incrementPlayCount(song);
          _currentSongController.add(song);
          currentSongNotifier.value = song;

          unawaited(_audioPlayer.play()); // fire-and-forget
        }

        // Fire and forget UI updates (now reachable immediately)
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

  Future<void> pause() async {
    await _audioPlayer.pause();
    _isPlaying = false;
    isPlayingNotifier.value = false;
    // No need for notifyListeners - ValueNotifier handles UI updates
  }

  Future<void> resume() async {
    // Do NOT guard on _audioPlayer.playing here. In single-source (non-gapless)
    // mode, just_audio keeps playing==true even after ProcessingState.completed
    // (the "want-to-play" intent stays set). That means the guard would silently
    // swallow every tap of the play button after a track finishes. Calling
    // play() when already truly playing is a harmless no-op in just_audio.
    unawaited(_audioPlayer.play()); // fire-and-forget: play() completes on interrupt
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
    // _audioPlayer.playing can remain true after ProcessingState.completed in
    // single-source (non-gapless) mode — just_audio keeps the "want-to-play"
    // flag set even when there is nothing left to play. Treat completed/idle
    // as not-playing so the UI button reflects reality when the app returns
    // from the background.
    final ps = _audioPlayer.processingState;
    final actuallyPlaying = _audioPlayer.playing &&
        ps != ProcessingState.completed &&
        ps != ProcessingState.idle;
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
