import 'dart:async';
import 'dart:ui';
import 'dart:math' as math;
import 'package:aurora_music_v01/core/constants/font_constants.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart'
    as permissionhandler;
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';
import '../../../shared/models/models.dart';
import '../../../shared/services/audio_player_service.dart';
import '../../../shared/services/artist_aggregator_service.dart';
import '../../../shared/services/artist_separator_service.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/glassmorphic_dialog.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/widgets/feedback_popup_widget.dart';
import '../../../shared/widgets/translation_reminder_dialog.dart';
import '../widgets/home_tab.dart';
import '../../search/widgets/search_tab.dart';
import '../../settings/widgets/settings_tab.dart';
import '../../../shared/widgets/outline_indicator.dart';
import '../../../shared/widgets/expanding_player.dart'; // For back button handling
import '../../../shared/widgets/auto_scroll_text.dart';
import '../../../shared/widgets/animated_progress_line.dart';
import '../../../shared/services/local_caching_service.dart';
import '../../../shared/services/notification_manager.dart';
import '../../../shared/services/download_progress_monitor.dart';
import '../../../shared/services/bluetooth_service.dart';
import '../widgets/library_tab.dart';
import 'package:aurora_music_v01/features/onboarding/screens/onboarding_screen.dart';
import '../../../shared/widgets/app_background.dart';
import '../../../shared/services/insights_promo_service.dart';
import '../screens/listening_recap_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  late final LocalCachingArtistService _artistService =
      LocalCachingArtistService();
  final ArtistAggregatorService _artistAggregator = ArtistAggregatorService();

  /// Kept so we can remove the songsNotifier listener in dispose() without
  /// needing a BuildContext at that point.
  AudioPlayerService? _audioServiceRef;
  List<SongModel> songs = [];
  List<String> randomArtists = [];
  List<SongModel> randomSongs = [];
  AnimationController? _animationController;
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<bool> _isScrolledNotifier = ValueNotifier<bool>(false);
  // Pull-to-refresh tracking
  double _pullProgress = 0.0;
  bool _isRefreshing = false;
  static const double _pullThreshold = 380.0; // pixels to pull for full refresh
  int _totalSongs = 0;
  List<SeparatedArtist> artists = [];
  List<AlbumModel> albums = [];
  // Removed expandable bottom sheet in favor of simple Hero-based navigation
  bool _isInitialized = false;
  late final ScrollController _appBarTextController;
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

    _showWelcomeMessage();
    _checkAndShowFeedbackReminder();
    _checkAndShowTranslationReminder();
    _checkRecapBanner();
  }

  // Initialize the home screen and check permissions
  Future<void> _initializeHomeScreen() async {
    try {
      // Set the toast context for notifications
      NotificationManager.setToastContext(context);

      // Subscribe to instant song-list updates (e.g. folder exclusion toggles).
      final audioService =
          Provider.of<AudioPlayerService>(context, listen: false);
      if (_audioServiceRef == null) {
        _audioServiceRef = audioService;
        audioService.songsNotifier.addListener(_onSongsListChanged);
      }

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
    ArtistSeparatorService().addListener(_onArtistSeparatorChanged);
  }

  void _onArtistSeparatorChanged() {
    // Separator config changed — reload artist list for search tab
    if (mounted) unawaited(_loadAlbumsAndArtists());
  }

  void _showWelcomeMessage() {
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        _notificationManager.showNotification(
          AppLocalizations.of(context).welcomeBack,
          onComplete: () => _notificationManager.showDefaultTitle(),
        );
      }
    });
  }

  Future<void> _checkRecapBanner() async {
    // Wait for library to load so SmartSuggestionsService is initialised.
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;
    final audioService =
        Provider.of<AudioPlayerService>(context, listen: false);
    await InsightsPromoService.checkAndTriggerBanner(
        audioService.firstListenTime);
  }

  Future<void> _checkAndShowFeedbackReminder() async {
    // Wait a bit before showing feedback reminder
    await Future.delayed(const Duration(seconds: 10));
    if (mounted) {
      await FeedbackPopupWidget.showIfNeeded(context);
    }
  }

  Future<void> _checkAndShowTranslationReminder() async {
    // Show after feedback reminder delay to avoid overlap
    await Future.delayed(const Duration(seconds: 20));
    if (mounted) {
      await TranslationReminderDialog.showIfNeeded(context);
    }
  }

  Future<void> _loadSmartSuggestions() async {
    if (songs.isEmpty) return;

    final audioPlayerService =
        Provider.of<AudioPlayerService>(context, listen: false);

    // Get smart suggestions based on listening patterns
    final suggestedTracks = await audioPlayerService.getSuggestedTracks();
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
      // Use ArtistAggregatorService for properly separated artists
      final loadedArtists = await _artistAggregator.getAllArtists();
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
      // Update notification manager so toast only shows when app bar is hidden
      NotificationManager.setAppBarVisible(!isScrolled);
    }
  }

  /// Called when [AudioPlayerService.songsNotifier] updates (e.g. a folder
  /// exclusion toggle).  Refreshes the song list used by [SearchTab] and
  /// reloads the For You / smart-suggestions section.
  void _onSongsListChanged() {
    if (!mounted) return;
    final audioService = _audioServiceRef;
    if (audioService == null) return;
    setState(() {
      songs = audioService.songs;
    });
    unawaited(_loadSmartSuggestions());
  }

  @override
  void dispose() {
    _audioServiceRef?.songsNotifier.removeListener(_onSongsListChanged);
    _animationController?.dispose();
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _isScrolledNotifier.dispose();
    _tabController.dispose();
    _appBarTextController.dispose();
    _notificationManager.dispose();
    _downloadStatusSubscription?.cancel();
    _downloadMonitor.stopMonitoring();
    ArtistSeparatorService().removeListener(_onArtistSeparatorChanged);
    super.dispose();
  }

  // Handle overscroll for pull-to-refresh
  bool _handleOverscroll(OverscrollNotification notification) {
    // Only handle overscroll at the top (negative overscroll)
    if (notification.overscroll < 0 && !_isRefreshing) {
      final pullAmount = -notification.overscroll;
      _pullProgress =
          (_pullProgress + pullAmount / _pullThreshold).clamp(0.0, 1.0);
      _notificationManager.updatePullProgress(_pullProgress);
    }
    return false;
  }

  // Handle scroll updates to allow pulling back (reducing progress)
  bool _handleScrollUpdate(ScrollUpdateNotification notification) {
    // If we have pull progress and user is scrolling down (releasing pull)
    if (_pullProgress > 0 &&
        !_isRefreshing &&
        notification.scrollDelta != null) {
      final delta = notification.scrollDelta!;
      // Positive delta means scrolling down (releasing the pull)
      if (delta > 0) {
        _pullProgress =
            (_pullProgress - delta / _pullThreshold).clamp(0.0, 1.0);
        _notificationManager.updatePullProgress(_pullProgress);
      }
    }
    return false;
  }

  // Handle scroll end to trigger refresh or reset
  bool _handleScrollEnd(ScrollEndNotification notification) {
    if (_pullProgress >= 1.0 && !_isRefreshing) {
      // Trigger refresh
      _triggerPullRefresh();
    } else if (!_isRefreshing) {
      // Reset progress
      _pullProgress = 0.0;
      _notificationManager.clearPullProgress();
    }
    return false;
  }

  Future<void> _triggerPullRefresh() async {
    _isRefreshing = true;
    _pullProgress = 0.0;
    unawaited(HapticFeedback.mediumImpact());

    await _refreshLibrary();

    _isRefreshing = false;
    unawaited(HapticFeedback.lightImpact());
  }

  Future<void> _refreshLibrary() async {
    final audioPlayerService =
        Provider.of<AudioPlayerService>(context, listen: false);
    final localizations = AppLocalizations.of(context);

    _notificationManager.showNotification(
      localizations.scanningSongs,
      isProgress: true,
    );

    try {
      // Re-initialize the music library from AudioPlayerService
      // Force rescan to truly re-query all songs from MediaStore
      final success =
          await audioPlayerService.initializeMusicLibrary(forceRescan: true);

      if (success) {
        // Get the updated songs from the service
        final allSongs = audioPlayerService.songs;
        _totalSongs = allSongs.length;

        // Update local state and trigger UI refresh
        if (mounted) {
          setState(() {
            songs = allSongs;
          });

          // Reload smart suggestions for For You section
          await _loadSmartSuggestions();

          // Reload albums and artists
          unawaited(_loadAlbumsAndArtists());
        }

        if (!mounted) return;
        _notificationManager.showNotification(
          '${localizations.libraryUpdated} ($_totalSongs ${localizations.songsLoaded})',
          duration: const Duration(seconds: 5),
          onComplete: () => _notificationManager.showDefaultTitle(),
        );

        await audioPlayerService.saveLibrary();
      } else {
        if (!mounted) return;
        _notificationManager.showNotification(
          localizations.scanFailed,
          duration: const Duration(seconds: 5),
          onComplete: () => _notificationManager.showDefaultTitle(),
        );
      }
    } catch (e) {
      debugPrint('Error refreshing library: $e');
      if (!mounted) return;
      _notificationManager.showNotification(
        localizations.scanFailed,
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
    final localizations = AppLocalizations.of(context);

    try {
      if (Platform.isAndroid) {
        // Check status without requesting (don't force request)
        final hasAudioPermission =
            await permissionhandler.Permission.audio.status.isGranted;
        final hasStoragePermission =
            await permissionhandler.Permission.storage.status.isGranted;

        if (hasAudioPermission || hasStoragePermission) {
          if (audioPlayerService.isLibraryInitialized) {
            if (!mounted) return;
            setState(() {
              songs = audioPlayerService.songs;
            });
            unawaited(_loadSmartSuggestions());
            unawaited(_loadAlbumsAndArtists());
            return;
          }

          // If we already have permissions, initialize the library
          if (!mounted) return;
          _notificationManager.showNotification(
            localizations.loadingLibrary,
            isProgress: true,
          );

          final success = await audioPlayerService.initializeMusicLibrary();

          if (!mounted) return;
          if (success) {
            _notificationManager.showNotification(
              localizations.libraryLoaded,
              duration: const Duration(seconds: 2),
              onComplete: () => _notificationManager.showDefaultTitle(),
            );

            // Get songs from the audio service
            setState(() {
              songs = audioPlayerService.songs;
            });
            unawaited(_loadSmartSuggestions());
            unawaited(_loadAlbumsAndArtists());
          } else {
            _showPermissionDialog();
          }
        } else {
          // Show permission UI - don't automatically request
          _showPermissionDialog();
        }
      } else if (Platform.isWindows) {
        if (audioPlayerService.isLibraryInitialized) {
          if (!mounted) return;
          setState(() {
            songs = audioPlayerService.songs;
          });
          unawaited(_loadSmartSuggestions());
          unawaited(_loadAlbumsAndArtists());
          return;
        }

        // Initialize for Windows immediately - no permissions needed
        _notificationManager.showNotification(
          localizations.loadingLibrary,
          isProgress: true,
        );

        final success = await audioPlayerService.initializeMusicLibrary();

        if (!mounted) return;
        if (success) {
          _notificationManager.showNotification(
            localizations.libraryLoaded,
            duration: const Duration(seconds: 2),
            onComplete: () => _notificationManager.showDefaultTitle(),
          );
        }

        setState(() {
          songs = audioPlayerService.songs;
        });
        unawaited(_loadSmartSuggestions());
        unawaited(_loadAlbumsAndArtists());
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
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(AppLocalizations.of(dialogContext).permissionRequired),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(AppLocalizations.of(dialogContext).permissionExplanation),
              const SizedBox(height: 12),
              Text(AppLocalizations.of(dialogContext).noPermissionExplanation,
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: Text(AppLocalizations.of(dialogContext).cancel),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                // User denied permission - handle accordingly
                setState(() {
                  songs = [];
                });

                // Show a snackbar explaining how to enable later
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(AppLocalizations.of(context).permissionLater),
                    duration: const Duration(seconds: 5),
                    action: SnackBarAction(
                      label: AppLocalizations.of(context).settings,
                      onPressed: () async {
                        await permissionhandler.openAppSettings();
                      },
                    ),
                  ),
                );
              },
            ),
            TextButton(
              child: Text(AppLocalizations.of(dialogContext).grantPermission),
              onPressed: () async {
                final audioPlayerService = Provider.of<AudioPlayerService>(
                    dialogContext,
                    listen: false);
                final localizations = AppLocalizations.of(dialogContext);
                Navigator.of(dialogContext).pop();
                // Request permissions
                final statuses = await [
                  permissionhandler.Permission.audio,
                  permissionhandler.Permission.storage,
                ].request();

                if (!mounted) return;

                final hasAudioPermission =
                    statuses[permissionhandler.Permission.audio]?.isGranted ??
                        false;
                final hasStoragePermission =
                    statuses[permissionhandler.Permission.storage]?.isGranted ??
                        false;

                if (hasAudioPermission || hasStoragePermission) {
                  // Permissions granted, initialize library
                  _notificationManager.showNotification(
                    localizations.loadingLibrary,
                    isProgress: true,
                  );

                  final success =
                      await audioPlayerService.initializeMusicLibrary();

                  if (!mounted) return;
                  if (success) {
                    _notificationManager.showNotification(
                      localizations.libraryLoaded,
                      duration: const Duration(seconds: 2),
                      onComplete: () => _notificationManager.showDefaultTitle(),
                    );

                    // Get songs from the audio service
                    setState(() {
                      songs = audioPlayerService.songs;
                      _randomizeContent();
                    });
                    unawaited(_loadAlbumsAndArtists());
                  } else {
                    setState(() {
                      songs = [];
                    });

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(localizations.libraryError),
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
                      content: Text(localizations.permDeny),
                      action: SnackBarAction(
                        label: localizations.settings,
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

  Future<bool> _showExitConfirmation() async {
    // If the player is expanded, minimize it instead of showing exit dialog
    if (ExpandingPlayer.isExpanded) {
      ExpandingPlayer.minimize();
      return false;
    }

    final audioService =
        Provider.of<AudioPlayerService>(context, listen: false);

    // Show the exit dialog when user attempts to leave the app
    final shouldExit = await showGlassmorphicDialog<bool>(
          context: context,
          builder: (context) => GlassmorphicDialog(
            title: Text(AppLocalizations.of(context).exitApp),
            content: Text(AppLocalizations.of(context).exitAppConfirm),
            actions: <Widget>[
              GlassmorphicTextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(AppLocalizations.of(context).no),
              ),
              GlassmorphicTextButton(
                onPressed: () => Navigator.of(context).pop(true),
                isPrimary: true,
                child: Text(AppLocalizations.of(context).yes),
              ),
            ],
          ),
        ) ??
        false;

    if (shouldExit) {
      // Stop audio and exit the app properly
      await audioService.stop();
      audioService.dispose();

      // Exit the app
      if (Platform.isAndroid) {
        unawaited(SystemNavigator.pop());
      } else if (Platform.isIOS) {
        exit(0);
      }
    }
    return shouldExit;
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
              child: StreamBuilder<NotificationState>(
                stream: _notificationManager.notificationStream,
                initialData: NotificationState.empty,
                builder: (context, snapshot) {
                  final state = snapshot.data ?? NotificationState.empty;
                  final message = state.message;
                  final isProgress = state.isProgress;
                  final pullProgress = state.pullProgress;

                  return AnimatedProgressLine(
                    isAnimating: isProgress,
                    determinateProgress: pullProgress,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: message.isEmpty
                          ? Text(
                              AppLocalizations.of(context).auroraMusic,
                              key: const ValueKey('default'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontFamily: FontConstants.fontFamily,
                                color: Colors.white,
                                fontSize: 34,
                                fontWeight: FontWeight.w500,
                              ),
                            )
                          : AutoScrollText(
                              key: ValueKey(message),
                              text: message,
                              style: const TextStyle(
                                fontFamily: FontConstants.fontFamily,
                                color: Colors.white,
                                fontSize: 34,
                                fontWeight: FontWeight.w500,
                              ),
                              onMessageComplete: (message) =>
                                  _notificationManager.showDefaultTitle(),
                            ),
                    ),
                  );
                },
              ),
            ),
            // Performance: Use AnimatedSize instead of AnimatedContainer
            // and Visibility instead of AnimatedOpacity for the bluetooth indicator
            AnimatedSize(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOutCubic,
              child: isConnected
                  ? Container(
                      height: 30,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
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
                              key: ValueKey(
                                  _bluetoothService.connectedDeviceName),
                              style: const TextStyle(
                                fontFamily: FontConstants.fontFamily,
                                fontSize: 12,
                                color: Color(0xFF10B981),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Only listen to currentSong changes, not all AudioPlayerService changes
    final currentSong = context.select<AudioPlayerService, SongModel?>(
      (service) => service.currentSong,
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _showExitConfirmation();
      },
      child: AppBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          resizeToAvoidBottomInset: false,
          body: Stack(
            children: [
              RepaintBoundary(
                child: NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    if (notification is OverscrollNotification) {
                      return _handleOverscroll(notification);
                    } else if (notification is ScrollUpdateNotification) {
                      return _handleScrollUpdate(notification);
                    } else if (notification is ScrollEndNotification) {
                      return _handleScrollEnd(notification);
                    }
                    return false;
                  },
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
                        // Performance: Removed BackdropFilter - blur during scroll causes dropped frames
                        // The app background already provides visual depth
                        flexibleSpace: LayoutBuilder(
                          builder: (context, constraints) {
                            // Calculate how collapsed the app bar is
                            // toolbarHeight(70) + bottom(55) + statusBar padding
                            final statusBarHeight =
                                MediaQuery.of(context).padding.top;
                            final minHeight =
                                kToolbarHeight + 55 + statusBarHeight;
                            final maxHeight = 250 + statusBarHeight;
                            final currentHeight = constraints.maxHeight;
                            // 0.0 = fully collapsed, 1.0 = fully expanded
                            final expandRatio = ((currentHeight - minHeight) /
                                    (maxHeight - minHeight))
                                .clamp(0.0, 1.0);

                            return FlexibleSpaceBar(
                              background: ValueListenableBuilder<bool>(
                                valueListenable:
                                    InsightsPromoService.recapBannerNotifier,
                                builder: (context, recapAvailable, _) {
                                  return AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 600),
                                    child: recapAvailable
                                        ? _RecapAppBarContent(
                                            key: const ValueKey('recap'),
                                            onShow: () {
                                              final period =
                                                  InsightsPromoService
                                                      .recapBannerPeriodNotifier
                                                      .value;
                                              InsightsPromoService
                                                  .recapBannerNotifier
                                                  .value = false;
                                              // Persist the period so the recap screen
                                              // opens with the right data window.
                                              InsightsPromoService
                                                  .setRecapPeriodDays(period);
                                              // Record that this week/month was viewed.
                                              final audioService = Provider.of<
                                                      AudioPlayerService>(
                                                  context,
                                                  listen: false);
                                              final first =
                                                  audioService.firstListenTime;
                                              if (first != null) {
                                                InsightsPromoService
                                                    .markRecapViewed(
                                                        period, first);
                                              }
                                              Navigator.of(context).push(
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      const ListeningRecapScreen(),
                                                ),
                                              );
                                            },
                                            onLater: () => InsightsPromoService
                                                .recapBannerNotifier
                                                .value = false,
                                          )
                                        : ColoredBox(
                                            key: const ValueKey('normal'),
                                            color: Colors.transparent,
                                            child: Center(
                                              child: Opacity(
                                                opacity: expandRatio,
                                                child: buildAppBarTitle(),
                                              ),
                                            ),
                                          ),
                                  );
                                },
                              ),
                              centerTitle: true,
                            );
                          },
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
                                        ? _BlurredNavBar(
                                            key: const ValueKey('scrolled'),
                                            child: _HomeTabBar(
                                                tabController: _tabController),
                                          )
                                        : _HomeTabBar(
                                            tabController: _tabController,
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
                              await launchUrl(
                                Uri.parse(
                                  'https://play.google.com/store/apps/details?id=com.aurorasoftware.music',
                                ),
                                mode: LaunchMode.externalApplication,
                              );
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
              ),
              // (Mini player is now overlaid globally in MaterialApp.builder)
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeTabBar extends StatefulWidget {
  final TabController tabController;

  const _HomeTabBar({required this.tabController});

  @override
  State<_HomeTabBar> createState() => _HomeTabBarState();
}

class _HomeTabBarState extends State<_HomeTabBar> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.tabController.index;
    widget.tabController.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    widget.tabController.removeListener(_onTabChanged);
    super.dispose();
  }

  void _onTabChanged() {
    final newIndex = widget.tabController.index;
    if (newIndex != _currentIndex && mounted) {
      setState(() {
        _currentIndex = newIndex;
      });
    }
  }

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
              fontFamily: FontConstants.fontFamily,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return TabBar(
      controller: widget.tabController,
      dividerColor: Colors.transparent,
      labelPadding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
      indicatorPadding: const EdgeInsets.symmetric(vertical: 4.0),
      indicator: OutlineIndicator(
        radius: const Radius.circular(20),
        text: [
          AppLocalizations.of(context).home,
          AppLocalizations.of(context).library,
          AppLocalizations.of(context).search,
          AppLocalizations.of(context).settings,
        ][_currentIndex],
      ),
      tabs: [
        _buildTabItem(context, AppLocalizations.of(context).home),
        _buildTabItem(context, AppLocalizations.of(context).library),
        _buildTabItem(context, AppLocalizations.of(context).search),
        _buildTabItem(context, AppLocalizations.of(context).settings),
      ],
    );
  }
}

/// Glassmorphic blurred pill container for the scrolled navbar state.
/// Respects [PerformanceModeProvider]: high-end gets BackdropFilter blur,
/// low-end gets a solid semi-transparent surface instead.
class _BlurredNavBar extends StatelessWidget {
  final Widget child;

  const _BlurredNavBar({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final shouldBlur = Provider.of<PerformanceModeProvider>(
      context,
      listen: false,
    ).shouldEnableBlur;

    const radius = BorderRadius.all(Radius.circular(30));
    final colorScheme = Theme.of(context).colorScheme;

    final decoration = shouldBlur
        ? const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0x26FFFFFF), // white 0.15
                Color(0x0DFFFFFF), // white 0.05
              ],
            ),
            borderRadius: radius,
            border: Border.fromBorderSide(
              BorderSide(color: Color(0x33FFFFFF)), // white 0.2
            ),
          )
        : BoxDecoration(
            color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.92),
            borderRadius: radius,
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
          );

    final inner = DecoratedBox(
      decoration: decoration,
      child: child,
    );

    if (!shouldBlur) {
      return ClipRRect(borderRadius: radius, child: inner);
    }

    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: inner,
      ),
    );
  }
}

