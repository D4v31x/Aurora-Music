import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'dart:async';
import 'dart:ui' as ui;

import 'core/constants/app_config.dart';
import 'shared/services/audio_player_service.dart';
import 'shared/services/audio_handler.dart';
import 'shared/services/error_tracking_service.dart';
import 'shared/services/shader_warmup_service.dart';
import 'shared/services/background_manager_service.dart';
import 'shared/services/sleep_timer_controller.dart';
import 'shared/services/artist_separator_service.dart';
import 'shared/services/home_layout_service.dart';
import 'l10n/generated/app_localizations.dart';
import 'features/features.dart';
import 'l10n/locale_provider.dart';
import 'shared/providers/providers.dart';
import 'shared/widgets/expanding_player.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'firebase_options.dart';
import 'shared/services/equalizer_service.dart';

/// Global navigator key for the ROOT navigator.
///
/// The root navigator hosts only transient popups that must appear *above* the
/// mini player: dialogs, menus and bottom sheets (the latter via
/// `useRootNavigator: true`). All in-app pages live in [pageNavigatorKey].
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Global navigator key for the inner PAGE navigator.
///
/// Hosts every full-screen page (splash, home, detail, settings, now playing).
/// The mini player is painted directly above this navigator but below the root
/// navigator, so it floats over pages yet stays beneath dialogs/menus/sheets.
final GlobalKey<NavigatorState> pageNavigatorKey = GlobalKey<NavigatorState>();

/// Global audio handler instance
late AuroraAudioHandler audioHandler;

/// Global equalizer effect — attached to the player via AudioPipeline
late AndroidEqualizer equalizer;

