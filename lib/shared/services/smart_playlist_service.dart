/// Smart playlist model and service.
///
/// Provides user-defined smart playlists with rules
/// for automatic track filtering.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:path_provider/path_provider.dart';

/// Types of rules that can be applied to smart playlists
enum SmartPlaylistRuleType {
  playCount,
  lastPlayed,
  genre,
  artist,
  album,
  year,
  duration,
  dateAdded,
  title,
}

/// Comparison operators for rules
enum RuleOperator {
  equals,
  notEquals,
  greaterThan,
  lessThan,
  greaterOrEqual,
  lessOrEqual,
  contains,
  notContains,
  startsWith,
  endsWith,
}

/// A single rule in a smart playlist
class SmartPlaylistRule {
  final SmartPlaylistRuleType type;
  final RuleOperator operator;
  final dynamic value;

  const SmartPlaylistRule({
    required this.type,
    required this.operator,
    required this.value,
  });

  Map<String, dynamic> toJson() => {
        'type': type.index,
        'operator': operator.index,
        'value': value,
      };

  factory SmartPlaylistRule.fromJson(Map<String, dynamic> json) {
    return SmartPlaylistRule(
      type: SmartPlaylistRuleType.values[json['type']],
      operator: RuleOperator.values[json['operator']],
      value: json['value'],
    );
  }

  /// Get a human-readable description of this rule
  String getDescription() {
    String typeStr;
    switch (type) {
      case SmartPlaylistRuleType.playCount:
        typeStr = 'Play count';
        break;
      case SmartPlaylistRuleType.lastPlayed:
        typeStr = 'Last played';
        break;
      case SmartPlaylistRuleType.genre:
        typeStr = 'Genre';
        break;
      case SmartPlaylistRuleType.artist:
        typeStr = 'Artist';
        break;
      case SmartPlaylistRuleType.album:
        typeStr = 'Album';
        break;
      case SmartPlaylistRuleType.year:
        typeStr = 'Year';
        break;
      case SmartPlaylistRuleType.duration:
        typeStr = 'Duration';
        break;
      case SmartPlaylistRuleType.dateAdded:
        typeStr = 'Date added';
        break;
      case SmartPlaylistRuleType.title:
        typeStr = 'Title';
        break;
    }

    String opStr;
    switch (operator) {
      case RuleOperator.equals:
        opStr = 'is';
        break;
      case RuleOperator.notEquals:
        opStr = 'is not';
        break;
      case RuleOperator.greaterThan:
        opStr = '>';
        break;
      case RuleOperator.lessThan:
        opStr = '<';
        break;
      case RuleOperator.greaterOrEqual:
        opStr = '≥';
        break;
      case RuleOperator.lessOrEqual:
        opStr = '≤';
        break;
      case RuleOperator.contains:
        opStr = 'contains';
        break;
      case RuleOperator.notContains:
        opStr = 'does not contain';
        break;
      case RuleOperator.startsWith:
        opStr = 'starts with';
        break;
      case RuleOperator.endsWith:
        opStr = 'ends with';
        break;
    }

    String valueStr = value.toString();
    if (type == SmartPlaylistRuleType.lastPlayed ||
        type == SmartPlaylistRuleType.dateAdded) {
      // Format as "X days ago"
      if (value is int) {
        valueStr = '$value days';
      }
    } else if (type == SmartPlaylistRuleType.duration) {
      // Format as minutes
      if (value is int) {
        final mins = value ~/ 60;
        final secs = value % 60;
        valueStr = '${mins}m ${secs}s';
      }
    }

    return '$typeStr $opStr $valueStr';
  }
}

/// How multiple rules should be combined
enum RuleMatch {
  all, // AND - all rules must match
  any, // OR - any rule can match
}

/// A smart playlist definition
class SmartPlaylist {
  final String id;
  final String name;
  final List<SmartPlaylistRule> rules;
  final RuleMatch matchType;
  final int? limit; // Optional limit on number of tracks
  final bool sortByPlayCount;
  final bool sortDescending;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SmartPlaylist({
    required this.id,
    required this.name,
    required this.rules,
    this.matchType = RuleMatch.all,
    this.limit,
    this.sortByPlayCount = false,
    this.sortDescending = true,
    required this.createdAt,
    required this.updatedAt,
  });

