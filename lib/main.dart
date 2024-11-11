import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:provider/provider.dart';
import 'package:rive/rive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:appwrite/appwrite.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:ui' as ui;
import 'dart:convert';
import 'dart:math' as math;

import 'services/Audio_Player_Service.dart';
import 'services/expandable_player_controller.dart';
import 'localization/app_localizations.dart';
import 'screens/splash_screen.dart';
import 'localization/locale_provider.dart';

// Appwrite client configuration
late Client client;
late Account account;
late Databases databases;
String? currentUserId;

// Error Tracking Service
class ErrorTrackingService {
  static const String _storageKey = 'pending_errors';
  static final ErrorTrackingService _instance = ErrorTrackingService._internal();
  final List<ErrorRecord> _currentErrors = [];

  factory ErrorTrackingService() {
    return _instance;
  }

  ErrorTrackingService._internal();

  Future<void> recordError(dynamic error, StackTrace? stack) async {
    final errorRecord = ErrorRecord(
      timestamp: DateTime.now(),
      error: error.toString(),
      stackTrace: stack?.toString(),
    );

    _currentErrors.add(errorRecord);
    await _savePendingErrors();
  }

  Future<void> _savePendingErrors() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<Map<String, dynamic>> errorMaps = _currentErrors
          .map((error) => error.toJson())
          .toList();

      await prefs.setString(_storageKey, jsonEncode(errorMaps));
    } catch (e) {
      
    }
  }

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
      
    }
    return [];
  }

  Future<void> clearPendingErrors() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
      _currentErrors.clear();
    } catch (e) {
      
    }
  }
}

class ErrorRecord {
  final DateTime timestamp;
  final String error;
  final String? stackTrace;

  ErrorRecord({
    required this.timestamp,
    required this.error,
    this.stackTrace,
  });

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'error': error,
    'stackTrace': stackTrace,
  };

  factory ErrorRecord.fromJson(Map<String, dynamic> json) => ErrorRecord(
    timestamp: DateTime.parse(json['timestamp']),
    error: json['error'],
    stackTrace: json['stackTrace'],
  );
}

// Add this function before syncUserData()
Map<String, dynamic> processErrorsForAppwrite(List<ErrorRecord> errors) {
  // Keep only the most recent errors if there are too many
  const int maxErrors = 10;
  final recentErrors = errors.length > maxErrors
      ? errors.sublist(errors.length - maxErrors)
      : errors;

  // Create a condensed error summary
  final List<String> processedErrors = recentErrors.map((error) {
    final timestamp = error.timestamp.toIso8601String();
    final shortStack = error.stackTrace?.split('\n').take(3).join(' | ') ?? 'No stack trace';
    return '$timestamp: ${error.error.substring(0, math.min(200, error.error.length))} | $shortStack';
  }).toList();

  // Join all errors with a delimiter and truncate if necessary
  String errorString = processedErrors.join('\n').substring(0, math.min(4900, processedErrors.join('\n').length));

  return {
    'error_count': errors.length, // This will be an integer
    'recent_errors': errorString, // String under 5000 chars
    'last_error_time': errors.isNotEmpty ? errors.last.timestamp.toIso8601String() : null, // String in ISO format or null
  };
}

