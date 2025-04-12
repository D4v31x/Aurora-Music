import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'package:aurora_music_v01/screens/tracks_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart' as permissionhandler;
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/playlist_model.dart';
import '../models/utils.dart';
import '../services/Audio_Player_Service.dart';
import '../localization/locale_provider.dart';
import '../localization/app_localizations.dart';
import '../services/spotify_service.dart';
import '../widgets/changelog_dialog.dart';
import '../widgets/expandable_bottom.dart';
import 'AlbumDetailScreen.dart';
import 'Artist_screen.dart';
import 'FolderDetail_screen.dart';
import 'PlaylistDetail_screen.dart';
import 'Playlist_screen.dart';
import 'categories.dart';
import 'now_playing.dart';
import '../widgets/glassmorphic_container.dart';
import '../widgets/outline_indicator.dart';
import '../widgets/mini_player.dart';
import '../services/local_caching_service.dart';
import '../services/artwork_cache_service.dart';
import '../services/expandable_player_controller.dart';
import '../widgets/artist_card.dart';
import '../widgets/library_tab.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:aurora_music_v01/providers/theme_provider.dart';
import 'package:aurora_music_v01/widgets/about_dialog.dart';

/// A screen that displays the main interface of the Aurora Music app.
///
/// This screen contains four main tabs:
/// - Home: Displays quick access items and suggested content
/// - Library: Shows the user's music library organized by categories
/// - Search: Allows users to search through their music collection
/// - Settings: Provides app configuration options
///
/// The screen also features a mini-player at the bottom when music is playing
/// and supports background artwork that changes based on the current song.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

