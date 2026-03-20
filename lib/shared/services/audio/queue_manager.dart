part of '../audio_player_service.dart';

extension AudioQueueManagerExtension on AudioPlayerService {

  /// Add a single song to the queue.
  ///
  /// The song is inserted right after any already-queued songs (i.e., songs
  /// previously added via [addToQueue] or [playNext]) but BEFORE the
  /// remaining source songs.  This ensures repeated "Add to queue" calls
  /// build a FIFO queue that finishes before the source continues.
  Future<void> addToQueue(SongModel song) async {
    if (_playlist.isEmpty) {
      // If no playlist, create one with this song
      await setPlaylist([song], 0);
      return;
    }

    // Insert after any already-queued songs, before source continuation.
    final insertIndex = (_currentIndex + 1 + _queueCount).clamp(0, _playlist.length);
    _playlist.insert(insertIndex, song);
    _queueCount++;

    if (_gaplessPlayback) {
      try {
        final mediaItem = _createMediaItemSync(song);
        final uri = song.uri ?? song.data;
        await _audioPlayer.insertAudioSource(insertIndex, AudioSource.uri(Uri.parse(uri), tag: mediaItem));

        // Update notification queue with lightweight items
        final mediaItems =
            _playlist.map((s) => _createMediaItemSync(s)).toList();
        audioHandler.updateNotificationQueue(mediaItems);

        // Load artwork in background
        unawaited(_loadRemainingArtworkInBackground(_playlist));
      } catch (e) {
        debugPrint('Error adding song to queue: $e');
      }
    }

    _scheduleNotify();
    unawaited(saveQueueState());
  }

  /// Add multiple songs to the queue at once.
  ///
  /// The songs are inserted after all existing queued songs, before source
  /// continuation. Equivalent to calling [addToQueue] for each song.
  Future<void> addMultipleToQueue(List<SongModel> songs) async {
    if (songs.isEmpty) return;

    if (_playlist.isEmpty) {
      // If no playlist, create one with these songs
      await setPlaylist(songs, 0);
      return;
    }

    final insertStart = (_currentIndex + 1 + _queueCount).clamp(0, _playlist.length);
    _playlist.insertAll(insertStart, songs);
    _queueCount += songs.length;

    if (_gaplessPlayback) {
      try {
        final mediaItems =
            songs.map((song) => _createMediaItemSync(song)).toList();

        final audioSources = songs.asMap().entries.map((e) {
          final uri = e.value.uri ?? e.value.data;
          return AudioSource.uri(Uri.parse(uri), tag: mediaItems[e.key]);
        }).toList();
        await _audioPlayer.insertAudioSources(insertStart, audioSources);

        // Update notification queue with lightweight items
        final allMediaItems =
            _playlist.map((s) => _createMediaItemSync(s)).toList();
        audioHandler.updateNotificationQueue(allMediaItems);

        // Load artwork in background
        unawaited(_loadRemainingArtworkInBackground(_playlist));
      } catch (e) {
        debugPrint('Error adding songs to queue: $e');
      }
    }

    _scheduleNotify();
    unawaited(saveQueueState());
  }

  /// Add a song to play immediately after the current track.
  ///
  /// Unlike [addToQueue], which appends after all queued songs, this inserts
  /// the song at the very front of the queue (position _currentIndex + 1).
  Future<void> playNext(SongModel song) async {
    if (_playlist.isEmpty) {
      await setPlaylist([song], 0);
      return;
    }

    final insertIndex = _currentIndex + 1;
    _playlist.insert(insertIndex, song);
    _queueCount++; // This song is part of the user-queued zone

    if (_gaplessPlayback) {
      try {
        final mediaItem = _createMediaItemSync(song);
        final uri = song.uri ?? song.data;
        await _audioPlayer.insertAudioSource(
            insertIndex, AudioSource.uri(Uri.parse(uri), tag: mediaItem));

        // Update notification queue with lightweight items
        final mediaItems =
            _playlist.map((s) => _createMediaItemSync(s)).toList();
        audioHandler.updateNotificationQueue(mediaItems);

        // Load artwork in background
        unawaited(_loadRemainingArtworkInBackground(_playlist));
      } catch (e) {
        debugPrint('Error inserting song to play next: $e');
      }
    }

    _scheduleNotify();
    unawaited(saveQueueState());
  }

