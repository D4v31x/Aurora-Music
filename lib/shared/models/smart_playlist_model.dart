/// Rule-based "smart" / auto playlist model.
///
/// A [SmartPlaylist] is not a fixed list of songs — it stores a set of
/// [SmartPlaylistRule]s that are evaluated live against the current library
/// (see `SmartPlaylistService.evaluate`) every time it's opened, so it always
/// reflects newly-added music, updated play counts, and liked-song changes.
library;

import 'dart:io';
import 'package:on_audio_query/on_audio_query.dart';

/// The song attribute a [SmartPlaylistRule] matches against.
enum SmartPlaylistField {
  title,
  artist,
  album,
  genre,
  folder,
  liked,
  playCount,
  durationSeconds,
  dateAddedDaysAgo,
}

/// Whether a field expects free text, a number, or is a simple boolean flag.
enum SmartPlaylistFieldKind { text, number, boolean }

extension SmartPlaylistFieldX on SmartPlaylistField {
  SmartPlaylistFieldKind get kind {
    switch (this) {
      case SmartPlaylistField.title:
      case SmartPlaylistField.artist:
      case SmartPlaylistField.album:
      case SmartPlaylistField.genre:
      case SmartPlaylistField.folder:
        return SmartPlaylistFieldKind.text;
      case SmartPlaylistField.playCount:
      case SmartPlaylistField.durationSeconds:
      case SmartPlaylistField.dateAddedDaysAgo:
        return SmartPlaylistFieldKind.number;
      case SmartPlaylistField.liked:
        return SmartPlaylistFieldKind.boolean;
    }
  }
}

/// The comparison applied between a song's value for [SmartPlaylistRule.field]
/// and [SmartPlaylistRule.value]. Which operators are valid depends on the
/// field's [SmartPlaylistFieldKind] (see [SmartPlaylistFieldX.kind]).
enum SmartPlaylistOperator {
  contains,
  notContains,
  equals,
  notEquals,
  greaterThan,
  lessThan,
  isTrue,
  isFalse,
}

/// How multiple rules within one [SmartPlaylist] are combined.
enum SmartPlaylistMatchMode { all, any }

/// How the evaluated result set is ordered before [SmartPlaylist.limit] is
/// applied.
enum SmartPlaylistSortBy {
  titleAZ,
  artistAZ,
  dateAddedNewest,
  playCountHighest,
  durationLongest,
  random,
}

class SmartPlaylistRule {
  final SmartPlaylistField field;
  final SmartPlaylistOperator operator;

  /// Raw comparison value, always stored as a string for simple JSON
  /// round-tripping. Parsed to num/bool as needed during evaluation based on
  /// [SmartPlaylistField.kind].
  final String value;

  const SmartPlaylistRule({
    required this.field,
    required this.operator,
    required this.value,
  });

  SmartPlaylistRule copyWith({
    SmartPlaylistField? field,
    SmartPlaylistOperator? operator,
    String? value,
  }) {
    return SmartPlaylistRule(
      field: field ?? this.field,
      operator: operator ?? this.operator,
      value: value ?? this.value,
    );
  }

  Map<String, dynamic> toJson() => {
        'field': field.name,
        'operator': operator.name,
        'value': value,
      };

  factory SmartPlaylistRule.fromJson(Map<String, dynamic> json) {
    return SmartPlaylistRule(
      field: SmartPlaylistField.values.firstWhere(
        (f) => f.name == json['field'],
        orElse: () => SmartPlaylistField.title,
      ),
      operator: SmartPlaylistOperator.values.firstWhere(
        (o) => o.name == json['operator'],
        orElse: () => SmartPlaylistOperator.contains,
      ),
      value: json['value']?.toString() ?? '',
    );
  }

