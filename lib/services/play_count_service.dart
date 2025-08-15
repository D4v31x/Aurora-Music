import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/logging_service.dart';
import '../utils/file_utils.dart';

/// Service responsible for tracking play counts and statistics
/// Handles analytics data for songs, albums, artists, playlists, and folders
class PlayCountService {
  static final PlayCountService _instance = PlayCountService._internal();
  factory PlayCountService() => _instance;
  PlayCountService._internal();

  // Play count tracking maps
  final Map<String, int> _trackPlayCounts = {};
  final Map<String, int> _albumPlayCounts = {};
  final Map<String, int> _artistPlayCounts = {};
  final Map<String, int> _playlistPlayCounts = {};
  final Map<String, int> _folderAccessCounts = {};

  // Getters for read-only access
  Map<String, int> get trackPlayCounts => Map.unmodifiable(_trackPlayCounts);
  Map<String, int> get albumPlayCounts => Map.unmodifiable(_albumPlayCounts);
  Map<String, int> get artistPlayCounts => Map.unmodifiable(_artistPlayCounts);
  Map<String, int> get playlistPlayCounts => Map.unmodifiable(_playlistPlayCounts);
  Map<String, int> get folderAccessCounts => Map.unmodifiable(_folderAccessCounts);

  /// Loads play count data from storage
  Future<void> loadPlayCounts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final trackData = prefs.getString('track_play_counts');
      if (trackData != null) {
        final Map<String, dynamic> decoded = jsonDecode(trackData);
        _trackPlayCounts.clear();
        decoded.forEach((key, value) => _trackPlayCounts[key] = value as int);
      }

      final albumData = prefs.getString('album_play_counts');
      if (albumData != null) {
        final Map<String, dynamic> decoded = jsonDecode(albumData);
        _albumPlayCounts.clear();
        decoded.forEach((key, value) => _albumPlayCounts[key] = value as int);
      }

      final artistData = prefs.getString('artist_play_counts');
      if (artistData != null) {
        final Map<String, dynamic> decoded = jsonDecode(artistData);
        _artistPlayCounts.clear();
        decoded.forEach((key, value) => _artistPlayCounts[key] = value as int);
      }

      final playlistData = prefs.getString('playlist_play_counts');
      if (playlistData != null) {
        final Map<String, dynamic> decoded = jsonDecode(playlistData);
        _playlistPlayCounts.clear();
        decoded.forEach((key, value) => _playlistPlayCounts[key] = value as int);
      }

      final folderData = prefs.getString('folder_access_counts');
      if (folderData != null) {
        final Map<String, dynamic> decoded = jsonDecode(folderData);
        _folderAccessCounts.clear();
        decoded.forEach((key, value) => _folderAccessCounts[key] = value as int);
      }

