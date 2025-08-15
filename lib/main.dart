import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'dart:ui' as ui;

import 'constants/app_config.dart';
import 'services/audio_player_service.dart';
import 'services/expandable_player_controller.dart';
import 'services/error_tracking_service.dart';
import 'services/shader_warmup_service.dart';
import 'services/background_manager_service.dart';
import 'localization/app_localizations.dart';
import 'screens/splash_screen.dart';
import 'localization/locale_provider.dart';
import 'providers/theme_provider.dart';


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

    // Warmup shaders for better performance
    await ShaderWarmupService.warmupShaders();

    // Load user preferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? languageCode = prefs.getString('languageCode') ?? AppConfig.defaultLanguageCode;

    // Initialize audio background service
    await JustAudioBackground.init(
      androidNotificationChannelId: AppConfig.androidNotificationChannelId,
      androidNotificationChannelName: AppConfig.androidNotificationChannelName,
      androidNotificationOngoing: true,
    );

    // Configure memory management
    ImageCache().maximumSize = AppConfig.imageCacheMaxSize;
    ImageCache().maximumSizeBytes = AppConfig.imageCacheMaxSizeBytes;

    // Launch the application with all required providers
    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (context) => AudioPlayerService()),
          ChangeNotifierProvider(create: (context) => ExpandablePlayerController()),
          ChangeNotifierProvider(create: (context) => ThemeProvider()),
          ChangeNotifierProvider(create: (context) => BackgroundManagerService()),
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