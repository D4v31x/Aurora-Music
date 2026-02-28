part of '../audio_player_service.dart';

extension AudioLibraryManagerExtension on AudioPlayerService {
  // Check permissions safely without crashing the app
  Future<bool> _checkPermissionStatus() async {
    try {
      return await _audioQuery.permissionsStatus();
    } catch (e) {
      debugPrint('Permission check error: $e');
      return false;
    }
  }

  // Scan common music directories to update MediaStore with new files
  Future<void> _scanMusicDirectories() async {
    try {
      // Common music directories on Android
      final musicPaths = [
        '/storage/emulated/0/Music',
        '/storage/emulated/0/Download',
        '/storage/emulated/0/Downloads',
        '/storage/emulated/0/DCIM',
        '/storage/emulated/0/Podcasts',
        '/storage/emulated/0/Ringtones',
        '/storage/emulated/0/Notifications',
        '/storage/emulated/0/Alarms',
        '/sdcard/Music',
        '/sdcard/Download',
        '/sdcard/Downloads',
      ];

      debugPrint('Scanning music directories for new files...');
      int scannedCount = 0;

      for (final basePath in musicPaths) {
        final dir = Directory(basePath);
        if (await dir.exists()) {
          try {
            await for (final entity
                in dir.list(recursive: true, followLinks: false)) {
              if (entity is File) {
                final path = entity.path.toLowerCase();
                // Check for common audio file extensions
                if (path.endsWith('.mp3') ||
                    path.endsWith('.m4a') ||
                    path.endsWith('.flac') ||
                    path.endsWith('.wav') ||
                    path.endsWith('.aac') ||
                    path.endsWith('.ogg') ||
                    path.endsWith('.wma') ||
                    path.endsWith('.opus')) {
                  await _audioQuery.scanMedia(entity.path);
                  scannedCount++;
                }
              }
            }
          } catch (e) {
            debugPrint('Error scanning $basePath: $e');
          }
        }
      }

      debugPrint('Scanned $scannedCount audio files');

      // Give MediaStore a moment to process the scanned files
      await Future.delayed(const Duration(milliseconds: 500));
    } catch (e) {
      debugPrint('Error scanning music directories: $e');
    }
  }

  // Public method to initialize music library - should be called only from HomeScreen
  Future<bool> initializeMusicLibrary({bool forceRescan = false}) async {
    try {
      final hasPermissions = await _checkPermissionStatus();

      if (!hasPermissions) {
        debugPrint('No permissions yet - library remains empty');
        return false;
      }

      // Only load from cache if not forcing a rescan
      if (!forceRescan) {
        await loadLibrary();
      } else {
        // Clear the library set to force fresh query
        _librarySet.clear();
        debugPrint('Force rescan: cleared library cache');

        // Scan common music directories to update MediaStore
        await _scanMusicDirectories();
      }

      // Try to load songs - always query fresh from MediaStore
      try {
        // Query with proper parameters to get all songs from external storage
        final songs = await _audioQuery.querySongs(
          orderType: OrderType.ASC_OR_SMALLER,
          uriType: UriType.EXTERNAL,
          ignoreCase: true,
        );
        debugPrint('Queried ${songs.length} songs from storage');
        _updateSongs(songs);

        // Save the updated library
        if (forceRescan) {
          await saveLibrary();
        }

        // Initialize the liked songs playlist
        await loadLikedSongs();
        final likedSongs = songs
            .where((song) => _likedSongs.contains(song.id.toString()))
            .toList();

        _likedSongsPlaylist = Playlist(
          id: AudioPlayerService.LIKED_SONGS_PLAYLIST_ID,
          name: _likedPlaylistName,
          songs: likedSongs,
        );

        // Update auto playlists (Most Played, Recently Added)
        _updateAutoPlaylists();

        notifyListeners();
        return true;
      } catch (e) {
        debugPrint('Error loading songs: $e');
        return false;
      }
    } catch (e) {
      debugPrint('Error initializing music library: $e');
      return false;
    }
  }

  // Public method to request permissions from UI
  Future<bool> requestPermissions() async {
    try {
      final permissionStatus = await _audioQuery.permissionsStatus();

      if (!permissionStatus) {
        // Only request if needed
        final granted = await _audioQuery.permissionsRequest();

        // If permissions were just granted, initialize the library
        if (granted) {
          await Future.delayed(const Duration(milliseconds: 500));
          await initializeMusicLibrary();
        }

        return granted;
      }

      return permissionStatus;
    } catch (e) {
      debugPrint('Permission request error: $e');
      return false;
    }
  }

  // Playlist Management
  Future<void> _loadPlaylists() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/playlists.json');

