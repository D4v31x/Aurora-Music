import 'package:flutter/material.dart';
import 'package:rive/rive.dart' as rive;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:ui';  // Import this for ImageFilter
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
      // Nejdřív zkontrolujeme oprávnění
      final hasPermissions = await _requestPermissions();
      if (!hasPermissions) {
        return; // Ukončíme inicializaci, pokud nemáme oprávnění
      }

      final tasks = [
        ('Načítání knihovny', _loadAppData()),
        ('Načítání obrázků', _preloadImages()),
        ('Finální příprava', _finalizeInitialization()),
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
          
        }
      }

      if (mounted) {
        setState(() {
          _currentTask = 'Dokončování...';
          _progress = 1.0;
          _isDataLoaded = true;
          _checkAndTransition();
        });
      }
    } catch (e) {
      
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
      print('Error loading app data: $e');
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
      print('Error preloading images: $e');
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
                  left: 20,
                  right: 20,
                  bottom: 100,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Progress bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: _progress,
                          backgroundColor: Colors.white.withOpacity(0.2),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white.withOpacity(0.8),
                          ),
                          minHeight: 6,
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      // Aktuální úkol
                      Text(
                        _currentTask,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      
                      // Seznam dokončených úkolů
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 60,
                        child: ListView.builder(
                          itemCount: _completedTasks.length,
                          itemBuilder: (context, index) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.check_circle_outline,
                                    color: Colors.green,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _completedTasks[index],
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.7),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
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
}