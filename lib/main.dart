import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'dart:ui' as ui;

import 'core/constants/app_config.dart';
import 'shared/services/audio_player_service.dart';
import 'shared/services/audio_handler.dart';
import 'shared/services/shader_warmup_service.dart';
import 'shared/services/background_manager_service.dart';
import 'shared/services/sleep_timer_controller.dart';
import 'shared/services/artist_separator_service.dart';
import 'shared/services/home_layout_service.dart';
import 'l10n/generated/app_localizations.dart';
import 'features/features.dart';
import 'l10n/locale_provider.dart';
import 'shared/providers/providers.dart';
import 'shared/widgets/performance_debug_overlay.dart';
import 'shared/widgets/expanding_player.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

late AuroraAudioHandler audioHandler;

/// App entry point
void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();

    // Silence debug output in release builds
    if (!kDebugMode) {
      debugPrint = (String? message, {int? wrapWidth}) {};
    }

    ImageCache().maximumSize = AppConfig.imageCacheMaxSize;
    ImageCache().maximumSizeBytes = AppConfig.imageCacheMaxSizeBytes;

    final parallelInit = Future.wait([
      SharedPreferences.getInstance(),
      ArtistSeparatorService().initialize(),
      HomeLayoutService().initialize(),
    ]);

    final shaderWarmup = ShaderWarmupService.warmupShaders();
    final results = await parallelInit;
    final prefs = results[0] as SharedPreferences;
    final languageCode =
        prefs.getString('languageCode') ?? AppConfig.defaultLanguageCode;

    await shaderWarmup;

    final player = AudioPlayer();
    audioHandler = await AudioService.init(
      builder: () => AuroraAudioHandler(player),
      config: const AudioServiceConfig(
        androidNotificationChannelId: AppConfig.androidNotificationChannelId,
        androidNotificationChannelName:
            AppConfig.androidNotificationChannelName,
        androidStopForegroundOnPause: false,
        androidNotificationIcon: 'drawable/ic_stat_music',
      ),
    );

    // Launch the application with all required providers
    await SentryFlutter.init(
    (options) {
      options.dsn = const String.fromEnvironment('SENTRY_DSN');
      options.tracesSampleRate = 0.2;
      options.profilesSampleRate = 0.2;
    },
    appRunner: () => runApp(SentryWidget(child: 
      MultiProvider(
          providers: [
            ChangeNotifierProvider(
              create: (_) => AudioPlayerService()
              ),
            ChangeNotifierProvider(
              create: (_) => ThemeProvider(), lazy: false
              ),
            ChangeNotifierProvider(
              create: (_) => PerformanceModeProvider(), lazy: false
              ),
            ChangeNotifierProvider(
              create: (_) => BackgroundManagerService(), lazy: false
              ),
            ChangeNotifierProvider(
              create: (_) => SleepTimerController(), lazy: true
              ),
            ChangeNotifierProvider.value(value: ArtistSeparatorService()),
            ChangeNotifierProvider.value(value: HomeLayoutService()),
          ],
          child: Builder(
              builder: (context) {
                final audioPlayerService =
                  Provider.of<AudioPlayerService>(context, listen: false);
              final backgroundManager =
                  Provider.of<BackgroundManagerService>(context, listen: false);
              final performanceProvider =
                  Provider.of<PerformanceModeProvider>(context, listen: false);

              audioPlayerService.setBackgroundManager(backgroundManager);

              WidgetsBinding.instance.addPostFrameCallback((_) {
                performanceProvider.initialize();
              });

              return MyApp(
                languageCode: languageCode,
              );
            },
          ),
        ),
    )));
  } catch (e, stack) {
    debugPrint('Fatal error during app initialization: $e\n$stack');
    rethrow;
  }
}
class _MiniPlayerObserver extends NavigatorObserver {
  int _popupCount = 0;

  void _update() {
    ExpandingPlayer.popupActiveNotifier.value = _popupCount > 0;
  }

  @override
  void didPush(Route route, Route? previousRoute) {
    if (route is PopupRoute) {
      _popupCount++;
      _update();
    }
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    if (route is PopupRoute) {
      _popupCount = (_popupCount - 1).clamp(0, 999);
      _update();
    }
  }

  @override
  void didRemove(Route route, Route? previousRoute) {
    if (route is PopupRoute) {
      _popupCount = (_popupCount - 1).clamp(0, 999);
      _update();
    }
  }

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) {
    if (oldRoute is PopupRoute && newRoute is! PopupRoute) {
      _popupCount = (_popupCount - 1).clamp(0, 999);
      _update();
    } else if (newRoute is PopupRoute && oldRoute is! PopupRoute) {
      _popupCount++;
      _update();
    }
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
  final _MiniPlayerObserver _miniPlayerObserver = _MiniPlayerObserver();

  @override
  void initState() {
    super.initState();
    _locale = ui.Locale(widget.languageCode);
    WidgetsBinding.instance.addObserver(this);

    // Listen for notification clicks to expand the player
    AudioService.notificationClicked.listen((clicked) {
      if (clicked) {
        // Expand the mini player to show Now Playing screen
        ExpandingPlayer.expand();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // When app comes back to foreground, sync playback state
    if (state == AppLifecycleState.resumed) {
      try {
        final audioService =
            Provider.of<AudioPlayerService>(context, listen: false);
        audioService.syncPlaybackState();
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
            navigatorObservers: [_miniPlayerObserver],
            builder: (context, child) {
              return HeroControllerScope(
                controller: HeroController(
                  createRectTween: (Rect? begin, Rect? end) {
                    return MaterialRectCenterArcTween(begin: begin, end: end);
                  },
                ),
                child: Stack(
                  children: [
                    child ?? const SizedBox.shrink(),
                    const ExpandingPlayer(),
                  ],
                ),
              );
            },
            home: Builder(
              builder: (context) {
              return const PerformanceDebugOverlay(
                child: SplashScreen(),
              );
              },
            ),
          ),
        );
      },
    );
  }
}