/// The state class for the HomeScreen widget.
///
/// This class manages:
/// - Tab navigation and animations
/// - Music playback controls
/// - UI state and appearance
/// - Search functionality
/// - Settings configuration
class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  // Theme state
  late bool isDarkMode;

  // Controllers
  late TabController _tabController;
  late final ScrollController _scrollController = ScrollController();
  late final ScrollController _appBarTextController;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  late AnimationController _searchAnimationController;
  AnimationController? _animationController;

  // Services
  late final LocalCachingArtistService _artistService = LocalCachingArtistService();
  late final ArtworkCacheService _artworkService = ArtworkCacheService();
  late AudioPlayerService _audioPlayerService;
  final NotificationManager _notificationManager = NotificationManager();

  // UI State
  late final ValueNotifier<SongModel?> _currentSongNotifier = ValueNotifier<SongModel?>(null);
  final GlobalKey<ExpandableBottomSheetState> _expandableKey = GlobalKey<ExpandableBottomSheetState>();
  late Animation<double> _searchAnimation;
  Animation<Offset>? _slideAnimation;
  ImageProvider<Object>? _currentBackgroundImage;

  // Data
  List<SongModel> songs = [];
  List<String> randomArtists = [];
  List<SongModel> randomSongs = [];
  List<AlbumModel> albums = [];
  List<ArtistModel> artists = [];
  List<SongModel> _filteredSongs = [];
  final List<AlbumModel> _filteredAlbums = [];
  List<ArtistModel> _filteredArtists = [];
  final List<Map<String, dynamic>> _recentlyPlayedTracks = [];
  final List<Map<String, dynamic>> _spotifyPlaylists = [];

  // Caching
  final Map<int, Uint8List?> _artworkCache = {};
  final Map<int, ImageProvider<Object>?> _imageProviderCache = {};

  // State flags
  bool isWelcomeBackVisible = true;
  bool isAuroraMusicVisible = false;
  bool _showAppBar = true;
  bool _isSearching = false;
  bool _isInitialized = false;
  bool _isTabBarScrolled = false;
  bool _hasShownChangelog = false;
  String _currentVersion = '';

  // Notification state
  final Queue<String> _notificationQueue = Queue<String>();
  bool _isShowingNotification = false;
  String appBarMessage = '';
  bool isAppBarMessageVisible = false;

  // Scanning state
  bool _isScanning = false;
  int _scannedSongs = 0;
  int _totalSongs = 0;

  /// Initializes the state of the HomeScreen.
  ///
  /// Sets up:
  /// - Scroll listeners
  /// - Search functionality
  /// - Audio player service
  /// - Tab controller
  /// - Animations
  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    _searchController.addListener(_onSearchChanged);

    // Initialize audio player service
    final audioPlayerService = Provider.of<AudioPlayerService>(context, listen: false);
    _currentSongNotifier.value = audioPlayerService.currentSong;
    audioPlayerService.addListener(_updateCurrentSong);

    // Initialize tab controller
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });

    // Initialize search animations
    _searchAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _searchAnimation = CurvedAnimation(
      parent: _searchAnimationController,
      curve: Curves.easeInOut,
    );

    // Setup search focus listener
    _searchFocusNode.addListener(_onSearchFocusChange);

    // Initialize slide animation
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController!,
      curve: Curves.easeInOut,
    ));

    // Load initial data
    _loadLibraryData();
    _initializeData().then((_) {
      if (mounted) {
        setState(() {
          _isInitialized = true;
          _randomizeContent();
        });
      }
    });

    fetchSongs();

    // Initialize welcome animations
    _initializeWelcomeAnimations();

    // Check for updates and show changelog
    checkForNewVersion();
    _loadVersionInfo();

    // Initialize app bar controller
    _appBarTextController = ScrollController();
    _scrollController.addListener(_handleScroll);

    // Show welcome message
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showWelcomeMessage();
      _checkAndShowChangelog();
    });
  }

  /// Handles changes in search focus state
  void _onSearchFocusChange() {
    if (!mounted) return;

    setState(() {
      _isSearching = _searchFocusNode.hasFocus;
    });

    if (_searchFocusNode.hasFocus) {
      _searchAnimationController.forward();
    } else {
      _searchAnimationController.reverse();
    }
  }

  /// Initializes welcome animations
  void _initializeWelcomeAnimations() {
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          isWelcomeBackVisible = false;
        });
      }
    });

    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) {
        setState(() {
          isAuroraMusicVisible = true;
        });
      }
    });
  }

  /// Shows the welcome message notification
  void _showWelcomeMessage() {
    if (!mounted) return;
    _notificationManager.showNotification(
      AppLocalizations.of(context).translate('welcome_back'),
      duration: const Duration(seconds: 3),
      onComplete: () => _notificationManager.showDefaultTitle(),
    );
  }

  /// Handles scroll events for the main scroll view
  void _handleScroll() {
    final isScrolled = _scrollController.offset > 180;
    if (_isTabBarScrolled != isScrolled && mounted) {
      setState(() {
        _isTabBarScrolled = isScrolled;
      });
    }
  }

  /// Updates the current song state when it changes
  void _updateCurrentSong() {
    if (!mounted) return;
    _currentSongNotifier.value = _audioPlayerService.currentSong;
  }

  /// Randomizes the displayed content in the UI
  void _randomizeContent() {
    if (!mounted || songs.isEmpty) return;

    setState(() {
      randomSongs = List.from(songs)..shuffle();
      randomSongs = randomSongs.take(3).toList();

      final uniqueArtists = songs
          .map((song) => splitArtists(song.artist ?? ''))
          .expand((artist) => artist)
          .toSet()
          .toList();

      randomArtists = List.from(uniqueArtists)..shuffle();
      randomArtists = randomArtists.take(3).toList();
    });
  }

  Future<void> _loadVersionInfo() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _currentVersion = packageInfo.version;
    });
  }

  Future<void> _checkAndShowChangelog() async {
    if (_hasShownChangelog) return;

    final prefs = await SharedPreferences.getInstance();
    final lastVersion = prefs.getString('last_version') ?? '';

    if (lastVersion != _currentVersion) {
      await prefs.setString('last_version', _currentVersion);
      if (mounted) {
        _showChangelogDialog();
        _hasShownChangelog = true;
      }
    }
  }

  Future<List<SongModel>> _processSongsInBackground(List<SongModel> songs) async {
    return compute(_processMetadata, songs);
  }

  static List<SongModel> _processMetadata(List<SongModel> songs) {
    // Perform any heavy processing on the songs here
    return songs;
  }

  /// Handles scroll events for the main content
  void _scrollListener() {
    if (!mounted) return;

    final shouldShowAppBar = _scrollController.offset <= 180;
    if (_showAppBar != shouldShowAppBar) {
      setState(() {
        _showAppBar = shouldShowAppBar;
      });
    }
  }

  /// Adds a message to the app bar notification queue
  ///
  /// [message] The message to display
  /// [duration] How long to display the message (defaults to 3 seconds)
  void enqueueAppBarMessage(String message, {Duration duration = const Duration(seconds: 3)}) {
    _notificationQueue.add(message);
    _showNextNotification(duration);
  }

  /// Shows the next notification in the queue if one exists
  ///
  /// [duration] How long to show the notification
  void _showNextNotification(Duration duration) {
    if (_isShowingNotification || _notificationQueue.isEmpty) return;

    _isShowingNotification = true;
    final message = _notificationQueue.removeFirst();

    if (!mounted) return;

    setState(() {
      appBarMessage = message;
    });

    Future.delayed(duration, () {
      if (!mounted) return;

      setState(() {
        appBarMessage = '';
      });
      _isShowingNotification = false;
      _showNextNotification(duration);
    });
  }

  /// Shows a message in the app bar
  ///
  /// [message] The message to display
  /// [duration] How long to display the message (defaults to 8 seconds)
  void showAppBarMessage(String message, {Duration duration = const Duration(seconds: 8)}) {
    enqueueAppBarMessage(message, duration: duration);
  }

  /// Handles changes in the search query
  void _onSearchChanged() {
    if (!mounted) return;

    final query = _searchController.text.toLowerCase();

    if (query.isEmpty) {
      setState(() {
        _filteredSongs = [];
        _filteredArtists = [];
      });
      return;
    }

    setState(() {
      _filteredSongs = songs.where((song) {
        final titleMatch = song.title.toLowerCase().contains(query);
        final artistMatch = (song.artist ?? '').toLowerCase().contains(query);
        return titleMatch || artistMatch;
      }).toList();

      _filteredArtists = artists.where((artist) {
        final artistName = artist.artist.toLowerCase();
        return artistName.contains(query);
      }).toList();
    });
  }

  /// Initializes the app's data by loading songs, artists, and albums
  Future<void> _initializeData() async {
    if (!mounted) return;

    try {
      final onAudioQuery = OnAudioQuery();

      final results = await Future.wait([
        onAudioQuery.querySongs(),
        onAudioQuery.queryArtists(),
        onAudioQuery.queryAlbums(),
      ]);

      if (!mounted) return;

      setState(() {
        songs = results[0] as List<SongModel>;
        artists = results[1] as List<ArtistModel>;
        albums = results[2] as List<AlbumModel>;
        _randomizeContent();
      });
    } catch (e) {
      debugPrint('Initialization error: $e');
    }
  }

  /// Updates the background image based on the current song
  ///
  /// [song] The current song being played
  Future<void> _updateBackgroundImage(SongModel? song) async {
    if (!mounted) return;

    ImageProvider<Object>? newBackground;

    if (song == null) {
      newBackground = AssetImage(
        isDarkMode
            ? 'assets/images/background/dark_back.jpg'
            : 'assets/images/background/light_back.jpg',
      );
    } else {
      final artwork = await _getArtwork(song.id);
      newBackground = artwork != null
          ? MemoryImage(artwork)
          : AssetImage(
              isDarkMode
                  ? 'assets/images/background/dark_back.jpg'
                  : 'assets/images/background/light_back.jpg',
            ) as ImageProvider<Object>;
    }

    if (!mounted) return;

    setState(() {
      _currentBackgroundImage = newBackground;
    });
  }

  /// Retrieves artwork for a song from cache or loads it if not cached
  ///
  /// [id] The ID of the song to get artwork for
  /// Returns the artwork as a byte array if found, null otherwise
  Future<Uint8List?> _getArtwork(int id) async {
    if (_artworkCache.containsKey(id)) {
      return _artworkCache[id];
    }

    final artwork = await OnAudioQuery().queryArtwork(id, ArtworkType.AUDIO);
    _artworkCache[id] = artwork;
    return artwork;
  }

  @override
  void dispose() {
    _animationController?.dispose();
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _currentSongNotifier.dispose();
    _tabController.dispose();
    _searchAnimationController.dispose();
    _searchFocusNode.dispose();
    Provider.of<AudioPlayerService>(context, listen: false).removeListener(_updateCurrentSong);
    _appBarTextController.dispose();
    _notificationManager.dispose();
    _audioPlayerService.removeListener(_updateCurrentSong);
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

  Future<VersionCheckResult> checkForNewVersion() async {
    try {
      final response = await http.get(Uri.parse(
          'https://api.github.com/repos/D4v31x/Aurora-Music/releases/latest'));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final versionString = data['tag_name'];

        final regex = RegExp(r'^v?(\d+\.\d+\.\d+(-[a-zA-Z0-9.\-]+)?)$');
        final match = regex.firstMatch(versionString);
        if (match != null && match.groupCount > 0) {
          final latestVersionString = match.group(1)!;
          final latestVersion = Version.parse(latestVersionString);

          final currentVersion = Version.parse('0.0.9');

          if (latestVersion > currentVersion) {
            return VersionCheckResult(
              isUpdateAvailable: true,
              latestVersion: latestVersion,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Version check error: $e');
    }
    return VersionCheckResult(isUpdateAvailable: false, latestVersion: null);
  }

  void _showUpToDateSnackBar() {
    setState(() {
      appBarMessage = AppLocalizations.of(context).translate('app_up_to_date');
      isAppBarMessageVisible = true;
    });
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          isAppBarMessageVisible = false;
        });
      }
    });
  }

  void _showVersionCheckErrorSnackBar() {
    setState(() {
      appBarMessage = AppLocalizations.of(context).translate('version_check_error');
      isAppBarMessageVisible = true;
    });
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          isAppBarMessageVisible = false;
        });
      }
    });
  }

  void _showUpdateAvailableDialog(Version latestVersion) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          AppLocalizations.of(context).translate('update_available'),
        ),
        content: Text(
          AppLocalizations.of(context)
              .translate('update_message')
              .replaceFirst('%s', latestVersion.toString()),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text(AppLocalizations.of(context).translate('later')),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await launchUrl(Uri.parse('https://github.com/D4v31x/Aurora-Music/releases/latest'));
            },
            child: Text(AppLocalizations.of(context).translate('update_now')),
          ),
        ],
      ),
    );
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

  Future<void> fetchSongs() async {
    try {
      if (Platform.isAndroid) {
        final statuses = await [
          permissionhandler.Permission.audio,
          permissionhandler.Permission.storage,
        ].request();

        bool hasAudioPermission = statuses[permissionhandler.Permission.audio]?.isGranted ?? false;
        bool hasStoragePermission = statuses[permissionhandler.Permission.storage]?.isGranted ?? false;

        if (hasAudioPermission || hasStoragePermission) {
          final onAudioQuery = OnAudioQuery();
          final songsResult = await onAudioQuery.querySongs();
          final processedSongs = await _processSongsInBackground(songsResult);

          setState(() {
            songs = processedSongs;
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context).translate('perm_deny')),
            ),
          );
        }
      } else if (Platform.isWindows) {
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

        final List<SongModel> windowsSongs = files.map(createSongModelFromFile).toList();
        final processedSongs = await _processSongsInBackground(windowsSongs);

        setState(() {
          songs = processedSongs;
        });
      }
    } catch (e, stack) {
      debugPrint('Error fetching songs: $e\n$stack');
    }
  }

  SongModel createSongModelFromFile(File file) {
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
  }

  void launchURL(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      try {
        await launchUrl(uri);
      } catch (_) {}
    } else {
      throw 'Could not launch $url';
    }
  }

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
    final audioPlayerService = Provider.of<AudioPlayerService>(context);
    _audioPlayerService = Provider.of<AudioPlayerService>(context, listen: false);
    _updateBackgroundImage(audioPlayerService.currentSong);
  }

  void _onSongTap(SongModel song) {
    final audioPlayerService = Provider.of<AudioPlayerService>(context, listen: false);
    final expandableController = Provider.of<ExpandablePlayerController>(context, listen: false);

    List<SongModel> playlist = _tabController.index == 2 ? _filteredSongs : randomSongs;
    int initialIndex = playlist.indexOf(song);

    audioPlayerService.setPlaylist(playlist, initialIndex);
    audioPlayerService.play();
    _updateBackgroundImage(song);

    expandableController.show();
  }

  Widget buildBackground(SongModel? currentSong) {
    _currentBackgroundImage ??= AssetImage(
      isDarkMode
          ? 'assets/images/background/dark_back.jpg'
          : 'assets/images/background/light_back.jpg',
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      decoration: BoxDecoration(
        image: DecorationImage(
          image: _currentBackgroundImage!,
          fit: BoxFit.cover,
        ),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          color: Colors.black.withOpacity(0.5),
        ),
      ),
    );
  }

  Widget buildSettingsCategory({required String title, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 10.0),
        ...children,
        const SizedBox(height: 20.0),
      ],
    );
  }

  Widget buildThemeSelector() {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        return glassmorphicContainer(
          child: ListTile(
            title: Text(
              AppLocalizations.of(context).translate('theme'),
              style: const TextStyle(color: Colors.white),
            ),
            trailing: Switch(
              value: themeProvider.isDarkMode,
              onChanged: (value) {
                themeProvider.toggleTheme();
                _updateBackgroundImage(Provider.of<AudioPlayerService>(context, listen: false).currentSong);
              },
              activeColor: Colors.white,
              inactiveTrackColor: Colors.white.withOpacity(0.3),
            ),
            subtitle: Text(
              themeProvider.isDarkMode
                  ? AppLocalizations.of(context).translate('dark_mode')
                  : AppLocalizations.of(context).translate('light_mode'),
              style: TextStyle(color: Colors.white.withOpacity(0.7)),
            ),
          ),
        );
      },
    );
  }

  Widget buildSettingsTab() {
    final audioPlayerService = Provider.of<AudioPlayerService>(context);
    final currentSong = audioPlayerService.currentSong;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 30.0)
          .copyWith(bottom: currentSong != null ? 90.0 : 30.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Playback Settings
          buildSettingsCategory(
            title: AppLocalizations.of(context).translate('playback'),
            children: [
              glassmorphicContainer(
                child: Column(
                  children: [
                    // Gapless Playback
                    ListTile(
                      leading: const Icon(Icons.play_circle_outline, color: Colors.white),
                      title: const Text(
                        'Gapless Playback',
                        style: TextStyle(color: Colors.white),
                      ),
                      trailing: Switch(
                        value: audioPlayerService.gaplessPlayback,
                        onChanged: (value) => audioPlayerService.setGaplessPlayback(value),
                        activeColor: Colors.white,
                        inactiveTrackColor: Colors.white.withOpacity(0.3),
                      ),
                    ),
                    const Divider(color: Colors.white24),

                    // Volume Normalization
                    ListTile(
                      leading: const Icon(Icons.volume_up_outlined, color: Colors.white),
                      title: const Text(
                        'Volume Normalization',
                        style: TextStyle(color: Colors.white),
                      ),
                      trailing: Switch(
                        value: audioPlayerService.volumeNormalization,
                        onChanged: (value) => audioPlayerService.setVolumeNormalization(value),
                        activeColor: Colors.white,
                        inactiveTrackColor: Colors.white.withOpacity(0.3),
                      ),
                    ),
                    const Divider(color: Colors.white24),

                    // Playback Speed
                    ListTile(
                      leading: const Icon(Icons.speed, color: Colors.white),
                      title: const Text(
                        'Playback Speed',
                        style: TextStyle(color: Colors.white),
                      ),
                      trailing: DropdownButton<double>(
                        dropdownColor: Colors.grey[900],
                        value: audioPlayerService.playbackSpeed,
                        items: [0.5, 0.75, 1.0, 1.25, 1.5, 2.0].map((speed) {
                          return DropdownMenuItem<double>(
                            value: speed,
                            child: Text(
                              '${speed}x',
                              style: const TextStyle(color: Colors.white),
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            audioPlayerService.setPlaybackSpeed(value);
                          }
                        },
                        underline: Container(),
                        icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Library Settings
          buildSettingsCategory(
            title: AppLocalizations.of(context).translate('library'),
            children: [
              glassmorphicContainer(
                child: Column(
                  children: [
                    // Default Sort Order
                    ListTile(
                      leading: const Icon(Icons.sort, color: Colors.white),
                      title: const Text(
                        'Default Sort Order',
                        style: TextStyle(color: Colors.white),
                      ),
                      trailing: DropdownButton<String>(
                        dropdownColor: Colors.grey[900],
                        value: audioPlayerService.defaultSortOrder,
                        items: ['title', 'artist', 'album', 'date_added'].map((sort) {
                          return DropdownMenuItem<String>(
                            value: sort,
                            child: Text(
                              sort.replaceAll('_', ' ').toUpperCase(),
                              style: const TextStyle(color: Colors.white),
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            audioPlayerService.setDefaultSortOrder(value);
                          }
                        },
                        underline: Container(),
                        icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                      ),
                    ),
                    const Divider(color: Colors.white24),

                    // Auto Playlists
                    ListTile(
                      leading: const Icon(Icons.playlist_add_check, color: Colors.white),
                      title: const Text(
                        'Auto Playlists',
                        style: TextStyle(color: Colors.white),
                      ),
                      trailing: Switch(
                        value: audioPlayerService.autoPlaylists,
                        onChanged: (value) => audioPlayerService.setAutoPlaylists(value),
                        activeColor: Colors.white,
                        inactiveTrackColor: Colors.white.withOpacity(0.3),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Advanced Settings
          buildSettingsCategory(
            title: AppLocalizations.of(context).translate('advanced'),
            children: [
              glassmorphicContainer(
                child: Column(
                  children: [
                    // Cache Size
                    ListTile(
                      leading: const Icon(Icons.memory, color: Colors.white),
                      title: const Text(
                        'Cache Size',
                        style: TextStyle(color: Colors.white),
                      ),
                      trailing: DropdownButton<int>(
                        dropdownColor: Colors.grey[900],
                        value: audioPlayerService.cacheSize,
                        items: [100, 250, 500, 1000, 2000].map((size) {
                          return DropdownMenuItem<int>(
                            value: size,
                            child: Text(
                              '${size}MB',
                              style: const TextStyle(color: Colors.white),
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            audioPlayerService.setCacheSize(value);
                          }
                        },
                        underline: Container(),
                        icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                      ),
                    ),
                    const Divider(color: Colors.white24),

                    // Media Controls
                    ListTile(
                      leading: const Icon(Icons.notifications, color: Colors.white),
                      title: const Text(
                        'Media Controls',
                        style: TextStyle(color: Colors.white),
                      ),
                      trailing: Switch(
                        value: audioPlayerService.mediaControls,
                        onChanged: (value) => audioPlayerService.setMediaControls(value),
                        activeColor: Colors.white,
                        inactiveTrackColor: Colors.white.withOpacity(0.3),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // About Section
          buildSettingsCategory(
            title: AppLocalizations.of(context).translate('about'),
            children: [
              glassmorphicContainer(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.info_outline, color: Colors.white),
                      title: Text(
                        AppLocalizations.of(context).translate('about_aurora'),
                        style: const TextStyle(color: Colors.white),
                      ),
                      trailing: const Icon(Icons.chevron_right, color: Colors.white),
                      onTap: () => _showAboutDialog(),
                    ),
                    const Divider(color: Colors.white24),
                    ListTile(
                      leading: const Icon(Icons.system_update, color: Colors.white),
                      title: Text(
                        AppLocalizations.of(context).translate('check_updates'),
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        'Version $_currentVersion',
                        style: TextStyle(color: Colors.white.withOpacity(0.7)),
                      ),
                      onTap: checkForUpdates,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildManualUpdateCheck() {
    return glassmorphicContainer(
      child: ListTile(
        title: Text(
          AppLocalizations.of(context).translate('check_for_updates'),
          style: const TextStyle(color: Colors.white),
        ),
        trailing: const Icon(Icons.system_update, color: Colors.white),
        onTap: () async {
          _notificationManager.showNotification(
            AppLocalizations.of(context).translate('checking_for_updates'),
            duration: const Duration(seconds: 2),
          );

          VersionCheckResult result = await checkForNewVersion();

          if (result.isUpdateAvailable && result.latestVersion != null) {
            _notificationManager.showNotification(
              AppLocalizations.of(context).translate('update_found'),
              duration: const Duration(seconds: 3),
              onComplete: () {
                _showUpdateAvailableDialog(result.latestVersion!);
                _notificationManager.showDefaultTitle();
              },
            );
          } else {
            _notificationManager.showNotification(
              AppLocalizations.of(context).translate('no_update_found'),
              duration: const Duration(seconds: 3),
              onComplete: () => _notificationManager.showDefaultTitle(),
            );
          }
        },
      ),
    );
  }

  Widget buildLanguageSelector() {
    return glassmorphicContainer(
      child: ListTile(
        title: Text(
          AppLocalizations.of(context).translate('language'),
          style: const TextStyle(color: Colors.white),
        ),
        trailing: DropdownButton<String>(
          value: LocaleProvider.of(context)!.locale.languageCode,
          dropdownColor: Colors.black.withOpacity(0.8),
          style: const TextStyle(color: Colors.white),
          onChanged: (String? newValue) {
            if (newValue != null) {
              LocaleProvider.of(context)!.setLocale(Locale(newValue));
            }
          },
          items: <String>['en', 'cs'].map<DropdownMenuItem<String>>((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(
                value == 'en' ? 'English' : 'Čeština',
                style: const TextStyle(color: Colors.white),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget buildLibraryTab() {
    final audioPlayerService = Provider.of<AudioPlayerService>(context);

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: 20.0,
        right: 20.0,
        top: 30.0,
        bottom: audioPlayerService.currentSong != null ? 90.0 : 30.0,
      ),
      child: AnimationLimiter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: AnimationConfiguration.toStaggeredList(
            duration: const Duration(milliseconds: 375),
            childAnimationBuilder: (widget) => SlideAnimation(
              verticalOffset: 50.0,
              child: FadeInAnimation(child: widget),
            ),
            children: [
              buildCategorySection(
                title: AppLocalizations.of(context).translate('tracks'),
                items: audioPlayerService.getMostPlayedTracks(),
                onDetailsTap: () => Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) => const TracksScreen(),
                    transitionsBuilder: (context, animation, secondaryAnimation, child) =>
                        FadeTransition(opacity: animation, child: child),
                  ),
                ),
                onItemTap: (song) {
                  if (song is SongModel) {
                    audioPlayerService.setPlaylist([song], 0);
                    audioPlayerService.play();
                  }
                },
              ),
              const SizedBox(height: 30.0),
              buildCategorySection(
                title: AppLocalizations.of(context).translate('albums'),
                items: audioPlayerService.getMostPlayedAlbums(),
                onDetailsTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AlbumsScreen()),
                ),
                onItemTap: (album) {
                  if (album is AlbumModel) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AlbumDetailScreen(albumName: album.album),
                      ),
                    );
                  }
                },
              ),
              const SizedBox(height: 30.0),
              Consumer<AudioPlayerService>(
                builder: (context, audioPlayerService, child) {
                  return buildCategorySection(
                    title: AppLocalizations.of(context).translate('playlists'),
                    items: audioPlayerService.getThreePlaylists(),
                    onDetailsTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const PlaylistsScreenList()),
                    ),
                    onItemTap: (playlist) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PlaylistDetailScreen(playlist: playlist),
                        ),
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 30.0),
              buildCategorySection(
                title: AppLocalizations.of(context).translate('artists'),
                items: audioPlayerService.getMostPlayedArtists(),
                onDetailsTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ArtistsScreen()),
                ),
                onItemTap: (artist) {
                  if (artist is String) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ArtistDetailsScreen(
                          artistName: artist,
                          artistImagePath: null,
                        ),
                      ),
                    );
                  }
                },
              ),
              const SizedBox(height: 30.0),
              buildCategorySection(
                title: AppLocalizations.of(context).translate('folders'),
                items: audioPlayerService.getThreeFolders(),
                onDetailsTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const FoldersScreen()),
                ),
                onItemTap: (folder) {
                  if (folder is String) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => FolderDetailScreen(
                          folderPath: folder,
                        ),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildCategorySection({
    required String title,
    required dynamic items,
    required VoidCallback onDetailsTap,
    Function(dynamic)? onItemTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            GestureDetector(
              onTap: onDetailsTap,
              child: glassmorphicContainer(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Text(
                    AppLocalizations.of(context).translate('details'),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10.0),
        SizedBox(
          height: 150,
          child: items is Future
              ? FutureBuilder<List<dynamic>>(
                  future: items as Future<List<dynamic>>,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    } else if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(child: Text('No data available'));
                    } else {
                      return _buildAnimatedItemsList(snapshot.data!, onItemTap);
                    }
                  },
                )
              : _buildAnimatedItemsList(items, onItemTap),
        ),
      ],
    );
  }

  Widget _buildAnimatedItemsList(List<dynamic> items, Function(dynamic)? onItemTap) {
    return AnimationLimiter(
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: min(3, items.length),
        itemBuilder: (context, index) {
          final item = items[index];
          return AnimationConfiguration.staggeredList(
            position: index,
            duration: const Duration(milliseconds: 375),
            child: SlideAnimation(
              horizontalOffset: 50.0,
              child: FadeInAnimation(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onItemTap != null ? () => onItemTap(item) : null,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: glassmorphicContainer(
                        child: SizedBox(
                          width: 120,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              getItemIcon(item),
                              const SizedBox(height: 8),
                              Text(
                                getItemTitle(item),
                                style: const TextStyle(color: Colors.white),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget getItemIcon(dynamic item) {
    if (item is SongModel) {
      return QueryArtworkWidget(
        id: item.id,
        type: ArtworkType.AUDIO,
        nullArtworkWidget: const Icon(Icons.music_note, color: Colors.white, size: 60),
      );
    } else if (item is AlbumModel) {
      return QueryArtworkWidget(
        id: item.id,
        type: ArtworkType.ALBUM,
        nullArtworkWidget: const Icon(Icons.album, color: Colors.white, size: 60),
      );
    } else if (item is Playlist) {
      return const Icon(Icons.playlist_play, color: Colors.white, size: 60);
    } else if (item is ArtistModel) {
      return const CircleAvatar(
        radius: 30,
        backgroundImage: AssetImage('assets/images/logo/default_art.png'),
      );
    } else if (item is String) {
      return const Icon(Icons.folder, color: Colors.white, size: 60);
    }
    return const Icon(Icons.error, color: Colors.white, size: 60);
  }

  String getItemTitle(dynamic item) {
    if (item is SongModel) return item.title;
    if (item is AlbumModel) return item.album;
    if (item is Playlist) return item.name;
    if (item is ArtistModel) return item.artist;
    if (item is String) return item;
    return 'Unknown';
  }

  Widget buildSearchBar() {
    return AnimatedBuilder(
      animation: _searchAnimation,
      builder: (context, child) {
        return Container(
          height: 60 + (40 * _searchAnimation.value),
          padding: EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 10 + (10 * _searchAnimation.value),
          ),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3 + (0.2 * _searchAnimation.value)),
            borderRadius: BorderRadius.circular(30),
          ),
          child: TextField(
            controller: _searchController,
            focusNode: _searchFocusNode,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: AppLocalizations.of(context).translate('search_hint'),
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
              prefixIcon: const Icon(Icons.search, color: Colors.white),
              suffixIcon: _isSearching
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.white),
                      onPressed: () {
                        _searchController.clear();
                        _searchFocusNode.unfocus();
                        _onSearchChanged();
                      },
                    )
                  : null,
              border: InputBorder.none,
            ),
            onChanged: (_) => _onSearchChanged(),
          ),
        );
      },
    );
  }

  Widget buildHomeTab() {
    return Consumer<AudioPlayerService>(
      builder: (context, audioPlayerService, _) {
        final currentSong = audioPlayerService.currentSong;

        return RefreshIndicator(
          onRefresh: _refreshLibrary,
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              left: 20.0,
              right: 20.0,
              top: 20.0,
              bottom: currentSong != null ? 90.0 : 30.0,
            ),
            child: AnimationLimiter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: AnimationConfiguration.toStaggeredList(
                  duration: const Duration(milliseconds: 375),
                  childAnimationBuilder: (widget) => SlideAnimation(
                    verticalOffset: 50.0,
                    child: FadeInAnimation(child: widget),
                  ),
                  children: [
                    const SizedBox(height: 20.0),
                    SlideAnimation(
                      verticalOffset: 50.0,
                      child: FadeInAnimation(
                        child: Text(
                          AppLocalizations.of(context).translate('quick_access'),
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20.0),
                    SlideAnimation(
                      verticalOffset: 50.0,
                      child: FadeInAnimation(
                        child: _buildQuickAccessSection(audioPlayerService),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickAccessSection(AudioPlayerService audioPlayerService) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildCategorySection(
          title: AppLocalizations.of(context).translate('recently_played'),
          items: audioPlayerService.getRecentlyPlayed(),
          onDetailsTap: () {},
          onItemTap: (song) {
            if (song is SongModel) {
              audioPlayerService.setPlaylist([song], 0);
              audioPlayerService.play();
            }
          },
        ),
        const SizedBox(height: 30.0),
        buildCategorySection(
          title: AppLocalizations.of(context).translate('albums'),
          items: audioPlayerService.getMostPlayedAlbums(),
          onDetailsTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AlbumsScreen()),
          ),
          onItemTap: (album) {
            if (album is AlbumModel) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AlbumDetailScreen(albumName: album.album),
                ),
              );
            }
          },
        ),
        const SizedBox(height: 30.0),
        ValueListenableBuilder<List<Playlist>>(
          valueListenable: audioPlayerService.playlistsNotifier,
          builder: (context, playlists, _) {
            return buildCategorySection(
              title: AppLocalizations.of(context).translate('playlists'),
              items: audioPlayerService.getThreePlaylists(),
              onDetailsTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PlaylistsScreenList()),
              ),
              onItemTap: (playlist) {
                if (playlist is Playlist) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PlaylistDetailScreen(playlist: playlist),
                    ),
                  );
                }
              },
            );
          },
        ),
      ],
    );
  }

  Widget buildSearchTab() {
    if (!_isInitialized) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            focusNode: _searchFocusNode,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: AppLocalizations.of(context).translate('search'),
              hintStyle: const TextStyle(color: Colors.white54),
              prefixIcon: const Icon(Icons.search, color: Colors.white54),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: const BorderSide(color: Colors.white24),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: const BorderSide(color: Colors.white24),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: const BorderSide(color: Colors.white),
              ),
            ),
          ),
        ),
        Expanded(
          child: buildSearchResults(),
        ),
      ],
    );
  }

  Widget buildSearchResults() {
    if (_searchController.text.isEmpty) {
      return Center(
        child: Text(AppLocalizations.of(context).translate('Start_type'), style: const TextStyle(color: Colors.white70)),
      );
    }

    final query = _searchController.text.toLowerCase();
    final matchingArtists = artists.where(
      (artist) => artist.artist.toLowerCase().contains(query),
    ).toList();

    final closestArtist = matchingArtists.isNotEmpty ? matchingArtists.first : null;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (closestArtist != null) ...[
          ArtistCard(
            artistName: closestArtist.artist,
            onTap: () => _navigateToArtistDetails(closestArtist.artist, null),
          ),
          const SizedBox(height: 20),
        ],
        if (_filteredSongs.isNotEmpty) ...[
          Text(
            AppLocalizations.of(context).translate('songs'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          ..._filteredSongs.map(_buildSongListTile),
        ],
      ],
    );
  }

  Widget _buildSongListTile(SongModel song) {
    return ListTile(
      leading: buildCachedArtwork(song.id),
      title: Text(
        song.title,
        style: const TextStyle(color: Colors.white),
      ),
      subtitle: Text(
        song.artist ?? '',
        style: TextStyle(color: Colors.white.withOpacity(0.7)),
      ),
      trailing: const Icon(Icons.favorite_border, color: Colors.white),
      onTap: () => _onSongTap(song),
    );
  }

  void _onSuggestedSongTap(SongModel song, List<SongModel> suggestedSongs) {
    final audioPlayerService = Provider.of<AudioPlayerService>(context, listen: false);
    final expandableController = Provider.of<ExpandablePlayerController>(context, listen: false);

    final initialIndex = suggestedSongs.indexOf(song);

    audioPlayerService.setPlaylist(suggestedSongs, initialIndex);
    audioPlayerService.play();
    _updateBackgroundImage(song);

    expandableController.show();
  }

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

  void _showChangelogDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => ChangelogDialog(
        currentVersion: _currentVersion,
      ),
    );
  }

  void updateScanningProgress(int current, int total) {
    _notificationManager.showNotification(
      AppLocalizations.of(context).translate('scanning_songs'),
      isProgress: true,
    );
  }

  void _showAboutDialog() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final codename = dotenv.env['CODE_NAME'] ?? 'Unknown';

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AuroraAboutDialog(
        version: packageInfo.version,
        codename: codename,
      ),
    );
  }

  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: glassmorphicContainer(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  AppLocalizations.of(context).translate('select_language'),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),
                ...AppLocalizations.supportedLocales.map((locale) {
                  final languageName = AppLocalizations.getLanguageName(locale.languageCode);
                  final currentLocale = LocaleProvider.of(context)?.locale;

                  return ListTile(
                    leading: Radio<Locale>(
                      value: locale,
                      groupValue: currentLocale,
                      onChanged: (Locale? value) {
                        if (value != null) {
                          LocaleProvider.of(context)?.setLocale(value);
                          Navigator.pop(context);
                        }
                      },
                      activeColor: Colors.white,
                    ),
                    title: Text(
                      languageName,
                      style: const TextStyle(color: Colors.white),
                    ),
                    onTap: () {
                      LocaleProvider.of(context)?.setLocale(locale);
                      Navigator.pop(context);
                    },
                  );
                }),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.1),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    AppLocalizations.of(context).translate('close'),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final audioPlayerService = Provider.of<AudioPlayerService>(context);
    final currentSong = audioPlayerService.currentSong;
    final expandableController = Provider.of<ExpandablePlayerController>(context);

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            buildBackground(currentSong),
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
                          tabs: [
                            _buildTabItem(AppLocalizations.of(context).translate('home')),
                            _buildTabItem(AppLocalizations.of(context).translate('library')),
                            _buildTabItem(AppLocalizations.of(context).translate('search')),
                            _buildTabItem(AppLocalizations.of(context).translate('settings')),
                          ],
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
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              body: TabBarView(
                controller: _tabController,
                children: [
                  buildHomeTab(),
                  const LibraryTab(),
                  buildSearchTab(),
                  buildSettingsTab(),
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

  /// Builds the quick access section of the home screen
  Widget buildQuickAccessSection() {
    final audioPlayerService = Provider.of<AudioPlayerService>(context);
    final likedSongsPlaylist = audioPlayerService.likedSongsPlaylist;

    return AnimationLimiter(
      child: Column(
        children: AnimationConfiguration.toStaggeredList(
          duration: const Duration(milliseconds: 375),
          childAnimationBuilder: (widget) => SlideAnimation(
            verticalOffset: 50.0,
            child: FadeInAnimation(child: widget),
          ),
          children: [
            if (likedSongsPlaylist != null)
              _buildLikedSongsPlaylistTile(likedSongsPlaylist),
            if (likedSongsPlaylist == null)
              _buildNoDataContainer(),
          ],
        ),
      ),
    );
  }

  /// Builds a tile for the liked songs playlist
  Widget _buildLikedSongsPlaylistTile(Playlist playlist) {
    return glassmorphicContainer(
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.asset(
            'assets/images/UI/liked_icon.png',
            width: 48,
            height: 48,
            fit: BoxFit.cover,
          ),
        ),
        title: Text(
          playlist.name,
          style: const TextStyle(color: Colors.white),
        ),
        subtitle: Text(
          '${playlist.songs.length} ${AppLocalizations.of(context).translate('tracks')}',
          style: TextStyle(color: Colors.white.withOpacity(0.7)),
        ),
        onTap: () => _navigateToPlaylistDetail(playlist),
      ),
    );
  }

  /// Navigates to the playlist detail screen
  void _navigateToPlaylistDetail(Playlist playlist) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlaylistDetailScreen(playlist: playlist),
      ),
    );
  }

  /// Builds a container for when no data is available
  Widget _buildNoDataContainer() {
    return glassmorphicContainer(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          AppLocalizations.of(context).translate('No_data'),
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  /// Builds the suggested tracks section of the home screen
  Widget buildSuggestedTracksSection() {
    if (randomSongs.isEmpty) {
      return _buildNoDataContainer();
    }

    final topThreeSongs = randomSongs.take(3).toList();
    final audioPlayerService = Provider.of<AudioPlayerService>(context);
    final likedSongsPlaylist = audioPlayerService.likedSongsPlaylist;

    return AnimationLimiter(
      child: Column(
        children: AnimationConfiguration.toStaggeredList(
          duration: const Duration(milliseconds: 375),
          childAnimationBuilder: (widget) => SlideAnimation(
            verticalOffset: 50.0,
            child: FadeInAnimation(child: widget),
          ),
          children: topThreeSongs.map((song) =>
            _buildSuggestedSongTile(song, topThreeSongs, likedSongsPlaylist)
          ).toList(),
        ),
      ),
    );
  }

  /// Builds a tile for a suggested song
  Widget _buildSuggestedSongTile(SongModel song, List<SongModel> allSongs, Playlist? likedSongsPlaylist) {
    final isLiked = likedSongsPlaylist?.songs.any((s) => s.id == song.id) ?? false;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _onSuggestedSongTap(song, allSongs),
          child: glassmorphicContainer(
            child: ListTile(
              leading: _artworkService.buildCachedArtwork(
                song.id,
                size: 50,
              ),
              title: Text(
                song.title,
                style: const TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                splitArtists(song.artist ?? '').join(', '),
                style: const TextStyle(color: Colors.grey),
              ),
              trailing: Icon(
                isLiked ? Icons.favorite : Icons.favorite_border,
                color: isLiked ? Colors.pink : Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Gets a cached image provider for artwork
  Future<ImageProvider<Object>> _getCachedImageProvider(int id) async {
    if (_imageProviderCache.containsKey(id)) {
      return _imageProviderCache[id] ??
             const AssetImage('assets/images/logo/default_art.png') as ImageProvider<Object>;
    }

    final artwork = await _getArtwork(id);
    final ImageProvider<Object> provider = artwork != null
        ? MemoryImage(artwork)
        : const AssetImage('assets/images/logo/default_art.png') as ImageProvider<Object>;
    _imageProviderCache[id] = provider;
    return provider;
  }

  /// Builds a cached artwork widget
  Widget buildCachedArtwork(int id, {double size = 50}) {
    return FutureBuilder<ImageProvider<Object>>(
      future: _getCachedImageProvider(id),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: size,
            height: size,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              image: DecorationImage(
                image: snapshot.data!,
                fit: BoxFit.cover,
              ),
            ),
          );
        }
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.music_note, color: Colors.white),
        );
      },
    );
  }

  /// Builds the suggested artists section of the home screen
  Widget buildSuggestedArtistsSection() {
    if (randomArtists.isEmpty) {
      return _buildNoDataContainer();
    }

    return SizedBox(
      height: 150,
      child: AnimationLimiter(
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: randomArtists.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (context, index) => _buildArtistCard(randomArtists[index], index),
        ),
      ),
    );
  }

  /// Builds a card for an individual artist
  Widget _buildArtistCard(String artist, int index) {
    return AnimationConfiguration.staggeredList(
      position: index,
      duration: const Duration(milliseconds: 375),
      child: SlideAnimation(
        horizontalOffset: 50.0,
        child: FadeInAnimation(
          child: FutureBuilder<String?>(
            future: _artistService.fetchArtistImage(artist),
            builder: (context, snapshot) => _buildArtistCardContent(artist, snapshot.data),
          ),
        ),
      ),
    );
  }

  /// Builds the content of an artist card
  Widget _buildArtistCardContent(String artist, String? imagePath) {
    return GestureDetector(
      onTap: () => _navigateToArtistDetails(artist, imagePath),
      child: glassmorphicContainer(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 40,
                backgroundImage: imagePath != null ? FileImage(File(imagePath)) : null,
                child: imagePath == null
                    ? const Icon(Icons.person, size: 40, color: Colors.white)
                    : null,
              ),
              const SizedBox(height: 8),
              Text(artist, style: const TextStyle(color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }

  /// Navigates to the artist details screen
  void _navigateToArtistDetails(String artist, String? imagePath) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ArtistDetailsScreen(
          artistName: artist,
          artistImagePath: imagePath,
        ),
      ),
    );
  }

  /// Checks for available updates and shows appropriate notifications
  Future<void> checkForUpdates() async {
    _notificationManager.showNotification(
      AppLocalizations.of(context).translate('checking_for_updates'),
      duration: const Duration(seconds: 2),
    );

    VersionCheckResult result = await checkForNewVersion();

    if (result.isUpdateAvailable && result.latestVersion != null) {
      _notificationManager.showNotification(
        AppLocalizations.of(context).translate('update_found'),
        duration: const Duration(seconds: 3),
        onComplete: () {
          _showUpdateAvailableDialog(result.latestVersion!);
          _notificationManager.showDefaultTitle();
        },
      );
    } else {
      _notificationManager.showNotification(
        AppLocalizations.of(context).translate('no_update_found'),
        duration: const Duration(seconds: 3),
        onComplete: () => _notificationManager.showDefaultTitle(),
      );
    }
  }
}

class AutoScrollText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final Function(String) onMessageComplete;

  const AutoScrollText({
    super.key,
    required this.text,
    required this.style,
    required this.onMessageComplete,
  });

  @override
  State<AutoScrollText> createState() => _AutoScrollTextState();
}

class _AutoScrollTextState extends State<AutoScrollText> with SingleTickerProviderStateMixin {
  late ScrollController _scrollController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  String _displayedText = '';
  Timer? _messageTimer;
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _displayedText = widget.text;

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _fadeController.forward();

    // Delay the start of scrolling and message timer
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _startMessageTimer();
        _startScrollIfNeeded();
      }
    });
  }

  void _startScrollIfNeeded() {
    if (!mounted || _isAnimating) return;
    _isAnimating = true;

    const duration = Duration(milliseconds: 3000);
    final maxScroll = _scrollController.position.maxScrollExtent;

    if (!mounted) {
      _isAnimating = false;
      return;
    }

    _scrollController.animateTo(
      maxScroll,
      duration: duration,
      curve: Curves.linear,
    ).then((_) {
      if (!mounted) return null;
      return Future.delayed(const Duration(milliseconds: 500));
    }).then((_) {
      if (!mounted) return null;
      return _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOut,
      );
    }).then((_) {
      if (mounted) {
        _isAnimating = false;
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (mounted) {
            _startScrollIfNeeded();
          }
        });
      }
    });
  }

  void _startMessageTimer() {
    if (!mounted) return;

    final bool isScanningMessage = _isScanningMessage();
    if (isScanningMessage) return;

    _messageTimer?.cancel();
    _messageTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        _fadeToNextMessage();
      }
    });
  }

  void _fadeToNextMessage() {
    if (!mounted) return;
    _fadeController.reverse().then((_) {
      if (mounted) {
        widget.onMessageComplete(widget.text);
      }
    });
  }

  @override
  void didUpdateWidget(AutoScrollText oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.text != widget.text && mounted) {
      setState(() {
        _displayedText = widget.text;
      });

      if (!_isScanningMessage()) {
        _fadeController.forward();
      }

      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
      _isAnimating = false;
      _startScrollIfNeeded();
      _startMessageTimer();
    }
  }

  @override
  void dispose() {
    _messageTimer?.cancel();
    _scrollController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  bool _isScanningMessage() {
    if (!mounted) return false;
    return widget.text.contains(
      AppLocalizations.of(context).translate('scanning_songs'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        controller: _scrollController,
        physics: const NeverScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            _displayedText,
            style: widget.style,
            maxLines: 1,
          ),
        ),
      ),
    );
  }
}

class VersionCheckResult {
  final bool isUpdateAvailable;
  final Version? latestVersion;

  VersionCheckResult({required this.isUpdateAvailable, this.latestVersion});
}

class NotificationManager {
  String _currentNotification = '';
  Timer? _notificationTimer;
  final StreamController<String> _notificationController = StreamController<String>.broadcast();
  bool _isShowingProgress = false;

  Stream<String> get notificationStream => _notificationController.stream;

  void showNotification(
    String message, {
    Duration duration = const Duration(seconds: 3),
    bool isProgress = false,
    VoidCallback? onComplete,
  }) {
    if (isProgress && _isShowingProgress) {
      _currentNotification = message;
      _notificationController.add(message);
      return;
    }

    _notificationTimer?.cancel();
    _isShowingProgress = isProgress;
    _currentNotification = message;
    _notificationController.add(message);

    if (!isProgress) {
      _notificationTimer = Timer(duration, () {
        onComplete?.call();
      });
    }
  }

  void showDefaultTitle() {
    _isShowingProgress = false;
    _currentNotification = '';
    _notificationController.add('');
  }

  void dispose() {
    _notificationTimer?.cancel();
    _notificationController.close();
  }
}