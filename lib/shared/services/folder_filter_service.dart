/// Folder filter service — persist which folders are excluded from the library.
library;

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Singleton service that tracks which local folders the user has excluded
/// from the music library scan.
///
/// Changes are persisted to [SharedPreferences] immediately on every toggle.
/// Call [ensureInitialized] before reading [isExcluded] or [filterSongs];
/// it is a no-op after the first call.
class FolderFilterService extends ChangeNotifier {
  static const _prefsKey = 'folder_filter_excluded_v1';

  static final FolderFilterService _instance =
      FolderFilterService._internal();

  factory FolderFilterService() => _instance;
  FolderFilterService._internal();

  Set<String> _excludedFolders = {};
  bool _initialized = false;

  /// Read-only view of the currently excluded folder paths.
  Set<String> get excludedFolders => Set.unmodifiable(_excludedFolders);

  /// Whether any folders are currently excluded.
  bool get hasExclusions => _excludedFolders.isNotEmpty;

  /// Load persisted exclusions from disk.  No-op after first call.
  Future<void> ensureInitialized() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_prefsKey) ?? [];
    _excludedFolders = Set.from(list);
    _initialized = true;
  }

  /// Returns `true` when [folderPath] is excluded from the library.
  bool isExcluded(String folderPath) => _excludedFolders.contains(folderPath);

  /// Toggle the excluded state for [folderPath] and persist the change.
  Future<void> setExcluded(String folderPath, bool excluded) async {
    if (excluded) {
      _excludedFolders.add(folderPath);
    } else {
      _excludedFolders.remove(folderPath);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey, _excludedFolders.toList());
    notifyListeners();
  }

  /// Return only the songs whose parent directory is not excluded.
  List<SongModel> filterSongs(List<SongModel> songs) {
    if (_excludedFolders.isEmpty) return songs;
    return songs.where((song) {
      final folder = File(song.data).parent.path;
      return !_excludedFolders.contains(folder);
    }).toList();
  }
}
