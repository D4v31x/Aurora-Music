import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../services/logging_service.dart';

/// Utility class for common file operations
/// Provides standardized file handling with error logging
class FileUtils {
  /// Gets the application documents directory
  static Future<Directory> getDocumentsDirectory() async {
    try {
      return await getApplicationDocumentsDirectory();
    } catch (e) {
      LoggingService.error('Failed to get documents directory', 'FileUtils', e);
      rethrow;
    }
  }

  /// Gets the application cache directory
  static Future<Directory> getCacheDirectory() async {
    try {
      return await getTemporaryDirectory();
    } catch (e) {
      LoggingService.error('Failed to get cache directory', 'FileUtils', e);
      rethrow;
    }
  }

  /// Checks if a file exists
  static Future<bool> fileExists(String path) async {
    try {
      return await File(path).exists();
    } catch (e) {
      LoggingService.error('Failed to check file existence: $path', 'FileUtils', e);
      return false;
    }
  }

  /// Creates a directory if it doesn't exist
  static Future<Directory> ensureDirectoryExists(String path) async {
    try {
      final directory = Directory(path);
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      return directory;
    } catch (e) {
      LoggingService.error('Failed to create directory: $path', 'FileUtils', e);
      rethrow;
    }
  }

  /// Safely deletes a file
  static Future<bool> deleteFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      LoggingService.error('Failed to delete file: $path', 'FileUtils', e);
      return false;
    }
  }

  /// Gets file size safely
  static Future<int> getFileSize(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        return await file.length();
      }
      return 0;
    } catch (e) {
      LoggingService.error('Failed to get file size: $path', 'FileUtils', e);
      return 0;
    }
  }

  /// Cleans up old files in a directory based on age
  static Future<void> cleanupOldFiles(String directoryPath, Duration maxAge) async {
    try {
      final directory = Directory(directoryPath);
      if (!await directory.exists()) return;

      final cutoffTime = DateTime.now().subtract(maxAge);
      final files = await directory.list().toList();

      for (final entity in files) {
        if (entity is File) {
          final stat = await entity.stat();
          if (stat.modified.isBefore(cutoffTime)) {
            await entity.delete();
            LoggingService.debug('Deleted old file: ${entity.path}', 'FileUtils');
          }
        }
      }
    } catch (e) {
      LoggingService.error('Failed to cleanup old files in: $directoryPath', 'FileUtils', e);
    }
  }
}