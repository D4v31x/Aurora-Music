part of '../audio_player_service.dart';

extension AudioPlayCountsExtension on AudioPlayerService {
  Future<void> _loadPlayCounts() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/play_counts.json');

    if (await file.exists()) {
      final contents = await file.readAsString();
      final json = jsonDecode(contents);

      _trackPlayCounts = Map<String, int>.from(json['tracks']);
      _albumPlayCounts = Map<String, int>.from(json['albums']);
      _artistPlayCounts = Map<String, int>.from(json['artists']);
      _playlistPlayCounts = Map<String, int>.from(json['playlists']);
      _folderAccessCounts = Map<String, int>.from(json['folders']);
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

  void _incrementPlayCount(SongModel song) {
    _trackPlayCounts[song.id.toString()] =
        (_trackPlayCounts[song.id.toString()] ?? 0) + 1;

    if (song.albumId != null) {
      _albumPlayCounts[song.albumId.toString()] =
          (_albumPlayCounts[song.albumId.toString()] ?? 0) + 1;
    }

    if (song.artistId != null) {
      final artistNames = splitArtists(song.artist ?? '');
      for (final artist in artistNames) {
        _artistPlayCounts[artist] = (_artistPlayCounts[artist] ?? 0) + 1;
      }
    }

    final folder = File(song.data).parent.path;
    _folderAccessCounts[folder] = (_folderAccessCounts[folder] ?? 0) + 1;

    if (song.artist != null) {
      final artistNames = splitArtists(song.artist!);
      for (final artist in artistNames) {
        _artistPlayCounts[artist] = (_artistPlayCounts[artist] ?? 0) + 1;
      }
    }

    // Record to smart suggestions service for personalized recommendations
    _smartSuggestions.recordPlay(song);

    // Use debounced save to reduce disk I/O
    _scheduleSavePlayCounts();
  }

  /// Get smart suggested tracks based on listening patterns and time of day
  Future<List<SongModel>> getSuggestedTracks({int count = 3}) async {
    await _smartSuggestions.initialize();
    return _smartSuggestions.getSuggestedTracks(count: count);
  }

  /// Get smart suggested artists based on listening patterns and time of day
  Future<List<String>> getSuggestedArtists({int count = 3}) async {
    await _smartSuggestions.initialize();
    return _smartSuggestions.getSuggestedArtists(count: count);
  }

  /// Check if user has enough listening history for smart suggestions
  bool hasListeningHistory() => _smartSuggestions.hasListeningHistory();

  // Most Played Queries
  Future<List<SongModel>> getMostPlayedTracks() async {
    final allSongs = await _audioQuery.querySongs(
      orderType: OrderType.ASC_OR_SMALLER,
      uriType: UriType.EXTERNAL,
      ignoreCase: true,
    );
    final sortedTracks = allSongs
      ..sort((a, b) => (_trackPlayCounts[b.id.toString()] ?? 0)
          .compareTo(_trackPlayCounts[a.id.toString()] ?? 0));
    return sortedTracks.take(10).toList();
  }

  Future<List<AlbumModel>> getMostPlayedAlbums() async {
    final albums = await _audioQuery.queryAlbums();
    albums.sort((a, b) => (_albumPlayCounts[b.id.toString()] ?? 0)
        .compareTo(_albumPlayCounts[a.id.toString()] ?? 0));
    return albums.take(10).toList();
  }

  Future<List<ArtistModel>> getMostPlayedArtists() async {
    final allArtists = await _audioQuery.queryArtists();
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
    return sortedPlaylists.take(3).toList();
  }

  List<String> getThreeFolders() {
    final folderAccessCounts = _folderAccessCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return folderAccessCounts.take(3).map((entry) => entry.key).toList();
  }

  /// Get recently played songs sorted by play count
  /// [count] - number of songs to return (default 3, use -1 for all)
  Future<List<SongModel>> getRecentlyPlayed({int count = 3}) async {
    final allSongs = await _audioQuery.querySongs(
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

  /// Get all recently played songs (full list for playback)
  Future<List<SongModel>> getAllRecentlyPlayed() async {
    return getRecentlyPlayed(count: -1);
  }

  /// Get all recently added songs (full list for playback)
  Future<List<SongModel>> getAllRecentlyAdded() async {
    final allSongs = await _audioQuery.querySongs(
      sortType: SongSortType.DATE_ADDED,
      orderType: OrderType.DESC_OR_GREATER,
      uriType: UriType.EXTERNAL,
      ignoreCase: true,
    );
    return allSongs;
  }

  /// Get all most played tracks (full list for playback)
  Future<List<SongModel>> getAllMostPlayedTracks() async {
    final allSongs = await _audioQuery.querySongs(
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
