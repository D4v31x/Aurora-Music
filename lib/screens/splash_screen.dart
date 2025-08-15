import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mesh/mesh.dart';
import 'dart:ui';  // Import this for ImageFilter
import '../services/audio_player_service.dart';
import '../services/artwork_cache_service.dart';
import '../services/user_preferences.dart';
import '../services/logging_service.dart';
import '../constants/animation_constants.dart';
import 'welcome_screen.dart';
import 'home_screen.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';


class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  String _versionNumber = '';
  String _codeName = '';
  bool _isDataLoaded = false;
  bool _isAnimationComplete = false;
  final List<Future> _initializationTasks = [];
  final bool _isLoadingComplete = false;
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
    // Reduced delay for faster initialization
    await Future.delayed(AnimationConstants.shortDelay);
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
    _fadeController = AnimationController(
      duration: AnimationConstants.normal,
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: AnimationConstants.visibleOpacity,
      end: AnimationConstants.hiddenOpacity,
    ).animate(_fadeController);

    _fadeController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _isAnimationComplete = true;
          _checkAndTransition();
        });
      }
    });
  }

  void _checkAndTransition() {
    if (_isAnimationComplete) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _transitionToNextScreen();
        }
      });
    }
  }

  Future<void> _transitionToNextScreen() async {
    bool isFirstTime = await UserPreferences.isFirstTimeUser();

    if (mounted) {
      if (isFirstTime) {
        await UserPreferences.setFirstTimeUser(false);
        _navigateToScreen(const WelcomeScreen());
      } else {
        _navigateToScreen(const HomeScreen());
      }
    }
  }

  void _navigateToScreen(Widget screen) {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (context, animation, secondaryAnimation) => Container(
          color: Colors.transparent,
          child: screen,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const curve = AnimationConstants.easeOutQuart;

          // Slide up animation
          var slideAnimation = Tween<Offset>(
            begin: const Offset(0.0, 1.0),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: curve,
          ));

          // Fade animation
          var fadeAnimation = Tween<double>(
            begin: AnimationConstants.hiddenOpacity,
            end: AnimationConstants.visibleOpacity,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: curve,
          ));

          // Rotation animation for a subtle effect
          var rotationAnimation = Tween<double>(
            begin: AnimationConstants.subtleRotation,
            end: AnimationConstants.hiddenOpacity,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: curve,
          ));

          return RepaintBoundary(
            child: Stack(
              children: [
                // Gradient background that matches theme
                Positioned.fill(
                  child: RepaintBoundary(
                    child: AnimatedBuilder(
                      animation: animation,
                      builder: (context, _) {
                        final isDarkMode = Theme.of(context).brightness == Brightness.dark;
                        return OMeshGradient(
                          mesh: OMeshRect(
                            width: 2,
                            height: 2,
                            fallbackColor: isDarkMode ? const Color(0xFF1A237E) : const Color(0xFFCFD8DC),
                            vertices: [
                              // Top-left corner
                              (0.0, 0.0).v.to(isDarkMode ? const Color(0xFF1A237E) : const Color(0xFFCFD8DC)),
                              // Top-right corner  
                              (1.0, 0.0).v.to(isDarkMode ? const Color(0xFF311B92) : const Color(0xFFBBDEFB)),
                              // Bottom-left corner
                              (0.0, 1.0).v.to(isDarkMode ? const Color(0xFF512DA8) : const Color(0xFF90CAF9)),
                              // Bottom-right corner
                              (1.0, 1.0).v.to(isDarkMode ? const Color(0xFF7B1FA2) : const Color(0xFF64B5F6)),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
                // Animated content
                RepaintBoundary(
                  child: AnimatedBuilder(
                    animation: animation,
                    builder: (context, _) {
                      return SlideTransition(
                        position: slideAnimation,
                        child: FadeTransition(
                          opacity: fadeAnimation,
                          child: Transform.rotate(
                            angle: rotationAnimation.value,
                            child: child,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
        transitionDuration: AnimationConstants.pageTransition * 2, // 1200ms
      ),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RepaintBoundary(
        child: Stack(
          children: [
            Positioned.fill(
              child: RepaintBoundary(
                child: Image.asset(
                  'assets/images/background/Bcg_V0.0.9.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Center(
              child: RepaintBoundary(
                child: Lottie.asset(
                  'assets/animations/Splash.json',
                  controller: _fadeController,
                  onLoaded: (composition) {
                    _fadeController.duration = composition.duration;
                    _fadeController.forward();
                  },
                ),
              ),
            ),
          ],
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
      _navigateToScreen(const WelcomeScreen());
    } else {
      // All subsequent launches - go straight to home
      _navigateToScreen(const HomeScreen());
    }
  }

  Color _getWarningColor(String warning) {
    if (warning.contains('Offline mode')) {
      return Colors.blue.withOpacity(0.8);
    } else if (warning.contains('Cloud services')) {
      return Colors.red.withOpacity(0.8);
    } else if (warning.contains('No internet')) {
      return Colors.red.withOpacity(0.8);
    } else if (warning.contains('Playlist sync')) {
      return Colors.orange.withOpacity(0.8);
    } else if (warning.contains('default artwork')) {
      return Colors.purple.withOpacity(0.8);
    } else {
      return Colors.amber.withOpacity(0.8);
    }
  }

  IconData _getWarningIcon(String warning) {
    if (warning.contains('Offline mode')) {
      return Icons.offline_bolt;
    } else if (warning.contains('Cloud services')) {
      return Icons.cloud_off;
    } else if (warning.contains('No internet')) {
      return Icons.wifi_off;
    } else if (warning.contains('Playlist sync')) {
      return Icons.playlist_remove;
    } else if (warning.contains('default artwork')) {
      return Icons.image_not_supported;
    } else {
      return Icons.warning_amber_rounded;
    }
  }

  List<String> _sortWarnings(List<String> warnings) {
    final priorityOrder = {
      'No internet connection': 0,
      'Offline mode active': 1,
      'Cloud services unavailable': 2,
      'Playlist sync disabled': 3,
      'Using default artwork': 4,
      'Some features may be limited': 5,
    };

    return List<String>.from(warnings)..sort((a, b) {
      return (priorityOrder[a] ?? 999).compareTo(priorityOrder[b] ?? 999);
    });
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