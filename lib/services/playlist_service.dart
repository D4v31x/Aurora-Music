import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:on_audio_query/on_audio_query.dart';
import '../models/playlist_model.dart';
import '../services/logging_service.dart';
import '../services/play_count_service.dart';
import '../utils/file_utils.dart';
import '../utils/validation_utils.dart';

/// Service responsible for playlist management
/// Handles creation, modification, and persistence of playlists
class PlaylistService extends ChangeNotifier {
  static final PlaylistService _instance = PlaylistService._internal();
  factory PlaylistService() => _instance;
  PlaylistService._internal();

  final List<Playlist> _playlists = [];
  final OnAudioQuery _audioQuery = OnAudioQuery();
  final PlayCountService _playCountService = PlayCountService();
  
  bool _autoPlaylists = true;

  // Getters
  List<Playlist> get playlists => List.unmodifiable(_playlists);
  bool get autoPlaylists => _autoPlaylists;

  /// ValueNotifier for reactive UI updates
  final ValueNotifier<List<Playlist>> playlistsNotifier = ValueNotifier<List<Playlist>>([]);

  /// Initializes the playlist service
  Future<void> initialize() async {
    try {
      await loadPlaylists();
      await initializeLikedSongsPlaylist();
      if (_autoPlaylists) {
        await updateAutoPlaylists();
      }
      LoggingService.info('Playlist service initialized', 'PlaylistService');
    } catch (e) {
      LoggingService.error('Failed to initialize playlist service', 'PlaylistService', e);
    }
  }

  /// Loads playlists from storage
  Future<void> loadPlaylists() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/playlists.json');

