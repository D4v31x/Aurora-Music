import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart'
    as permissionhandler;
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';
import '../models/utils.dart';
import '../services/audio_player_service.dart';
import '../localization/app_localizations.dart';
import '../widgets/changelog_dialog.dart';
import '../widgets/home/home_tab.dart';
import '../widgets/home/search_tab.dart';
import '../widgets/home/settings_tab.dart';
import '../widgets/outline_indicator.dart';
import '../widgets/expanding_player.dart'; // For back button handling
import '../widgets/auto_scroll_text.dart';
import '../services/local_caching_service.dart';
import '../services/notification_manager.dart';
import '../services/download_progress_monitor.dart';
import '../services/version_service.dart';
import '../services/bluetooth_service.dart';
import '../services/donation_service.dart';
import '../widgets/library_tab.dart';
import 'package:aurora_music_v01/screens/onboarding/onboarding_screen.dart';
import 'package:aurora_music_v01/providers/theme_provider.dart';
import '../widgets/app_background.dart';
import '../widgets/glassmorphic_container.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late bool isDarkMode;
  late TabController _tabController;
  late final LocalCachingArtistService _artistService =
      LocalCachingArtistService();
  List<SongModel> songs = [];
  List<String> randomArtists = [];
  List<SongModel> randomSongs = [];
  AnimationController? _animationController;
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<bool> _isScrolledNotifier = ValueNotifier<bool>(false);
  int _totalSongs = 0;
  List<ArtistModel> artists = [];
  List<AlbumModel> albums = [];
  // Removed expandable bottom sheet in favor of simple Hero-based navigation
  bool _isInitialized = false;
  late final ScrollController _appBarTextController;
  bool _hasShownChangelog = false;
  final String _currentVersion = '';
  final NotificationManager _notificationManager = NotificationManager();
  final DownloadProgressMonitor _downloadMonitor = DownloadProgressMonitor();
  final BluetoothService _bluetoothService = BluetoothService();
  StreamSubscription<String>? _downloadStatusSubscription;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _setupListeners();

    // Initialize Bluetooth service
    _bluetoothService.initialize();

    // Start monitoring downloads
    _downloadMonitor.startMonitoring();
    _downloadStatusSubscription =
        _downloadMonitor.downloadStatusStream.listen((status) {
      if (status.isNotEmpty) {
        _notificationManager.showNotification(
          status,
          isProgress: true,
        );
      }
    });

    // Initialize immediately after frame callback to ensure context is available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeHomeScreen();
    });

    _checkAndShowChangelog();
    _showWelcomeMessage();
  }

  // Initialize the home screen and check permissions
  Future<void> _initializeHomeScreen() async {
    try {
      // Set initialized state
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }

      // Check if we need to show permission UI
      await _checkPermissions();
    } catch (e) {
      debugPrint('Error initializing home screen: $e');
      // Fallback initialization if something goes wrong
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    }
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

    // Check and show donation reminder after a delay
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        DonationService.showReminderIfNeeded(context);
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

  Future<void> _loadSmartSuggestions() async {
    if (songs.isEmpty) return;

    final audioPlayerService =
        Provider.of<AudioPlayerService>(context, listen: false);

    // Get smart suggestions based on listening patterns
    final suggestedTracks =
        await audioPlayerService.getSuggestedTracks(count: 3);
    final suggestedArtists =
        await audioPlayerService.getSuggestedArtists(count: 5);

    if (mounted) {
      setState(() {
        randomSongs =
            suggestedTracks.isNotEmpty ? suggestedTracks : _getFallbackSongs();
        randomArtists = suggestedArtists.isNotEmpty
            ? suggestedArtists
            : _getFallbackArtists();
      });
    }
  }

  List<SongModel> _getFallbackSongs() {
    // Fallback to random when no listening history
    final shuffled = List.from(songs)..shuffle();
    return shuffled.take(3).toList().cast<SongModel>();
  }

  List<String> _getFallbackArtists() {
    // Fallback to random artists
    final uniqueArtists = songs
        .map((song) => splitArtists(song.artist ?? ''))
        .expand((artist) => artist)
        .toSet()
        .toList();
    final shuffled = List.from(uniqueArtists)..shuffle();
    return shuffled.take(5).toList().cast<String>();
  }

  // Keep for backwards compatibility but use smart suggestions
  void _randomizeContent() {
    _loadSmartSuggestions();
  }

  Future<void> _loadAlbumsAndArtists() async {
    try {
      final onAudioQuery = OnAudioQuery();
      final loadedAlbums = await onAudioQuery.queryAlbums();
      final loadedArtists = await onAudioQuery.queryArtists();
      if (mounted) {
        setState(() {
          albums = loadedAlbums;
          artists = loadedArtists;
        });
      }
    } catch (e) {
      debugPrint('Error loading albums and artists: $e');
    }
  }

  void _scrollListener() {
    final offset = _scrollController.offset;
    final isScrolled = offset > 180;

    // Only update if state actually changed
    if (isScrolled != _isScrolledNotifier.value) {
      _isScrolledNotifier.value = isScrolled;
    }
  }

  @override
  void dispose() {
    _animationController?.dispose();
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _isScrolledNotifier.dispose();
    _tabController.dispose();
    _appBarTextController.dispose();
    _notificationManager.dispose();
    _downloadStatusSubscription?.cancel();
    _downloadMonitor.stopMonitoring();
    super.dispose();
  }

  Future<void> _refreshLibrary() async {
    final audioPlayerService =
        Provider.of<AudioPlayerService>(context, listen: false);

    _notificationManager.showNotification(
      AppLocalizations.of(context).translate('scanning_songs'),
      isProgress: true,
    );

    try {
      final onAudioQuery = OnAudioQuery();
      final allSongs = await onAudioQuery.querySongs();
      _totalSongs = allSongs.length;

      // Process songs in batches to avoid excessive setState calls
      for (var song in allSongs) {
        await audioPlayerService.addSongToLibrary(song);
      }

      // Single setState after all processing
      if (mounted) {
        setState(() {
          songs = allSongs;
          _randomizeContent();
        });
        _loadAlbumsAndArtists();
      }

      _notificationManager.showNotification(
        '${AppLocalizations.of(context).translate('library_updated')} ($_totalSongs ${AppLocalizations.of(context).translate('songs_loaded')})',
        duration: const Duration(seconds: 5),
        onComplete: () => _notificationManager.showDefaultTitle(),
      );

      await audioPlayerService.saveLibrary();
    } catch (e) {
      _notificationManager.showNotification(
        AppLocalizations.of(context).translate('scan_failed'),
        duration: const Duration(seconds: 5),
        onComplete: () => _notificationManager.showDefaultTitle(),
      );
    }
  }

  // Check for permissions and show appropriate UI
  Future<void> _checkPermissions({bool force = false}) async {
    if (!mounted) return;

    // If forcing, go straight to the permission dialog
    if (force) {
      _showPermissionDialog();
      return;
    }

    final audioPlayerService =
        Provider.of<AudioPlayerService>(context, listen: false);

    try {
      if (Platform.isAndroid) {
        // Check status without requesting (don't force request)
        final hasAudioPermission =
            await permissionhandler.Permission.audio.status.isGranted;
        final hasStoragePermission =
            await permissionhandler.Permission.storage.status.isGranted;

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
            _loadAlbumsAndArtists();
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
        _loadAlbumsAndArtists();
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
          title: Text(
              AppLocalizations.of(context).translate('permission_required')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(AppLocalizations.of(context)
                  .translate('permission_explanation')),
              const SizedBox(height: 12),
              Text(
                  AppLocalizations.of(context)
                      .translate('no_permission_explanation'),
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
                    content: Text(AppLocalizations.of(context)
                        .translate('permission_later')),
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
              child: Text(
                  AppLocalizations.of(context).translate('grant_permission')),
              onPressed: () async {
                Navigator.of(context).pop();
                // Request permissions
                final statuses = await [
                  permissionhandler.Permission.audio,
                  permissionhandler.Permission.storage,
                ].request();

                final hasAudioPermission =
                    statuses[permissionhandler.Permission.audio]?.isGranted ??
                        false;
                final hasStoragePermission =
                    statuses[permissionhandler.Permission.storage]?.isGranted ??
                        false;

                if (hasAudioPermission || hasStoragePermission) {
                  // Permissions granted, initialize library
                  final audioPlayerService =
                      Provider.of<AudioPlayerService>(context, listen: false);

                  _notificationManager.showNotification(
                    AppLocalizations.of(context).translate('loading_library'),
                    isProgress: true,
                  );

                  final success =
                      await audioPlayerService.initializeMusicLibrary();

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
                    _loadAlbumsAndArtists();
                  } else {
                    setState(() {
                      songs = [];
                    });

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(AppLocalizations.of(context)
                            .translate('library_error')),
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
                      content: Text(
                          AppLocalizations.of(context).translate('perm_deny')),
                      action: SnackBarAction(
                        label:
                            AppLocalizations.of(context).translate('settings'),
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
    // If the player is expanded, minimize it instead of showing exit dialog
    if (ExpandingPlayer.isExpanded) {
      ExpandingPlayer.minimize();
      return false;
    }

    // Show the exit dialog when user attempts to leave the app
    final shouldExit = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(AppLocalizations.of(context).translate('exit_app')),
            content: Text(
                AppLocalizations.of(context).translate('exit_app_confirm')),
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
        ) ??
        false;

    if (shouldExit) {
      // Stop audio and exit the app properly
      final audioService =
          Provider.of<AudioPlayerService>(context, listen: false);
      await audioService.stop();
      audioService.dispose();

      // Exit the app
      if (Platform.isAndroid) {
        SystemNavigator.pop();
      } else if (Platform.isIOS) {
        exit(0);
      }
    }
    return false; // Don't pop the route, we handle exit manually
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final themeProvider = Provider.of<ThemeProvider>(context);
    isDarkMode = themeProvider.isDarkMode;
  }

  // All library initialization is now handled by AudioPlayerService
  Widget buildAppBarTitle() {
    return ListenableBuilder(
      listenable: _bluetoothService,
      builder: (context, child) {
        final isConnected = _bluetoothService.isBluetoothConnected;
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSlide(
              offset: isConnected ? const Offset(0, -0.3) : Offset.zero,
              duration: const Duration(milliseconds: 400),
              curve: Curves.ease,
              child: StreamBuilder<String>(
                stream: _notificationManager.notificationStream,
                initialData: '',
                builder: (context, snapshot) {
                  final message = snapshot.data ?? '';
                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: message.isEmpty
                        ? Text(
                            AppLocalizations.of(context)
                                .translate('aurora_music'),
                            key: const ValueKey('default'),
                            textAlign: TextAlign.center,
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
                            onMessageComplete: (message) =>
                                _notificationManager.showDefaultTitle(),
                          ),
                  );
                },
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              curve: Curves.ease,
              height: isConnected ? 30 : 0,
              child: ClipRect(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.ease,
                  opacity: isConnected ? 1.0 : 0.0,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: const Color(0xFF10B981), // Green color
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.bluetooth_connected,
                          color: Color(0xFF10B981),
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          transitionBuilder:
                              (Widget child, Animation<double> animation) {
                            return FadeTransition(
                                opacity: animation, child: child);
                          },
                          child: Text(
                            _bluetoothService.connectedDeviceName,
                            key:
                                ValueKey(_bluetoothService.connectedDeviceName),
                            style: const TextStyle(
                              fontFamily: 'ProductSans',
                              fontSize: 12,
                              color: Color(0xFF10B981),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final audioPlayerService = Provider.of<AudioPlayerService>(context);
    final currentSong = audioPlayerService.currentSong;

    return WillPopScope(
      onWillPop: _onWillPop,
      child: AppBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          resizeToAvoidBottomInset: false,
          body: Stack(
            children: [
              RepaintBoundary(
                child: NestedScrollView(
                  controller: _scrollController,
                  headerSliverBuilder: (context, innerBoxIsScrolled) => [
                    SliverAppBar(
                      backgroundColor: Colors.transparent,
                      elevation: 0.0,
                      toolbarHeight: 70,
                      automaticallyImplyLeading: false,
                      floating: true,
                      pinned: true,
                      expandedHeight: 250,
                      flexibleSpace: ClipRRect(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                          child: FlexibleSpaceBar(
                            background: Container(
                              color: Colors.transparent,
                              child: Center(
                                child: buildAppBarTitle(),
                              ),
                            ),
                            centerTitle: true,
                            title: innerBoxIsScrolled
                                ? Text(
                                    AppLocalizations.of(context)
                                        .translate('aurora_music'),
                                    style: const TextStyle(
                                      fontFamily: 'ProductSans',
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                      ),
                      bottom: PreferredSize(
                        preferredSize: const Size.fromHeight(55),
                        child: ValueListenableBuilder<bool>(
                            valueListenable: _isScrolledNotifier,
                            builder: (context, isScrolled, _) {
                              return Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(20, 0, 20, 6),
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 300),
                                  child: isScrolled
                                      ? GlassmorphicContainer(
                                          key: const ValueKey('scrolled'),
                                          borderRadius:
                                              BorderRadius.circular(30),
                                          blur: 20,
                                          child: _HomeTabBar(
                                              tabController: _tabController),
                                        )
                                      : Container(
                                          key: const ValueKey('normal'),
                                          child: _HomeTabBar(
                                              tabController: _tabController),
                                        ),
                                ),
                              );
                            }),
                      ),
                    ),
                  ],
                  body: TabBarView(
                    controller: _tabController,
                    children: [
                      RepaintBoundary(
                        child: HomeTab(
                          randomSongs: randomSongs,
                          randomArtists: randomArtists,
                          artistService: _artistService,
                          currentSong: currentSong,
                          onRefresh: _refreshLibrary,
                        ),
                      ),
                      const RepaintBoundary(child: LibraryTab()),
                      RepaintBoundary(
                        child: SearchTab(
                          songs: songs,
                          artists: artists,
                          albums: albums,
                          isInitialized: _isInitialized,
                        ),
                      ),
                      RepaintBoundary(
                        child: SettingsTab(
                          notificationManager: _notificationManager,
                          onUpdateCheck: () async {
                            await launchUrl(Uri.parse(
                                'https://github.com/D4v31x/Aurora-Music/releases/latest'));
                          },
                          onResetSetup: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                  builder: (context) =>
                                      const OnboardingScreen()),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Remove ExpandingPlayer from here - it's now global in main.dart
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeTabBar extends StatelessWidget {
  final TabController tabController;

  const _HomeTabBar({required this.tabController});

  Widget _buildTabItem(BuildContext context, String text) {
    return Container(
      constraints: const BoxConstraints(minWidth: 80),
      height: 28,
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

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: tabController,
      builder: (context, child) {
        return TabBar(
          controller: tabController,
          dividerColor: Colors.transparent,
          isScrollable: false,
          labelPadding:
              const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
          indicatorPadding: const EdgeInsets.symmetric(vertical: 4.0),
          indicator: OutlineIndicator(
            color: Colors.white,
            strokeWidth: 2,
            radius: const Radius.circular(20),
            text: [
              AppLocalizations.of(context).translate('home'),
              AppLocalizations.of(context).translate('library'),
              AppLocalizations.of(context).translate('search'),
              AppLocalizations.of(context).translate('settings'),
            ][tabController.index],
          ),
          tabs: [
            _buildTabItem(
                context, AppLocalizations.of(context).translate('home')),
            _buildTabItem(
                context, AppLocalizations.of(context).translate('library')),
            _buildTabItem(
                context, AppLocalizations.of(context).translate('search')),
            _buildTabItem(
                context, AppLocalizations.of(context).translate('settings')),
          ],
        );
      },
    );
  }
}
