import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'dart:ui' as ui;

import 'constants/app_config.dart';
import 'services/audio_player_service.dart';
import 'services/error_tracking_service.dart';
import 'services/shader_warmup_service.dart';
import 'services/background_manager_service.dart';
import 'services/sleep_timer_controller.dart';
import 'localization/app_localizations.dart';
import 'screens/splash_screen.dart';
import 'localization/locale_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/performance_mode_provider.dart';
import 'widgets/performance_debug_overlay.dart';

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
    final prefs = await SharedPreferences.getInstance();
    final languageCode =
        prefs.getString('languageCode') ?? AppConfig.defaultLanguageCode;

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
          // Use lazy initialization for better startup performance
          ChangeNotifierProvider.value(
              value: AudioPlayerService()), // Use pre-initialized instance
          ChangeNotifierProvider(create: (_) => ThemeProvider(), lazy: false),
          ChangeNotifierProvider(
              create: (_) => PerformanceModeProvider(), lazy: false),
          ChangeNotifierProvider(
              create: (_) => BackgroundManagerService(), lazy: false),
          ChangeNotifierProvider(
              create: (_) => SleepTimerController(), lazy: true),
          Provider<ErrorTrackingService>.value(value: errorTracker),
        ],
        child: Builder(
          builder: (context) {
            // Connect the services after providers are initialized
            final audioPlayerService =
                Provider.of<AudioPlayerService>(context, listen: false);
            final backgroundManager =
                Provider.of<BackgroundManagerService>(context, listen: false);
            final performanceProvider =
                Provider.of<PerformanceModeProvider>(context, listen: false);

            // Set the background manager in the audio player service
            audioPlayerService.setBackgroundManager(backgroundManager);

            // Initialize performance provider
            WidgetsBinding.instance.addPostFrameCallback((_) {
              performanceProvider.initialize();
            });

            return MyApp(
              languageCode: languageCode,
            );
          },
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

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  late ui.Locale _locale;

  @override
  void initState() {
    super.initState();
    _locale = ui.Locale(widget.languageCode);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    // When app is detached (swiped from recents), stop audio and clean up
    if (state == AppLifecycleState.detached) {
      _cleanupAndExit();
    }
  }

  Future<void> _cleanupAndExit() async {
    try {
      final audioService = Provider.of<AudioPlayerService>(context, listen: false);
      await audioService.stop();
      audioService.dispose();
    } catch (e) {
      // Ignore errors during cleanup
    }
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

    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        // Update theme provider with dynamic colors
        if (lightDynamic != null || darkDynamic != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            themeProvider.setDynamicColorSchemes(lightDynamic, darkDynamic);
          });
        }

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
            // Custom hero controller for faster, smoother transitions
            builder: (context, child) {
              return HeroControllerScope(
                controller: HeroController(
                  createRectTween: (Rect? begin, Rect? end) {
                    return MaterialRectCenterArcTween(begin: begin, end: end);
                  },
                ),
                child: child ?? const SizedBox.shrink(),
              );
            },
            home: Builder(
              builder: (context) {
                // Wrap the entire app with the performance debug overlay and AppBackground widget
                return PerformanceDebugOverlay(
                  child: const SplashScreen(),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
