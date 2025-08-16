import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui';  // Import this for ImageFilter
import '../services/audio_player_service.dart';
import '../services/artwork_cache_service.dart';
import '../services/user_preferences.dart';
import '../services/logging_service.dart';
import '../constants/animation_constants.dart';
import '../widgets/app_background.dart';
import 'setup_screen.dart';
import 'home_screen.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';


class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
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

  Future<void> _initializeApp() async {
    try {
      final hasPermissions = await _requestPermissions();
      if (!hasPermissions) return;

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
        await _checkOnboardingStatus();
      }
    } catch (e) {
      LoggingService.error('Initialization error', 'SplashScreen', e);
      if (!_warnings.contains('Some features may be limited')) {
        _warnings.add('Some features may be limited');
      }
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
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
      final audioPlayerService = context.read<AudioPlayerService>();

      if (Platform.isWindows) {
        // Windows-specific loading logic
        final directory = await getApplicationDocumentsDirectory();
        final musicDir = Directory('${directory.path}/Music');
        
        if (!await musicDir.exists()) {
          await musicDir.create(recursive: true);
        }

        final files = await musicDir.list(recursive: true)
            .where((entity) => entity is File && 
                  (entity.path.toLowerCase().endsWith('.mp3') || 
                   entity.path.toLowerCase().endsWith('.m4a') ||
                   entity.path.toLowerCase().endsWith('.wav')))
            .cast<File>()
            .toList();

        // Convert files to SongModel objects
        final List<SongModel> windowsSongs = [];
        for (final file in files) {
          final fileName = file.path.split(Platform.pathSeparator).last;
          final title = fileName.substring(0, fileName.lastIndexOf('.'));
          
          final song = SongModel({
            '_id': file.hashCode,
            'title': title,
            'artist': 'Unknown Artist',
            'album': 'Unknown Album',
            'duration': 0,
            'uri': file.path,
            '_data': file.path,
            'date_added': file.statSync().modified.millisecondsSinceEpoch,
            'is_music': 1,
            'size': file.lengthSync(),
          });
          
          windowsSongs.add(song);
        }

        await audioPlayerService.initializeWithSongs(windowsSongs);
      } else {
        // Android loading logic
        final onAudioQuery = OnAudioQuery();
        final songs = await onAudioQuery.querySongs(
          sortType: SongSortType.DATE_ADDED,
          orderType: OrderType.DESC_OR_GREATER,
        );
        await audioPlayerService.initializeWithSongs(songs);
      }

      await Future.delayed(const Duration(milliseconds: 100));
    } catch (e) {
      
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

      // Android artwork loading logic
      final onAudioQuery = OnAudioQuery();
      if (audioPlayerService.songs.isNotEmpty) {
        final songsToPreload = audioPlayerService.songs.take(30).toList();
        for (final song in songsToPreload) {
          await artworkService.preloadArtwork(song.id);
        }
      }

      final artists = await onAudioQuery.queryArtists();
      final artistsToPreload = artists.take(20).toList();
      for (final artist in artistsToPreload) {
        await artworkService.preloadArtistArtwork(artist.id);
      }

      // Load static images
      final staticImages = [
        'assets/images/background/Bcg_V0.0.9.png',
        'assets/images/logo/default_art.png',
      ];

      for (final image in staticImages) {
        if (!mounted) return;
        await precacheImage(AssetImage(image), context);
      }
    } catch (e) {
      
    }
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
      RRect.fromRectAndRadius(const Rect.fromLTWH(0, 0, 100, 100), const Radius.circular(12)),
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
    _fadeController = AnimationController(
      duration: AnimationConstants.normal,
      vsync: this,
    );
    
    // Transition controller for smooth screen transition
    _transitionController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // Scale animation for logo shrinking effect
    _scaleAnimation = Tween<double>(
      begin: AnimationConstants.scaleNormal,
      end: AnimationConstants.scaleDown,
    ).animate(CurvedAnimation(
      parent: _transitionController,
      curve: AnimationConstants.easeInOutCubic,
    ));

    // Background fade for smooth transition
    _backgroundFadeAnimation = Tween<double>(
      begin: AnimationConstants.visibleOpacity,
      end: AnimationConstants.hiddenOpacity,
    ).animate(CurvedAnimation(
      parent: _transitionController,
      curve: AnimationConstants.easeInOut,
    ));

    _fadeController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _isAnimationComplete = true;
        });
        _checkAndTransition();
      }
    });

    _transitionController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _performActualTransition();
      }
    });
  }

  void _checkAndTransition() {
    if (_isAnimationComplete && _isDataLoaded && !_isTransitioning) {
      setState(() {
        _isTransitioning = true;
      });
      // Start the smooth transition animation
      _transitionController.forward();
    }
  }

  Future<void> _performActualTransition() async {
    bool isFirstTime = await UserPreferences.isFirstTimeUser();

    if (mounted) {
      if (isFirstTime) {
        await UserPreferences.setFirstTimeUser(false);
        _navigateToScreenWithHero(const SetupScreen());
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
          // Create a more sophisticated transition
          const curve = Curves.easeInOutCubicEmphasized;
          
          // Multi-layered animation approach
          final slideAnimation = Tween<Offset>(
            begin: const Offset(0.0, 0.15), // Smaller slide for smoother feel
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Interval(0.2, 1.0, curve: curve),
          ));

          final fadeAnimation = Tween<double>(
            begin: 0.0,
            end: 1.0,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Interval(0.0, 0.8, curve: curve),
          ));

          final scaleAnimation = Tween<double>(
            begin: 0.92,
            end: 1.0,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Interval(0.1, 1.0, curve: curve),
          ));

          return FadeTransition(
            opacity: fadeAnimation,
            child: SlideTransition(
              position: slideAnimation,
              child: ScaleTransition(
                scale: scaleAnimation,
                child: child,
              ),
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 1000),
        reverseTransitionDuration: const Duration(milliseconds: 600),
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
    return AppBackground(
      enableAnimation: true,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: AnimatedBuilder(
          animation: Listenable.merge([_fadeController, _transitionController]),
          builder: (context, child) {
            return Stack(
              children: [
                // Optional overlay for splash-specific styling
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: _backgroundFadeAnimation,
                    builder: (context, _) {
                      return Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withOpacity(0.1 * _backgroundFadeAnimation.value),
                              Colors.black.withOpacity(0.3 * _backgroundFadeAnimation.value),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                
                // Splash animation logo with Hero widget for seamless transition
                Center(
                  child: AnimatedBuilder(
                    animation: _scaleAnimation,
                    builder: (context, _) {
                      return Transform.scale(
                        scale: _scaleAnimation.value,
                        child: Hero(
                          tag: 'app_logo_hero',
                          child: RepaintBoundary(
                            child: Lottie.asset(
                              'assets/animations/Splash.json',
                              controller: _fadeController,
                              fit: BoxFit.contain,
                              width: 200,
                              height: 200,
                              frameRate: FrameRate.composition, // Use original frame rate
                              onLoaded: (composition) {
                                _fadeController.duration = composition.duration;
                                _fadeController.forward();
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                
                // Progress indicator and status (only show during loading)
                if (!_isAnimationComplete || _progress < 1.0)
                  Positioned(
                    bottom: 120,
                    left: 40,
                    right: 40,
                    child: AnimatedOpacity(
                      opacity: _isTransitioning ? 0.0 : 1.0,
                      duration: const Duration(milliseconds: 300),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_currentTask.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Text(
                                _currentTask,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w300,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: _progress,
                              backgroundColor: Colors.white24,
                              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                              minHeight: 2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                
                // Version info
                Positioned(
                  bottom: 40,
                  left: 0,
                  right: 0,
                  child: AnimatedOpacity(
                    opacity: _isTransitioning ? 0.0 : 1.0,
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      '$_versionNumber • $_codeName',
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                        fontWeight: FontWeight.w300,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _checkOnboardingStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final onboardingCompleted = prefs.getBool('onboarding_completed') ?? false;
    
    if (!mounted) return;

    if (!onboardingCompleted) {
      // First time only - show onboarding
      _navigateToScreenWithHero(const SetupScreen());
    } else {
      // All subsequent launches - go straight to home
      _navigateToScreenWithHero(const HomeScreen());
    }
  }

  Future<void> _warmupShaders() async {
    // Use a smaller size for faster warmup
    const size = Size(50, 50);
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint();

    // Warm up common gradients
    paint.shader = LinearGradient(
      colors: [Colors.white, Colors.white.withOpacity(0.0)],
      stops: const [0.8, 1.0],
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

    // Warm up blur effects with reduced sigma for faster processing
    final filter = ImageFilter.blur(sigmaX: 5, sigmaY: 5);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..imageFilter = filter,
    );

    // Record and compile with smaller image size
    final picture = recorder.endRecording();
    await picture.toImage(size.width.toInt(), size.height.toInt());
    picture.dispose();
  }
}