import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart' as permissionhandler;
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';
import '../models/utils.dart';
import '../services/audio_player_service.dart';
import '../localization/app_localizations.dart';
import '../widgets/changelog_dialog.dart';
import '../widgets/expandable_bottom.dart';
import '../widgets/home/home_tab.dart';
import '../widgets/home/search_tab.dart';
import '../widgets/home/settings_tab.dart';
import 'now_playing.dart';
import '../widgets/outline_indicator.dart';
import '../widgets/mini_player.dart';
import '../widgets/app_background.dart';
import '../widgets/auto_scroll_text.dart';
import '../services/local_caching_service.dart';
import '../services/expandable_player_controller.dart';
import '../services/notification_manager.dart';
import '../services/version_service.dart';
import '../widgets/library_tab.dart';
import 'package:aurora_music_v01/providers/theme_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late bool isDarkMode;
  late TabController _tabController;
  late final LocalCachingArtistService _artistService = LocalCachingArtistService();
  bool _showAppBar = true;
  List<SongModel> songs = [];
  List<String> randomArtists = [];
  List<SongModel> randomSongs = [];
  AnimationController? _animationController;
  final ScrollController _scrollController = ScrollController();
  final StreamController<bool> _streamController = StreamController<bool>();
  SongModel? currentSong;
  // These fields are used in _refreshLibrary method
  bool _isScanning = false;
  int _scannedSongs = 0;
  int _totalSongs = 0;
  List<ArtistModel> artists = [];
  final GlobalKey<ExpandableBottomSheetState> _expandableKey = GlobalKey<ExpandableBottomSheetState>();
  bool _isInitialized = false;
  late final ScrollController _appBarTextController;
  bool _isTabBarScrolled = false;
  bool _hasShownChangelog = false;
  String _currentVersion = '';
  final NotificationManager _notificationManager = NotificationManager();

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _setupListeners();
    
    // Don't try to access media at startup - delay it
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) {
        // Only initialize after UI is loaded
        _initializeHomeScreen();
      }
    });
    
    _checkAndShowChangelog();
    _showWelcomeMessage();
  }
  
  // Initialize the home screen and check permissions
  void _initializeHomeScreen() async {
    final audioPlayerService = Provider.of<AudioPlayerService>(context, listen: false);
    
    // Set initialized state
    setState(() {
      _isInitialized = true;
    });
    
    // Check if we need to show permission UI
    await _checkPermissions();
  }
  
  void _initializeControllers() {
    _tabController = TabController(length: 4, vsync: this);
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _appBarTextController = ScrollController();
  }
  
  void _setupListeners() {
    _scrollController.addListener(_scrollListener);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _setupScrollListener();
  }
  
  void _setupScrollListener() {
    _scrollController.addListener(() {
      final isScrolled = _scrollController.offset > 180;
      if (_isTabBarScrolled != isScrolled) {
        setState(() {
          _isTabBarScrolled = isScrolled;
        });
      }
    });
  }
  
  void _showWelcomeMessage() {
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        _notificationManager.showNotification(
          AppLocalizations.of(context).translate('welcome_back'),
          duration: const Duration(seconds: 3),
          onComplete: () => _notificationManager.showDefaultTitle(),
        );
      }
    });
  }

  Future<void> _checkAndShowChangelog() async {
    if (_hasShownChangelog) return;

    final shouldShow = await VersionService.shouldShowChangelog();
    if (shouldShow && mounted) {
      _showChangelogDialog();
      _hasShownChangelog = true;
    }
  }

  void _showChangelogDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => ChangelogDialog(
        currentVersion: _currentVersion,
      ),
    );
  }

  Future<List<SongModel>> _processSongsInBackground(List<SongModel> songs) async {
    return compute(_processMetadata, songs);
  }

  static List<SongModel> _processMetadata(List<SongModel> songs) {
    // Perform any heavy processing on the songs here
    return songs;
  }

  void _randomizeContent() {
    if (songs.isNotEmpty) {
      randomSongs = List.from(songs)..shuffle();
      randomSongs = randomSongs.take(3).toList();
      final uniqueArtists = songs
          .map((song) => splitArtists(song.artist ?? ''))
          .expand((artist) => artist)
          .toSet()
          .toList();
      randomArtists = List.from(uniqueArtists)..shuffle();
      randomArtists = randomArtists.take(3).toList();
    }
  }

  void _scrollListener() {
    if (_scrollController.offset > 180 && _showAppBar) {
      setState(() {
        _showAppBar = false;
      });
    } else if (_scrollController.offset <= 180 && !_showAppBar) {
      setState(() {
        _showAppBar = true;
      });
    }
  }

  @override
  void dispose() {
    _animationController?.dispose();
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _streamController.close();
    _tabController.dispose();
    _appBarTextController.dispose();
    _notificationManager.dispose();
    super.dispose();
  }

  Future<void> _loadLibraryData() async {
    if (Platform.isWindows) {
      final directory = await getApplicationDocumentsDirectory();
      final musicDir = Directory('${directory.path}/Music');

      if (!await musicDir.exists()) {
        await musicDir.create(recursive: true);
      }

      final files = await musicDir
          .list(recursive: true, followLinks: false)
          .where((entity) =>
      entity is File &&
          (entity.path.toLowerCase().endsWith('.mp3') ||
              entity.path.toLowerCase().endsWith('.m4a') ||
              entity.path.toLowerCase().endsWith('.wav')))
          .cast<File>()
          .toList();

      final songs = files.map((file) {
        final fileName = file.path.split(Platform.pathSeparator).last;
        final title = fileName.contains('.') ? fileName.substring(0, fileName.lastIndexOf('.')) : fileName;

        return SongModel({
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
      }).toList();

      setState(() {
        this.songs = songs;
      });
      return;
    }

    try {
      final onAudioQuery = OnAudioQuery();
      final songs = await onAudioQuery.querySongs();
      setState(() {
        this.songs = songs;
      });
    } catch (e) {
      debugPrint('Error loading library data: $e');
    }
  }

  Future<void> _refreshLibrary() async {
    final audioPlayerService = Provider.of<AudioPlayerService>(context, listen: false);

    setState(() {
      _isScanning = true;
      _scannedSongs = 0;
      _totalSongs = 0;
    });

    _notificationManager.showNotification(
      AppLocalizations.of(context).translate('scanning_songs'),
      isProgress: true,
    );

    try {
      final onAudioQuery = OnAudioQuery();
      final allSongs = await onAudioQuery.querySongs();
      _totalSongs = allSongs.length;

      for (var song in allSongs) {
        await audioPlayerService.addSongToLibrary(song);
        await Future.delayed(const Duration(milliseconds: 10));

        setState(() {
          _scannedSongs++;
        });
      }

      setState(() {
        songs = allSongs;
        _randomizeContent();
        _isScanning = false;
      });

      _notificationManager.showNotification(
        '${AppLocalizations.of(context).translate('library_updated')} ($_totalSongs ${AppLocalizations.of(context).translate('songs_loaded')})',
        duration: const Duration(seconds: 5),
        onComplete: () => _notificationManager.showDefaultTitle(),
      );

      await audioPlayerService.saveLibrary();

    } catch (e) {
      setState(() {
        _isScanning = false;
      });

      _notificationManager.showNotification(
        AppLocalizations.of(context).translate('scan_failed'),
        duration: const Duration(seconds: 5),
        onComplete: () => _notificationManager.showDefaultTitle(),
      );
    }
  }

  // Check for permissions and show appropriate UI
  Future<void> _checkPermissions() async {
    if (!mounted) return;
    
    final audioPlayerService = Provider.of<AudioPlayerService>(context, listen: false);
    
    try {
      if (Platform.isAndroid) {
        // Check status without requesting (don't force request)
        final hasAudioPermission = await permissionhandler.Permission.audio.status.isGranted;
        final hasStoragePermission = await permissionhandler.Permission.storage.status.isGranted;
        
        if (hasAudioPermission || hasStoragePermission) {
          // If we already have permissions, initialize the library
          _notificationManager.showNotification(
            AppLocalizations.of(context).translate('loading_library'),
            isProgress: true,
          );
          
          final success = await audioPlayerService.initializeMusicLibrary();
          
          if (success) {
            _notificationManager.showNotification(
              AppLocalizations.of(context).translate('library_loaded'),
              duration: const Duration(seconds: 2),
              onComplete: () => _notificationManager.showDefaultTitle(),
            );
            
            // Get songs from the audio service
            setState(() {
              songs = audioPlayerService.songs;
              _randomizeContent();
            });
          } else {
            _showPermissionDialog();
          }
        } else {
          // Show permission UI - don't automatically request
          _showPermissionDialog();
        }
      } else if (Platform.isWindows) {
        // Initialize for Windows immediately - no permissions needed
        _notificationManager.showNotification(
          AppLocalizations.of(context).translate('loading_library'),
          isProgress: true,
        );
        
        final success = await audioPlayerService.initializeMusicLibrary();
        
        if (success) {
          _notificationManager.showNotification(
            AppLocalizations.of(context).translate('library_loaded'),
            duration: const Duration(seconds: 2),
            onComplete: () => _notificationManager.showDefaultTitle(),
          );
        }
        
        setState(() {
          songs = audioPlayerService.songs;
          _randomizeContent();
        });
      }
    } catch (e) {
      debugPrint('Error in _checkPermissions: $e');
      if (mounted) {
        _showPermissionDialog();
      }
    }
  }
  
  // Show a dialog to request permissions
  void _showPermissionDialog() {
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(AppLocalizations.of(context).translate('permission_required')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(AppLocalizations.of(context).translate('permission_explanation')),
              const SizedBox(height: 12),
              Text(AppLocalizations.of(context).translate('no_permission_explanation'), 
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: Text(AppLocalizations.of(context).translate('cancel')),
              onPressed: () {
                Navigator.of(context).pop();
                // User denied permission - handle accordingly
                setState(() {
                  songs = [];
                });
                
                // Show a snackbar explaining how to enable later
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(AppLocalizations.of(context).translate('permission_later')),
                    duration: const Duration(seconds: 5),
                    action: SnackBarAction(
                      label: AppLocalizations.of(context).translate('settings'),
                      onPressed: () async {
                        await permissionhandler.openAppSettings();
                      },
                    ),
                  ),
                );
              },
            ),
            TextButton(
              child: Text(AppLocalizations.of(context).translate('grant_permission')),
              onPressed: () async {
                Navigator.of(context).pop();
                // Request permissions
                final statuses = await [
                  permissionhandler.Permission.audio,
                  permissionhandler.Permission.storage,
                ].request();
                
                final hasAudioPermission = statuses[permissionhandler.Permission.audio]?.isGranted ?? false;
                final hasStoragePermission = statuses[permissionhandler.Permission.storage]?.isGranted ?? false;
                
                if (hasAudioPermission || hasStoragePermission) {
                  // Permissions granted, initialize library
                  final audioPlayerService = Provider.of<AudioPlayerService>(context, listen: false);
                  
                  _notificationManager.showNotification(
                    AppLocalizations.of(context).translate('loading_library'),
                    isProgress: true,
                  );
                  
                  final success = await audioPlayerService.initializeMusicLibrary();
                  
                  if (success) {
                    _notificationManager.showNotification(
                      AppLocalizations.of(context).translate('library_loaded'),
                      duration: const Duration(seconds: 2),
                      onComplete: () => _notificationManager.showDefaultTitle(),
                    );
                    
                    // Get songs from the audio service
                    setState(() {
                      songs = audioPlayerService.songs;
                      _randomizeContent();
                    });
                  } else {
                    setState(() {
                      songs = [];
                    });
                    
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(AppLocalizations.of(context).translate('library_error')),
                      ),
                    );
                  }
                } else {
                  // Still no permissions - handle accordingly
                  setState(() {
                    songs = [];
                  });
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(AppLocalizations.of(context).translate('perm_deny')),
                      action: SnackBarAction(
                        label: AppLocalizations.of(context).translate('settings'),
                        onPressed: () async {
                          await permissionhandler.openAppSettings();
                        },
                      ),
                    ),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }
  
  // Note: This Windows code has been moved to AudioPlayerService
  // and is no longer used directly in HomeScreen

  // Windows file handling moved to AudioPlayerService

  Future<bool> _onWillPop() async {
    final expandableController = Provider.of<ExpandablePlayerController>(context, listen: false);

    // If the player is expanded, collapse it instead of showing exit dialog
    if (expandableController.isExpanded) {
      expandableController.collapse();
      return false;
    }

    // Otherwise show the exit dialog
    return await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).translate('exit_app')),
        content: Text(AppLocalizations.of(context).translate('exit_app_confirm')),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(AppLocalizations.of(context).translate('no')),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(AppLocalizations.of(context).translate('yes')),
          ),
        ],
      ),
    ) ?? false;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final themeProvider = Provider.of<ThemeProvider>(context);
    isDarkMode = themeProvider.isDarkMode;
  }























  // All library initialization is now handled by AudioPlayerService



  Widget buildAppBarTitle() {
    return StreamBuilder<String>(
      stream: _notificationManager.notificationStream,
      initialData: '',
      builder: (context, snapshot) {
        final message = snapshot.data ?? '';

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: message.isEmpty
              ? Text(
            AppLocalizations.of(context).translate('aurora_music'),
            key: const ValueKey('default'),
            style: const TextStyle(
              fontFamily: 'ProductSans',
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.bold,
            ),
          )
              : AutoScrollText(
            key: ValueKey(message),
            text: message,
            style: const TextStyle(
              fontFamily: 'ProductSans',
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.bold,
            ),
            onMessageComplete: (message) => _notificationManager.showDefaultTitle(),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Selector2<AudioPlayerService, ExpandablePlayerController, SongModel?>(
      selector: (context, audioService, expandableController) => audioService.currentSong,
      builder: (context, currentSong, child) {
        return WillPopScope(
          onWillPop: _onWillPop,
          child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            // Using the app background widget to provide consistent UI
            Positioned.fill(child: AppBackground(child: Container())),
            NestedScrollView(
              controller: _scrollController,
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
                SliverAppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0.0,
                  toolbarHeight: 70,
                  automaticallyImplyLeading: false,
                  floating: true,
                  pinned: true,
                  expandedHeight: 220,
                  flexibleSpace: FlexibleSpaceBar(
                    expandedTitleScale: 1.0,
                    centerTitle: true,
                    titlePadding: const EdgeInsets.only(bottom: 120),
                    title: !innerBoxIsScrolled ? buildAppBarTitle() : null,
                  ),
                  bottom: PreferredSize(
                    preferredSize: const Size.fromHeight(70.0),
                    child: ClipRect(
                      child: BackdropFilter(
                        filter: _isTabBarScrolled
                            ? ImageFilter.blur(sigmaX: 10, sigmaY: 10)
                            : ImageFilter.blur(sigmaX: 0, sigmaY: 0),
                        child: TabBar(
                          controller: _tabController,
                          dividerColor: Colors.transparent,
                          isScrollable: true,
                          labelPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
                          indicatorPadding: const EdgeInsets.symmetric(vertical: 8.0),
                          indicator: OutlineIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                            radius: const Radius.circular(20),
                            text: [
                              AppLocalizations.of(context).translate('home'),
                              AppLocalizations.of(context).translate('library'),
                              AppLocalizations.of(context).translate('search'),
                              AppLocalizations.of(context).translate('settings'),
                            ][_tabController.index],
                          ),
                          tabs: [
                            _buildTabItem(AppLocalizations.of(context).translate('home')),
                            _buildTabItem(AppLocalizations.of(context).translate('library')),
                            _buildTabItem(AppLocalizations.of(context).translate('search')),
                            _buildTabItem(AppLocalizations.of(context).translate('settings')),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              body: TabBarView(
                controller: _tabController,
                children: [
                  HomeTab(
                    randomSongs: randomSongs,
                    randomArtists: randomArtists,
                    artistService: _artistService,
                    currentSong: currentSong,
                    onRefresh: _refreshLibrary,
                  ),
                  const LibraryTab(), // Use the separated LibraryTab widget
                  SearchTab(
                    songs: songs,
                    artists: artists,
                    isInitialized: _isInitialized,
                  ),
                  SettingsTab(
                    notificationManager: _notificationManager,
                    onUpdateCheck: () async {
                      await launchUrl(Uri.parse('https://github.com/D4v31x/Aurora-Music/releases/latest'));
                    },
                  ),
                ],
              ),
            ),
            if (currentSong != null)
              ExpandableBottomSheet(
                key: _expandableKey,
                minHeight: 60,
                minChild: MiniPlayer(currentSong: currentSong),
                maxChild: const NowPlayingScreen(),
              ),
          ],
        ),
      ),
        );
      },
    );
  }

  Widget _buildTabItem(String text) {
    return Container(
      constraints: const BoxConstraints(minWidth: 80),
      height: 30,
      child: Tab(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            text,
            maxLines: 1,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontFamily: 'ProductSans',
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}