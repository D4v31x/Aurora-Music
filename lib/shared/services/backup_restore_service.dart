/// Backup and restore service.
///
/// Provides export and import functionality for playlists,
/// settings, and user data.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Types of data that can be backed up
enum BackupDataType {
  playlists,
  settings,
  likedSongs,
  playCounts,
  history,
  smartPlaylists,
  trackSettings,
  crossfadeSettings,
  all,
}

/// Result of a backup or restore operation
class BackupResult {
  final bool success;
  final String? filePath;
  final String? error;
  final int itemsProcessed;

  const BackupResult({
    required this.success,
    this.filePath,
    this.error,
    this.itemsProcessed = 0,
  });
}

/// Service for backup and restore operations
class BackupRestoreService {
  static const String _backupVersion = '1.0';

  /// Create a full backup of all user data
  Future<BackupResult> createFullBackup() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final backupData = <String, dynamic>{
        'version': _backupVersion,
        'exportDate': DateTime.now().toIso8601String(),
        'appVersion': '0.1.25+7', // Should be read from package info
      };

      int itemCount = 0;

      // Read and include each data file if it exists
      final dataFiles = {
        'playlists': 'playlists.json',
        'likedSongs': 'liked_songs.json',
        'playCounts': 'play_counts.json',
        'settings': 'settings.json',
        'history': 'listening_history.json',
        'smartPlaylists': 'smart_playlists.json',
        'trackSettings': 'track_settings.json',
        'crossfadeSettings': 'crossfade_settings.json',
        'homeLayout': 'home_layout.json',
        'artistSeparators': 'artist_separators.json',
      };

      for (final entry in dataFiles.entries) {
        final file = File('${directory.path}/${entry.value}');
        if (await file.exists()) {
          try {
            final contents = await file.readAsString();
            backupData[entry.key] = jsonDecode(contents);
            itemCount++;
          } catch (e) {
            debugPrint('Error reading ${entry.key}: $e');
          }
        }
      }

      // Create backup file
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final backupFile =
          File('${directory.path}/aurora_backup_$timestamp.json');
      await backupFile.writeAsString(
        const JsonEncoder.withIndent('  ').convert(backupData),
      );