    if (await file.exists()) {
      final contents = await file.readAsString();
      final json = jsonDecode(contents) as List;
      _playlists = json
          .map((playlistJson) => Playlist(
                id: playlistJson['id'],
                name: playlistJson['name'],
                songs: (playlistJson['songs'] as List)
                    .map((songJson) => SongModel(songJson))
                    .toList(),
              ))
          .toList();
    }
  }

  Future<void> savePlaylists() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/playlists.json');

    final json = _playlists
        .map((playlist) => {
              'id': playlist.id,
              'name': playlist.name,
              'songs': playlist.songs.map((song) => song.getMap).toList(),
            })
        .toList();

    await file.writeAsString(jsonEncode(json));
    // Update the notifier for reactive widgets
    playlistsNotifier.value = List.from(_playlists);
  }

  void createPlaylist(String name, List<SongModel> songs) {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final newPlaylist = Playlist(id: id, name: name, songs: songs);
    _playlists.add(newPlaylist);
    _playlistsDirty = true;
    _scheduleSavePlayCounts(); // Will also save playlists
    _scheduleNotify();
  }

  void addSongToPlaylist(String playlistId, SongModel song) {
    final playlistIndex = _playlists.indexWhere((p) => p.id == playlistId);
    if (playlistIndex == -1) return;
    final playlist = _playlists[playlistIndex];
    if (!playlist.songs.contains(song)) {
      playlist.songs.add(song);
      _playlistsDirty = true;
      _scheduleSavePlayCounts();
      _scheduleNotify();
    }
  }

  void removeSongFromPlaylist(String playlistId, SongModel song) {
    if (playlistId == 'liked_songs') {
      _likedSongs.remove(song.id.toString());
      saveLikedSongs();
      _updateLikedSongsPlaylist();
    } else {
      final playlistIndex = _playlists.indexWhere((p) => p.id == playlistId);
      if (playlistIndex == -1) return;
      final playlist = _playlists[playlistIndex];
      playlist.songs.remove(song);
      _playlistsDirty = true;
      _scheduleSavePlayCounts();
    }
    _scheduleNotify();
  }

  void deletePlaylist(Playlist playlist) {
    _playlists.remove(playlist);
    _playlistsDirty = true;
    _scheduleSavePlayCounts();
    _scheduleNotify();
  }

  void renamePlaylist(String playlistId, String newName) {
    final playlistIndex = _playlists.indexWhere((p) => p.id == playlistId);
    if (playlistIndex != -1) {
      _playlists[playlistIndex] =
          _playlists[playlistIndex].copyWith(name: newName);
      _playlistsDirty = true;
      _scheduleSavePlayCounts();
      _scheduleNotify();
    }
  }

  void addSongsToPlaylist(String playlistId, List<SongModel> songs) {
    if (playlistId == 'liked_songs') {
      for (final song in songs) {
        if (!_likedSongs.contains(song.id.toString())) {
          _likedSongs.add(song.id.toString());
        }
      }
      saveLikedSongs();
      _updateLikedSongsPlaylist();
    } else {
      final playlistIndex = _playlists.indexWhere((p) => p.id == playlistId);
      if (playlistIndex == -1) return;
      final playlist = _playlists[playlistIndex];
      for (final song in songs) {
        if (!playlist.songs.contains(song)) {
          playlist.songs.add(song);
        }
      }
      _playlistsDirty = true;
      _scheduleSavePlayCounts();
    }
    _scheduleNotify();
  }

  Future<void> addSongToLibrary(SongModel song) async {
    if (!_librarySet.contains(song.id.toString())) {
      _librarySet.add(song.id.toString());
      await saveLibrary();
    }
  }

  Future<void> saveLibrary() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/library.json');

    final json = {
      'songs': _librarySet.toList(),
    };

    await file.writeAsString(jsonEncode(json));
  }

  Future<void> loadLibrary() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/library.json');

    if (await file.exists()) {
      final contents = await file.readAsString();
      final json = jsonDecode(contents);
      _librarySet = Set<String>.from(json['songs']);
    }
  }

  Future<void> initializeLikedSongsPlaylist() async {
    await loadLikedSongs();
    _updateLikedSongsPlaylist();
  }

  Future<void> loadLikedSongs() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/liked_songs.json');

    if (await file.exists()) {
      final contents = await file.readAsString();
      final json = jsonDecode(contents);
      _likedSongs = Set<String>.from(json['liked_songs'] ?? []);
      // Update notifier for reactive UI
      likedSongsNotifier.value = Set<String>.from(_likedSongs);
    }
  }

  Future<void> saveLikedSongs() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/liked_songs.json');

    final json = {
      'liked_songs': _likedSongs.toList(),
    };

    await file.writeAsString(jsonEncode(json));
  }

  void _updateLikedSongsPlaylist() {
    // Don't try to query audio directly - just use the songs we already have
    if (_songs.isEmpty) {
      _likedSongsPlaylist = Playlist(
        id: AudioPlayerService.LIKED_SONGS_PLAYLIST_ID,
        name: _likedPlaylistName,
        songs: [],
      );
      return;
    }

    try {
      final likedSongs = _songs
          .where((song) => _likedSongs.contains(song.id.toString()))
          .toList();

      _likedSongsPlaylist = Playlist(
        id: AudioPlayerService.LIKED_SONGS_PLAYLIST_ID,
        name: _likedPlaylistName,
        songs: likedSongs,
      );

      _scheduleNotify();
    } catch (e) {
      // Handle errors by keeping the current playlist or creating an empty one
      _likedSongsPlaylist ??= Playlist(
        id: AudioPlayerService.LIKED_SONGS_PLAYLIST_ID,
        name: _likedPlaylistName,
        songs: [],
      );
      debugPrint('Error updating liked songs playlist: $e');
    }
  }

  bool isLiked(SongModel song) {
    return _likedSongs.contains(song.id.toString());
  }

  Future<void> toggleLike(SongModel song) async {
    if (_likedSongs.contains(song.id.toString())) {
      _likedSongs.remove(song.id.toString());
    } else {
      _likedSongs.add(song.id.toString());
    }

    // Update notifier for reactive UI
    likedSongsNotifier.value = Set<String>.from(_likedSongs);

    await saveLikedSongs();
    _updateLikedSongsPlaylist();
    _scheduleNotify();
  }

  Playlist? get likedSongsPlaylist => _likedSongsPlaylist;

  Future<void> initializeWithSongs(List<SongModel> initialSongs) async {
    _updateSongs(initialSongs);
    _scheduleNotify();
  }

  /// Replaces a single song entry in the in-memory song list, playlist queue,
  /// and current-song notifiers without reloading the entire library.
  /// Called after metadata has been edited and MediaStore has been rescanned.
  void refreshSongInPlaylist(SongModel updatedSong) {
    // 1. Replace in the master songs list
    final songIdx = _songs.indexWhere((s) => s.id == updatedSong.id);
    if (songIdx != -1) {
      final updated = List<SongModel>.from(_songs);
      updated[songIdx] = updatedSong;
      _updateSongs(updated);
    }

    // 2. Replace in the active playback queue
    final queueIdx = _playlist.indexWhere((s) => s.id == updatedSong.id);
    if (queueIdx != -1) {
      _playlist[queueIdx] = updatedSong;
    }

    // 3. If this is the currently playing song, update all notifiers
    if (currentSong?.id == updatedSong.id) {
      _currentSongController.add(updatedSong);
      currentSongNotifier.value = updatedSong;
    }

    _scheduleNotify();
  }

  void _updateAutoPlaylists() {
    // Auto playlists are always enabled

    // Create "Most Played" playlist
    unawaited(getMostPlayedTracks().then((tracks) {
      final existingIndex =
          _playlists.indexWhere((p) => p.id == kMostPlayedPlaylistId);

      if (existingIndex != -1) {
        // Update existing playlist
        _playlists[existingIndex] = Playlist(
          id: kMostPlayedPlaylistId,
          name: 'Most Played',
          songs: tracks,
        );
      } else {
        // Create new playlist
        _playlists.add(Playlist(
          id: kMostPlayedPlaylistId,
          name: 'Most Played',
          songs: tracks,
        ));
      }

      _playlistsDirty = true;
      _scheduleSavePlayCounts();
      _scheduleNotify();
    }));

    // Create "Recently Added" playlist
    unawaited(_audioQuery
        .querySongs(
      sortType: SongSortType.DATE_ADDED,
      orderType: OrderType.DESC_OR_GREATER,
    )
        .then((tracks) {
      final existingIndex =
          _playlists.indexWhere((p) => p.id == kRecentlyAddedPlaylistId);

      if (existingIndex != -1) {
        // Update existing playlist
        _playlists[existingIndex] = Playlist(
          id: kRecentlyAddedPlaylistId,
          name: 'Recently Added',
          songs: tracks,
        );
      } else {
        // Create new playlist
        _playlists.add(Playlist(
          id: kRecentlyAddedPlaylistId,
          name: 'Recently Added',
          songs: tracks,
        ));
      }

      _playlistsDirty = true;
      _scheduleSavePlayCounts();
      _scheduleNotify();
    }));
  }

  // Ensure that _folderAccessCounts is correctly populated
  void _incrementFolderAccessCount(String folderPath) {
    _folderAccessCounts[folderPath] =
        (_folderAccessCounts[folderPath] ?? 0) + 1;
    _scheduleSavePlayCounts();
  }

  // Call this method whenever a song from a folder is played
  void playSongFromFolder(SongModel song) {
    final folderPath = File(song.data).parent.path;
    _incrementFolderAccessCount(folderPath);
    // Proceed to play the song
    setPlaylist([song], 0);
    unawaited(play());
  }

  // Method to update playlist name when language changes
  void updateLikedPlaylistName(String newName) {
    _likedPlaylistName = newName;
    if (_likedSongsPlaylist != null) {
      _likedSongsPlaylist = Playlist(
        id: AudioPlayerService.LIKED_SONGS_PLAYLIST_ID,
        name: _likedPlaylistName,
        songs: _likedSongsPlaylist!.songs,
      );
      _scheduleNotify();
    }
  }

  // Getter for the playlist name
  String get likedPlaylistName => _likedPlaylistName;
}