/// Application entry point
void main() async {
  try {
    // Initialize error tracking
    final errorTracker = ErrorTrackingService();

    // Ensure Flutter bindings are initialized
    WidgetsFlutterBinding.ensureInitialized();

    // Initialize Firebase — requires google-services.json at android/app/
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

    // Disable performance data collection in debug to keep overhead low
    if (kDebugMode) {
      await FirebasePerformance.instance.setPerformanceCollectionEnabled(false);
    }

    // Route all Flutter framework errors to Sentry + Firebase Crashlytics
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.dumpErrorToConsole(details);
      unawaited(errorTracker.recordError(details.exception, details.stack));
      unawaited(FirebaseCrashlytics.instance.recordFlutterFatalError(details));
    };

    // Catch uncaught async errors that escape the Flutter framework
    // (e.g. errors from platform channels, plugin callbacks, isolates).
    // Returning true marks the error as handled and prevents app termination.
    ui.PlatformDispatcher.instance.onError = (error, stack) {
      // Fire-and-forget — onError must be synchronous.
      unawaited(errorTracker.recordError(error, stack));
      unawaited(FirebaseCrashlytics.instance.recordError(error, stack, fatal: true));
      return true;
    };

    // Silence all debug output in release builds — kDebugMode is a
    // compile-time constant so the AOT compiler eliminates this in debug.
    if (!kDebugMode) {
      debugPrint = (String? message, {int? wrapWidth}) {};
    }

    // Configure memory management early for better startup memory usage
    ImageCache().maximumSize = AppConfig.imageCacheMaxSize;
    ImageCache().maximumSizeBytes = AppConfig.imageCacheMaxSizeBytes;

    // Start parallel initialization for faster startup
    final parallelInit = Future.wait([
      SharedPreferences.getInstance(),
      ArtistSeparatorService().initialize(),
      HomeLayoutService().initialize(),
    ]);

    // Warmup shaders in parallel with other initialization
    final shaderWarmup = ShaderWarmupService.warmupShaders();

    // Wait for parallel initialization
    final results = await parallelInit;
    final prefs = results[0] as SharedPreferences;
    final languageCode =
        prefs.getString('languageCode') ?? AppConfig.defaultLanguageCode;

    // Wait for shader warmup to complete
    await shaderWarmup;

    // Initialize audio service with custom handler (no stop button in notification)
    final eq = AndroidEqualizer();
    equalizer = eq;
    final player = AudioPlayer(
      audioPipeline: AudioPipeline(androidAudioEffects: [eq]),
    );
    audioHandler = await AudioService.init(
      builder: () => AuroraAudioHandler(player),
      config: const AudioServiceConfig(
        androidNotificationChannelId: AppConfig.androidNotificationChannelId,
        androidNotificationChannelName:
            AppConfig.androidNotificationChannelName,
        androidStopForegroundOnPause: false,
        // Monochrome status-bar notification icon (white silhouette on transparent).
        androidNotificationIcon: 'drawable/ic_stat_music',
      ),
    );

    // Launch the application with all required providers
    await SentryFlutter.init(
    (options) {
      options.dsn = const String.fromEnvironment('SENTRY_DSN');
      options.tracesSampleRate = 0.2;
      // ignore: experimental_member_use
      options.profilesSampleRate = 0.2;
    },
    appRunner: () {
      final app = MultiProvider(
        providers: [
          // Use lazy initialization for better startup performance
          ChangeNotifierProvider(create: (_) => AudioPlayerService()),
          ChangeNotifierProvider(create: (_) => ThemeProvider(), lazy: false),
          ChangeNotifierProvider(create: (_) => EqualizerService(), lazy: false),
          ChangeNotifierProvider(
              create: (_) => PerformanceModeProvider(), lazy: false),
          ChangeNotifierProvider(
              create: (_) => BackgroundManagerService(), lazy: false),
          ChangeNotifierProvider(
              create: (_) => SleepTimerController(), lazy: true),
          ChangeNotifierProvider.value(value: ArtistSeparatorService()),
          ChangeNotifierProvider.value(value: HomeLayoutService()),
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

            // Initialize performance provider and equalizer eagerly
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              performanceProvider.initialize();
              final equalizerService =
                  Provider.of<EqualizerService>(context, listen: false);
              if (!equalizerService.initialized) {
                await equalizerService.init(equalizer);
              }
            });

            return MyApp(
              languageCode: languageCode,
            );
          },
        ),
      );
      return runApp(
        SentryWidget(
          child: app,
        ),
      );
    });
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
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  late ui.Locale _locale;
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  late final FirebaseAnalyticsObserver _analyticsObserver;
  StreamSubscription<bool>? _notificationClickSub;

  @override
  void initState() {
    super.initState();
    _locale = ui.Locale(widget.languageCode);
    _analyticsObserver = FirebaseAnalyticsObserver(analytics: _analytics);
    WidgetsBinding.instance.addObserver(this);

    // Listen for notification clicks to expand the player
    _notificationClickSub =
        AudioService.notificationClicked.listen((clicked) {
      if (clicked) {
        // Expand the mini player to show Now Playing screen
        ExpandingPlayer.expand();
      }
    });
  }

  @override
  void dispose() {
    _notificationClickSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // When app comes back to foreground, sync playback state
    // This ensures UI reflects any changes made via lock screen controls
    if (state == AppLifecycleState.resumed) {
      try {
        final audioService =
            Provider.of<AudioPlayerService>(context, listen: false);
        audioService.syncPlaybackState();
        // Two-way sync playlists with the configured folder (no-op if unset).
        unawaited(audioService.syncPlaylistsWithFolder());
      } catch (e) {
        // Ignore errors if context is not available
      }
    }

    // When app is detached (swiped from recents), stop audio and clean up
    if (state == AppLifecycleState.detached) {
      _cleanupAndExit();
    }
  }

  Future<void> _cleanupAndExit() async {
    try {
      final audioService =
          Provider.of<AudioPlayerService>(context, listen: false);
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
            navigatorKey: navigatorKey,
            debugShowCheckedModeBanner: false,
            locale: _locale,
            themeMode: ThemeMode.dark,
            darkTheme: themeProvider.darkTheme,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
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
            // The root navigator's single page is the app shell: an inner page
            // navigator with the mini player painted directly above it. Dialogs,
            // menus and sheets are pushed onto the root navigator (sheets use
            // `useRootNavigator: true`), so they render above the mini player,
            // while normal pages — hosted by the inner navigator — render below
            // it. This separation is what keeps the mini player layered
            // correctly without fighting the navigator's overlay ordering.
            home: _AppShell(observers: [_analyticsObserver]),
          ),
        );
      },
    );
  }
}

/// The app shell: an inner page [Navigator] with the mini player painted on
/// top of it. The inner navigator hosts every full-screen page; the mini
/// player floats above those pages. Because dialogs/menus/sheets are pushed
/// onto the *root* navigator (above this whole shell), they always cover the
/// mini player.
class _AppShell extends StatefulWidget {
  final List<NavigatorObserver> observers;

  const _AppShell({required this.observers});

  @override
  State<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<_AppShell> {
  // The inner navigator needs its own hero controller so hero animations work
  // between pages (the root navigator has a separate one from MaterialApp).
  final HeroController _heroController = HeroController(
    createRectTween: (Rect? begin, Rect? end) =>
        MaterialRectCenterArcTween(begin: begin, end: end),
  );

  @override
  void dispose() {
    _heroController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Page layer — every full-screen route lives here, below the mini player.
        Positioned.fill(
          child: NavigatorPopHandler(
            // System back: when the root navigator has nothing to pop (no
            // dialog/sheet open), forward the gesture to the inner navigator.
            onPop: () => pageNavigatorKey.currentState?.maybePop(),
            child: HeroControllerScope(
              controller: _heroController,
              child: Navigator(
                key: pageNavigatorKey,
                observers: widget.observers,
                onGenerateRoute: (settings) => MaterialPageRoute<void>(
                  settings: settings,
                  builder: (_) => const SplashScreen(),
                ),
              ),
            ),
          ),
        ),
        // Mini player layer — floats above pages, below root-navigator popups.
        const Positioned.fill(child: ExpandingPlayer()),
      ],
    );
  }
}