      if (await file.exists()) {
        final content = await file.readAsString();
        final List<dynamic> playlistData = jsonDecode(content);
        
        _playlists.clear();
        for (final item in playlistData) {
          _playlists.add(Playlist.fromJson(item));
        }
        
        _updateNotifier();
        LoggingService.debug('Loaded ${_playlists.length} playlists', 'PlaylistService');
      }
    } catch (e) {
      LoggingService.error('Failed to load playlists', 'PlaylistService', e);
    }
  }

  /// Saves playlists to storage
  Future<void> savePlaylists() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/playlists.json');

      final playlistData = _playlists.map((playlist) => playlist.toJson()).toList();
      await file.writeAsString(jsonEncode(playlistData));
      
      LoggingService.debug('Saved ${_playlists.length} playlists', 'PlaylistService');
    } catch (e) {
      LoggingService.error('Failed to save playlists', 'PlaylistService', e);
    }
  }

  /// Creates a new playlist
  Future<bool> createPlaylist(String name, {List<SongModel>? songs}) async {
    try {
      if (!ValidationUtils.isValidPlaylistName(name)) {
        LoggingService.warning('Invalid playlist name: $name', 'PlaylistService');
        return false;
      }

      // Check for duplicate names
      if (_playlists.any((playlist) => playlist.name.toLowerCase() == name.toLowerCase())) {
        LoggingService.warning('Playlist already exists: $name', 'PlaylistService');
        return false;
      }

      final sanitizedName = ValidationUtils.sanitizeFileName(name);
      final playlist = Playlist(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: sanitizedName,
        songs: songs ?? [],
      );

      _playlists.add(playlist);
      await savePlaylists();
      _updateNotifier();
      
      LoggingService.info('Created playlist: $sanitizedName', 'PlaylistService');
      return true;
    } catch (e) {
      LoggingService.error('Failed to create playlist: $name', 'PlaylistService', e);
      return false;
    }
  }

  /// Deletes a playlist
  Future<bool> deletePlaylist(String playlistId) async {
    try {
      final index = _playlists.indexWhere((playlist) => playlist.id == playlistId);
      if (index == -1) {
        LoggingService.warning('Playlist not found for deletion: $playlistId', 'PlaylistService');
        return false;
      }

      final playlistName = _playlists[index].name;
      _playlists.removeAt(index);
      await savePlaylists();
      _updateNotifier();
      
      LoggingService.info('Deleted playlist: $playlistName', 'PlaylistService');
      return true;
    } catch (e) {
      LoggingService.error('Failed to delete playlist: $playlistId', 'PlaylistService', e);
      return false;
    }
  }

  /// Renames a playlist
  Future<bool> renamePlaylist(String playlistId, String newName) async {
    try {
      if (!ValidationUtils.isValidPlaylistName(newName)) {
        LoggingService.warning('Invalid new playlist name: $newName', 'PlaylistService');
        return false;
      }

      final index = _playlists.indexWhere((playlist) => playlist.id == playlistId);
      if (index == -1) {
        LoggingService.warning('Playlist not found for rename: $playlistId', 'PlaylistService');
        return false;
      }

      final sanitizedName = ValidationUtils.sanitizeFileName(newName);
      final oldName = _playlists[index].name;
      
      _playlists[index] = _playlists[index].copyWith(name: sanitizedName);
      await savePlaylists();
      _updateNotifier();
      
      LoggingService.info('Renamed playlist from "$oldName" to "$sanitizedName"', 'PlaylistService');
      return true;
    } catch (e) {
      LoggingService.error('Failed to rename playlist: $playlistId', 'PlaylistService', e);
      return false;
    }
  }

  /// Adds a song to a playlist
  Future<bool> addSongToPlaylist(String playlistId, SongModel song) async {
    try {
      final index = _playlists.indexWhere((playlist) => playlist.id == playlistId);
      if (index == -1) {
        LoggingService.warning('Playlist not found: $playlistId', 'PlaylistService');
        return false;
      }

      final playlist = _playlists[index];
      final updatedSongs = List<SongModel>.from(playlist.songs);
      
      // Check if song already exists
      if (updatedSongs.any((s) => s.id == song.id)) {
        LoggingService.debug('Song already in playlist', 'PlaylistService');
        return false;
      }

      updatedSongs.add(song);
      _playlists[index] = playlist.copyWith(songs: updatedSongs);
      await savePlaylists();
      _updateNotifier();
      
      LoggingService.debug('Added song to playlist: ${playlist.name}', 'PlaylistService');
      return true;
    } catch (e) {
      LoggingService.error('Failed to add song to playlist: $playlistId', 'PlaylistService', e);
      return false;
    }
  }

  /// Removes a song from a playlist
  Future<bool> removeSongFromPlaylist(String playlistId, int songId) async {
    try {
      final index = _playlists.indexWhere((playlist) => playlist.id == playlistId);
      if (index == -1) {
        LoggingService.warning('Playlist not found: $playlistId', 'PlaylistService');
        return false;
      }

      final playlist = _playlists[index];
      final updatedSongs = playlist.songs.where((song) => song.id != songId).toList();
      
      _playlists[index] = playlist.copyWith(songs: updatedSongs);
      await savePlaylists();
      _updateNotifier();
      
      LoggingService.debug('Removed song from playlist: ${playlist.name}', 'PlaylistService');
      return true;
    } catch (e) {
      LoggingService.error('Failed to remove song from playlist: $playlistId', 'PlaylistService', e);
      return false;
    }
  }

  /// Gets a playlist by ID
  Playlist? getPlaylistById(String playlistId) {
    return _playlists.firstWhere(
      (playlist) => playlist.id == playlistId,
      orElse: () => throw StateError('Playlist not found'),
    );
  }

  /// Initializes the "Liked Songs" playlist
  Future<void> initializeLikedSongsPlaylist() async {
    try {
      const likedPlaylistId = 'liked_songs';
      final existingIndex = _playlists.indexWhere((p) => p.id == likedPlaylistId);

      if (existingIndex == -1) {
        final likedPlaylist = Playlist(
          id: likedPlaylistId,
          name: 'Liked Songs',
          songs: [],
        );
        _playlists.insert(0, likedPlaylist);
        await savePlaylists();
        _updateNotifier();
        
        LoggingService.info('Initialized Liked Songs playlist', 'PlaylistService');
      }
    } catch (e) {
      LoggingService.error('Failed to initialize Liked Songs playlist', 'PlaylistService', e);
    }
  }

  /// Updates auto-generated playlists
  Future<void> updateAutoPlaylists() async {
    if (!_autoPlaylists) return;

    try {
      await _updateMostPlayedPlaylist();
      await _updateRecentlyAddedPlaylist();
    } catch (e) {
      LoggingService.error('Failed to update auto playlists', 'PlaylistService', e);
    }
  }

  /// Updates the "Most Played" playlist
  Future<void> _updateMostPlayedPlaylist() async {
    try {
      final mostPlayedEntries = _playCountService.getMostPlayedTracks(limit: 50);
      final allSongs = await _audioQuery.querySongs();
      
      final mostPlayedSongs = <SongModel>[];
      for (final entry in mostPlayedEntries) {
        final song = allSongs.firstWhere(
          (s) => s.id.toString() == entry.key,
          orElse: () => throw StateError('Song not found'),
        );
        mostPlayedSongs.add(song);
      }

      const playlistId = 'most_played';
      final existingIndex = _playlists.indexWhere((p) => p.id == playlistId);

      if (existingIndex != -1) {
        _playlists[existingIndex] = _playlists[existingIndex].copyWith(songs: mostPlayedSongs);
      } else {
        _playlists.add(Playlist(
          id: playlistId,
          name: 'Most Played',
          songs: mostPlayedSongs,
        ));
      }

      await savePlaylists();
      _updateNotifier();
    } catch (e) {
      LoggingService.error('Failed to update Most Played playlist', 'PlaylistService', e);
    }
  }

  /// Updates the "Recently Added" playlist
  Future<void> _updateRecentlyAddedPlaylist() async {
    try {
      final recentSongs = await _audioQuery.querySongs(
        sortType: SongSortType.DATE_ADDED,
        orderType: OrderType.DESC_OR_GREATER,
      );

      const playlistId = 'recently_added';
      final existingIndex = _playlists.indexWhere((p) => p.id == playlistId);
      final limitedSongs = recentSongs.take(50).toList();

      if (existingIndex != -1) {
        _playlists[existingIndex] = _playlists[existingIndex].copyWith(songs: limitedSongs);
      } else {
        _playlists.add(Playlist(
          id: playlistId,
          name: 'Recently Added',
          songs: limitedSongs,
        ));
      }

      await savePlaylists();
      _updateNotifier();
    } catch (e) {
      LoggingService.error('Failed to update Recently Added playlist', 'PlaylistService', e);
    }
  }

  /// Enables or disables auto-generated playlists
  Future<void> setAutoPlaylists(bool enabled) async {
    try {
      _autoPlaylists = enabled;
      
      if (!enabled) {
        // Remove auto-generated playlists
        _playlists.removeWhere((playlist) => 
          playlist.id == 'most_played' || playlist.id == 'recently_added');
        await savePlaylists();
        _updateNotifier();
      } else {
        await updateAutoPlaylists();
      }
      
      LoggingService.info('Auto playlists ${enabled ? 'enabled' : 'disabled'}', 'PlaylistService');
    } catch (e) {
      LoggingService.error('Failed to set auto playlists: $enabled', 'PlaylistService', e);
    }
  }

  /// Updates the ValueNotifier to trigger UI updates
  void _updateNotifier() {
    playlistsNotifier.value = List.from(_playlists);
    notifyListeners();
  }

  /// Clears all playlists (except system playlists)
  Future<void> clearPlaylists() async {
    try {
      _playlists.removeWhere((playlist) => 
        playlist.id != 'liked_songs' && 
        playlist.id != 'most_played' && 
        playlist.id != 'recently_added');
      
      await savePlaylists();
      _updateNotifier();
      
      LoggingService.info('Cleared user playlists', 'PlaylistService');
    } catch (e) {
      LoggingService.error('Failed to clear playlists', 'PlaylistService', e);
    }
  }

  @override
  void dispose() {
    playlistsNotifier.dispose();
    super.dispose();
  }
}