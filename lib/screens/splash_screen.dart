import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:ui'; // Import this for ImageFilter
import '../services/audio_player_service.dart';
import '../services/artwork_cache_service.dart';
import '../services/user_preferences.dart';
import '../services/logging_service.dart';
import '../constants/animation_constants.dart';
import 'onboarding/onboarding_screen.dart';
import 'home_screen.dart';
import 'package:provider/provider.dart';
import 'dart:io';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _transitionController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _backgroundFadeAnimation;
  String _versionNumber = '';
  String _codeName = '';
  bool _isDataLoaded = false;
  bool _isAnimationComplete = false;
  bool _isTransitioning = false;
  bool _didInitialize = false;
  String _currentTask = '';
  final List<String> _completedTasks = [];
  double _progress = 0.0;
  final List<String> _warnings = [];
  bool _hasConnectivityIssues = false;

  @override
  void initState() {
    super.initState();

    _initializeAnimations();
    _loadVersionInfo();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_didInitialize) {
      _didInitialize = true;

      _initializeApp();
    }
  }

  // Permission requests moved to onboarding flow
  // This prevents startup crashes and improves UX
  /*
  Future<bool> _requestPermissions() async {
    try {
      if (Platform.isWindows) {
        // Windows doesn't need audio permissions
        return true;
      }
      
      // Android permission logic
      final permissionStatus = await OnAudioQuery().permissionsStatus();
      if (!permissionStatus) {
        final granted = await OnAudioQuery().permissionsRequest();
        if (!granted) {
          if (mounted) {
            await showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => AlertDialog(
                title: const Text('Required Permissions'),
                content: const Text(
                  'The app needs access to your music library to function properly. '
                  'Please grant permissions in the app settings.',
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      SystemNavigator.pop();
                    },
                    child: const Text('Exit'),
                  ),
                  TextButton(
                    onPressed: () {
                      openAppSettings();
                    },
                    child: const Text('Open Settings'),
                  ),
                ],
              ),
            );
          }
          return false;
        }
      }
      await Future.delayed(const Duration(milliseconds: 100));
      return true;
    } catch (e) {
      return false;
    }
  }
  */

  Future<void> _initializeApp() async {
    try {
      // Skip permission requests during splash - they will be handled in onboarding

      final tasks = [
        ('Warming shaders', _warmupShaders()),
        ('Initializing Services', _initializeServices()),
        ('Loading Library', _loadAppData()),
        ('Caching Artwork', _preloadImages()),
        ('Final Preparations', _finalizeInitialization()),
      ];

      for (int i = 0; i < tasks.length; i++) {
        if (!mounted) return;

        final task = tasks[i];
        // Batch update: progress, current task, and completed tasks together
        setState(() {
          _currentTask = task.$1;
          _progress = i / tasks.length;
        });

        try {
          await task.$2;
          if (mounted) {
            // Batch completed task update
            setState(() {
              _completedTasks.add(task.$1);
            });
          }
        } catch (e) {
          LoggingService.error('Task failed: ${task.$1}', 'SplashScreen', e);
          // Only show warnings for critical errors
          if (task.$1 != 'Setting up Analytics') {
            if (mounted) {
              // Batch update: warnings and connectivity issues together
              setState(() {
                _warnings.add('Issue with ${task.$1.toLowerCase()}');
                _hasConnectivityIssues = true;
              });
            }
            await Future.delayed(const Duration(seconds: 1));
          }
          continue;
        }
      }

      if (_hasConnectivityIssues && _warnings.isNotEmpty) {
        await Future.delayed(const Duration(seconds: 2));
      }

      if (mounted) {
        // Batch final state update
        setState(() {
          _currentTask = 'Complete';
          _progress = 1.0;
          _isDataLoaded = true;
        });
        // Check if animation is also complete, then transition
        _checkAndTransition();
      }
    } catch (e) {
      LoggingService.error('Initialization error', 'SplashScreen', e);
      if (!_warnings.contains('Some features may be limited')) {
        _warnings.add('Some features may be limited');
      }
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        setState(() {
          _isDataLoaded = true;
        });
        _checkAndTransition();
      }
    }
  }

  Future<void> _initializeServices() async {
    try {
      // First check general internet connectivity
      try {
        final result = await InternetAddress.lookup('google.com');
        if (result.isEmpty || result[0].rawAddress.isEmpty) {
          throw Exception('No internet connection');
        }
      } catch (e) {
        // Batch update for connectivity warnings
        setState(() {
          _warnings.add('No internet connection');
          _warnings.add('Offline mode active');
          _hasConnectivityIssues = true;
        });
        await Future.delayed(const Duration(seconds: 1));
        return;
      }

      // Test image service connectivity
      try {
        final result = await InternetAddress.lookup('api.deezer.com');
        if (result.isEmpty || result[0].rawAddress.isEmpty) {
          throw Exception('Image service unavailable');
        }
      } catch (e) {
        // Single state update for default artwork warning
        setState(() {
          _warnings.add('Using default artwork');
        });
        await Future.delayed(const Duration(milliseconds: 800));
      }
    } catch (e) {
      if (!_warnings.contains('Some features may be limited')) {
        // Batch update for error warnings
        setState(() {
          _warnings.add('Some features may be limited');
          _hasConnectivityIssues = true;
        });
        await Future.delayed(const Duration(seconds: 1));
      }
    }
  }

  Future<void> _loadAppData() async {
    try {
      // Don't try to access media library in splash screen anymore
      // Just show loading animation and move on
      // The actual initialization is now handled in home_screen.dart

      // Just a short delay for animation
      await Future.delayed(const Duration(milliseconds: 500));
    } catch (e) {
      debugPrint('Error in splash screen: $e');
    }
  }

  Future<void> _preloadImages() async {
    if (!mounted) return;

    try {
      final artworkService = ArtworkCacheService();
      final audioPlayerService = context.read<AudioPlayerService>();

      // For Windows, we'll only preload static images
      if (Platform.isWindows) {
        final staticImages = [
          'assets/images/background/Bcg_V0.0.9.png',
          'assets/images/logo/default_art.png',
        ];

        for (final image in staticImages) {
          if (!mounted) return;
          await precacheImage(AssetImage(image), context);
        }
        return;
      }

      // Only preload artwork from songs already loaded in audioPlayerService
      // Don't query for additional songs or artists
      if (audioPlayerService.songs.isNotEmpty) {
        final songsToPreload = audioPlayerService.songs.take(10).toList();
        for (final song in songsToPreload) {
          await artworkService.preloadArtwork(song.id);
        }
      }

      // Don't query for artists directly - removed artist preloading
      // This prevents permission errors

      // Load static images
      final staticImages = [
        'assets/images/background/Bcg_V0.0.9.png',
        'assets/images/logo/default_art.png',
      ];

      for (final image in staticImages) {
        if (!mounted) return;
        await precacheImage(AssetImage(image), context);
      }
    } catch (e) {}
  }

  Future<void> _finalizeInitialization() async {
    // Pre-warm home screen components for smooth transition
    await _preWarmHomeScreen();

    // Reduced delay for faster initialization
    await Future.delayed(AnimationConstants.shortDelay);
  }

  /// Pre-warm home screen components to prevent transition lag
  Future<void> _preWarmHomeScreen() async {
    if (!mounted) return;

    try {
      // Pre-compile common shaders used in home screen
      await _warmupHomeScreenShaders();

      // Pre-cache essential images
      final homeImages = [
        'assets/images/UI/liked_icon.png',
        'assets/images/logo/default_art.png',
      ];

      for (final image in homeImages) {
        if (!mounted) return;
        try {
          await precacheImage(AssetImage(image), context);
        } catch (e) {
          // Continue if individual image fails
        }
      }

      // Pre-initialize providers that home screen will need
      if (mounted) {
        final audioService = context.read<AudioPlayerService>();
        // Ensure the service is ready
        audioService.toString(); // Just access it to ensure it's initialized
      }
    } catch (e) {
      // Don't block transition if pre-warming fails
    }
  }

  Future<void> _warmupHomeScreenShaders() async {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);

    // Warm up glassmorphism effects
    final glassPaint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(0, 0, 100, 100), const Radius.circular(12)),
      glassPaint,
    );

    // Warm up gradient effects
    final gradientPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Colors.purple, Colors.blue],
      ).createShader(const Rect.fromLTWH(0, 0, 100, 100));
    canvas.drawRect(const Rect.fromLTWH(0, 0, 100, 100), gradientPaint);

    final picture = recorder.endRecording();
    await picture.toImage(100, 100);
    picture.dispose();
  }

  Future<void> _loadVersionInfo() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    String codeName = dotenv.env['CODE_NAME'] ?? 'Unknown';

    setState(() {
      _versionNumber = packageInfo.version;
      _codeName = codeName;
    });
  }

  void _initializeAnimations() {
    // Primary fade controller for splash animation
    // Duration will be set by Lottie onLoaded callback
    _fadeController = AnimationController(
      duration:
          const Duration(milliseconds: 2000), // Default, will be overridden
      vsync: this,
    );

    // Transition controller for smooth screen transition
    _transitionController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    // Scale animation for logo - subtle breathing effect
    _scaleAnimation = Tween<double>(
      begin: 0.85,
      end: 0.75,
    ).animate(CurvedAnimation(
      parent: _transitionController,
      curve: Curves.easeInCubic,
    ));

    // Background fade for smooth transition
    _backgroundFadeAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _transitionController,
      curve: Curves.easeIn,
    ));

    _fadeController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        // Wait a brief moment after Lottie animation completes
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            setState(() {
              _isAnimationComplete = true;
            });
            _checkAndTransition();
          }
        });
      }
    });

    _transitionController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _performActualTransition();
      }
    });
  }

  void _checkAndTransition() {
    // Only transition when BOTH conditions are met:
    // 1. Lottie animation has completed
    // 2. App data/initialization is finished
    if (_isAnimationComplete && _isDataLoaded && !_isTransitioning) {
      setState(() {
        _isTransitioning = true;
      });
      // Small delay to let user appreciate the completed animation
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) {
          _transitionController.forward();
        }
      });
    }
  }

  Future<void> _performActualTransition() async {
    bool isFirstTime = await UserPreferences.isFirstTimeUser();

    if (mounted) {
      if (isFirstTime) {
        _navigateToScreenWithHero(const OnboardingScreen());
      } else {
        _navigateToScreenWithHero(const HomeScreen());
      }
    }
  }

  void _navigateToScreenWithHero(Widget screen) {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        opaque: true,
        pageBuilder: (context, animation, secondaryAnimation) => screen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          // Smooth crossfade with zoom-in effect
          final fadeAnimation = Tween<double>(
            begin: 0.0,
            end: 1.0,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: const Interval(0.3, 1.0, curve: Curves.easeInOut),
          ));

          final scaleAnimation = Tween<double>(
            begin: 1.15,
            end: 1.0,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: const Interval(0.0, 1.0, curve: Curves.easeOutCubic),
          ));

          return FadeTransition(
            opacity: fadeAnimation,
            child: ScaleTransition(
              scale: scaleAnimation,
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 900),
        reverseTransitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _transitionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: AnimatedBuilder(
        animation: Listenable.merge([_fadeController, _transitionController]),
        builder: (context, child) {
          return Stack(
            children: [
              // Gradient background with fade
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _backgroundFadeAnimation,
                  builder: (context, _) {
                    return Opacity(
                      opacity: _backgroundFadeAnimation.value,
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF0A0E1A),
                              Color(0xFF1A2332),
                              Color(0xFF0D1B2A),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Animated logo with modern scaling
              Center(
                child: AnimatedBuilder(
                  animation: _scaleAnimation,
                  builder: (context, _) {
                    return Transform.scale(
                      scale: _scaleAnimation.value,
                      child: Opacity(
                        opacity: _backgroundFadeAnimation.value,
                        child: Hero(
                          tag: 'app_logo_hero',
                          child: RepaintBoundary(
                            child: Lottie.asset(
                              'assets/animations/Splash.json',
                              controller: _fadeController,
                              fit: BoxFit.contain,
                              width: 220,
                              height: 220,
                              frameRate: FrameRate.composition,
                              onLoaded: (composition) {
                                _fadeController.duration = composition.duration;
                                _fadeController.forward();
                              },
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Modern progress indicator
              if (!_isAnimationComplete || _progress < 1.0)
                Positioned(
                  bottom: 100,
                  left: 48,
                  right: 48,
                  child: AnimatedOpacity(
                    opacity: _isTransitioning
                        ? 0.0
                        : (_backgroundFadeAnimation.value * 0.8),
                    duration: const Duration(milliseconds: 200),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_currentTask.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 20),
                            child: Text(
                              _currentTask,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.6),
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                                letterSpacing: 0.3,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: SizedBox(
                            height: 3,
                            child: LinearProgressIndicator(
                              value: _progress,
                              backgroundColor: Colors.white.withOpacity(0.1),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white.withOpacity(0.7),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Minimalist version info
              Positioned(
                bottom: 32,
                left: 0,
                right: 0,
                child: AnimatedOpacity(
                  opacity: _isTransitioning
                      ? 0.0
                      : (_backgroundFadeAnimation.value * 0.5),
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    '$_versionNumber • $_codeName',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 11,
                      fontWeight: FontWeight.w300,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _warmupShaders() async {
    // Simplified shader warmup for better performance on low-end devices
    const size = Size(25, 25); // Even smaller size for faster warmup
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint();

    // Simple gradient warmup - essential for UI performance
    paint.shader = LinearGradient(
      colors: [Colors.white, Colors.white.withOpacity(0.0)],
      stops: const [0.8, 1.0],
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

    // Skip blur warmup on low-performance devices to speed up initialization
    try {
      final picture = recorder.endRecording();
      await picture.toImage(size.width.toInt(), size.height.toInt());
      picture.dispose();
    } catch (e) {
      // If shader warmup fails, continue silently
    }
  }
}
