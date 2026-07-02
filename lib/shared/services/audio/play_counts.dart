part of '../audio_player_service.dart';

extension AudioPlayCountsExtension on AudioPlayerService {
  Future<void> _loadPlayCounts() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/play_counts.json');

    if (!await file.exists()) return;

    try {
      final contents = await file.readAsString();
      final json = jsonDecode(contents);

      _trackPlayCounts = Map<String, int>.from(json['tracks'] ?? {});
      _albumPlayCounts = Map<String, int>.from(json['albums'] ?? {});
      _artistPlayCounts = Map<String, int>.from(json['artists'] ?? {});
      _playlistPlayCounts = Map<String, int>.from(json['playlists'] ?? {});
      _folderAccessCounts = Map<String, int>.from(json['folders'] ?? {});
    } catch (_) {
      // Corrupted data — delete and start fresh to prevent startup crash.
      await file.delete();
    }
  }

  Future<void> _savePlayCounts() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/play_counts.json');

    final json = {
      'tracks': _trackPlayCounts,
      'albums': _albumPlayCounts,
      'artists': _artistPlayCounts,
      'playlists': _playlistPlayCounts,
      'folders': _folderAccessCounts,
    };

    await file.writeAsString(jsonEncode(json));
  }

  /// Number of times [song] has been played, for use in smart-playlist rule
  /// evaluation and other statistics.
  int playCountFor(SongModel song) =>
      _trackPlayCounts[song.id.toString()] ?? 0;

  void _incrementPlayCount(SongModel song) {
    // Commit the real listened time of the previously-playing song before
    // we start counting this new one separately.
    _finalizeListenTime(nextTrackId: song.id.toString());

    _trackPlayCounts[song.id.toString()] =
        (_trackPlayCounts[song.id.toString()] ?? 0) + 1;

    if (song.albumId != null) {
      _albumPlayCounts[song.albumId.toString()] =
          (_albumPlayCounts[song.albumId.toString()] ?? 0) + 1;
    }

    // Update artist counts (handles multi-artist tracks)
    if (song.artist != null) {
      final artistNames = splitArtists(song.artist!);
      for (final artist in artistNames) {
        _artistPlayCounts[artist] = (_artistPlayCounts[artist] ?? 0) + 1;
      }
    }

    final folder = File(song.data).parent.path;
    _folderAccessCounts[folder] = (_folderAccessCounts[folder] ?? 0) + 1;

    // Record to smart suggestions service for personalized recommendations
    _smartSuggestions.recordPlay(song);

    // Use debounced save to reduce disk I/O
    _scheduleSavePlayCounts();
  }

  /// Get smart suggested tracks based on listening patterns and time of day
  Future<List<SongModel>> getSuggestedTracks({int count = 3}) async {
    await _smartSuggestions.initialize();
    return _smartSuggestions.getSuggestedTracks(
      count: count,
      songs: _rawSongs.isNotEmpty ? _songs : null,
    );
  }

  /// Get smart suggested artists based on listening patterns and time of day
  Future<List<String>> getSuggestedArtists({int count = 3}) async {
    await _smartSuggestions.initialize();
    return _smartSuggestions.getSuggestedArtists(
      count: count,
      songs: _rawSongs.isNotEmpty ? _songs : null,
    );
  }

  /// Check if user has enough listening history for smart suggestions
  bool hasListeningHistory() => _smartSuggestions.hasListeningHistory();

  /// Timestamp of the user's very first recorded play, or null if no history.
  DateTime? get firstListenTime => _smartSuggestions.firstListenTime;

  // Most Played Queries

  /// Returns the top [count] most-played tracks.
  ///
  /// Performance: uses the in-memory [_songs] cache instead of issuing a
  /// full MediaStore query (`_audioQuery.querySongs`) on every call, which
  /// was the single biggest blocking operation on the main thread.
  Future<List<SongModel>> getMostPlayedTracks() async {
    // Use the already-loaded in-memory song list. Fall back to a fresh query
    // only when the library hasn't loaded yet (cold-start before initializeMusicLibrary).
    // We check _rawSongs (not _songs) so that an all-excluded filter still
    // returns an empty list instead of falling through to the raw MediaStore.
    final allSongs = _rawSongs.isNotEmpty
        ? _songs
        : await _audioQuery.querySongs(
            orderType: OrderType.ASC_OR_SMALLER,
            uriType: UriType.EXTERNAL,
            ignoreCase: true,
          );
    final playedSongs = allSongs
        .where((song) => (_trackPlayCounts[song.id.toString()] ?? 0) > 0)
        .toList()
      ..sort((a, b) => (_trackPlayCounts[b.id.toString()] ?? 0)
          .compareTo(_trackPlayCounts[a.id.toString()] ?? 0));
    return playedSongs.take(10).toList();
  }

  Future<List<AlbumModel>> getMostPlayedAlbums() async {
    final albums = await _audioQuery.queryAlbums();
    // Restrict to albums that contain at least one visible (non-excluded) song.
    if (_rawSongs.isNotEmpty) {
      final allowedAlbumIds = _songs.map((s) => s.albumId).toSet();
      albums.retainWhere((a) => allowedAlbumIds.contains(a.id));
    }
    albums.sort((a, b) => (_albumPlayCounts[b.id.toString()] ?? 0)
        .compareTo(_albumPlayCounts[a.id.toString()] ?? 0));
    return albums.take(10).toList();
  }

  Future<List<ArtistModel>> getMostPlayedArtists() async {
    final allArtists = await _audioQuery.queryArtists();
    // Restrict to artists that have at least one visible (non-excluded) song.
    if (_rawSongs.isNotEmpty) {
      final visibleArtistNames = _songs.map((s) => s.artist ?? '').toSet();
      allArtists.retainWhere((a) => visibleArtistNames.contains(a.artist));
    }
    final artistPlayCounts = <String, int>{};

    for (final artist in allArtists) {
      final artistNames = splitArtists(artist.artist);
      for (final name in artistNames) {
        artistPlayCounts[name] = (_artistPlayCounts[name] ?? 0);
      }
    }

    final sortedArtists = allArtists
      ..sort((a, b) => (artistPlayCounts[b.artist] ?? 0)
          .compareTo(artistPlayCounts[a.artist] ?? 0));

    return sortedArtists.take(10).toList();
  }

  List<Playlist> getThreePlaylists() {
    final sortedPlaylists = _playlists.toList()
      ..sort((a, b) => (_playlistPlayCounts[b.id] ?? 0)
          .compareTo(_playlistPlayCounts[a.id] ?? 0));
    final liked = _likedSongsPlaylist;
    if (liked != null) {
      return [liked, ...sortedPlaylists.take(2)];
    }
    return sortedPlaylists.take(3).toList();
  }

  List<String> getThreeFolders() {
    final filterService = FolderFilterService();
    final folderAccessCounts = _folderAccessCounts.entries
        .where((e) => !filterService.isExcluded(e.key))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return folderAccessCounts.take(3).map((entry) => entry.key).toList();
  }

  /// Returns recently played songs sorted by play count.
  ///
  /// Performance: reads from the in-memory [_songs] cache rather than
  /// issuing a new `querySongs` MediaStore call on every invocation.
  /// [count] – number of songs to return (default 3, -1 = all).
  Future<List<SongModel>> getRecentlyPlayed({int count = 3}) async {
    final allSongs = _rawSongs.isNotEmpty
        ? _songs
        : await _audioQuery.querySongs(
            orderType: OrderType.ASC_OR_SMALLER,
            uriType: UriType.EXTERNAL,
            ignoreCase: true,
          );
    final recentlyPlayedSongs = allSongs
        .where((song) => _trackPlayCounts.containsKey(song.id.toString()))
        .toList();

    recentlyPlayedSongs.sort((a, b) => (_trackPlayCounts[b.id.toString()] ?? 0)
        .compareTo(_trackPlayCounts[a.id.toString()] ?? 0));

    if (count == -1) {
      return recentlyPlayedSongs;
    }
    return recentlyPlayedSongs.take(count).toList();
  }

  /// Returns all recently played songs (full list for playback).
  Future<List<SongModel>> getAllRecentlyPlayed() async {
    return getRecentlyPlayed(count: -1);
  }

  /// Returns all recently-added songs, sorted newest-first.
  ///
  /// Performance: derives the list from the cached [_songs] and sorts
  /// in-memory by [dateAdded] rather than firing a new MediaStore query.
  Future<List<SongModel>> getAllRecentlyAdded() async {
    final allSongs = _rawSongs.isNotEmpty
        ? List<SongModel>.from(_songs)
        : await _audioQuery.querySongs(
            sortType: SongSortType.DATE_ADDED,
            orderType: OrderType.DESC_OR_GREATER,
            uriType: UriType.EXTERNAL,
            ignoreCase: true,
          );
    // If the cache was used, sort by dateAdded descending in-memory.
    if (_rawSongs.isNotEmpty) {
      allSongs.sort((a, b) => (b.dateAdded ?? 0).compareTo(a.dateAdded ?? 0));
    }
    return allSongs;
  }

  /// Returns all most-played tracks (full list for playback).
  ///
  /// Performance: uses the in-memory [_songs] cache — no MediaStore round-trip.
  Future<List<SongModel>> getAllMostPlayedTracks() async {
    final allSongs = _songs.isNotEmpty
        ? _songs
        : await _audioQuery.querySongs(
            orderType: OrderType.ASC_OR_SMALLER,
            uriType: UriType.EXTERNAL,
            ignoreCase: true,
          );
    final playedSongs = allSongs
        .where((song) => (_trackPlayCounts[song.id.toString()] ?? 0) > 0)
        .toList();

    playedSongs.sort((a, b) => (_trackPlayCounts[b.id.toString()] ?? 0)
        .compareTo(_trackPlayCounts[a.id.toString()] ?? 0));
    return playedSongs;
  }
}
