/// Rule-based "smart" / auto playlist service.
///
/// Persists [SmartPlaylist] rule-sets (not song lists) to disk, and evaluates
/// them live against the current library on demand via [evaluate] /
/// [buildPlaylist]. Because evaluation always runs against the freshest
/// library snapshot + play counts + liked songs, a smart playlist's contents
/// automatically reflect newly added tracks and updated listening habits
/// without ever needing to be "refreshed" manually.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:path_provider/path_provider.dart';
import '../models/playlist_model.dart';
import '../models/smart_playlist_model.dart';

class SmartPlaylistService extends ChangeNotifier {
  static const String _fileName = 'smart_playlists.json';

  List<SmartPlaylist> _smartPlaylists = [];
  bool _loaded = false;

  List<SmartPlaylist> get smartPlaylists => List.unmodifiable(_smartPlaylists);
  bool get loaded => _loaded;

  Future<void> load() async {
    if (_loaded) return;
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$_fileName');
      if (await file.exists()) {
        final contents = await file.readAsString();
        final list = jsonDecode(contents) as List;
        _smartPlaylists = list
            .map((e) => SmartPlaylist.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('Error loading smart playlists: $e');
    } finally {
      _loaded = true;
      notifyListeners();
    }
  }

  Future<void> _save() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$_fileName');
      final json = _smartPlaylists.map((p) => p.toJson()).toList();
      await file.writeAsString(jsonEncode(json));
    } catch (e) {
      debugPrint('Error saving smart playlists: $e');
    }
  }

  Future<SmartPlaylist> createSmartPlaylist({
    required String name,
    required List<SmartPlaylistRule> rules,
    SmartPlaylistMatchMode matchMode = SmartPlaylistMatchMode.all,
    SmartPlaylistSortBy sortBy = SmartPlaylistSortBy.titleAZ,
    int? limit,
  }) async {
    final playlist = SmartPlaylist(
      id: 'smart_${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      rules: rules,
      matchMode: matchMode,
      sortBy: sortBy,
      limit: limit,
      createdAt: DateTime.now(),
    );
    _smartPlaylists = [..._smartPlaylists, playlist];
    await _save();
    notifyListeners();
    return playlist;
  }

  Future<void> updateSmartPlaylist(SmartPlaylist updated) async {
    _smartPlaylists = _smartPlaylists
        .map((p) => p.id == updated.id ? updated : p)
        .toList();
    await _save();
    notifyListeners();
  }

  Future<void> deleteSmartPlaylist(String id) async {
    _smartPlaylists = _smartPlaylists.where((p) => p.id != id).toList();
    await _save();
    notifyListeners();
  }

  /// Evaluates [playlist]'s rules against [library], returning the matching,
  /// sorted, and (if set) limited list of songs.
  List<SongModel> evaluate(
    SmartPlaylist playlist, {
    required List<SongModel> library,
    required bool Function(SongModel) isLiked,
    required int Function(SongModel) playCountOf,
  }) {
    Iterable<SongModel> results = library;

    if (playlist.rules.isNotEmpty) {
      results = results.where((song) {
        if (playlist.matchMode == SmartPlaylistMatchMode.all) {
          return playlist.rules.every((rule) => rule.matches(
                song,
                isLiked: isLiked,
                playCountOf: playCountOf,
              ));
        } else {
          return playlist.rules.any((rule) => rule.matches(
                song,
                isLiked: isLiked,
                playCountOf: playCountOf,
              ));
        }
      });
    }

    var list = results.toList();

    switch (playlist.sortBy) {
      case SmartPlaylistSortBy.titleAZ:
        list.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case SmartPlaylistSortBy.artistAZ:
        list.sort((a, b) =>
            (a.artist ?? '').toLowerCase().compareTo((b.artist ?? '').toLowerCase()));
        break;
      case SmartPlaylistSortBy.dateAddedNewest:
        list.sort((a, b) => (b.dateAdded ?? 0).compareTo(a.dateAdded ?? 0));
        break;
      case SmartPlaylistSortBy.playCountHighest:
        list.sort((a, b) => playCountOf(b).compareTo(playCountOf(a)));
        break;
      case SmartPlaylistSortBy.durationLongest:
        list.sort((a, b) => (b.duration ?? 0).compareTo(a.duration ?? 0));
        break;
      case SmartPlaylistSortBy.random:
        list.shuffle(Random());
        break;
    }

    final limit = playlist.limit;
    if (limit != null && limit > 0 && list.length > limit) {
      list = list.sublist(0, limit);
    }

    return list;
  }

  /// Convenience wrapper around [evaluate] that packages the result as a
  /// transient [Playlist] object, suitable for reuse with the existing
  /// `PlaylistDetailScreen` (which expects a [Playlist]).
  Playlist buildPlaylist(
    SmartPlaylist playlist, {
    required List<SongModel> library,
    required bool Function(SongModel) isLiked,
    required int Function(SongModel) playCountOf,
  }) {
    final songs = evaluate(
      playlist,
      library: library,
      isLiked: isLiked,
      playCountOf: playCountOf,
    );
    return Playlist(id: playlist.id, name: playlist.name, songs: songs);
  }
}
