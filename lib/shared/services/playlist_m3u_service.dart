/// M3U / M3U8 playlist import & export service.
///
/// Converts between Aurora [Playlist] objects and the `.m3u8` text format
/// used by most music players (Poweramp, VLC, foobar2000, etc.).
///
/// Export writes an extended M3U file (`#EXTM3U` + `#EXTINF` lines) referencing
/// the absolute file path (`SongModel.data`) of each track. Import parses such a
/// file and resolves each referenced path back to a [SongModel] from the local
/// library so the playlist can be played and persisted.
library;

import 'dart:convert';
import 'dart:io';

import 'package:on_audio_query/on_audio_query.dart';

import '../models/playlist_model.dart';

/// Service for reading and writing `.m3u` / `.m3u8` playlist files.
class PlaylistM3uService {
  const PlaylistM3uService();

  // MARK: - Serialization

  /// Builds the textual content of an extended M3U8 playlist for [playlist].
  ///
  /// Paths are written as absolute file system paths so that other players
  /// (and re-imports) can resolve them. Lines use `\n` endings.
  String buildM3uContent(Playlist playlist) {
    final buffer = StringBuffer();
    buffer.writeln('#EXTM3U');
    for (final song in playlist.songs) {
      final path = song.data;
      if (path.isEmpty) continue;
      final seconds = ((song.duration ?? 0) / 1000).round();
      final artist = song.artist ?? '';
      final title = song.title;
      final display = artist.isNotEmpty ? '$artist - $title' : title;
      buffer.writeln('#EXTINF:$seconds,$display');
      buffer.writeln(path);
    }
    return buffer.toString();
  }

  // MARK: - Export

  /// Writes [playlist] as an `.m3u8` file at [filePath] and returns the file.
  Future<File> exportToFile(Playlist playlist, String filePath) async {
    final file = File(filePath);
    await file.parent.create(recursive: true);
    await file.writeAsString(buildM3uContent(playlist), flush: true);
    return file;
  }

  /// Sanitizes a playlist name into a safe file name (without extension).
  String sanitizeFileName(String name) {
    final cleaned = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    return cleaned.isEmpty ? 'playlist' : cleaned;
  }

  // MARK: - Import

  /// Parses the raw [content] of an M3U/M3U8 file into ordered track paths.
  ///
  /// Ignores comment/directive lines (those starting with `#`) and blank lines.
  /// Relative paths are resolved against [baseDir] when provided.
  List<String> parsePaths(String content, {String? baseDir}) {
    final paths = <String>[];
    for (final raw in const LineSplitter().convert(content)) {
      final line = raw.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      // Skip remote URLs – this player handles local files only.
      if (line.contains('://')) continue;
      var path = line;
      if (!_isAbsolute(path) && baseDir != null) {
        path = _joinPath(baseDir, path);
      }
      paths.add(_normalize(path));
    }
    return paths;
  }

  /// Reads an `.m3u`/`.m3u8` file and resolves its entries to [SongModel]s from
  /// [library]. Entries that cannot be matched are skipped.
  ///
  /// Returns the matched songs in the order they appear in the file.
  Future<List<SongModel>> resolveSongsFromFile(
    String filePath,
    List<SongModel> library,
  ) async {
    final file = File(filePath);
    if (!await file.exists()) return const [];
    final content = await file.readAsString();
    final baseDir = file.parent.path;
    final paths = parsePaths(content, baseDir: baseDir);
    return resolveSongs(paths, library);
  }

  /// Matches [paths] to songs in [library] by normalized absolute path, with a
  /// fallback to matching by file name when an exact path match fails.
  List<SongModel> resolveSongs(List<String> paths, List<SongModel> library) {
    if (paths.isEmpty || library.isEmpty) return const [];

    final byPath = <String, SongModel>{};
    final byName = <String, SongModel>{};
    for (final song in library) {
      final data = song.data;
      if (data.isEmpty) continue;
      byPath[_normalize(data)] = song;
      byName.putIfAbsent(_fileName(data).toLowerCase(), () => song);
    }

    final result = <SongModel>[];
    final seen = <int>{};
    for (final path in paths) {
      final norm = _normalize(path);
      var match = byPath[norm];
      match ??= byName[_fileName(norm).toLowerCase()];
      if (match != null && seen.add(match.id)) {
        result.add(match);
      }
    }
    return result;
  }

  // MARK: - Path Helpers

  bool _isAbsolute(String path) =>
      path.startsWith('/') || RegExp(r'^[A-Za-z]:[\\/]').hasMatch(path);

  String _joinPath(String base, String relative) {
    final b = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    final r = relative.startsWith('./') ? relative.substring(2) : relative;
    return '$b/$r';
  }

  String _normalize(String path) {
    var p = path.replaceAll('\\', '/');
    // Collapse any double slashes (but keep a leading one).
    p = p.replaceAll(RegExp(r'(?<!^)/{2,}'), '/');
    if (p.length > 1 && p.endsWith('/')) p = p.substring(0, p.length - 1);
    return p;
  }

  String _fileName(String path) {
    final norm = path.replaceAll('\\', '/');
    final idx = norm.lastIndexOf('/');
    return idx >= 0 ? norm.substring(idx + 1) : norm;
  }
}