// Update the syncUserData function to use the new error processing
Future<void> syncUserData() async {
  if (currentUserId == null) {
    
    return;
  }

  try {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    String appVersion = packageInfo.version;
    String buildNumber = packageInfo.buildNumber;
    String fullVersion = '$appVersion+$buildNumber';

    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    String? deviceModel;
    String? androidVersion;
    String? manufacturer;

    if (Platform.isAndroid) {
      AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      deviceModel = androidInfo.model;
      androidVersion = androidInfo.version.release;
      manufacturer = androidInfo.manufacturer;
    } else if (Platform.isIOS) {
      IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
      deviceModel = iosInfo.utsname.machine;
      manufacturer = 'Apple';
    }

    final errorTracker = ErrorTrackingService();
    final pendingErrors = await errorTracker.loadPendingErrors();

    // Process errors to fit Appwrite's limitations
    final processedErrorData = processErrorsForAppwrite(pendingErrors);

    String lastOpened = DateTime.now().toIso8601String();
    final documentId = 'user_$currentUserId';

    try {
      await databases.createDocument(
        databaseId: dotenv.env['APPWRITE_DATABASE_ID']!,
        collectionId: dotenv.env['APPWRITE_COLLECTION_ID']!,
        documentId: documentId,
        data: {
          'user_id': currentUserId,
          'app_version': appVersion,
          'build_number': buildNumber,
          'full_version': fullVersion,
          'device_model': deviceModel ?? 'Unknown',
          'manufacturer': manufacturer ?? 'Unknown',
          'android_version': androidVersion ?? 'Unknown',
          'last_opened': lastOpened,
          'error_count': processedErrorData['error_count'],
          'recent_errors': processedErrorData['recent_errors'],
          'last_error_time': processedErrorData['last_error_time'],
        },
        permissions: [
          Permission.read(Role.user(currentUserId!)),
          Permission.write(Role.user(currentUserId!)),
        ],
      );
      
      await errorTracker.clearPendingErrors();

    } catch (e) {
      if (e is AppwriteException && e.code == 409) {
        try {
          await databases.updateDocument(
            databaseId: dotenv.env['APPWRITE_DATABASE_ID']!,
            collectionId: dotenv.env['APPWRITE_COLLECTION_ID']!,
            documentId: documentId,
            data: {
              'app_version': appVersion,
              'build_number': buildNumber,
              'full_version': fullVersion,
              'device_model': deviceModel ?? 'Unknown',
              'manufacturer': manufacturer ?? 'Unknown',
              'android_version': androidVersion ?? 'Unknown',
              'last_opened': lastOpened,
              'error_count': processedErrorData['error_count'],
              'recent_errors': processedErrorData['recent_errors'],
              'last_error_time': processedErrorData['last_error_time'],
            },
          );
          
          await errorTracker.clearPendingErrors();
        } catch (updateError) {
          
        }
      } else {
        
      }
    }
  } catch (e) {
    
  }
}

void main() async {
  try {
    // Create error tracking instance
    final errorTracker = ErrorTrackingService();

    // Set up Flutter error handling
    FlutterError.onError = (FlutterErrorDetails details) async {
      FlutterError.dumpErrorToConsole(details);
      await errorTracker.recordError(details.exception, details.stack);
    };

    // Set up platform error handling
    PlatformDispatcher.instance.onError = (error, stack) {
      errorTracker.recordError(error, stack);
      return true;
    };

    WidgetsFlutterBinding.ensureInitialized();
    await dotenv.load(fileName: ".env");

    // Initialize Appwrite
    client = Client()
      ..setEndpoint(dotenv.env['APPWRITE_ENDPOINT']!)
      ..setProject(dotenv.env['APPWRITE_PROJECT_ID']!)
      ..setSelfSigned(status: true); // Remove in production

    account = Account(client);
    databases = Databases(client);

    // Create anonymous session
    try {
      final session = await account.createAnonymousSession();
      currentUserId = session.userId;
      
    } catch (e) {
      if (e is AppwriteException && e.code == 401) {
        try {
          final session = await account.getSession(sessionId: 'current');
          currentUserId = session.userId;
          
        } catch (sessionError) {
          
        }
      } else {
        
      }
    }

    // Sync user data if we have a session
    if (currentUserId != null) {
      await syncUserData();
    }

    await RiveFile.initialize();

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? languageCode = prefs.getString('languageCode') ?? 'en';

    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.ryanheise.bg_demo.channel.audio',
      androidNotificationChannelName: 'Audio playback',
      androidNotificationOngoing: true,
    );

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (context) => AudioPlayerService()),
          ChangeNotifierProvider(create: (context) => ExpandablePlayerController()),
        ],
        child: MyApp(
          languageCode: languageCode,
          account: account,
        ),
      ),
    );
  } catch (e, stack) {
    // Record any errors during initialization
    final errorTracker = ErrorTrackingService();
    await errorTracker.recordError(e, stack);
    rethrow;
  }
}

class MyApp extends StatefulWidget {
  final String languageCode;
  final Account account;

  const MyApp({super.key, required this.languageCode, required this.account});

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
    return LocaleProvider(
      locale: _locale,
      setLocale: setLocale,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: _locale,
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
        home: const SplashScreen(),
      ),
    );
  }
}