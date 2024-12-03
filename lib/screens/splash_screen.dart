import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:rive/rive.dart' as rive;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui';  // Import this for ImageFilter
import '../main.dart';
import '../services/Audio_Player_Service.dart';
import '../services/artwork_cache_service.dart';
import '../services/local_caching_service.dart';
import '../services/user_preferences.dart';
import 'welcome_screen.dart';
import 'home_screen.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:appwrite/appwrite.dart';
import '../services/analytics_service.dart';
import '../services/error_reporting_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late rive.RiveAnimationController _riveController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  String _versionNumber = '';
  String _codeName = '';
  bool _isDataLoaded = false;
  bool _isAnimationComplete = false;
  final List<Future> _initializationTasks = [];
  bool _isLoadingComplete = false;
  bool _didInitialize = false;
  String _currentTask = '';
  List<String> _completedTasks = [];
  double _progress = 0.0;
  late Client _appwriteClient;
  late AnalyticsService _analyticsService;
  late ErrorReportingService _errorReportingService;
  List<String> _warnings = [];
  bool _hasConnectivityIssues = false;
  late Account _account;

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
        ('Initializing Services', _initializeServices()),
        ('Loading Library', _loadAppData()),
        ('Caching Artwork', _preloadImages()),
        if (!_hasConnectivityIssues) ('Setting up Analytics', _setupAnalytics()),
        ('Final Preparations', _finalizeInitialization()),
      ];

      for (int i = 0; i < tasks.length; i++) {
        if (!mounted) return;

        final task = tasks[i];
        setState(() {
          _currentTask = task.$1;
          _progress = i / tasks.length;
        });

        try {
          await task.$2;
          if (mounted) {
            setState(() {
              _completedTasks.add(task.$1);
            });
          }
        } catch (e) {
          print('Task failed: ${task.$1} with error: $e');
          // Only show warnings for critical errors
          if (task.$1 != 'Setting up Analytics') {
            if (mounted) {
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
        setState(() {
          _currentTask = 'Complete';
          _progress = 1.0;
          _isDataLoaded = true;
        });
        await _checkOnboardingStatus();
      }
    } catch (e) {
      print('Initialization error: $e');
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
        setState(() {
          _warnings.add('No internet connection');
          _warnings.add('Offline mode active');
          _hasConnectivityIssues = true;
        });
        await Future.delayed(const Duration(seconds: 1));
        return;
      }

      // Initialize Appwrite client
      _appwriteClient = Client()
        ..setEndpoint(dotenv.env['APPWRITE_ENDPOINT'] ?? '')
        ..setProject(dotenv.env['APPWRITE_PROJECT_ID'] ?? '')
        ..setSelfSigned(status: true);

      // Test Appwrite connection first
      try {
        final account = Account(_appwriteClient);
        await account.get();
        
        _analyticsService = AnalyticsService(_appwriteClient);
        _errorReportingService = ErrorReportingService(_appwriteClient);
        
      } catch (e) {
        setState(() {
          _warnings.add('Cloud services unavailable');
          _warnings.add('Playlist sync disabled');
          _hasConnectivityIssues = true;
        });
        await Future.delayed(const Duration(seconds: 1));
      }

      // Test image service connectivity
      try {
        final result = await InternetAddress.lookup('api.deezer.com');
        if (result.isEmpty || result[0].rawAddress.isEmpty) {
          throw Exception('Image service unavailable');
        }
      } catch (e) {
        setState(() {
          _warnings.add('Using default artwork');
        });
        await Future.delayed(const Duration(milliseconds: 800));
      }

    } catch (e) {
      if (!_warnings.contains('Some features may be limited')) {
        setState(() {
          _warnings.add('Some features may be limited');
          _hasConnectivityIssues = true;
        });
        await Future.delayed(const Duration(seconds: 1));
      }
    }
  }

  Future<void> _setupAnalytics() async {
    // Skip if services weren't initialized or we have connectivity issues
    if (_hasConnectivityIssues || 
        _warnings.isNotEmpty || 
        !_isServicesInitialized()) {
      return;
    }

    try {
      await _analyticsService.initialize();
      await _analyticsService.logAppStart();
    } catch (e) {
      print('Analytics setup delayed: $e');
    }
  }

  // Add helper method to check if services are initialized
  bool _isServicesInitialized() {
    try {
      return _appwriteClient != null && 
             _analyticsService != null && 
             _errorReportingService != null;
    } catch (e) {
      return false;
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
    await Future.delayed(const Duration(milliseconds: 200));
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
    _riveController = rive.SimpleAnimation('Timeline 1');
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(_fadeController);

    // Upravený listener pro dokončení Rive animace
    _riveController.isActiveChanged.addListener(() {
      if (!_riveController.isActive) {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _isAnimationComplete = true;
              _checkAndTransition();
            });
          }
        });
      }
    });
  }

  void _checkAndTransition() {
    if (_isDataLoaded && _isAnimationComplete) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _transitionToNextScreen();
        }
      });
    }
  }

  Future<void> _transitionToNextScreen() async {
    await _fadeController.forward();
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
          // Definice křivek pro různé části animace
          const curve = Curves.easeOutCubic;
          
          // Scale animace (mírné zvětšení)
          var scaleAnimation = Tween<double>(
            begin: 0.95,
            end: 1.0,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: curve,
          ));
          
          // Fade animace
          var fadeAnimation = Tween<double>(
            begin: 0.0,
            end: 1.0,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: curve,
          ));
          
          // Blur efekt
          var blurAnimation = Tween<double>(
            begin: 5,
            end: 0,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: curve,
          ));

          return Stack(
            children: [
              // Pozadí
              Positioned.fill(
                child: Image.asset(
                  'assets/images/background/Bcg_V0.0.9.png',
                  fit: BoxFit.cover,
                ),
              ),
              // Animovaný obsah
              AnimatedBuilder(
                animation: animation,
                builder: (context, child) {
                  return BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: blurAnimation.value,
                      sigmaY: blurAnimation.value,
                    ),
                    child: FadeTransition(
                      opacity: fadeAnimation,
                      child: Transform.scale(
                        scale: scaleAnimation.value,
                        child: child,
                      ),
                    ),
                  );
                },
                child: child,
              ),
            ],
          );
        },
        transitionDuration: const Duration(milliseconds: 800),
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
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/background/Bcg_V0.0.9.png',
              fit: BoxFit.cover,
            ),
          ),
          FadeTransition(
            opacity: _fadeAnimation,
            child: Stack(
              children: [
                Center(
                  child: rive.RiveAnimation.asset(
                    "assets/animations/untitled.riv",
                    controllers: [_riveController],
                  ),
                ),
                Positioned(
                  left: 30,
                  right: 30,
                  bottom: 100,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Animated progress bar
                      TweenAnimationBuilder<double>(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                        tween: Tween<double>(
                          begin: 0,
                          end: _progress,
                        ),
                        builder: (context, value, _) => Column(
                          children: [
                            LinearProgressIndicator(
                              value: value,
                              backgroundColor: Colors.white.withOpacity(0.2),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white.withOpacity(0.8),
                              ),
                              minHeight: 3, // Thinner progress bar
                            ),
                            const SizedBox(height: 20),
                            // Animated current task text
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              switchInCurve: Curves.easeInOut,
                              switchOutCurve: Curves.easeInOut,
                              transitionBuilder: (Widget child, Animation<double> animation) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: SlideTransition(
                                    position: Tween<Offset>(
                                      begin: const Offset(0.0, 0.1),
                                      end: Offset.zero,
                                    ).animate(animation),
                                    child: child,
                                  ),
                                );
                              },
                              child: Text(
                                _currentTask,
                                key: ValueKey<String>(_currentTask),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Warnings section (new)
                      if (_warnings.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        AnimationLimiter(
                          child: Column(
                            children: AnimationConfiguration.toStaggeredList(
                              duration: const Duration(milliseconds: 375),
                              childAnimationBuilder: (widget) => SlideAnimation(
                                verticalOffset: 20.0,
                                child: FadeInAnimation(child: widget),
                              ),
                              children: _sortWarnings(_warnings).map((warning) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      _getWarningIcon(warning),
                                      color: _getWarningColor(warning),
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      warning,
                                      style: TextStyle(
                                        color: _getWarningColor(warning),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              )).toList(),
                            ),
                          ),
                        ),
                      ],
                      
                      // Completed tasks with staggered animation
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 60,
                        child: AnimationLimiter(
                          child: ListView.builder(
                            itemCount: _completedTasks.length,
                            itemBuilder: (context, index) {
                              return AnimationConfiguration.staggeredList(
                                position: index,
                                duration: const Duration(milliseconds: 375),
                                child: SlideAnimation(
                                  verticalOffset: 20.0,
                                  child: FadeInAnimation(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 3),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.check_circle,
                                            color: Colors.green.withOpacity(0.8),
                                            size: 14,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            _completedTasks[index],
                                            style: TextStyle(
                                              color: Colors.white.withOpacity(0.6),
                                              fontSize: 13
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 20,
                  child: Text(
                    'Version $_versionNumber ($_codeName)',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _checkOnboardingStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final onboardingCompleted = prefs.getBool('onboarding_completed') ?? false;
    
    if (!onboardingCompleted && mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const WelcomeScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
        ),
      );
      return;
    }
    
    // If onboarding is completed, continue with your existing navigation logic
    _checkAndTransition();
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
}