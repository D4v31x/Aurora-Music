import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'dart:ui';
import '../../shared/services/audio_player_service.dart';
import '../../shared/services/artist_aggregator_service.dart';
import '../../shared/services/artwork_cache_service.dart';
import '../../shared/services/user_preferences.dart';
import '../../shared/services/logging_service.dart';
import '../../core/constants/font_constants.dart';
import '../onboarding/screens/onboarding_screen.dart';
import '../home/screens/home_screen.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../shared/widgets/expanding_player.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _transitionController;
  late Animation<double> _logoFadeAnimation;
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
  static const Duration _minimumSplashDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    ExpandingPlayer.hiddenNotifier.value = true;
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
      final startedAt = DateTime.now();
      final tasks = <(String, Future<void> Function())>[
        ('Warming shaders', _warmupShaders),
        ('Initializing Services', _initializeServices),
        ('Loading Library', _loadAppData),
        ('Preparing Home', _prepareHomeData),
        ('Caching Artwork', _preloadImages),
        ('Final Preparations', _finalizeInitialization),
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
          await task.$2();
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

      await _waitForMinimumSplashDuration(startedAt);

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
      // Check network interface connectivity without pinging external hosts
      try {
        final result = await Connectivity().checkConnectivity();
        if (result.isEmpty ||
            result.every((r) => r == ConnectivityResult.none)) {
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
      if (!mounted) return;
      final audioPlayerService = context.read<AudioPlayerService>();
      await audioPlayerService.initializeMusicLibrary();
    } catch (e) {
      debugPrint('Error in splash screen: $e');
    }
  }

  Future<void> _prepareHomeData() async {
    if (!mounted) return;

    final audioPlayerService = context.read<AudioPlayerService>();
    if (!audioPlayerService.isLibraryInitialized ||
        audioPlayerService.songs.isEmpty) {
      return;
    }

    await Future.wait<void>([
      _boundedPreparation(
        audioPlayerService.getSuggestedTracks().then((_) {}),
      ),
      _boundedPreparation(
        audioPlayerService.getSuggestedArtists(count: 5).then((_) {}),
      ),
      _boundedPreparation(
        ArtistAggregatorService().getAllArtists().then((_) {}),
      ),
    ]);
  }

  Future<void> _boundedPreparation(Future<void> future) async {
    try {
      await future.timeout(const Duration(seconds: 4));
    } catch (_) {}
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

      if (audioPlayerService.songs.isNotEmpty) {
        final songsToPreload = [
          if (audioPlayerService.currentSong != null)
            audioPlayerService.currentSong!,
          ...audioPlayerService.songs.take(18),
        ];
        final seenIds = <int>{};
        final uniqueSongs = songsToPreload
            .where((song) => seenIds.add(song.id))
            .toList(growable: false);

        for (var i = 0; i < uniqueSongs.length; i += 4) {
          if (!mounted) return;
          final chunk = uniqueSongs.skip(i).take(4);
          await Future.wait(
              chunk.map((song) => artworkService.preloadArtwork(song.id)));
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
    } catch (_) {}
  }

  Future<void> _finalizeInitialization() async {
    // Pre-warm home screen components for smooth transition
    await _preWarmHomeScreen();
  }

  Future<void> _waitForMinimumSplashDuration(DateTime startedAt) async {
    final elapsed = DateTime.now().difference(startedAt);
    final remaining = _minimumSplashDuration - elapsed;
    if (remaining > Duration.zero) {
      await Future.delayed(remaining);
    }
  }

  /// Pre-warm home screen components to prevent transition lag
  Future<void> _preWarmHomeScreen() async {
    if (!mounted) return;

    try {
      // Pre-compile common shaders used in home screen
      await _warmupHomeScreenShaders();

      // Pre-cache essential images
      final homeImages = [
        'assets/images/UI/liked.png',
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
      ..color = Colors.white.withValues(alpha: 0.1)
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
    const String codeName =
        String.fromEnvironment('CODE_NAME', defaultValue: 'Unknown');

    setState(() {
      _versionNumber = packageInfo.version;
      _codeName = codeName;
    });
  }

  void _initializeAnimations() {
    // Primary controller drives a simple logo fade-in.
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // Logo gently fades in.
    _logoFadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
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

    // Start the logo fade-in immediately.
    _fadeController.forward();
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
    if (screen is HomeScreen) ExpandingPlayer.hiddenNotifier.value = false;
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

                // ── Logo (centre) ─────────────────────────────────────────
                Center(
                  child: Transform.scale(
                    scale: _scaleAnimation.value,
                    child: FadeTransition(
                      opacity: _logoFadeAnimation,
                      child: Hero(
                        tag: 'app_logo_hero',
                        child: Image.asset(
                          'assets/images/logo/Music_full_logo.png',
                          fit: BoxFit.contain,
                          width: size.width * 0.5,
                          filterQuality: FilterQuality.high,
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

                        // Progress bar — matches the library refresh line, but thicker
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

  // ── Helper: full-screen mesh-gradient background ─────────────────────────
  // A smoky blurred-artwork mesh inspired by dark album covers: charcoal depth,
  // silver haze and crimson light bands melting through the middle.
  Widget _buildBackground(Size size) {
    final width = size.width;
    final height = size.height;
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Color(0xFF151515)),
        Positioned.fill(
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 95, sigmaY: 95),
            child: Stack(
              children: [
                _meshOval(
                  width * 1.15,
                  height * 0.42,
                  top: -height * 0.14,
                  right: -width * 0.22,
                  color: const Color(0xFFECECEA),
                ),
                _meshOval(
                  width * 1.05,
                  height * 0.36,
                  top: height * 0.30,
                  left: -width * 0.32,
                  color: const Color(0xFFFF254C),
                ),
                _meshOval(
                  width * 1.05,
                  height * 0.34,
                  top: height * 0.27,
                  right: -width * 0.18,
                  color: const Color(0xFFFF355C),
                  alpha: 0.90,
                ),
                _meshOval(
                  width * 1.10,
                  height * 0.48,
                  top: height * 0.18,
                  left: width * 0.18,
                  color: const Color(0xFF171717),
                  alpha: 1.0,
                ),
                _meshOval(
                  width * 0.95,
                  height * 0.28,
                  bottom: height * 0.12,
                  left: -width * 0.10,
                  color: const Color(0xFF9B9B96),
                  alpha: 0.72,
                ),
                _meshOval(
                  width * 1.05,
                  height * 0.42,
                  bottom: -height * 0.15,
                  left: -width * 0.28,
                  color: const Color(0xFFE3E3E0),
                  alpha: 0.84,
                ),
                _meshOval(
                  width * 1.18,
                  height * 0.45,
                  bottom: -height * 0.12,
                  right: -width * 0.16,
                  color: const Color(0xFF101010),
                  alpha: 1.0,
                ),
              ],
            ),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.black.withValues(alpha: 0.24),
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.35),
                ],
                stops: const [0.0, 0.45, 1.0],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // A soft oval used to shape wide blurred colour bands.
  Widget _meshOval(
    double ovalWidth,
    double ovalHeight, {
    double? top,
    double? left,
    double? right,
    double? bottom,
    required Color color,
    double alpha = 0.95,
  }) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      bottom: bottom,
      child: Container(
        width: ovalWidth,
        height: ovalHeight,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(ovalHeight),
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: alpha),
              color.withValues(alpha: 0.0),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helper: shader warmup ────────────────────────────────────────────────
  Future<void> _warmupShaders() async {
    // Simplified shader warmup for better performance on low-end devices
    const size = Size(25, 25); // Even smaller size for faster warmup
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint();

    // Simple gradient warmup - essential for UI performance
    paint.shader = LinearGradient(
      colors: [Colors.white, Colors.white.withValues(alpha: 0.0)],
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

// ── Splash progress bar ───────────────────────────────────────────────────────
class _GlassProgressBar extends StatelessWidget {
  final double progress;
  const _GlassProgressBar({required this.progress});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: progress.clamp(0.0, 1.0)),
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return SizedBox(
          width: double.infinity,
          height: 8,
          child: CustomPaint(
            painter: _SplashProgressPainter(
              progress: value,
              lineColor: Colors.white,
              lineHeight: 6,
            ),
          ),
        );
      },
    );
  }
}

class _SplashProgressPainter extends CustomPainter {
  final double progress;
  final Color lineColor;
  final double lineHeight;

  const _SplashProgressPainter({
    required this.progress,
    required this.lineColor,
    required this.lineHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    final inset = lineHeight / 2;
    final start = Offset(inset, y);
    final end = Offset(size.width - inset, y);
    final usableWidth = (size.width - lineHeight).clamp(0.0, double.infinity);

    final backgroundPaint = Paint()
      ..color = lineColor.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = lineHeight
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(start, end, backgroundPaint);

    if (progress <= 0) return;

    final foregroundPaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = lineHeight
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      start,
      Offset(inset + usableWidth * progress.clamp(0.0, 1.0), y),
      foregroundPaint,
    );
  }

  @override
  bool shouldRepaint(_SplashProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.lineHeight != lineHeight;
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
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
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
