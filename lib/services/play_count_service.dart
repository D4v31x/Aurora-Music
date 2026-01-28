/// Play count tracking service.
///
/// Manages tracking and persistence of play counts for songs, albums,
/// artists, playlists, and folders.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:path_provider/path_provider.dart';
import '../models/utils.dart';
import 'audio_constants.dart';
import 'smart_suggestions_service.dart';

// MARK: - Play Count Service

/// Service for tracking play counts of audio content.
///
/// Tracks:
/// - Individual track plays
/// - Album plays (aggregated from track plays)
/// - Artist plays (aggregated, handles multi-artist tracks)
/// - Playlist access counts
/// - Folder access counts
///
/// Data is persisted to local storage with debounced saves to reduce I/O.
class PlayCountService {
  // MARK: - Private Fields

  final SmartSuggestionsService _smartSuggestions;
  final OnAudioQuery _audioQuery = OnAudioQuery();

  /// Play counts for individual tracks by ID.
  Map<String, int> _trackPlayCounts = {};

  /// Play counts for albums by ID.
  Map<String, int> _albumPlayCounts = {};

  /// Play counts for artists by name.
  Map<String, int> _artistPlayCounts = {};

  /// Play counts for playlists by ID.
  Map<String, int> _playlistPlayCounts = {};

  /// Access counts for folders by path.
  Map<String, int> _folderAccessCounts = {};

  /// Flag indicating if play counts have changed since last save.
  bool _isDirty = false;

  /// Timer for debounced saves.
  Timer? _saveDebounceTimer;

  // MARK: - Constructor

  PlayCountService({SmartSuggestionsService? smartSuggestions})
      : _smartSuggestions = smartSuggestions ?? SmartSuggestionsService();

  // MARK: - Public Getters

  /// Gets the play count for a track by ID.
  int getTrackPlayCount(String trackId) => _trackPlayCounts[trackId] ?? 0;

  /// Gets the play count for an album by ID.
  int getAlbumPlayCount(String albumId) => _albumPlayCounts[albumId] ?? 0;

  /// Gets the play count for an artist by name.
  int getArtistPlayCount(String artistName) =>
      _artistPlayCounts[artistName] ?? 0;

  /// Gets the play count for a playlist by ID.
  int getPlaylistPlayCount(String playlistId) =>
      _playlistPlayCounts[playlistId] ?? 0;

  /// Gets the access count for a folder by path.
  int getFolderAccessCount(String folderPath) =>
      _folderAccessCounts[folderPath] ?? 0;

  /// Gets all track play counts.
  Map<String, int> get trackPlayCounts =>
      Map<String, int>.unmodifiable(_trackPlayCounts);

  /// Gets all folder access counts.
  Map<String, int> get folderAccessCounts =>
      Map<String, int>.unmodifiable(_folderAccessCounts);

  // MARK: - Public Methods

  /// Loads play counts from persistent storage.
  Future<void> load() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/${kPlayCountsFileName}');

