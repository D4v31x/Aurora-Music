part of '../audio_player_service.dart';

extension AudioSettingsManagerExtension on AudioPlayerService {
  Future<void> _loadSettings() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/settings.json');

    if (await file.exists()) {
      final contents = await file.readAsString();
      final json = jsonDecode(contents);

      _gaplessPlayback = json['gaplessPlayback'] ?? true;
      _volumeNormalization = json['volumeNormalization'] ?? false;
      _playbackSpeed = (json['playbackSpeed'] ?? 1.0).toDouble();
      _defaultSortOrder = json['defaultSortOrder'] ?? 'title';
      _cacheSize = json['cacheSize'] ?? 100;
      _mediaControls = json['mediaControls'] ?? true;

      // Apply settings to audio player
      await _applySettings();
    }
  }

  Future<void> _saveSettings() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/settings.json');

    final json = {
      'gaplessPlayback': _gaplessPlayback,
      'volumeNormalization': _volumeNormalization,
      'playbackSpeed': _playbackSpeed,
      'defaultSortOrder': _defaultSortOrder,
      'cacheSize': _cacheSize,
      'mediaControls': _mediaControls,
    };

    await file.writeAsString(jsonEncode(json));
  }

  Future<void> _applySettings() async {
    // Apply playback speed
    await _audioPlayer.setSpeed(_playbackSpeed);

    // Apply volume normalization using regular volume control
    if (_volumeNormalization) {
      await _audioPlayer.setVolume(1.0);
    }

    // Configure gapless playback
    if (_gaplessPlayback) {
      // Create a concatenating audio source for gapless playback
      if (_playlist.isNotEmpty) {
        // Use lightweight MediaItems for instant startup
        final mediaItems =
            _playlist.map((song) => _createMediaItemSync(song)).toList();

        final playlist = ConcatenatingAudioSource(
          children: _playlist
              .asMap()
              .entries
              .map((entry) => AudioSource.uri(
                    Uri.parse(entry.value.uri ?? entry.value.data),
                    tag: mediaItems[entry.key],
                  ))
              .toList(),
        );

        // Set the audio source with the current index
        await _audioPlayer.setAudioSource(
          playlist,
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
    // Settings changes are infrequent, direct notify is fine
  }

  Future<void> setVolumeNormalization(bool value) async {
    _volumeNormalization = value;
    await _applySettings();
    await _saveSettings();
  }

  Future<void> setPlaybackSpeed(double value) async {
    _playbackSpeed = value;
    // Apply speed directly without reloading audio source
    await _audioPlayer.setSpeed(_playbackSpeed);
    await _saveSettings();
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
          flags: AndroidAudioFlags.audibilityEnforced,
          usage: AndroidAudioUsage.media,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
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
          flags: AndroidAudioFlags.audibilityEnforced,
          usage: AndroidAudioUsage.media,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        androidWillPauseWhenDucked: true,
      ));

      // Re-initialize the audio service if needed
      if (_audioPlayer.playing) {
        // Update the current media item to refresh the notification
        final currentSong = this.currentSong;
        if (currentSong != null) {
          final mediaItem = await _createMediaItem(currentSong);
          await _audioPlayer.setAudioSource(
            AudioSource.uri(
              Uri.parse(currentSong.data),
              tag: mediaItem,
            ),
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

    int totalSize = 0;

    // Clean artwork cache
    if (await cacheDir.exists()) {
      final files = await cacheDir.list().toList();
      totalSize += files.fold<int>(
          0, (sum, file) => sum + (file is File ? file.lengthSync() : 0));

      if (totalSize > _cacheSize * 1024 * 1024) {
        files.sort(
            (a, b) => a.statSync().accessed.compareTo(b.statSync().accessed));
        var currentSize = totalSize;
        for (final file in files) {
          if (currentSize <= _cacheSize * 1024 * 1024) break;
          if (file is File) {
            final fileSize = file.lengthSync();
            await file.delete();
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
      totalSize += spotifyFiles.fold<int>(
          0, (sum, file) => sum + (file is File ? file.lengthSync() : 0));

      if (totalSize > _cacheSize * 1024 * 1024) {
        spotifyFiles.sort(
            (a, b) => a.statSync().accessed.compareTo(b.statSync().accessed));
        var currentSize = totalSize;
        for (final file in spotifyFiles) {
          if (currentSize <= _cacheSize * 1024 * 1024) break;
          if (file is File) {
            final fileSize = file.lengthSync();
            await file.delete();
            currentSize -= fileSize;
          }
        }
      }
    }
  }
}