  /// Remove a song from the queue by index.
  /// If the currently playing track is removed, playback skips to the next
  /// available track (or stops when the queue becomes empty).
  Future<void> removeFromQueue(int index) async {
    if (index < 0 || index >= _playlist.length) return;

    if (index == _currentIndex) {
      if (_playlist.length == 1) {
        // Only song — clear the queue and stop.
        await stop();
        _playlist = [];
        _currentIndex = -1;
        _scheduleNotify();
        unawaited(saveQueueState());
        return;
      }
      // Remove from both the in-memory list and the audio source first, then
      // determine which track to play next (calculated after removal so the
      // index arithmetic is always based on the updated list length).
      if (_gaplessPlayback) {
        try {
          // Remove from the audio source before updating _playlist so that the
          // index is still valid for the unmodified source.
          await _audioPlayer.removeAudioSourceAt(index);
        } catch (e) {
          debugPrint(
              'Error removing currently playing song from audio source: $e');
        }
      }
      _playlist.removeAt(index);
      // After removal: the next song (at the same index) becomes current.
      // If the removed song was in the queued zone, the new current is also
      // queued, so decrement the count.
      if (_queueCount > 0) _queueCount--;
      _currentIndex = index < _playlist.length ? index : _playlist.length - 1;

      if (_gaplessPlayback) {
        try {
          await _audioPlayer.seek(Duration.zero, index: _currentIndex);
          if (!_isPlaying) await _audioPlayer.play();
          final mediaItems =
              _playlist.map((s) => _createMediaItemSync(s)).toList();
          audioHandler.updateNotificationQueue(mediaItems);
        } catch (e) {
          debugPrint('Error seeking after removing currently playing song: $e');
        }
      } else {
        await play(index: _currentIndex);
      }

      // Update song notifiers.
      final song = _playlist[_currentIndex];
      _currentSongController.add(song);
      currentSongNotifier.value = song;
      _scheduleNotify();
      unawaited(saveQueueState());
      return;
    }

    _playlist.removeAt(index);

    // Adjust current index and queue boundary.
    if (index < _currentIndex) {
      _currentIndex--;
      // Queue zone shifts left with _currentIndex, so relative count stays.
    } else if (index > _currentIndex && index <= _currentIndex + _queueCount) {
      // Removed song was in the queued zone.
      _queueCount--;
    }
    // Removing from source zone (beyond queued zone) needs no adjustment.

    if (_gaplessPlayback) {
      try {
        await _audioPlayer.removeAudioSourceAt(index);

        // Update notification queue with lightweight items
        final mediaItems =
            _playlist.map((s) => _createMediaItemSync(s)).toList();
        audioHandler.updateNotificationQueue(mediaItems);
      } catch (e) {
        debugPrint('Error removing song from queue: $e');
      }
    }

    _scheduleNotify();
  }

  /// Move a song within the queue
  Future<void> moveInQueue(int oldIndex, int newIndex) async {
    if (oldIndex < 0 || oldIndex >= _playlist.length) return;
    if (newIndex < 0 || newIndex >= _playlist.length) return;
    if (oldIndex == newIndex) return;

    // Determine whether the moved song is crossing the queue/source boundary
    // BEFORE the actual move (using pre-move positions).
    final queueZoneEnd = _currentIndex + _queueCount; // last queued song index
    final wasQueued = oldIndex > _currentIndex && oldIndex <= queueZoneEnd;
    final willBeQueued = newIndex > _currentIndex && newIndex <= queueZoneEnd;

    final song = _playlist.removeAt(oldIndex);
    _playlist.insert(newIndex, song);

    // Adjust current index
    if (oldIndex == _currentIndex) {
      _currentIndex = newIndex;
    } else if (oldIndex < _currentIndex && newIndex >= _currentIndex) {
      _currentIndex--;
    } else if (oldIndex > _currentIndex && newIndex <= _currentIndex) {
      _currentIndex++;
    }

    // Adjust _queueCount if the song crossed the queue/source boundary.
    if (wasQueued && !willBeQueued) {
      _queueCount = (_queueCount - 1).clamp(0, _playlist.length);
    } else if (!wasQueued && willBeQueued) {
      _queueCount++;
    }

    if (_gaplessPlayback) {
      try {
        await _audioPlayer.moveAudioSource(oldIndex, newIndex);

        // Update notification queue with lightweight items
        final mediaItems =
            _playlist.map((s) => _createMediaItemSync(s)).toList();
        audioHandler.updateNotificationQueue(mediaItems);
      } catch (e) {
        debugPrint('Error moving song in queue: $e');
      }
    }

    _scheduleNotify();
  }

  /// Clear the entire queue except the currently playing song
  Future<void> clearQueue() async {
    if (_playlist.isEmpty) return;

    final currentSong = this.currentSong;
    if (currentSong != null) {
      // Keep only the current song
      _playlist = [currentSong];
      _currentIndex = 0;
      _queueCount = 0;

      if (_gaplessPlayback) {
        try {
          final mediaItem = await _createMediaItem(currentSong);
          final uri = currentSong.uri ?? currentSong.data;
          final position = _audioPlayer.position;

          await _audioPlayer.setAudioSources(
            [AudioSource.uri(Uri.parse(uri), tag: mediaItem)],
            initialIndex: 0,
            initialPosition: position,
          );

          audioHandler.updateNotificationQueue([mediaItem]);
        } catch (e) {
          debugPrint('Error clearing queue: $e');
        }
      }
    } else {
      _playlist = [];
      _currentIndex = -1;
      _queueCount = 0;
    }

    _scheduleNotify();
  }

