part of '../audio_player_service.dart';

/// M3U / M3U8 playlist import, export, and folder synchronization.
///
/// Provides:
/// * [exportPlaylistContent] – the raw `.m3u8` text for sharing.
/// * [importPlaylistFromM3uFile] – create a playlist from an `.m3u`/`.m3u8` file.
/// * [setPlaylistSyncFolder] / [playlistSyncFolder] – configure a folder where
///   playlists are mirrored as `.m3u8` files (Poweramp-style).
/// * [syncPlaylistsWithFolder] – two-way sync between in-app playlists and the
///   `.m3u8` files in the configured folder.
extension AudioPlaylistM3uExtension on AudioPlayerService {
  static const String _kSyncFolderPrefKey = 'playlist_sync_folder';

  /// The M3U service used for (de)serialization and path matching.
  PlaylistM3uService get _m3uService => const PlaylistM3uService();

  // MARK: - Export

  /// Returns the `.m3u8` text content for [playlist] (for sharing/saving).
  String exportPlaylistContent(Playlist playlist) =>
      _m3uService.buildM3uContent(playlist);

  /// Writes [playlist] to a temporary `.m3u8`/`.m3u` file and returns its
  /// path.
  ///
  /// Useful as the source for a share sheet. [extension] may be `m3u8`
  /// (default) or `m3u`.
  Future<String> exportPlaylistToTempFile(Playlist playlist,
      {String extension = 'm3u8'}) async {
    final dir = await getTemporaryDirectory();
    final name = _m3uService.sanitizeFileName(playlist.name);
    final path = '${dir.path}/$name.$extension';
    await _m3uService.exportToFile(playlist, path);
    return path;
  }

  // MARK: - Import

  /// Imports a playlist from the `.m3u`/`.m3u8` file at [filePath].
  ///
  /// Resolves each referenced track against the current library. Returns the
  /// created [Playlist], or `null` if no tracks could be matched.
  Future<Playlist?> importPlaylistFromM3uFile(
    String filePath, {
    String? name,
  }) async {
    final songs = await _m3uService.resolveSongsFromFile(filePath, _songs);
    if (songs.isEmpty) return null;

    final playlistName = (name != null && name.trim().isNotEmpty)
        ? name.trim()
        : _fileBaseName(filePath);

    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final playlist = Playlist(id: id, name: playlistName, songs: songs);
    _playlists.add(playlist);
    _playlistsDirty = true;
    unawaited(savePlaylists());
    _scheduleNotify();
    return playlist;
  }

  // MARK: - Sync Folder Configuration