      return BackupResult(
        success: true,
        filePath: backupFile.path,
        itemsProcessed: itemCount,
      );
    } catch (e) {
      debugPrint('Error creating backup: $e');
      return BackupResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Create a selective backup of specific data types
  Future<BackupResult> createSelectiveBackup(
      List<BackupDataType> dataTypes) async {
    if (dataTypes.contains(BackupDataType.all)) {
      return createFullBackup();
    }

    try {
      final directory = await getApplicationDocumentsDirectory();
      final backupData = <String, dynamic>{
        'version': _backupVersion,
        'exportDate': DateTime.now().toIso8601String(),
        'appVersion': '0.1.25+7',
        'partial': true,
        'includedTypes': dataTypes.map((t) => t.name).toList(),
      };

      int itemCount = 0;

      for (final type in dataTypes) {
        final fileName = _getFileNameForType(type);
        if (fileName != null) {
          final file = File('${directory.path}/$fileName');
          if (await file.exists()) {
            try {
              final contents = await file.readAsString();
              backupData[type.name] = jsonDecode(contents);
              itemCount++;
            } catch (e) {
              debugPrint('Error reading ${type.name}: $e');
            }
          }
        }
      }

      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final backupFile =
          File('${directory.path}/aurora_backup_partial_$timestamp.json');
      await backupFile.writeAsString(
        const JsonEncoder.withIndent('  ').convert(backupData),
      );

      return BackupResult(
        success: true,
        filePath: backupFile.path,
        itemsProcessed: itemCount,
      );
    } catch (e) {
      debugPrint('Error creating selective backup: $e');
      return BackupResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Restore from a backup file
  Future<BackupResult> restoreFromBackup(String filePath) async {
    try {
      final backupFile = File(filePath);
      if (!await backupFile.exists()) {
        return const BackupResult(
          success: false,
          error: 'Backup file not found',
        );
      }

      final contents = await backupFile.readAsString();
      final backupData = jsonDecode(contents) as Map<String, dynamic>;

      // Verify backup version
      final version = backupData['version'] as String?;
      if (version == null) {
        return const BackupResult(
          success: false,
          error: 'Invalid backup file: missing version',
        );
      }

      final directory = await getApplicationDocumentsDirectory();
      int itemCount = 0;

      // Mapping of backup keys to file names
      final dataFiles = {
        'playlists': 'playlists.json',
        'likedSongs': 'liked_songs.json',
        'playCounts': 'play_counts.json',
        'settings': 'settings.json',
        'history': 'listening_history.json',
        'smartPlaylists': 'smart_playlists.json',
        'trackSettings': 'track_settings.json',
        'crossfadeSettings': 'crossfade_settings.json',
        'homeLayout': 'home_layout.json',
        'artistSeparators': 'artist_separators.json',
      };

      for (final entry in dataFiles.entries) {
        if (backupData.containsKey(entry.key)) {
          try {
            final file = File('${directory.path}/${entry.value}');
            await file.writeAsString(jsonEncode(backupData[entry.key]));
            itemCount++;
          } catch (e) {
            debugPrint('Error restoring ${entry.key}: $e');
          }
        }
      }

      return BackupResult(
        success: true,
        itemsProcessed: itemCount,
      );
    } catch (e) {
      debugPrint('Error restoring backup: $e');
      return BackupResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Validate a backup file
  Future<Map<String, dynamic>?> validateBackup(String filePath) async {
    try {
      final backupFile = File(filePath);
      if (!await backupFile.exists()) return null;

      final contents = await backupFile.readAsString();
      final backupData = jsonDecode(contents) as Map<String, dynamic>;

      // Basic validation
      if (!backupData.containsKey('version')) return null;
      if (!backupData.containsKey('exportDate')) return null;

      return {
        'version': backupData['version'],
        'exportDate': backupData['exportDate'],
        'appVersion': backupData['appVersion'],
        'partial': backupData['partial'] ?? false,
        'includedTypes': backupData['includedTypes'],
        'dataKeys': backupData.keys
            .where((k) =>
                !['version', 'exportDate', 'appVersion', 'partial', 'includedTypes']
                    .contains(k))
            .toList(),
      };
    } catch (e) {
      debugPrint('Error validating backup: $e');
      return null;
    }
  }

  /// Get all backup files in the app directory
  Future<List<FileSystemEntity>> getBackupFiles() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final files = <FileSystemEntity>[];

      await for (final entity in directory.list()) {
        if (entity is File && entity.path.contains('aurora_backup')) {
          files.add(entity);
        }
      }

      // Sort by modification time, newest first
      files.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
      return files;
    } catch (e) {
      debugPrint('Error listing backup files: $e');
      return [];
    }
  }

  /// Delete a backup file
  Future<bool> deleteBackup(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error deleting backup: $e');
      return false;
    }
  }

  /// Export specific playlists as JSON
  Future<String?> exportPlaylistsAsJson(List<Map<String, dynamic>> playlists) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final exportData = {
        'version': _backupVersion,
        'exportDate': DateTime.now().toIso8601String(),
        'type': 'playlists_only',
        'playlists': playlists,
      };

      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final file = File('${directory.path}/aurora_playlists_$timestamp.json');
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(exportData),
      );

      return file.path;
    } catch (e) {
      debugPrint('Error exporting playlists: $e');
      return null;
    }
  }

  String? _getFileNameForType(BackupDataType type) {
    switch (type) {
      case BackupDataType.playlists:
        return 'playlists.json';
      case BackupDataType.settings:
        return 'settings.json';
      case BackupDataType.likedSongs:
        return 'liked_songs.json';
      case BackupDataType.playCounts:
        return 'play_counts.json';
      case BackupDataType.history:
        return 'listening_history.json';
      case BackupDataType.smartPlaylists:
        return 'smart_playlists.json';
      case BackupDataType.trackSettings:
        return 'track_settings.json';
      case BackupDataType.crossfadeSettings:
        return 'crossfade_settings.json';
      case BackupDataType.all:
        return null; // Handled separately
    }
  }
}
