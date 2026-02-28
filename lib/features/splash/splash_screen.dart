import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:ui';
import 'dart:math' as math;
import '../../shared/services/audio_player_service.dart';
import '../../shared/services/artwork_cache_service.dart';
import '../../shared/services/user_preferences.dart';
import '../../shared/services/logging_service.dart';
import '../../core/constants/animation_constants.dart';
import '../../core/constants/font_constants.dart';
import '../onboarding/screens/onboarding_screen.dart';
import '../home/screens/home_screen.dart';
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

  Future<void> _initializeApp() async {
    try {
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
        final result = await InternetAddress.lookup('api.discogs.com');
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
        final staticImages = ['assets/images/logo/default_art.png'];

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
      final staticImages = ['assets/images/logo/default_art.png'];

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
    final PackageInfo packageInfo = await PackageInfo.fromPlatform();
    final String codeName = dotenv.env['CODE_NAME'] ?? 'Unknown';

    setState(() {
      _versionNumber = packageInfo.version;
      _codeName = codeName;
    });
  }

  void _initializeAnimations() {
    // Primary controller drives the Lottie animation
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    // Transition controller for exit
    _transitionController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );

    // Logo shrinks slightly on exit
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.88,
    ).animate(CurvedAnimation(
      parent: _transitionController,
      curve: Curves.easeInCubic,
    ));

    // Whole splash fades out on exit
    _backgroundFadeAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _transitionController,
      curve: Curves.easeIn,
    ));

    _fadeController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (mounted) {
          setState(() => _isAnimationComplete = true);
          _checkAndTransition();
        }
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
      _transitionController.forward();
    }
  }

  Future<void> _performActualTransition() async {
    final bool isFirstTime = await UserPreferences.isFirstTimeUser();

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
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF080B14),
      body: AnimatedBuilder(
        animation: Listenable.merge([_fadeController, _transitionController]),
        builder: (context, _) {
          final fade = _backgroundFadeAnimation.value;
          return Opacity(
            opacity: fade,
            child: Stack(
              children: [
                // ── Background ──────────────────────────────────────────────
                Positioned.fill(child: _buildBackground(size)),

                // ── Ambient orbs ────────────────────────────────────────────
                _buildOrb(
                  size: size,
                  alignment: const Alignment(-0.6, -0.55),
                  color: const Color(0xFF6C3FD4),
                  radius: 220,
                  blur: 80,
                ),
                _buildOrb(
                  size: size,
                  alignment: const Alignment(0.7, 0.4),
                  color: const Color(0xFF1E3FBF),
                  radius: 180,
                  blur: 80,
                ),
                _buildOrb(
                  size: size,
                  alignment: const Alignment(0.1, 0.65),
                  color: const Color(0xFF8B2FC9),
                  radius: 120,
                  blur: 60,
                ),

                // ── Noise / grain overlay ────────────────────────────────────
                Positioned.fill(
                  child: Opacity(
                    opacity: 0.04,
                    child: CustomPaint(painter: _NoisePainter()),
                  ),
                ),

                // ── Lottie animation (centre) ─────────────────────────────
                Center(
                  child: Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Hero(
                      tag: 'app_logo_hero',
                      child: RepaintBoundary(
                        child: Lottie.asset(
                          'assets/animations/Splash.json',
                          controller: _fadeController,
                          fit: BoxFit.contain,
                          width: 300,
                          height: 300,
                          frameRate: FrameRate.composition,
                          onLoaded: (composition) {
                            _fadeController.duration = composition.duration;
                            _fadeController.forward();
                          },
                        ),
                      ),
                    ),
                  ),
                ),

                // ── Bottom area: progress + version ──────────────────────
                Positioned(
                  left: 40,
                  right: 40,
                  bottom: 56,
                  child: AnimatedOpacity(
                    opacity: _isTransitioning ? 0.0 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Task label
                        if (_currentTask.isNotEmpty && _progress < 1.0)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              _currentTask,
                              style: const TextStyle(
                                fontFamily: FontConstants.fontFamily,
                                color: Color(0xFF6B7080),
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                                letterSpacing: 0.4,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),

                        // Progress bar — pill shape, glassy
                        _GlassProgressBar(progress: _progress),

                        const SizedBox(height: 20),

                        // Version chip
                        if (_versionNumber.isNotEmpty)
                          _VersionChip(
                            version: _versionNumber,
                            codeName: _codeName,
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Helper: full-screen gradient background ──────────────────────────────
  Widget _buildBackground(Size size) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.3),
          radius: 1.4,
          colors: [
            Color(0xFF12172A),
            Color(0xFF080B14),
          ],
        ),
      ),
    );
  }

  // ── Helper: soft ambient orb ─────────────────────────────────────────────
  Widget _buildOrb({
    required Size size,
    required Alignment alignment,
    required Color color,
    required double radius,
    required double blur,
  }) {
    return Positioned.fill(
      child: Align(
        alignment: alignment,
        child: ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            width: radius * 2,
            height: radius * 2,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.28),
            ),
          ),
        ),
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

// ── Glassmorphic progress bar ─────────────────────────────────────────────────
class _GlassProgressBar extends StatelessWidget {
  final double progress;
  const _GlassProgressBar({required this.progress});

  @override
  Widget build(BuildContext context) {
    return Container(
          height: 3,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(100),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: progress.clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(100),
                gradient: const LinearGradient(
                  colors: [Color(0xFF9B73F0), Color(0xFF6C8FED)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7B5FDC).withOpacity(0.6),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
          ),
    );
  }
}

// ── Version chip ──────────────────────────────────────────────────────────────
class _VersionChip extends StatelessWidget {
  final String version;
  final String codeName;
  const _VersionChip({required this.version, required this.codeName});

  @override
  Widget build(BuildContext context) {
    final label = codeName.isNotEmpty ? 'v$version · $codeName' : 'v$version';
    return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
            ),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: FontConstants.fontFamily,
              color: Color(0xFF5A5F74),
              fontSize: 11,
              fontWeight: FontWeight.w400,
              letterSpacing: 0.6,
            ),
          ),
    );
  }
}

// ── Subtle grain/noise texture overlay ───────────────────────────────────────
class _NoisePainter extends CustomPainter {
  static final math.Random _rng = math.Random(42);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;
    // Sparse dot grid for a film-grain feel — cheap and fast
    for (int i = 0; i < 600; i++) {
      canvas.drawCircle(
        Offset(
          _rng.nextDouble() * size.width,
          _rng.nextDouble() * size.height,
        ),
        0.6,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