  /// Evaluates this single rule against [song].
  bool matches(
    SongModel song, {
    required bool Function(SongModel) isLiked,
    required int Function(SongModel) playCountOf,
  }) {
    switch (field.kind) {
      case SmartPlaylistFieldKind.text:
        final songValue = _textValueFor(song).toLowerCase();
        final ruleValue = value.toLowerCase();
        switch (operator) {
          case SmartPlaylistOperator.contains:
            return songValue.contains(ruleValue);
          case SmartPlaylistOperator.notContains:
            return !songValue.contains(ruleValue);
          case SmartPlaylistOperator.equals:
            return songValue == ruleValue;
          case SmartPlaylistOperator.notEquals:
            return songValue != ruleValue;
          default:
            return false;
        }
      case SmartPlaylistFieldKind.number:
        final songValue = _numberValueFor(song, playCountOf: playCountOf);
        final ruleValue = double.tryParse(value) ?? 0;
        switch (operator) {
          case SmartPlaylistOperator.equals:
            return songValue == ruleValue;
          case SmartPlaylistOperator.notEquals:
            return songValue != ruleValue;
          case SmartPlaylistOperator.greaterThan:
            return songValue > ruleValue;
          case SmartPlaylistOperator.lessThan:
            return songValue < ruleValue;
          default:
            return false;
        }
      case SmartPlaylistFieldKind.boolean:
        final songValue = isLiked(song);
        switch (operator) {
          case SmartPlaylistOperator.isTrue:
            return songValue;
          case SmartPlaylistOperator.isFalse:
            return !songValue;
          default:
            return false;
        }
    }
  }

  String _textValueFor(SongModel song) {
    switch (field) {
      case SmartPlaylistField.title:
        return song.title;
      case SmartPlaylistField.artist:
        return song.artist ?? '';
      case SmartPlaylistField.album:
        return song.album ?? '';
      case SmartPlaylistField.genre:
        return song.genre ?? '';
      case SmartPlaylistField.folder:
        return File(song.data).parent.path;
      default:
        return '';
    }
  }

  double _numberValueFor(
    SongModel song, {
    required int Function(SongModel) playCountOf,
  }) {
    switch (field) {
      case SmartPlaylistField.playCount:
        return playCountOf(song).toDouble();
      case SmartPlaylistField.durationSeconds:
        return ((song.duration ?? 0) / 1000.0);
      case SmartPlaylistField.dateAddedDaysAgo:
        final addedMs = song.dateAdded;
        if (addedMs == null) return double.infinity;
        // on_audio_query stores dateAdded as epoch seconds on Android.
        final addedDate =
            DateTime.fromMillisecondsSinceEpoch(addedMs * 1000);
        return DateTime.now().difference(addedDate).inHours / 24.0;
      default:
        return 0;
    }
  }
}

class SmartPlaylist {
  final String id;
  final String name;
  final List<SmartPlaylistRule> rules;
  final SmartPlaylistMatchMode matchMode;
  final SmartPlaylistSortBy sortBy;

  /// Maximum number of songs to include, or null for unlimited.
  final int? limit;
  final DateTime createdAt;

  const SmartPlaylist({
    required this.id,
    required this.name,
    required this.rules,
    this.matchMode = SmartPlaylistMatchMode.all,
    this.sortBy = SmartPlaylistSortBy.titleAZ,
    this.limit,
    required this.createdAt,
  });

  SmartPlaylist copyWith({
    String? name,
    List<SmartPlaylistRule>? rules,
    SmartPlaylistMatchMode? matchMode,
    SmartPlaylistSortBy? sortBy,
    int? limit,
    bool clearLimit = false,
  }) {
    return SmartPlaylist(
      id: id,
      name: name ?? this.name,
      rules: rules ?? this.rules,
      matchMode: matchMode ?? this.matchMode,
      sortBy: sortBy ?? this.sortBy,
      limit: clearLimit ? null : (limit ?? this.limit),
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'rules': rules.map((r) => r.toJson()).toList(),
        'matchMode': matchMode.name,
        'sortBy': sortBy.name,
        'limit': limit,
        'createdAt': createdAt.toIso8601String(),
      };

  factory SmartPlaylist.fromJson(Map<String, dynamic> json) {
    return SmartPlaylist(
      id: json['id'],
      name: json['name'],
      rules: (json['rules'] as List? ?? [])
          .map((r) => SmartPlaylistRule.fromJson(r as Map<String, dynamic>))
          .toList(),
      matchMode: SmartPlaylistMatchMode.values.firstWhere(
        (m) => m.name == json['matchMode'],
        orElse: () => SmartPlaylistMatchMode.all,
      ),
      sortBy: SmartPlaylistSortBy.values.firstWhere(
        (s) => s.name == json['sortBy'],
        orElse: () => SmartPlaylistSortBy.titleAZ,
      ),
      limit: json['limit'] as int?,
      createdAt:
          DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
    );
  }
}