  /// Clear upcoming songs only (songs after current)
  Future<void> clearUpcoming() async {
    if (_playlist.isEmpty || _currentIndex >= _playlist.length - 1) return;

    // Remove all songs after current
    _playlist = _playlist.sublist(0, _currentIndex + 1);
    _queueCount = 0; // All queued and source songs are cleared

    if (_gaplessPlayback) {
      try {
        // Remove all sources after current index in one call
        await _audioPlayer.removeAudioSourceRange(
            _currentIndex + 1, _audioPlayer.audioSources.length);

        // Update notification queue with lightweight items
        final mediaItems =
            _playlist.map((s) => _createMediaItemSync(s)).toList();
        audioHandler.updateNotificationQueue(mediaItems);
      } catch (e) {
        debugPrint('Error clearing upcoming queue: $e');
      }
    }

    _scheduleNotify();
  }

  void toggleShuffle() {
    _isShuffle = !_isShuffle;
    isShuffleNotifier.value = _isShuffle;
    debugPrint('🔀 [SHUFFLE] Toggled shuffle: $_isShuffle');

    if (_isShuffle) {
      // Save the current order and shuffle the queue in-place, keeping the
      // current track at position 0 so playback is uninterrupted.
      _originalPlaylist = List<SongModel>.from(_playlist);
      _shuffleQueue();
    } else {
      // Restore the original queue order.
      _restoreOriginalQueue();
    }

    // We manage shuffle ourselves — always keep just_audio's internal shuffle
    // mode disabled so the player follows our explicit _playlist order.
    _audioPlayer.setShuffleModeEnabled(false);
    debugPrint(
        '🔀 [SHUFFLE] Queue reordered, playlist length: ${_playlist.length}');
    unawaited(saveQueueState());
    _scheduleNotify();
  }

  /// Shuffles _playlist in-place, moving the current track to index 0 so that
  /// ongoing playback is preserved and the audio source can be rebuilt with the
  /// same initial index (0).
  void _shuffleQueue() {
    if (_playlist.length <= 1) return;
    final current = _playlist[_currentIndex];
    final rest = List<SongModel>.from(_playlist)..removeAt(_currentIndex);
    rest.shuffle(Random());
    _playlist = [current, ...rest];
    _currentIndex = 0;
    _queueCount = 0; // Queue distinction lost after shuffle
    unawaited(_rebuildAudioSourcePreservingPosition());
  }

  /// Restores the pre-shuffle queue order while keeping the current track's
  /// position accurate.
  void _restoreOriginalQueue() {
    if (_originalPlaylist.isEmpty) return;
    final current = currentSong;
    _playlist = List<SongModel>.from(_originalPlaylist);
    _originalPlaylist = [];
    _queueCount = 0; // Queue distinction not preserved through shuffle/restore
    if (current != null) {
      final restoredIndex = _playlist.indexWhere((s) => s.id == current.id);
      _currentIndex = restoredIndex != -1 ? restoredIndex : 0;
    }
    unawaited(_rebuildAudioSourcePreservingPosition());
  }

  /// Rebuilds the gapless audio source with the current _playlist
  /// order, preserving the playback position of the active track.
  Future<void> _rebuildAudioSourcePreservingPosition() async {
    if (!_gaplessPlayback) return;
    try {
      final position = _audioPlayer.position;
      final mediaItems = _playlist.map((s) => _createMediaItemSync(s)).toList();

      audioHandler.suppressIndexUpdates();
      await _audioPlayer.setAudioSources(
        _playlist.asMap().entries.map((entry) {
          final song = entry.value;
          final uri = song.uri ?? song.data;
          return AudioSource.uri(Uri.parse(uri), tag: mediaItems[entry.key]);
        }).toList(),
        initialIndex: _currentIndex,
        initialPosition: position,
      );
      audioHandler.resumeIndexUpdates();
      // Re-disable just_audio's internal shuffle; we manage ordering ourselves.
      await _audioPlayer.setShuffleModeEnabled(false);
      await _audioPlayer.setLoopMode(_loopMode);

      audioHandler.updateNotificationQueue(mediaItems);
      if (_currentIndex < mediaItems.length) {
        audioHandler.updateNotificationMediaItem(mediaItems[_currentIndex]);
      }

      if (_isPlaying) {
        await _audioPlayer.play();
      }
    } catch (e) {
      audioHandler.resumeIndexUpdates();
      debugPrint('Error rebuilding audio source: $e');
    }
  }

  void toggleRepeat() {
    // Cycle through: off → all → one → off
    switch (_loopMode) {
      case LoopMode.off:
        _loopMode = LoopMode.all;
        break;
      case LoopMode.all:
        _loopMode = LoopMode.one;
        break;
      case LoopMode.one:
        _loopMode = LoopMode.off;
        break;
    }
    loopModeNotifier.value = _loopMode;
    debugPrint('🔁 [REPEAT] Cycled loop mode: $_loopMode');
    // Apply loop mode to the audio player
    _audioPlayer.setLoopMode(_loopMode);
    debugPrint(
        '🔁 [REPEAT] Applied to player, current loopMode: ${_audioPlayer.loopMode}');
    unawaited(saveQueueState());
    _scheduleNotify();
  }
}