      LoggingService.debug('Play counts loaded successfully', 'PlayCountService');
    } catch (e) {
      LoggingService.error('Failed to load play counts', 'PlayCountService', e);
    }
  }

  /// Saves play count data to storage
  Future<void> savePlayCounts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      await prefs.setString('track_play_counts', jsonEncode(_trackPlayCounts));
      await prefs.setString('album_play_counts', jsonEncode(_albumPlayCounts));
      await prefs.setString('artist_play_counts', jsonEncode(_artistPlayCounts));
      await prefs.setString('playlist_play_counts', jsonEncode(_playlistPlayCounts));
      await prefs.setString('folder_access_counts', jsonEncode(_folderAccessCounts));

      LoggingService.debug('Play counts saved successfully', 'PlayCountService');
    } catch (e) {
      LoggingService.error('Failed to save play counts', 'PlayCountService', e);
    }
  }

  /// Increments play count for a track
  void incrementTrackPlayCount(String trackId) {
    _trackPlayCounts[trackId] = (_trackPlayCounts[trackId] ?? 0) + 1;
    LoggingService.debug('Track play count incremented: $trackId', 'PlayCountService');
  }

  /// Increments play count for an album
  void incrementAlbumPlayCount(String albumId) {
    _albumPlayCounts[albumId] = (_albumPlayCounts[albumId] ?? 0) + 1;
    LoggingService.debug('Album play count incremented: $albumId', 'PlayCountService');
  }

  /// Increments play count for an artist
  void incrementArtistPlayCount(String artistName) {
    _artistPlayCounts[artistName] = (_artistPlayCounts[artistName] ?? 0) + 1;
    LoggingService.debug('Artist play count incremented: $artistName', 'PlayCountService');
  }

  /// Increments play count for a playlist
  void incrementPlaylistPlayCount(String playlistId) {
    _playlistPlayCounts[playlistId] = (_playlistPlayCounts[playlistId] ?? 0) + 1;
    LoggingService.debug('Playlist play count incremented: $playlistId', 'PlayCountService');
  }

  /// Increments access count for a folder
  void incrementFolderAccessCount(String folderPath) {
    _folderAccessCounts[folderPath] = (_folderAccessCounts[folderPath] ?? 0) + 1;
    LoggingService.debug('Folder access count incremented: $folderPath', 'PlayCountService');
  }

  /// Gets play count for a specific track
  int getTrackPlayCount(String trackId) {
    return _trackPlayCounts[trackId] ?? 0;
  }

  /// Gets play count for a specific album
  int getAlbumPlayCount(String albumId) {
    return _albumPlayCounts[albumId] ?? 0;
  }

  /// Gets play count for a specific artist
  int getArtistPlayCount(String artistName) {
    return _artistPlayCounts[artistName] ?? 0;
  }

  /// Gets the most played tracks sorted by play count
  List<MapEntry<String, int>> getMostPlayedTracks({int limit = 50}) {
    final entries = _trackPlayCounts.entries.toList();
    entries.sort((a, b) => b.value.compareTo(a.value));
    return entries.take(limit).toList();
  }

  /// Gets the most played albums sorted by play count
  List<MapEntry<String, int>> getMostPlayedAlbums({int limit = 20}) {
    final entries = _albumPlayCounts.entries.toList();
    entries.sort((a, b) => b.value.compareTo(a.value));
    return entries.take(limit).toList();
  }

  /// Gets the most played artists sorted by play count
  List<MapEntry<String, int>> getMostPlayedArtists({int limit = 20}) {
    final entries = _artistPlayCounts.entries.toList();
    entries.sort((a, b) => b.value.compareTo(a.value));
    return entries.take(limit).toList();
  }

  /// Clears all play count data
  Future<void> clearAllPlayCounts() async {
    try {
      _trackPlayCounts.clear();
      _albumPlayCounts.clear();
      _artistPlayCounts.clear();
      _playlistPlayCounts.clear();
      _folderAccessCounts.clear();
      
      await savePlayCounts();
      LoggingService.info('All play counts cleared', 'PlayCountService');
    } catch (e) {
      LoggingService.error('Failed to clear play counts', 'PlayCountService', e);
    }
  }

  /// Exports play count data for backup
  Future<String> exportPlayCountData() async {
    try {
      final data = {
        'tracks': _trackPlayCounts,
        'albums': _albumPlayCounts,
        'artists': _artistPlayCounts,
        'playlists': _playlistPlayCounts,
        'folders': _folderAccessCounts,
        'exported_at': DateTime.now().toIso8601String(),
      };
      
      return jsonEncode(data);
    } catch (e) {
      LoggingService.error('Failed to export play count data', 'PlayCountService', e);
      rethrow;
    }
  }

  /// Imports play count data from backup
  Future<void> importPlayCountData(String jsonData) async {
    try {
      final Map<String, dynamic> data = jsonDecode(jsonData);
      
      if (data['tracks'] != null) {
        _trackPlayCounts.clear();
        (data['tracks'] as Map<String, dynamic>).forEach((key, value) {
          _trackPlayCounts[key] = value as int;
        });
      }
      
      if (data['albums'] != null) {
        _albumPlayCounts.clear();
        (data['albums'] as Map<String, dynamic>).forEach((key, value) {
          _albumPlayCounts[key] = value as int;
        });
      }
      
      if (data['artists'] != null) {
        _artistPlayCounts.clear();
        (data['artists'] as Map<String, dynamic>).forEach((key, value) {
          _artistPlayCounts[key] = value as int;
        });
      }
      
      if (data['playlists'] != null) {
        _playlistPlayCounts.clear();
        (data['playlists'] as Map<String, dynamic>).forEach((key, value) {
          _playlistPlayCounts[key] = value as int;
        });
      }
      
      if (data['folders'] != null) {
        _folderAccessCounts.clear();
        (data['folders'] as Map<String, dynamic>).forEach((key, value) {
          _folderAccessCounts[key] = value as int;
        });
      }
      
      await savePlayCounts();
      LoggingService.info('Play count data imported successfully', 'PlayCountService');
    } catch (e) {
      LoggingService.error('Failed to import play count data', 'PlayCountService', e);
      rethrow;
    }
  }
}