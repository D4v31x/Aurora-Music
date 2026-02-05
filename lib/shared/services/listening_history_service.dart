/// Listening history service for tracking playback timeline.
///
/// Records when tracks are played and provides access to
/// historical playback data for rewind features.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:path_provider/path_provider.dart';

/// A single entry in the listening history
class HistoryEntry {
  /// Unique ID of the song
  final int songId;

  /// When the song was played
  final DateTime timestamp;

  /// Position in the track when playback ended (for resume)
  final Duration? lastPosition;

  /// Duration of the track
  final int? durationMs;

  /// Track title (cached for display when song unavailable)
  final String title;

  /// Track artist (cached for display)
  final String? artist;

  /// Album name (cached for display)
  final String? album;

  /// Album ID for artwork
  final int? albumId;

  const HistoryEntry({
    required this.songId,
    required this.timestamp,
    this.lastPosition,
    this.durationMs,
    required this.title,
    this.artist,
    this.album,
    this.albumId,
  });

  Map<String, dynamic> toJson() => {
        'songId': songId,
        'timestamp': timestamp.toIso8601String(),
        'lastPositionMs': lastPosition?.inMilliseconds,
        'durationMs': durationMs,
        'title': title,
        'artist': artist,
        'album': album,
        'albumId': albumId,
      };

  factory HistoryEntry.fromJson(Map<String, dynamic> json) {
    return HistoryEntry(
      songId: json['songId'],
      timestamp: DateTime.parse(json['timestamp']),
      lastPosition: json['lastPositionMs'] != null
          ? Duration(milliseconds: json['lastPositionMs'])
          : null,
      durationMs: json['durationMs'],
      title: json['title'] ?? 'Unknown',
      artist: json['artist'],
      album: json['album'],
      albumId: json['albumId'],
    );
  }

  factory HistoryEntry.fromSong(
    SongModel song, {
    DateTime? timestamp,
    Duration? lastPosition,
  }) {
    return HistoryEntry(
      songId: song.id,
      timestamp: timestamp ?? DateTime.now(),
      lastPosition: lastPosition,
      durationMs: song.duration,
      title: song.title,
      artist: song.artist,
      album: song.album,
      albumId: song.albumId,
    );
  }
}

/// Session information for resume functionality
class SessionInfo {
  /// List of song IDs in the queue
  final List<int> queueSongIds;

  /// Current index in the queue
  final int currentIndex;

  /// Position in the current track
  final Duration position;

  /// When the session was saved
  final DateTime timestamp;

  /// Shuffle state
  final bool shuffle;

  /// Loop mode (0=off, 1=one, 2=all)
  final int loopMode;

  const SessionInfo({
    required this.queueSongIds,
    required this.currentIndex,
    required this.position,
    required this.timestamp,
    this.shuffle = false,
    this.loopMode = 0,
  });

  Map<String, dynamic> toJson() => {
        'queueSongIds': queueSongIds,
        'currentIndex': currentIndex,
        'positionMs': position.inMilliseconds,
        'timestamp': timestamp.toIso8601String(),
        'shuffle': shuffle,
        'loopMode': loopMode,
      };

  factory SessionInfo.fromJson(Map<String, dynamic> json) {
    return SessionInfo(
      queueSongIds: List<int>.from(json['queueSongIds'] ?? []),
      currentIndex: json['currentIndex'] ?? 0,
      position: Duration(milliseconds: json['positionMs'] ?? 0),
      timestamp: DateTime.parse(
          json['timestamp'] ?? DateTime.now().toIso8601String()),
      shuffle: json['shuffle'] ?? false,
      loopMode: json['loopMode'] ?? 0,
    );
  }
}

/// Time period for filtering history
enum HistoryPeriod {
  today,
  yesterday,
  thisWeek,
  thisMonth,
  all,
}

/// Service for tracking and managing listening history
class ListeningHistoryService extends ChangeNotifier {
  static const int _maxHistorySize = 1000;
  static const Duration _saveDebounce = Duration(seconds: 5);

  final List<HistoryEntry> _history = [];
  SessionInfo? _lastSession;
  Timer? _saveTimer;
  bool _initialized = false;
  bool _dirty = false;

  List<HistoryEntry> get history => List.unmodifiable(_history);
  SessionInfo? get lastSession => _lastSession;
  bool get hasHistory => _history.isNotEmpty;
  bool get hasLastSession => _lastSession != null;

  /// Initialize the service and load saved history
  Future<void> initialize() async {
    if (_initialized) return;
    await _loadHistory();
    _initialized = true;
  }

  /// Record a played track
  Future<void> recordPlay(SongModel song, {Duration? position}) async {
    final entry = HistoryEntry.fromSong(
      song,
      lastPosition: position,
    );

    // Add to history
    _history.insert(0, entry);

    // Trim history if too large
    if (_history.length > _maxHistorySize) {
      _history.removeRange(_maxHistorySize, _history.length);
    }

    _scheduleSave();
    notifyListeners();
  }