  SmartPlaylist copyWith({
    String? name,
    List<SmartPlaylistRule>? rules,
    RuleMatch? matchType,
    int? limit,
    bool clearLimit = false,
    bool? sortByPlayCount,
    bool? sortDescending,
  }) {
    return SmartPlaylist(
      id: id,
      name: name ?? this.name,
      rules: rules ?? this.rules,
      matchType: matchType ?? this.matchType,
      limit: clearLimit ? null : (limit ?? this.limit),
      sortByPlayCount: sortByPlayCount ?? this.sortByPlayCount,
      sortDescending: sortDescending ?? this.sortDescending,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'rules': rules.map((r) => r.toJson()).toList(),
        'matchType': matchType.index,
        'limit': limit,
        'sortByPlayCount': sortByPlayCount,
        'sortDescending': sortDescending,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory SmartPlaylist.fromJson(Map<String, dynamic> json) {
    return SmartPlaylist(
      id: json['id'],
      name: json['name'],
      rules: (json['rules'] as List)
          .map((r) => SmartPlaylistRule.fromJson(r))
          .toList(),
      matchType: RuleMatch.values[json['matchType'] ?? 0],
      limit: json['limit'],
      sortByPlayCount: json['sortByPlayCount'] ?? false,
      sortDescending: json['sortDescending'] ?? true,
      createdAt: DateTime.parse(
          json['createdAt'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(
          json['updatedAt'] ?? DateTime.now().toIso8601String()),
    );
  }
}

/// Service for managing smart playlists
class SmartPlaylistService extends ChangeNotifier {
  final List<SmartPlaylist> _playlists = [];
  final Map<String, int> _playCounts = {};
  final Map<String, DateTime> _lastPlayed = {};
  bool _initialized = false;

  List<SmartPlaylist> get playlists => List.unmodifiable(_playlists);

  /// Initialize the service
  Future<void> initialize() async {
    if (_initialized) return;
    await _loadPlaylists();
    _initialized = true;
  }

  /// Set play count data (should be called from AudioPlayerService)
  void setPlayCountData(Map<String, int> counts) {
    _playCounts.clear();
    _playCounts.addAll(counts);
  }

  /// Set last played data (should be called from ListeningHistoryService)
  void setLastPlayedData(Map<String, DateTime> lastPlayed) {
    _lastPlayed.clear();
    _lastPlayed.addAll(lastPlayed);
  }

  /// Create a new smart playlist
  Future<SmartPlaylist> createPlaylist({
    required String name,
    required List<SmartPlaylistRule> rules,
    RuleMatch matchType = RuleMatch.all,
    int? limit,
    bool sortByPlayCount = false,
    bool sortDescending = true,
  }) async {
    final playlist = SmartPlaylist(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      rules: rules,
      matchType: matchType,
      limit: limit,
      sortByPlayCount: sortByPlayCount,
      sortDescending: sortDescending,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    _playlists.add(playlist);
    await _savePlaylists();
    notifyListeners();
    return playlist;
  }

  /// Update an existing smart playlist
  Future<void> updatePlaylist(SmartPlaylist playlist) async {
    final index = _playlists.indexWhere((p) => p.id == playlist.id);
    if (index != -1) {
      _playlists[index] = playlist;
      await _savePlaylists();
      notifyListeners();
    }
  }

  /// Delete a smart playlist
  Future<void> deletePlaylist(String id) async {
    _playlists.removeWhere((p) => p.id == id);
    await _savePlaylists();
    notifyListeners();
  }

  /// Get a specific playlist by ID
  SmartPlaylist? getPlaylist(String id) {
    try {
      return _playlists.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Evaluate a smart playlist against a list of songs
  List<SongModel> evaluatePlaylist(
    SmartPlaylist playlist,
    List<SongModel> allSongs,
  ) {
    List<SongModel> result = [];

    for (final song in allSongs) {
      final matches = _evaluateSong(song, playlist);
      if (matches) {
        result.add(song);
      }
    }

    // Sort if needed
    if (playlist.sortByPlayCount) {
      result.sort((a, b) {
        final countA = _playCounts[a.id.toString()] ?? 0;
        final countB = _playCounts[b.id.toString()] ?? 0;
        return playlist.sortDescending
            ? countB.compareTo(countA)
            : countA.compareTo(countB);
      });
    }

    // Apply limit if set
    if (playlist.limit != null && result.length > playlist.limit!) {
      result = result.take(playlist.limit!).toList();
    }

    return result;
  }

  bool _evaluateSong(SongModel song, SmartPlaylist playlist) {
    final results = <bool>[];

    for (final rule in playlist.rules) {
      results.add(_evaluateRule(song, rule));
    }

    if (results.isEmpty) return true;

    if (playlist.matchType == RuleMatch.all) {
      return results.every((r) => r);
    } else {
      return results.any((r) => r);
    }
  }

  bool _evaluateRule(SongModel song, SmartPlaylistRule rule) {
    switch (rule.type) {
      case SmartPlaylistRuleType.playCount:
        final count = _playCounts[song.id.toString()] ?? 0;
        return _compareNumber(count, rule.operator, rule.value as int);

      case SmartPlaylistRuleType.lastPlayed:
        final lastPlayed = _lastPlayed[song.id.toString()];
        if (lastPlayed == null) {
          // Never played - only matches "greater than X days" (meaning not played recently)
          return rule.operator == RuleOperator.greaterThan ||
              rule.operator == RuleOperator.greaterOrEqual;
        }
        final daysAgo = DateTime.now().difference(lastPlayed).inDays;
        return _compareNumber(daysAgo, rule.operator, rule.value as int);

      case SmartPlaylistRuleType.genre:
        final genre = song.genre ?? '';
        return _compareString(genre, rule.operator, rule.value as String);

      case SmartPlaylistRuleType.artist:
        final artist = song.artist ?? '';
        return _compareString(artist, rule.operator, rule.value as String);

      case SmartPlaylistRuleType.album:
        final album = song.album ?? '';
        return _compareString(album, rule.operator, rule.value as String);

      case SmartPlaylistRuleType.year:
        // Year might be in metadata but not directly available in SongModel
        // We'll skip this for now or use dateAdded as proxy
        return true;

      case SmartPlaylistRuleType.duration:
        final durationSecs = (song.duration ?? 0) ~/ 1000;
        return _compareNumber(durationSecs, rule.operator, rule.value as int);

      case SmartPlaylistRuleType.dateAdded:
        final dateAdded = song.dateAdded;
        if (dateAdded == null) return false;
        final songDate =
            DateTime.fromMillisecondsSinceEpoch(dateAdded * 1000);
        final daysAgo = DateTime.now().difference(songDate).inDays;
        return _compareNumber(daysAgo, rule.operator, rule.value as int);

      case SmartPlaylistRuleType.title:
        return _compareString(song.title, rule.operator, rule.value as String);
    }
  }

  bool _compareNumber(int value, RuleOperator op, int target) {
    switch (op) {
      case RuleOperator.equals:
        return value == target;
      case RuleOperator.notEquals:
        return value != target;
      case RuleOperator.greaterThan:
        return value > target;
      case RuleOperator.lessThan:
        return value < target;
      case RuleOperator.greaterOrEqual:
        return value >= target;
      case RuleOperator.lessOrEqual:
        return value <= target;
      default:
        return false;
    }
  }

  bool _compareString(String value, RuleOperator op, String target) {
    final lowerValue = value.toLowerCase();
    final lowerTarget = target.toLowerCase();

    switch (op) {
      case RuleOperator.equals:
        return lowerValue == lowerTarget;
      case RuleOperator.notEquals:
        return lowerValue != lowerTarget;
      case RuleOperator.contains:
        return lowerValue.contains(lowerTarget);
      case RuleOperator.notContains:
        return !lowerValue.contains(lowerTarget);
      case RuleOperator.startsWith:
        return lowerValue.startsWith(lowerTarget);
      case RuleOperator.endsWith:
        return lowerValue.endsWith(lowerTarget);
      default:
        return false;
    }
  }

  /// Export playlists as JSON for backup
  Map<String, dynamic> exportPlaylists() {
    return {
      'playlists': _playlists.map((p) => p.toJson()).toList(),
      'exportDate': DateTime.now().toIso8601String(),
    };
  }

  /// Import playlists from backup JSON
  Future<void> importPlaylists(Map<String, dynamic> json) async {
    final playlistsJson = json['playlists'] as List?;
    if (playlistsJson != null) {
      for (final pJson in playlistsJson) {
        final imported = SmartPlaylist.fromJson(pJson);
        // Check if playlist with same ID exists
        final existingIndex = _playlists.indexWhere((p) => p.id == imported.id);
        if (existingIndex != -1) {
          _playlists[existingIndex] = imported;
        } else {
          _playlists.add(imported);
        }
      }
      await _savePlaylists();
      notifyListeners();
    }
  }

  Future<void> _loadPlaylists() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/smart_playlists.json');

      if (await file.exists()) {
        final contents = await file.readAsString();
        final json = jsonDecode(contents) as Map<String, dynamic>;

        final playlistsJson = json['playlists'] as List?;
        if (playlistsJson != null) {
          for (final pJson in playlistsJson) {
            _playlists.add(SmartPlaylist.fromJson(pJson));
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading smart playlists: $e');
    }
  }

  Future<void> _savePlaylists() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/smart_playlists.json');

      final json = {
        'playlists': _playlists.map((p) => p.toJson()).toList(),
      };

      await file.writeAsString(jsonEncode(json));
    } catch (e) {
      debugPrint('Error saving smart playlists: $e');
    }
  }
}