      if (await file.exists()) {
        final contents = await file.readAsString();
        final json = jsonDecode(contents) as Map<String, dynamic>;

        _trackPlayCounts = Map<String, int>.from(json['tracks'] ?? {});
        _albumPlayCounts = Map<String, int>.from(json['albums'] ?? {});
        _artistPlayCounts = Map<String, int>.from(json['artists'] ?? {});
        _playlistPlayCounts = Map<String, int>.from(json['playlists'] ?? {});
        _folderAccessCounts = Map<String, int>.from(json['folders'] ?? {});
      }
    } catch (e) {
      debugPrint('Error loading play counts: $e');
    }
  }

  /// Saves play counts to persistent storage.
  Future<void> save() async {
    if (!_isDirty) return;

    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/${kPlayCountsFileName}');

      final json = {
        'tracks': _trackPlayCounts,
        'albums': _albumPlayCounts,
        'artists': _artistPlayCounts,
        'playlists': _playlistPlayCounts,
        'folders': _folderAccessCounts,
      };

      await file.writeAsString(jsonEncode(json));
      _isDirty = false;
    } catch (e) {
      debugPrint('Error saving play counts: $e');
    }
  }

  /// Records a play for a song, updating all related counts.
  void recordPlay(SongModel song) {
    // Update track count
    final trackId = song.id.toString();
    _trackPlayCounts[trackId] = (_trackPlayCounts[trackId] ?? 0) + 1;

    // Update album count
    if (song.albumId != null) {
      final albumId = song.albumId.toString();
      _albumPlayCounts[albumId] = (_albumPlayCounts[albumId] ?? 0) + 1;
    }

    // Update artist counts (handles multiple artists)
    if (song.artist != null) {
      final artistNames = splitArtists(song.artist!);
      for (final artist in artistNames) {
        _artistPlayCounts[artist] = (_artistPlayCounts[artist] ?? 0) + 1;
      }
    }

    // Update folder count
    final folder = File(song.data).parent.path;
    _folderAccessCounts[folder] = (_folderAccessCounts[folder] ?? 0) + 1;

    // Record to smart suggestions service
    _smartSuggestions.recordPlay(song);

    _markDirty();
  }

  /// Records a folder access.
  void recordFolderAccess(String folderPath) {
    _folderAccessCounts[folderPath] =
        (_folderAccessCounts[folderPath] ?? 0) + 1;
    _markDirty();
  }

  /// Records a playlist access.
  void recordPlaylistAccess(String playlistId) {
    _playlistPlayCounts[playlistId] =
        (_playlistPlayCounts[playlistId] ?? 0) + 1;
    _markDirty();
  }

  // MARK: - Query Methods

  /// Gets the most played tracks, sorted by play count.
  Future<List<SongModel>> getMostPlayedTracks({int count = 10}) async {
    try {
      final allSongs = await _audioQuery.querySongs(
        orderType: OrderType.ASC_OR_SMALLER,
        uriType: UriType.EXTERNAL,
        ignoreCase: true,
      );

      final sortedTracks = allSongs.toList()
        ..sort((a, b) => (_trackPlayCounts[b.id.toString()] ?? 0)
            .compareTo(_trackPlayCounts[a.id.toString()] ?? 0));

      return sortedTracks.take(count).toList();
    } catch (e) {
      debugPrint('Error getting most played tracks: $e');
      return [];
    }
  }

  /// Gets the most played albums, sorted by play count.
  Future<List<AlbumModel>> getMostPlayedAlbums({int count = 10}) async {
    try {
      final albums = await _audioQuery.queryAlbums();

      albums.sort((a, b) => (_albumPlayCounts[b.id.toString()] ?? 0)
          .compareTo(_albumPlayCounts[a.id.toString()] ?? 0));

      return albums.take(count).toList();
    } catch (e) {
      debugPrint('Error getting most played albums: $e');
      return [];
    }
  }

  /// Gets the most played artists, sorted by play count.
  Future<List<ArtistModel>> getMostPlayedArtists({int count = 10}) async {
    try {
      final allArtists = await _audioQuery.queryArtists();

      allArtists.sort((a, b) => (_artistPlayCounts[b.artist] ?? 0)
          .compareTo(_artistPlayCounts[a.artist] ?? 0));

      return allArtists.take(count).toList();
    } catch (e) {
      debugPrint('Error getting most played artists: $e');
      return [];
    }
  }

  /// Gets the most accessed folders, sorted by access count.
  List<String> getMostAccessedFolders({int count = 3}) {
    final entries = _folderAccessCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return entries.take(count).map((e) => e.key).toList();
  }

  /// Gets recently played tracks (tracks with any play count).
  Future<List<SongModel>> getRecentlyPlayed({int count = 3}) async {
    try {
      final allSongs = await _audioQuery.querySongs(
        orderType: OrderType.ASC_OR_SMALLER,
        uriType: UriType.EXTERNAL,
        ignoreCase: true,
      );

      final playedSongs = allSongs
          .where((song) => _trackPlayCounts.containsKey(song.id.toString()))
          .toList();

      playedSongs.sort((a, b) => (_trackPlayCounts[b.id.toString()] ?? 0)
          .compareTo(_trackPlayCounts[a.id.toString()] ?? 0));

      return playedSongs.take(count).toList();
    } catch (e) {
      debugPrint('Error getting recently played: $e');
      return [];
    }
  }

  // MARK: - Private Methods

  /// Marks data as dirty and schedules a debounced save.
  void _markDirty() {
    _isDirty = true;
    _scheduleSave();
  }

  /// Schedules a debounced save to reduce disk I/O.
  void _scheduleSave() {
    _saveDebounceTimer?.cancel();
    _saveDebounceTimer = Timer(
      const Duration(milliseconds: kSaveDebounceMs),
      save,
    );
  }

  /// Disposes of resources.
  void dispose() {
    _saveDebounceTimer?.cancel();
    if (_isDirty) {
      save();
    }
  }
}
