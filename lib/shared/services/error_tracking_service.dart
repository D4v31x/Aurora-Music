import 'dart:convert';
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_config.dart';

/// Service responsible for tracking and managing application errors
/// Implements error recording, storage, and synchronization
class ErrorTrackingService {
  static const String _storageKey = AppConfig.errorStorageKey;
  static final ErrorTrackingService _instance =
      ErrorTrackingService._internal();
  final List<ErrorRecord> _currentErrors = [];

  /// Singleton factory constructor
  factory ErrorTrackingService() {
    return _instance;
  }

  ErrorTrackingService._internal();

  /// Records a new error with timestamp and stack trace
  Future<void> recordError(dynamic error, StackTrace? stack) async {
    final errorRecord = ErrorRecord(
      timestamp: DateTime.now(),
      error: error.toString(),
      stackTrace: stack?.toString(),
    );

    _currentErrors.add(errorRecord);
    await _savePendingErrors();
  }

  /// Persists current errors to SharedPreferences
  Future<void> _savePendingErrors() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<Map<String, dynamic>> errorMaps =
          _currentErrors.map((error) => error.toJson()).toList();

      await prefs.setString(_storageKey, jsonEncode(errorMaps));
    } catch (e) {
      // Silent failure to prevent error recording loops
    }
  }

  /// Retrieves stored errors from SharedPreferences
  Future<List<ErrorRecord>> loadPendingErrors() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? storedErrors = prefs.getString(_storageKey);

      if (storedErrors != null) {
        final List<dynamic> decodedErrors = jsonDecode(storedErrors);
        return decodedErrors
            .map((error) => ErrorRecord.fromJson(error))
            .toList();
      }
    } catch (e) {
      // Silent failure to prevent error recording loops
    }
    return [];
  }

  /// Clears all stored errors
  Future<void> clearPendingErrors() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
      _currentErrors.clear();
    } catch (e) {
      // Silent failure to prevent error recording loops
    }
  }
}

/// Model class for storing error information
class ErrorRecord {
  final DateTime timestamp;
  final String error;
  final String? stackTrace;

  ErrorRecord({
    required this.timestamp,
    required this.error,
    this.stackTrace,
  });

  /// Converts ErrorRecord to JSON format for storage
  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'error': error,
        'stackTrace': stackTrace,
      };

  /// Creates ErrorRecord from JSON data
  factory ErrorRecord.fromJson(Map<String, dynamic> json) => ErrorRecord(
        timestamp: DateTime.parse(json['timestamp']),
        error: json['error'],
        stackTrace: json['stackTrace'],
      );
}

/// Processes error records for external storage
/// Formats and truncates error data to meet constraints
Map<String, dynamic> processErrorsForStorage(List<ErrorRecord> errors) {
  const int maxErrors = AppConfig.maxStoredErrors;
  final recentErrors = errors.length > maxErrors
      ? errors.sublist(errors.length - maxErrors)
      : errors;

  final List<String> processedErrors = recentErrors.map((error) {
    final timestamp = error.timestamp.toIso8601String();
    final shortStack =
        error.stackTrace?.split('\n').take(3).join(' | ') ?? 'No stack trace';
    return '$timestamp: ${error.error.substring(0, math.min(AppConfig.maxErrorMessageLength, error.error.length))} | $shortStack';
  }).toList();

  final String errorString = processedErrors.join('\n').substring(
      0,
      math.min(
          AppConfig.maxErrorStringLength, processedErrors.join('\n').length));

  return {
    'error_count': errors.length,
    'recent_errors': errorString,
    'last_error_time':
        errors.isNotEmpty ? errors.last.timestamp.toIso8601String() : null,
  };
}
