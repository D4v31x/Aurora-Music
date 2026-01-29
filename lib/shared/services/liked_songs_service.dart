/// Liked songs service.
///
/// Manages the user's liked/favorite songs collection.
/// Provides persistence and CRUD operations for liked songs.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:path_provider/path_provider.dart';
import '../models/playlist_model.dart';
import 'audio_constants.dart';

// MARK: - Liked Songs Service

/// Service for managing the user's liked songs.
///
/// Responsibilities:
/// - Persisting liked song IDs
/// - Creating a virtual playlist from liked songs
/// - Toggle like/unlike operations
class LikedSongsService {
  // MARK: - Private Fields

  Set<String> _likedSongs = {};
  Playlist? _likedSongsPlaylist;
  String _playlistName = 'Favorite Songs';
  Timer? _saveDebounceTimer;

  // MARK: - Public Getters

  /// Set of liked song IDs.
  Set<String> get likedSongIds => Set.unmodifiable(_likedSongs);

  /// Notifier for reactive UI updates.
  final ValueNotifier<Set<String>> likedSongsNotifier =
      ValueNotifier<Set<String>>({});

  /// The liked songs playlist.
  Playlist? get likedSongsPlaylist => _likedSongsPlaylist;

  /// Name of the liked songs playlist.
  String get playlistName => _playlistName;

  // MARK: - Initialization

  /// Loads liked songs from persistent storage.
  Future<void> load() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/${kLikedSongsFileName}');

      if (await file.exists()) {
        final contents = await file.readAsString();
        final json = jsonDecode(contents);
        _likedSongs = Set<String>.from(json['liked_songs'] ?? []);
        likedSongsNotifier.value = Set<String>.from(_likedSongs);
      }
    } catch (e) {
      debugPrint('Error loading liked songs: $e');
    }
  }

  /// Saves liked songs to persistent storage.
  Future<void> save() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/${kLikedSongsFileName}');

      final json = {
        'liked_songs': _likedSongs.toList(),
      };

      await file.writeAsString(jsonEncode(json));
    } catch (e) {
      debugPrint('Error saving liked songs: $e');
    }
  }

  // MARK: - Like Operations

  /// Checks if a song is liked.
  bool isLiked(SongModel song) {
    return _likedSongs.contains(song.id.toString());
  }

  /// Checks if a song ID is liked.
  bool isLikedById(String songId) {
    return _likedSongs.contains(songId);
  }

  /// Toggles the like status of a song.
  Future<void> toggleLike(SongModel song) async {
    final songId = song.id.toString();
    if (_likedSongs.contains(songId)) {
      _likedSongs.remove(songId);
    } else {
      _likedSongs.add(songId);
    }

    likedSongsNotifier.value = Set<String>.from(_likedSongs);
    _scheduleSave();
  }

  /// Likes a song (no-op if already liked).
  void likeSong(SongModel song) {
    final songId = song.id.toString();
    if (!_likedSongs.contains(songId)) {
      _likedSongs.add(songId);
      likedSongsNotifier.value = Set<String>.from(_likedSongs);
      _scheduleSave();
    }
  }

  /// Unlikes a song (no-op if not liked).
  void unlikeSong(SongModel song) {
    final songId = song.id.toString();
    if (_likedSongs.contains(songId)) {
      _likedSongs.remove(songId);
      likedSongsNotifier.value = Set<String>.from(_likedSongs);
      _scheduleSave();
    }
  }

  // MARK: - Playlist Management

  /// Updates the liked songs playlist with the given song library.
  void updatePlaylist(List<SongModel> allSongs) {
    try {
      final likedSongs = allSongs
          .where((song) => _likedSongs.contains(song.id.toString()))
          .toList();

      _likedSongsPlaylist = Playlist(
        id: kLikedSongsPlaylistId,
        name: _playlistName,
        songs: likedSongs,
      );
    } catch (e) {
      _likedSongsPlaylist ??= Playlist(
        id: kLikedSongsPlaylistId,
        name: _playlistName,
        songs: [],
      );
      debugPrint('Error updating liked songs playlist: $e');
    }
  }

  /// Updates the playlist name (for localization).
  void updatePlaylistName(String newName) {
    _playlistName = newName;
    if (_likedSongsPlaylist != null) {
      _likedSongsPlaylist = Playlist(
        id: kLikedSongsPlaylistId,
        name: _playlistName,
        songs: _likedSongsPlaylist!.songs,
      );
    }
  }

  /// Initializes the playlist with empty songs.
  void initializeEmptyPlaylist() {
    _likedSongsPlaylist = Playlist(
      id: kLikedSongsPlaylistId,
      name: _playlistName,
      songs: [],
    );
  }

  // MARK: - Private Methods

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
    likedSongsNotifier.dispose();
  }
}