  /// Returns the configured playlist sync folder, or `null` if unset.
  Future<String?> playlistSyncFolder() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kSyncFolderPrefKey);
  }

  /// Sets (or clears, when [folder] is `null`) the playlist sync folder.
  Future<void> setPlaylistSyncFolder(String? folder) async {
    final prefs = await SharedPreferences.getInstance();
    if (folder == null || folder.isEmpty) {
      await prefs.remove(_kSyncFolderPrefKey);
    } else {
      await prefs.setString(_kSyncFolderPrefKey, folder);
    }
  }

  // MARK: - Two-way Folder Sync

  /// Performs a two-way sync between in-app playlists and `.m3u8` files in the
  /// configured sync folder.
  ///
  /// For each user playlist an `.m3u8` file is maintained in the folder. When a
  /// folder file is newer than the app's last sync it is imported (updating the
  /// matching playlist or creating a new one); otherwise the app playlist is
  /// written out to the folder. New `.m3u8` files found in the folder are
  /// imported as new playlists.
  ///
  /// Returns `true` if any change was made. Silently no-ops if no folder is
  /// configured or the folder is inaccessible.
  Future<bool> syncPlaylistsWithFolder() async {
    final folder = await playlistSyncFolder();
    if (folder == null || folder.isEmpty) return false;

    final dir = Directory(folder);
    bool dirExists;
    try {
      dirExists = await dir.exists();
      if (!dirExists) {
        await dir.create(recursive: true);
        dirExists = true;
      }
    } catch (e) {
      debugPrint('Playlist sync: folder inaccessible: $e');
      return false;
    }

    var changed = false;

    // Index existing .m3u8/.m3u files in the folder by base name.
    final folderFiles = <String, File>{};
    try {
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is File) {
          final lower = entity.path.toLowerCase();
          if (lower.endsWith('.m3u8') || lower.endsWith('.m3u')) {
            folderFiles[_fileBaseName(entity.path).toLowerCase()] = entity;
          }
        }
      }
    } catch (e) {
      debugPrint('Playlist sync: listing failed: $e');
      return false;
    }

    final prefs = await SharedPreferences.getInstance();

    // 1. Reconcile each user playlist with its folder file.
    for (final playlist in List<Playlist>.from(_playlists)) {
      if (_isSyncExcludedPlaylist(playlist)) continue;

      final safeName = _m3uService.sanitizeFileName(playlist.name);
      final key = safeName.toLowerCase();
      final targetPath = '${dir.path}/$safeName.m3u8';
      final existing = folderFiles.remove(key);

      final lastSyncKey = 'playlist_sync_mtime_${playlist.id}';
      final lastSyncMs = prefs.getInt(lastSyncKey) ?? 0;

      if (existing != null) {
        int fileMtimeMs = 0;
        try {
          fileMtimeMs = (await existing.stat()).modified.millisecondsSinceEpoch;
        } catch (_) {}

        if (fileMtimeMs > lastSyncMs) {
          // Folder file is newer → import into the app.
          final songs =
              await _m3uService.resolveSongsFromFile(existing.path, _songs);
          if (songs.isNotEmpty &&
              !_sameSongList(playlist.songs, songs)) {
            playlist.songs
              ..clear()
              ..addAll(songs);
            _playlistsDirty = true;
            changed = true;
          }
          await prefs.setInt(lastSyncKey, fileMtimeMs);
        } else {
          // App playlist is the source of truth → write it out.
          await _writePlaylistFile(playlist, existing.path, prefs, lastSyncKey);
          changed = true;
        }
      } else {
        // No folder file yet → create one from the app playlist.
        await _writePlaylistFile(playlist, targetPath, prefs, lastSyncKey);
        changed = true;
      }
    }

    // 2. Any remaining folder files are new external playlists → import them.
    for (final entry in folderFiles.entries) {
      final file = entry.value;
      final songs =
          await _m3uService.resolveSongsFromFile(file.path, _songs);
      if (songs.isEmpty) continue;
      final id = DateTime.now().microsecondsSinceEpoch.toString();
      final playlist = Playlist(
        id: id,
        name: _fileBaseName(file.path),
        songs: songs,
      );
      _playlists.add(playlist);
      _playlistsDirty = true;
      changed = true;
      try {
        final mtime = (await file.stat()).modified.millisecondsSinceEpoch;
        await prefs.setInt('playlist_sync_mtime_$id', mtime);
      } catch (_) {}
    }

    if (changed) {
      unawaited(savePlaylists());
      _scheduleNotify();
    }
    return changed;
  }

  Future<void> _writePlaylistFile(
    Playlist playlist,
    String path,
    SharedPreferences prefs,
    String lastSyncKey,
  ) async {
    try {
      final file = await _m3uService.exportToFile(playlist, path);
      final mtime = (await file.stat()).modified.millisecondsSinceEpoch;
      await prefs.setInt(lastSyncKey, mtime);
    } catch (e) {
      debugPrint('Playlist sync: failed to write $path: $e');
    }
  }

  /// Auto-generated playlists are not synced to files.
  bool _isSyncExcludedPlaylist(Playlist playlist) {
    final id = playlist.id;
    return id == 'liked_songs' ||
        id == 'most_played' ||
        id == 'recently_added';
  }

  bool _sameSongList(List<SongModel> a, List<SongModel> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }

  String _fileBaseName(String path) {
    final norm = path.replaceAll('\\', '/');
    final slash = norm.lastIndexOf('/');
    var name = slash >= 0 ? norm.substring(slash + 1) : norm;
    final dot = name.lastIndexOf('.');
    if (dot > 0) name = name.substring(0, dot);
    return name;
  }
}
