/// Persists user-created [TrackTag] markers, keyed by song id, so long
/// tracks (e.g. DJ sets/mixes) can have named jump points that survive app
/// restarts. Mirrors the JSON-file persistence pattern used by
/// [SmartPlaylistService].
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/track_tag_model.dart';

class TrackTagService extends ChangeNotifier {
  static const String _fileName = 'track_tags.json';

  Map<String, List<TrackTag>> _tagsBySongId = {};
  bool _loaded = false;

  bool get loaded => _loaded;

  Future<void> load() async {
    if (_loaded) return;
    try {
      final file = await _tagsFile();
      if (await file.exists()) {
        final contents = await file.readAsString();
        final map = jsonDecode(contents) as Map<String, dynamic>;
        _tagsBySongId = map.map((songId, tags) => MapEntry(
              songId,
              (tags as List)
                  .map((t) => TrackTag.fromJson(t as Map<String, dynamic>))
                  .toList(),
            ));
      }
    } catch (e) {
      debugPrint('Error loading track tags: $e');
    } finally {
      _loaded = true;
      notifyListeners();
    }
  }

  Future<File> _tagsFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_fileName');
  }

  Future<void> _save() async {
    try {
      final file = await _tagsFile();
      final json = _tagsBySongId.map(
        (songId, tags) => MapEntry(songId, tags.map((t) => t.toJson()).toList()),
      );
      await file.writeAsString(jsonEncode(json));
    } catch (e) {
      debugPrint('Error saving track tags: $e');
    }
  }

  /// Tags for [songId], sorted by position ascending.
  List<TrackTag> tagsFor(int songId) {
    final tags = _tagsBySongId[songId.toString()] ?? const <TrackTag>[];
    final sorted = List<TrackTag>.from(tags)
      ..sort((a, b) => a.position.compareTo(b.position));
    return sorted;
  }

  bool hasTags(int songId) =>
      (_tagsBySongId[songId.toString()]?.isNotEmpty) ?? false;

  Future<void> addTag(int songId, TrackTag tag) async {
    final key = songId.toString();
    final tags = List<TrackTag>.from(_tagsBySongId[key] ?? const <TrackTag>[]);
    tags.add(tag);
    _tagsBySongId = {..._tagsBySongId, key: tags};
    await _save();
    notifyListeners();
  }

  /// Appends multiple tags at once (e.g. from a pasted setlist), performing
  /// a single save instead of one per tag.
  Future<void> addTags(int songId, List<TrackTag> newTags) async {
    if (newTags.isEmpty) return;
    final key = songId.toString();
    final tags = List<TrackTag>.from(_tagsBySongId[key] ?? const <TrackTag>[]);
    tags.addAll(newTags);
    _tagsBySongId = {..._tagsBySongId, key: tags};
    await _save();
    notifyListeners();
  }

  Future<void> updateTag(int songId, TrackTag updated) async {
    final key = songId.toString();
    final tags = List<TrackTag>.from(_tagsBySongId[key] ?? const <TrackTag>[]);
    final index = tags.indexWhere((t) => t.id == updated.id);
    if (index == -1) return;
    tags[index] = updated;
    _tagsBySongId = {..._tagsBySongId, key: tags};
    await _save();
    notifyListeners();
  }

  Future<void> deleteTag(int songId, String tagId) async {
    final key = songId.toString();
    final tags = List<TrackTag>.from(_tagsBySongId[key] ?? const <TrackTag>[]);
    tags.removeWhere((t) => t.id == tagId);
    _tagsBySongId = {..._tagsBySongId, key: tags};
    await _save();
    notifyListeners();
  }
}
