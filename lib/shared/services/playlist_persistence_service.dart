/// Playlist persistence service.
///
/// Handles saving and loading playlists from local storage.
/// Provides a clean API for managing user playlists.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:path_provider/path_provider.dart';
import '../models/playlist_model.dart';
import 'audio_constants.dart';

// MARK: - Playlist Persistence Service

/// Service for persisting and managing playlists.
///
/// Responsibilities:
/// - Loading playlists from disk
/// - Saving playlists to disk
/// - CRUD operations on playlists
/// - Auto-generated playlists (Most Played, Recently Added)
class PlaylistPersistenceService {
  // MARK: - Private Fields

  final OnAudioQuery _audioQuery = OnAudioQuery();

  List<Playlist> _playlists = [];
  bool _isDirty = false;
  Timer? _saveDebounceTimer;

  /// Play counts for playlists (for sorting).
  Map<String, int> _playlistPlayCounts = {};

  // MARK: - Public Getters

  /// All user playlists.
  List<Playlist> get playlists => List.unmodifiable(_playlists);

  /// Notifier for reactive UI updates.
  final ValueNotifier<List<Playlist>> playlistsNotifier =
      ValueNotifier<List<Playlist>>([]);

  // MARK: - Initialization

  /// Loads playlists from persistent storage.
  Future<void> load() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/${kPlaylistsFileName}');

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
        playlistsNotifier.value = List.from(_playlists);
      }
    } catch (e) {
      debugPrint('Error loading playlists: $e');
    }
  }

  /// Saves playlists to persistent storage.
  Future<void> save() async {
    if (!_isDirty) return;

    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/${kPlaylistsFileName}');

      final json = _playlists
          .map((playlist) => {
                'id': playlist.id,
                'name': playlist.name,
                'songs': playlist.songs.map((song) => song.getMap).toList(),
              })
          .toList();

      await file.writeAsString(jsonEncode(json));
      _isDirty = false;
      playlistsNotifier.value = List.from(_playlists);
    } catch (e) {
      debugPrint('Error saving playlists: $e');
    }
  }

  // MARK: - Playlist Operations

  /// Creates a new playlist.
  void createPlaylist(String name, List<SongModel> songs) {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final newPlaylist = Playlist(id: id, name: name, songs: songs);
    _playlists.add(newPlaylist);
    _markDirty();
  }

  /// Gets a playlist by ID.
  Playlist? getPlaylist(String playlistId) {
    try {
      return _playlists.firstWhere((p) => p.id == playlistId);
    } catch (e) {
      return null;
    }
  }

  /// Adds a song to a playlist.
  void addSongToPlaylist(String playlistId, SongModel song) {
    final playlist = getPlaylist(playlistId);
    if (playlist != null && !playlist.songs.contains(song)) {
      playlist.songs.add(song);
      _markDirty();
    }
  }

  /// Adds multiple songs to a playlist.
  void addSongsToPlaylist(String playlistId, List<SongModel> songs) {
    final playlist = getPlaylist(playlistId);
    if (playlist != null) {
      for (final song in songs) {
        if (!playlist.songs.contains(song)) {
          playlist.songs.add(song);
        }
      }
      _markDirty();
    }
  }

  /// Removes a song from a playlist.
  void removeSongFromPlaylist(String playlistId, SongModel song) {
    final playlist = getPlaylist(playlistId);
    if (playlist != null) {
      playlist.songs.remove(song);
      _markDirty();
    }
  }

  /// Deletes a playlist.
  void deletePlaylist(Playlist playlist) {
    _playlists.remove(playlist);
    _markDirty();
  }

  /// Renames a playlist.
  void renamePlaylist(String playlistId, String newName) {
    final playlistIndex = _playlists.indexWhere((p) => p.id == playlistId);
    if (playlistIndex != -1) {
      _playlists[playlistIndex] =
          _playlists[playlistIndex].copyWith(name: newName);
      _markDirty();
    }
  }

  /// Gets the top N playlists sorted by play count.
  List<Playlist> getTopPlaylists({int count = kPlaylistPreviewCount}) {
    final sorted = _playlists.toList()
      ..sort((a, b) => (_playlistPlayCounts[b.id] ?? 0)
          .compareTo(_playlistPlayCounts[a.id] ?? 0));
    return sorted.take(count).toList();
  }

  /// Sets playlist play counts for sorting.
  void setPlaylistPlayCounts(Map<String, int> counts) {
    _playlistPlayCounts = Map.from(counts);
  }

  // MARK: - Auto Playlists

  /// Updates auto-generated playlists (Most Played, Recently Added).
  Future<void> updateAutoPlaylists({
    required Future<List<SongModel>> Function() getMostPlayedTracks,
  }) async {
    try {
      // Update Most Played playlist
      final mostPlayedTracks = await getMostPlayedTracks();
      _updateOrCreatePlaylist(
        kMostPlayedPlaylistId,
        'Most Played',
        mostPlayedTracks,
      );

      // Update Recently Added playlist
      final recentlyAddedTracks = await _audioQuery.querySongs(
        sortType: SongSortType.DATE_ADDED,
        orderType: OrderType.DESC_OR_GREATER,
      );
      _updateOrCreatePlaylist(
        kRecentlyAddedPlaylistId,
        'Recently Added',
        recentlyAddedTracks,
      );

      _markDirty();
    } catch (e) {
      debugPrint('Error updating auto playlists: $e');
    }
  }

  void _updateOrCreatePlaylist(
      String id, String name, List<SongModel> songs) {
    final existingIndex = _playlists.indexWhere((p) => p.id == id);

    if (existingIndex != -1) {
      _playlists[existingIndex] = Playlist(id: id, name: name, songs: songs);
    } else {
      _playlists.add(Playlist(id: id, name: name, songs: songs));
    }
  }

  // MARK: - Private Methods

  void _markDirty() {
    _isDirty = true;
    _scheduleSave();
  }

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
    playlistsNotifier.dispose();
    if (_isDirty) {
      // Intentionally not awaited - see PlayCountService for explanation
      unawaited(save());
    }
  }
}
