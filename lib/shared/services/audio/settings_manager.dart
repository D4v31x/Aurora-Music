part of '../audio_player_service.dart';

extension AudioSettingsManagerExtension on AudioPlayerService {
  Future<void> _loadSettings() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/settings.json');

    if (await file.exists()) {
      try {
        final contents = await file.readAsString();
        final json = jsonDecode(contents);

        _gaplessPlayback = json['gaplessPlayback'] ?? true;
        _volumeNormalization = json['volumeNormalization'] ?? false;
        _playbackSpeed = (json['playbackSpeed'] ?? 1.0).toDouble();
        _pitchWithSpeed = json['pitchWithSpeed'] ?? false;
        _defaultSortOrder = json['defaultSortOrder'] ?? 'title';
        _cacheSize = json['cacheSize'] ?? 100;
        _mediaControls = json['mediaControls'] ?? true;

        // Apply settings to audio player
        await _applySettings();
      } catch (e) {
        // Corrupted JSON – delete the file and fall back to defaults
        if (kDebugMode) {
          print('Settings file corrupted, resetting to defaults: $e');
        }
        await file.delete();
      }
    }
  }

  Future<void> _saveSettings() async {
    // Serialize writes through the mutex to prevent concurrent corruption
    _settingsSaveLock = _settingsSaveLock.then((_) async {
      final directory = await getApplicationDocumentsDirectory();
      final path = '${directory.path}/settings.json';
      final tempFile = File('$path.tmp');

      final json = {
        'gaplessPlayback': _gaplessPlayback,
        'volumeNormalization': _volumeNormalization,
        'playbackSpeed': _playbackSpeed,
        'pitchWithSpeed': _pitchWithSpeed,
        'defaultSortOrder': _defaultSortOrder,
        'cacheSize': _cacheSize,
        'mediaControls': _mediaControls,
      };

      // Atomic write: write to temp file, then rename to target
      await tempFile.writeAsString(jsonEncode(json));
      await tempFile.rename(path);
    }).catchError((_) {
      // Swallow errors so the lock Future never stays in a failed state
    });
    await _settingsSaveLock;
  }

  Future<void> _applySettings() async {
    // Apply playback speed
    await _audioPlayer.setSpeed(_playbackSpeed);
    // Apply pitch: locked to 1.0 unless pitchWithSpeed is enabled
    await _audioPlayer.setPitch(_pitchWithSpeed ? _playbackSpeed : 1.0);

    // Volume normalization is applied per-song via a currentSongNotifier
    // listener registered in _init().  Reset to 1.0 when disabled.
    if (!_volumeNormalization) {
      await _audioPlayer.setVolume(1.0);
    }

    // Configure gapless playback
    if (_gaplessPlayback) {
      // Create a concatenating audio source for gapless playback
      if (_playlist.isNotEmpty) {
        // Use lightweight MediaItems for instant startup
        final mediaItems =
            _playlist.map((song) => _createMediaItemSync(song)).toList();

        await _audioPlayer.setAudioSources(
          _playlist
              .asMap()
              .entries
              .map((entry) => AudioSource.uri(
                    Uri.parse(entry.value.uri ?? entry.value.data),
                    tag: mediaItems[entry.key],
                  ))
              .toList(),
          initialIndex: _currentIndex,
          initialPosition: _audioPlayer.position,
        );

        // Load artwork in background
        unawaited(_loadRemainingArtworkInBackground(_playlist));
      }
    }
  }

  // Settings update methods
  Future<void> setGaplessPlayback(bool value) async {
    _gaplessPlayback = value;
    await _saveSettings();
    _scheduleNotify();
  }

  Future<void> setVolumeNormalization(bool value) async {
    _volumeNormalization = value;
    _scheduleNotify();
    if (value) {
      await _applyNormalizationForCurrentSong();
    } else {
      await _audioPlayer.setVolume(1.0);
    }
    await _saveSettings();
  }

  /// Reads the REPLAYGAIN_TRACK_GAIN tag for the current song and applies
  /// the corresponding volume to the audio player.
  /// No-ops when no song is loaded or when the song changes before the
  /// async file read completes.
  Future<void> _applyNormalizationForCurrentSong() async {
    final song = currentSong;
    if (song == null) return;
    final songId = song.id;
    final volume = await ReplayGainReader.getVolumeMultiplier(song.data);
    // Guard: only apply if the same song is still playing
    if (currentSong?.id == songId) {
      await _audioPlayer.setVolume(volume);
    }
  }

  Future<void> setPlaybackSpeed(double value) async {
    _playbackSpeed = value;
    await _audioPlayer.setSpeed(_playbackSpeed);
    await _audioPlayer.setPitch(_pitchWithSpeed ? _playbackSpeed : 1.0);
    await _saveSettings();
    _scheduleNotify();
  }

  Future<void> setPitchWithSpeed(bool value) async {
    _pitchWithSpeed = value;
    // Re-apply pitch immediately
    await _audioPlayer.setPitch(value ? _playbackSpeed : 1.0);
    await _saveSettings();
    _scheduleNotify();
  }

  Future<void> setDefaultSortOrder(String value) async {
    _defaultSortOrder = value;
    await _saveSettings();
    _sortPlaylist();
    _scheduleNotify();
  }

  Future<void> setCacheSize(int value) async {
    _cacheSize = value;
    await _saveSettings();
    unawaited(_manageCacheSize()); // Don't block on cache management
  }

  Future<void> setMediaControls(bool value) async {
    _mediaControls = value;
    await _saveSettings();

    // Update the audio session configuration.
    // Both branches use the same long-running music config so that
    // audio focus type (GAIN) is never accidentally downgraded.
    final session = await AudioSession.instance;
    if (!_mediaControls) {
      // Disable media notifications (audio focus config stays the same)
      await session.configure(const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionCategoryOptions:
            AVAudioSessionCategoryOptions.allowBluetooth,
        avAudioSessionMode: AVAudioSessionMode.defaultMode,
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.music,
          flags: AndroidAudioFlags.none,
          usage: AndroidAudioUsage.media,
        ),
        androidWillPauseWhenDucked: true,
      ));
    } else {
      // Enable media notifications
      await session.configure(const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionCategoryOptions:
            AVAudioSessionCategoryOptions.allowBluetooth,
        avAudioSessionMode: AVAudioSessionMode.defaultMode,
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.music,
          flags: AndroidAudioFlags.none,
          usage: AndroidAudioUsage.media,
        ),
        androidWillPauseWhenDucked: true,
      ));

      // Re-initialize the audio service if needed
      if (_audioPlayer.playing) {
        // Update the current media item to refresh the notification
        final currentSong = this.currentSong;
        if (currentSong != null) {
          final currentPosition = _audioPlayer.position;
          final mediaItem = await _createMediaItem(currentSong);
          await _audioPlayer.setAudioSource(
            AudioSource.uri(
              Uri.parse(currentSong.data),
              tag: mediaItem,
            ),
            initialPosition: currentPosition,
          );
        }
      }
    }
    // No need for notifyListeners - UI doesn't depend on this setting directly
  }

  Future<void> _manageCacheSize() async {
    final directory = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${directory.path}/artwork_cache');
    final spotifyCacheDir = Directory(directory.path);

    final maxBytes = _cacheSize * 1024 * 1024;
    int totalSize = 0;

    // Clean artwork cache
    if (await cacheDir.exists()) {
      final files = await cacheDir.list().toList();
      for (final entity in files) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }

      if (totalSize > maxBytes) {
        // Sort by last accessed (oldest first) using async stat
        final statEntries = <MapEntry<FileSystemEntity, FileStat>>[];
        for (final entity in files) {
          statEntries.add(MapEntry(entity, await entity.stat()));
        }
        statEntries.sort((a, b) => a.value.accessed.compareTo(b.value.accessed));

        var currentSize = totalSize;
        for (final entry in statEntries) {
          if (currentSize <= maxBytes) break;
          if (entry.key is File) {
            final fileSize = await (entry.key as File).length();
            await entry.key.delete();
            currentSize -= fileSize;
          }
        }
      }
    }

    // Clean Spotify song cache
    if (await spotifyCacheDir.exists()) {
      final files = await spotifyCacheDir.list().toList();
      final spotifyFiles = files
          .where((file) => file is File && file.path.endsWith('.mp3'))
          .toList();
      for (final entity in spotifyFiles) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }

      if (totalSize > maxBytes) {
        final statEntries = <MapEntry<FileSystemEntity, FileStat>>[];
        for (final entity in spotifyFiles) {
          statEntries.add(MapEntry(entity, await entity.stat()));
        }
        statEntries.sort((a, b) => a.value.accessed.compareTo(b.value.accessed));

        var currentSize = totalSize;
        for (final entry in statEntries) {
          if (currentSize <= maxBytes) break;
          if (entry.key is File) {
            final fileSize = await (entry.key as File).length();
            await entry.key.delete();
            currentSize -= fileSize;
          }
        }
      }
    }
  }
}