// ── Recap AppBar content ──────────────────────────────────────────────────────

class _RecapAppBarContent extends StatefulWidget {
  final VoidCallback onShow;
  final VoidCallback onLater;

  const _RecapAppBarContent({
    super.key,
    required this.onShow,
    required this.onLater,
  });

  @override
  State<_RecapAppBarContent> createState() => _RecapAppBarContentState();
}

class _RecapAppBarContentState extends State<_RecapAppBarContent>
    with TickerProviderStateMixin {
  late final AnimationController _auroraCtrl;
  late final AnimationController _entryCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _auroraCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _auroraCtrl.dispose();
    _entryCtrl.dispose();
    super.dispose();
  }

  Future<void> _dismiss(VoidCallback callback) async {
    await _entryCtrl.reverse();
    if (mounted) callback();
  }

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        stops: [0.0, 0.28, 1.0],
        colors: [Colors.white, Colors.white, Colors.transparent],
      ).createShader(bounds),
      blendMode: BlendMode.dstIn,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Color(0xFF08000F)),
          AnimatedBuilder(
            animation: _auroraCtrl,
            builder: (_, __) =>
                CustomPaint(painter: _RecapAuroraPainter(_auroraCtrl.value)),
          ),
          FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: Align(
                alignment: const Alignment(0, 0.05),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      AppLocalizations.of(context).recapBannerTitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: FontConstants.fontFamily,
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w600,
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FilledButton(
                          onPressed: () => _dismiss(widget.onShow),
                          style: FilledButton.styleFrom(
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.18),
                            foregroundColor: Colors.white,
                            side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.35)),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 10),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(50)),
                          ),
                          child: Text(
                              AppLocalizations.of(context).recapBannerShow),
                        ),
                        const SizedBox(width: 12),
                        TextButton(
                          onPressed: () => _dismiss(widget.onLater),
                          style: TextButton.styleFrom(
                            foregroundColor:
                                Colors.white.withValues(alpha: 0.65),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 10),
                          ),
                          child: Text(
                              AppLocalizations.of(context).recapBannerLater),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecapAuroraPainter extends CustomPainter {
  final double t;
  _RecapAuroraPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..blendMode = BlendMode.screen;
    const pi = math.pi;

    // Circle 1 — large violet
    _band(canvas, size, p,
        color: const Color(0xFF6600CC),
        cx: 0.50 + 0.14 * math.sin(1 * 2 * pi * t),
        cy: 0.35 + 0.11 * math.cos(2 * 2 * pi * t),
        rw: size.width * 0.80,
        rh: size.width * 0.80);

    // Circle 2 — large magenta
    _band(canvas, size, p,
        color: const Color(0xFF990055),
        cx: 0.38 + 0.16 * math.cos(1 * 2 * pi * t + pi * 0.75),
        cy: 0.48 + 0.10 * math.sin(2 * 2 * pi * t + pi * 0.4),
        rw: size.width * 0.72,
        rh: size.width * 0.72);

    // Circle 3 — large deep indigo
    _band(canvas, size, p,
        color: const Color(0xFF1A0099),
        cx: 0.62 + 0.13 * math.sin(2 * 2 * pi * t + pi),
        cy: 0.42 + 0.12 * math.cos(1 * 2 * pi * t + pi * 1.6),
        rw: size.width * 0.76,
        rh: size.width * 0.76);
  }

  /// Draws a soft aurora blob: three gradient layers for a deeply blurred glow.
  void _band(Canvas canvas, Size size, Paint p,
      {required Color color,
      required double cx,
      required double cy,
      required double rw,
      required double rh}) {
    final center = Offset(cx * size.width, cy * size.height);

    // Ultra-diffuse outer cloud
    p.shader = RadialGradient(
      colors: [color.withValues(alpha: 0.15), color.withValues(alpha: 0.0)],
    ).createShader(
        Rect.fromCenter(center: center, width: rw * 5.0, height: rh * 5.0));
    canvas.drawOval(
        Rect.fromCenter(center: center, width: rw * 5.0, height: rh * 5.0), p);

    // Outer diffuse halo
    p.shader = RadialGradient(
      colors: [color.withValues(alpha: 0.35), color.withValues(alpha: 0.0)],
    ).createShader(
        Rect.fromCenter(center: center, width: rw * 3.0, height: rh * 3.0));
    canvas.drawOval(
        Rect.fromCenter(center: center, width: rw * 3.0, height: rh * 3.0), p);

    // Inner bright core
    p.shader = RadialGradient(
      colors: [color.withValues(alpha: 0.80), color.withValues(alpha: 0.0)],
    ).createShader(Rect.fromCenter(center: center, width: rw, height: rh));
    canvas.drawOval(Rect.fromCenter(center: center, width: rw, height: rh), p);
  }

  @override
  bool shouldRepaint(_RecapAuroraPainter old) => old.t != t;
}
