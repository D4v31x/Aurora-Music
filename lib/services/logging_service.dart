import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

/// Centralized logging service for the application
/// Provides different log levels and proper output formatting
class LoggingService {
  static const String _appName = 'Aurora Music';

  /// Logs debug information (only in debug mode)
  static void debug(String message, [String? tag]) {
    if (kDebugMode) {
      developer.log(
        message,
        name: '$_appName${tag != null ? ' - $tag' : ''}',
        level: 500, // Debug level
      );
    }
  }

  /// Logs informational messages
  static void info(String message, [String? tag]) {
    developer.log(
      message,
      name: '$_appName${tag != null ? ' - $tag' : ''}',
      level: 800, // Info level
    );
  }

  /// Logs warning messages
  static void warning(String message, [String? tag]) {
    developer.log(
      message,
      name: '$_appName${tag != null ? ' - $tag' : ''}',
      level: 900, // Warning level
    );
  }

  /// Logs error messages
  static void error(String message, [String? tag, Object? error, StackTrace? stackTrace]) {
    developer.log(
      message,
      name: '$_appName${tag != null ? ' - $tag' : ''}',
      level: 1000, // Error level
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Logs critical error messages
  static void critical(String message, [String? tag, Object? error, StackTrace? stackTrace]) {
    developer.log(
      message,
      name: '$_appName${tag != null ? ' - $tag' : ''}',
      level: 1200, // Critical level
      error: error,
      stackTrace: stackTrace,
    );
  }
}