  /// Update the position of the most recent play
  void updateLastPosition(Duration position) {
    if (_history.isEmpty) return;

    final last = _history.first;
    _history[0] = HistoryEntry(
      songId: last.songId,
      timestamp: last.timestamp,
      lastPosition: position,
      durationMs: last.durationMs,
      title: last.title,
      artist: last.artist,
      album: last.album,
      albumId: last.albumId,
    );

    _scheduleSave();
  }

  /// Save current session for resume later
  Future<void> saveSession({
    required List<SongModel> queue,
    required int currentIndex,
    required Duration position,
    bool shuffle = false,
    int loopMode = 0,
  }) async {
    _lastSession = SessionInfo(
      queueSongIds: queue.map((s) => s.id).toList(),
      currentIndex: currentIndex,
      position: position,
      timestamp: DateTime.now(),
      shuffle: shuffle,
      loopMode: loopMode,
    );

    _scheduleSave();
    notifyListeners();
  }

  /// Clear the saved session
  Future<void> clearSession() async {
    _lastSession = null;
    _scheduleSave();
    notifyListeners();
  }

  /// Get history for a specific time period
  List<HistoryEntry> getHistoryForPeriod(HistoryPeriod period) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (period) {
      case HistoryPeriod.today:
        return _history.where((e) => e.timestamp.isAfter(today)).toList();

      case HistoryPeriod.yesterday:
        final yesterday = today.subtract(const Duration(days: 1));
        return _history
            .where((e) =>
                e.timestamp.isAfter(yesterday) && e.timestamp.isBefore(today))
            .toList();

      case HistoryPeriod.thisWeek:
        final weekStart =
            today.subtract(Duration(days: today.weekday - 1));
        return _history.where((e) => e.timestamp.isAfter(weekStart)).toList();

      case HistoryPeriod.thisMonth:
        final monthStart = DateTime(now.year, now.month, 1);
        return _history.where((e) => e.timestamp.isAfter(monthStart)).toList();

      case HistoryPeriod.all:
        return List.from(_history);
    }
  }

  /// Get most recently played track
  HistoryEntry? get lastPlayed => _history.isNotEmpty ? _history.first : null;

  /// Get unique songs played today
  List<HistoryEntry> getTodaysUniquePlays() {
    final todayHistory = getHistoryForPeriod(HistoryPeriod.today);
    final seen = <int>{};
    return todayHistory.where((e) => seen.add(e.songId)).toList();
  }

  /// Get play count for a specific day
  int getPlayCountForDate(DateTime date) {
    final dayStart = DateTime(date.year, date.month, date.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    return _history
        .where((e) => e.timestamp.isAfter(dayStart) && e.timestamp.isBefore(dayEnd))
        .length;
  }

  /// Get total listening time for a period
  Duration getTotalListeningTime(HistoryPeriod period) {
    final periodHistory = getHistoryForPeriod(period);
    int totalMs = 0;
    for (final entry in periodHistory) {
      if (entry.durationMs != null) {
        totalMs += entry.durationMs!;
      }
    }
    return Duration(milliseconds: totalMs);
  }

  /// Clear all history
  Future<void> clearHistory() async {
    _history.clear();
    await _saveHistory();
    notifyListeners();
  }

  /// Export history as JSON
  Map<String, dynamic> exportHistory() {
    return {
      'history': _history.map((e) => e.toJson()).toList(),
      'lastSession': _lastSession?.toJson(),
      'exportDate': DateTime.now().toIso8601String(),
    };
  }

  /// Import history from JSON
  Future<void> importHistory(Map<String, dynamic> json) async {
    final historyJson = json['history'] as List?;
    if (historyJson != null) {
      _history.clear();
      for (final entryJson in historyJson) {
        _history.add(HistoryEntry.fromJson(entryJson));
      }
    }

    final sessionJson = json['lastSession'] as Map<String, dynamic>?;
    if (sessionJson != null) {
      _lastSession = SessionInfo.fromJson(sessionJson);
    }

    await _saveHistory();
    notifyListeners();
  }

  void _scheduleSave() {
    _dirty = true;
    _saveTimer?.cancel();
    _saveTimer = Timer(_saveDebounce, () {
      if (_dirty) {
        _saveHistory();
        _dirty = false;
      }
    });
  }

  Future<void> _loadHistory() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/listening_history.json');

      if (await file.exists()) {
        final contents = await file.readAsString();
        final json = jsonDecode(contents) as Map<String, dynamic>;

        final historyJson = json['history'] as List?;
        if (historyJson != null) {
          for (final entryJson in historyJson) {
            _history.add(HistoryEntry.fromJson(entryJson));
          }
        }

        final sessionJson = json['lastSession'] as Map<String, dynamic>?;
        if (sessionJson != null) {
          _lastSession = SessionInfo.fromJson(sessionJson);
        }
      }
    } catch (e) {
      debugPrint('Error loading listening history: $e');
    }
  }

  Future<void> _saveHistory() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/listening_history.json');

      final json = {
        'history': _history.map((e) => e.toJson()).toList(),
        'lastSession': _lastSession?.toJson(),
      };

      await file.writeAsString(jsonEncode(json));
    } catch (e) {
      debugPrint('Error saving listening history: $e');
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    if (_dirty) {
      _saveHistory();
    }
    super.dispose();
  }
}
