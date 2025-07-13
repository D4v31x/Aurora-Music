import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/painting.dart' as painting;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:ui' as ui;
import 'dart:convert';
import 'dart:math' as math;

import 'services/Audio_Player_Service.dart';
import 'services/expandable_player_controller.dart';
import 'localization/app_localizations.dart';
import 'screens/splash_screen.dart';
import 'localization/locale_provider.dart';
import 'providers/theme_provider.dart';


/// Service responsible for tracking and managing application errors
/// Implements error recording, storage, and synchronization with Appwrite
class ErrorTrackingService {
  static const String _storageKey = 'pending_errors';
  static final ErrorTrackingService _instance = ErrorTrackingService._internal();
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
      final List<Map<String, dynamic>> errorMaps = _currentErrors
          .map((error) => error.toJson())
          .toList();

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

/// Processes error records for Appwrite storage
/// Formats and truncates error data to meet Appwrite's constraints
Map<String, dynamic> processErrorsForAppwrite(List<ErrorRecord> errors) {
  const int maxErrors = 10;
  final recentErrors = errors.length > maxErrors
      ? errors.sublist(errors.length - maxErrors)
      : errors;

  final List<String> processedErrors = recentErrors.map((error) {
    final timestamp = error.timestamp.toIso8601String();
    final shortStack = error.stackTrace?.split('\n').take(3).join(' | ') ?? 'No stack trace';
    return '$timestamp: ${error.error.substring(0, math.min(200, error.error.length))} | $shortStack';
  }).toList();

  String errorString = processedErrors.join('\n').substring(0, math.min(4900, processedErrors.join('\n').length));

  return {
    'error_count': errors.length,
    'recent_errors': errorString,
    'last_error_time': errors.isNotEmpty ? errors.last.timestamp.toIso8601String() : null,
  };
}

/// Precaches commonly used shaders for better performance
Future<void> _precacheShaders() async {
  final shaderWarmUpTask = Future(() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final shaders = [
      painting.LinearGradient(
        colors: [Colors.white, Colors.white.withValues(alpha: 0.0)],
        stops: const [0.8, 1.0],
      ).createShader(const Rect.fromLTWH(0, 0, 100, 100)),

      painting.LinearGradient(
        colors: [Colors.black.withValues(alpha: 0.8), Colors.transparent],
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
      ).createShader(const Rect.fromLTWH(0, 0, 100, 100)),
    ];

    for (final shader in shaders) {
      final paint = Paint()..shader = shader;
      canvas.drawRect(const Rect.fromLTWH(0, 0, 100, 100), paint);
    }

    final picture = recorder.endRecording();
    await picture.toImage(100, 100);
  });

  await shaderWarmUpTask;
}

/// Application entry point
void main() async {
  try {
    // Initialize error tracking
    final errorTracker = ErrorTrackingService();

    // Set up Flutter error handling
    FlutterError.onError = (FlutterErrorDetails details) async {
      FlutterError.dumpErrorToConsole(details);
      await errorTracker.recordError(details.exception, details.stack);
    };

    // Ensure Flutter bindings are initialized
    WidgetsFlutterBinding.ensureInitialized();

    // Load environment variables
    await dotenv.load(fileName: ".env");


    // Load user preferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? languageCode = prefs.getString('languageCode') ?? 'en';

    // Initialize audio background service
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.aurorasoftware.music.channel.audio',
      androidNotificationChannelName: 'Audio playback',
      androidNotificationOngoing: true,
    );

    // Configure memory management
    ImageCache().maximumSize = 1024;
    ImageCache().maximumSizeBytes = 200 << 20; // 200 MB

    // Launch the application with all required providers
    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (context) => AudioPlayerService()),
          ChangeNotifierProvider(create: (context) => ExpandablePlayerController()),
          ChangeNotifierProvider(create: (context) => ThemeProvider()),
          Provider<ErrorTrackingService>.value(value: errorTracker),
        ],
        child: MyApp(
          languageCode: languageCode,
        ),
      ),
    );

  } catch (e, stack) {
    final errorTracker = ErrorTrackingService();
    await errorTracker.recordError(e, stack);
    rethrow;
  }
}

/// Root application widget
class MyApp extends StatefulWidget {
  final String languageCode;

  const MyApp({super.key, required this.languageCode});

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late ui.Locale _locale;

  @override
  void initState() {
    super.initState();
    _locale = ui.Locale(widget.languageCode);
  }

  /// Updates the application locale and persists the selection
  void setLocale(ui.Locale locale) {
    setState(() {
      _locale = locale;
    });

    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('languageCode', locale.languageCode);
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return LocaleProvider(
      locale: _locale,
      setLocale: setLocale,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: _locale,
        themeMode: themeProvider.themeMode,
        theme: themeProvider.lightTheme,
        darkTheme: themeProvider.darkTheme,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          ui.Locale('en', ''),
          ui.Locale('cs', ''),
        ],
        home: Builder(
          builder: (context) {
            return const SplashScreen();
          },
        ),
      ),
    );
  }
}