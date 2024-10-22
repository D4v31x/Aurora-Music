import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'package:aurora_music_v01/screens/tracks_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart' as permissionhandler;
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';
import 'package:pub_semver/pub_semver.dart';
import '../models/playlist_model.dart';
import '../models/utils.dart';
import '../services/Audio_Player_Service.dart';
import '../localization/locale_provider.dart';
import '../localization/app_localizations.dart';
import '../services/spotify_service.dart';
import '../widgets/expandable_bottom.dart';
import 'Artist_screen.dart';
import 'PlaylistDetail_screen.dart';
import 'Playlist_screen.dart';
import 'categories.dart';
import 'now_playing.dart';
import '../widgets/glassmorphic_container.dart';
import '../widgets/outline_indicator.dart';
import '../widgets/mini_player.dart';
import '../services/local_caching_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class ThemeProvider with ChangeNotifier {
  bool _isDarkMode = false;

  bool get isDarkMode => _isDarkMode;

  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
  }
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late bool isDarkMode;
  late final Color _dominantColor = Colors.black;
  late TabController _tabController;
  late LocalCachingArtistService _artistService;
  late ValueNotifier<SongModel?> _currentSongNotifier;
  bool isWelcomeBackVisible = true;
  bool isAuroraMusicVisible = false;
  bool hasRandomized = false;
  bool _showAppBar = true;
  List<SongModel> songs = [];
  List<String> randomArtists = [];
  List<String> randomPlaylists = [];
  List<SongModel> randomSongs = [];
  Color? dominantColor;
  Color? textColor;
  AnimationController? _animationController;
  Animation<Offset>? _slideAnimation;
  final ScrollController _scrollController = ScrollController();
  final StreamController<bool> _streamController = StreamController<bool>();
  SongModel? currentSong;
  String appBarMessage = '';
  bool isAppBarMessageVisible = false;
  bool _isScanning = false;
  int _scannedSongs = 0;
  int _totalSongs = 0;
  late SpotifyService _spotifyService;
  List<Map<String, dynamic>> _recentlyPlayedTracks = [];
  List<Map<String, dynamic>> _spotifyPlaylists = [];
  final TextEditingController _searchController = TextEditingController();
  List<SongModel> _filteredSongs = [];
  List<AlbumModel> _filteredAlbums = [];
  List<ArtistModel> _filteredArtists = [];
  List<AlbumModel> albums = [];
  List<ArtistModel> artists = [];
  late Animation<double> _searchAnimation;
  final FocusNode _searchFocusNode = FocusNode();
  bool _isSearching = false;
  late AnimationController _searchAnimationController;
  String _artistDescription = '';



  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    _initializeArtistService();
    _searchController.addListener(_onSearchChanged);
    _artistService = LocalCachingArtistService();
    _currentSongNotifier = ValueNotifier<SongModel?>(null); // Initialize the ValueNotifier
    final audioPlayerService = Provider.of<AudioPlayerService>(context, listen: false);
    _currentSongNotifier.value = audioPlayerService.currentSong;
    audioPlayerService.addListener(_updateCurrentSong);
    _tabController = TabController(length: 4, vsync: this);
    _spotifyService = SpotifyService();
    _searchAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _searchAnimation = CurvedAnimation(
      parent: _searchAnimationController,
      curve: Curves.easeInOut,
    );
    _searchFocusNode.addListener(() {
      setState(() {
        _isSearching = _searchFocusNode.hasFocus;
      });
      if (_searchFocusNode.hasFocus) {
        _searchAnimationController.forward();
      } else {
        _searchAnimationController.reverse();
      }
    });

    fetchSongs().then((_) {
      if (!hasRandomized) {
        _randomizeContent();
        hasRandomized = true;
        if (mounted) {
          setState(() {});
        }
      }
    });

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

    checkForNewVersion();
    fetchSongs();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController!,
      curve: Curves.easeInOut,
    ));
  }

  Future<List<SongModel>> _processSongsInBackground(List<SongModel> songs) async {
    return await compute(_processMetadata, songs);
  }

  static List<SongModel> _processMetadata(List<SongModel> songs) {
    // Perform any heavy processing on the songs here
    // For example, you could extract additional metadata or perform audio analysis
    return songs;
  }

  void _updateCurrentSong() {
    final audioPlayerService = Provider.of<AudioPlayerService>(context, listen: false);
    _currentSongNotifier.value = audioPlayerService.currentSong;
  }

  // New method to randomize content
  void _randomizeContent() {
    if (songs.isNotEmpty) {
      randomSongs = (songs.toList()..shuffle()).take(3).toList();
      final uniqueArtists = songs
          .map((song) => splitArtists(song.artist ?? ''))
          .expand((artist) => artist)
          .toSet()
          .toList();
      randomArtists = (uniqueArtists..shuffle()).take(3).toList();
    }
  }

  void _scrollListener() {
    if (_scrollController.offset > 180 && _showAppBar) {
      if (mounted) {
        setState(() {
          _showAppBar = false;
        });
      }
    } else if (_scrollController.offset <= 180 && !_showAppBar) {
      if (mounted) {
        setState(() {
          _showAppBar = true;
        });
      }
    }
  }

  void showAppBarMessage(String message, {Duration duration = const Duration(seconds: 3)}) {
    if (mounted) {
      setState(() {
        appBarMessage = message;
        _isScanning = true;
      });
    }

    Future.delayed(duration, () {
      if (mounted) {
        setState(() {
          appBarMessage = '';
          _isScanning = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _animationController?.dispose();
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _streamController.close();
    _currentSongNotifier.dispose();
    _tabController.dispose();
    _searchAnimationController.dispose();
    _searchFocusNode.dispose();
    Provider.of<AudioPlayerService>(context, listen: false).removeListener(_updateCurrentSong);
    super.dispose();
  }
  Future<void> _loadLibraryData() async {
    final onAudioQuery = OnAudioQuery();
    albums = await onAudioQuery.queryAlbums();
    artists = await onAudioQuery.queryArtists();
    setState(() {});
  }


  Future<LocalCachingArtistService> _initializeArtistService() async {
    return LocalCachingArtistService();
  }

  Future<bool> checkForNewVersion() async {
    try {
      final response = await http.get(Uri.parse(
          'https://api.github.com/repos/D4v31x/Aurora-Music_ALPHA_RELEASES/releases/latest'));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final versionString = data['tag_name'];

        final regex = RegExp(r'^v?(\d+\.\d+\.\d+(-[a-zA-Z0-9.\-]+)?)$');
        final match = regex.firstMatch(versionString);
        if (match != null && match.groupCount > 0) {
          final latestVersionString = match.group(1)!;
          final latestVersion = Version.parse(latestVersionString);

          final currentVersion = Version.parse('0.0.8');

          return latestVersion > currentVersion;
        }
      }
    } catch (e) {
      print('Error checking for updates: $e');
    }
    return false;
  }

  void _showUpToDateSnackBar() {
    if (mounted) {
      setState(() {
        appBarMessage = AppLocalizations.of(context).translate('app_up_to_date');
        isAppBarMessageVisible = true;
      });
    }
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          isAppBarMessageVisible = false;
        });
      }
    });
  }

  void _showVersionCheckErrorSnackBar() {
    if (mounted) {
      setState(() {
        appBarMessage = AppLocalizations.of(context).translate('version_check_error');
        isAppBarMessageVisible = true;
      });
    }
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
      builder: (context) {
        return AlertDialog(
          title: Text(AppLocalizations.of(context).translate('update_available')),
          content: Text(
            AppLocalizations.of(context).translate('update_message').replaceFirst('%s', latestVersion.toString()),
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
                await launch('https://github.com/D4v31x/Aurora-Music_ALPHA_RELEASES/releases/latest');
              },
              child: Text(AppLocalizations.of(context).translate('update_now')),
            ),
          ],
        );
      },
    );
  }

  Future<void> _refreshLibrary() async {
    final audioPlayerService = Provider.of<AudioPlayerService>(context, listen: false);

    if (mounted) {
      setState(() {
        _isScanning = true;
        _scannedSongs = 0;
        _totalSongs = 0;
        appBarMessage = AppLocalizations.of(context).translate('preparing_to_scan');
      });
    }

    await Future.delayed(const Duration(seconds: 1));

    try {
      final onAudioQuery = OnAudioQuery();
      final allSongs = await onAudioQuery.querySongs();
      _totalSongs = allSongs.length;

      if (mounted) {
        setState(() {
          appBarMessage = '${AppLocalizations.of(context).translate('scanning_songs')} (0/$_totalSongs)';
        });
      }

      for (var song in allSongs) {
        await audioPlayerService.addSongToLibrary(song);
        await Future.delayed(const Duration(milliseconds: 10));

        if (mounted) {
          setState(() {
            _scannedSongs++;
            appBarMessage = '${AppLocalizations.of(context).translate('scanning_songs')} ($_scannedSongs/$_totalSongs)';
          });
        }
      }

      if (mounted) {
        setState(() {
          songs = allSongs;
          _randomizeContent();
          _isScanning = false;
          appBarMessage = '${AppLocalizations.of(context).translate('library_updated')} ($_totalSongs ${AppLocalizations.of(context).translate('songs_loaded')})';
        });
      }

      await audioPlayerService.saveLibrary();

      // Show the message for 5 seconds after completion
      await Future.delayed(const Duration(seconds: 5));

      if (mounted) {
        setState(() {
          appBarMessage = ''; // Clear the message
        });
      }

    } catch (e) {
      if (mounted) {
        setState(() {
          _isScanning = false;
          appBarMessage = AppLocalizations.of(context).translate('update_failed');
        });
      }

      // Show the error message for 5 seconds
      await Future.delayed(const Duration(seconds: 5));

      if (mounted) {
        setState(() {
          appBarMessage = ''; // Clear the message
        });
      }
    }
  }

  Future<void> fetchSongs() async {
    try {
      if (Platform.isAndroid) {
        // Request both permissions simultaneously
        Map<permissionhandler.Permission, permissionhandler.PermissionStatus> statuses = await [
          permissionhandler.Permission.audio,
          permissionhandler.Permission.storage,
        ].request();

        bool hasAudioPermission = statuses[permissionhandler.Permission.audio]?.isGranted ?? false;
        bool hasStoragePermission = statuses[permissionhandler.Permission.storage]?.isGranted ?? false;

        if (hasAudioPermission || hasStoragePermission) {
          final onAudioQuery = OnAudioQuery();
          final songsResult = await onAudioQuery.querySongs();
          final processedSongs = await _processSongsInBackground(songsResult);

          if (mounted) {
            setState(() {
              songs = processedSongs;
            });
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Permissions denied'),
            ),
          );
        }
      }
    } catch (e) {
    }
  }

  void launchURL(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      try {
        await launchUrl(uri);
      } catch (e) {
      }
    } else {
      throw 'Could not launch $url';
    }
  }

  Future<bool> _onWillPop() async {
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
    isDarkMode = MediaQuery.of(context).platformBrightness == Brightness.dark;
  }

  void _onSongTap(SongModel song) {
    final audioPlayerService = Provider.of<AudioPlayerService>(context, listen: false);
    audioPlayerService.setPlaylist(songs, songs.indexOf(song));
    audioPlayerService.play();
    if (mounted) {
      setState(() {}); // Trigger a rebuild to update the background
    }
  }

  @override
  Widget build(BuildContext context) {
    final audioPlayerService = Provider.of<AudioPlayerService>(context);
    final currentSong = audioPlayerService.currentSong;

    return WillPopScope(
        onWillPop: _onWillPop,
        child: Stack(
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(opacity: animation, child: child);
              },
              child: buildBackground(audioPlayerService.currentSong),
            ),
            Scaffold(
              backgroundColor: Colors.transparent,
              appBar: buildAppBar(),
              body: Column(
                children: [
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        buildHomeTab(),
                        buildLibraryTab(),
                        buildSearchTab(),
                        buildSettingsTab(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (currentSong != null)
              ExpandableBottomSheet(
                minHeight: 60,
                minChild: MiniPlayer(currentSong: currentSong),
                maxChild: const NowPlayingScreen(),
              ),
          ],
        ));
  }

  Widget buildBackground(SongModel? currentSong) {
    return FutureBuilder<Uint8List?>(
      future: currentSong != null
          ? OnAudioQuery().queryArtwork(currentSong.id, ArtworkType.AUDIO)
          : null,
      builder: (context, snapshot) {
        ImageProvider backgroundImage;
        if (snapshot.connectionState == ConnectionState.done && snapshot.data != null) {
          backgroundImage = MemoryImage(snapshot.data!);
        } else {
          backgroundImage = AssetImage(isDarkMode
              ? 'assets/images/background/dark_back.jpg'
              : 'assets/images/background/light_back.jpg');
        }

        return AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          decoration: BoxDecoration(
            image: DecorationImage(
              image: backgroundImage,
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
      },
    );
  }

  AppBar buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0.0,
      toolbarHeight: 180,
      automaticallyImplyLeading: false,
      title: Column(
        children: [
          // Animated Slide for aurora_music text
          AnimatedSlide(
            offset: _isScanning ? const Offset(0, -0.2) : const Offset(0, 0),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
            child: Center(
              child: Text(
                AppLocalizations.of(context).translate('aurora_music'),
                style: const TextStyle(
                  fontFamily: 'ProductSans',
                  fontStyle: FontStyle.normal,
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Direct update of message text without fading in/out
          Text(
            appBarMessage,
            style: const TextStyle(
              fontFamily: 'ProductSans',
              fontStyle: FontStyle.normal,
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          // Progress bar displayed without fading effect
          if (_isScanning)
            LinearProgressIndicator(
              value: _totalSongs > 0 ? _scannedSongs / _totalSongs : 0,
              backgroundColor: Colors.white.withOpacity(0.3),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
        ],
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(48.0),
        child: Align(
          alignment: Alignment.center,
          child: TabBar(
            controller: _tabController,
            dividerColor: Colors.transparent,
            indicator: const OutlineIndicator(
              color: Colors.white,
              strokeWidth: 2,
              text: '',
              radius: Radius.circular(24),
            ),
            tabs: [
              Tab(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    AppLocalizations.of(context).translate('home'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontFamily: 'ProductSans',
                    ),
                  ),
                ),
              ),
              Tab(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    AppLocalizations.of(context).translate('library'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontFamily: 'ProductSans',
                    ),
                  ),
                ),
              ),
              Tab(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    AppLocalizations.of(context).translate('search'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontFamily: 'ProductSans',
                    ),
                  ),
                ),
              ),
              Tab(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    AppLocalizations.of(context).translate('settings'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontFamily: 'ProductSans',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildSettingsTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: 20.0,
        right: 20.0,
        top: 30.0,
        bottom: currentSong != null ? 90.0 : 30.0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context).translate('settings'),
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20.0),
          buildSettingsCategory(
            title: AppLocalizations.of(context).translate('general'),
            children: [
              buildLanguageSelector(),
            ],
          ),
        ],
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

  Widget buildManualUpdateCheck() {
    return glassmorphicContainer(
      child: ListTile(
        title: Text(
          AppLocalizations.of(context).translate('check_for_updates'),
          style: const TextStyle(color: Colors.white),
        ),
        trailing: const Icon(Icons.system_update, color: Colors.white),
        onTap: () {
          checkForNewVersion();
          showAppBarMessage(AppLocalizations.of(context).translate('checking_for_updates'));
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
              child: FadeInAnimation(
                child: widget,
              ),
            ),
            children: [
              buildCategorySection(
                  title: AppLocalizations.of(context).translate('tracks'),
                  items: audioPlayerService.getMostPlayedTracks(),
                  onDetailsTap: () => Navigator.push(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (context, animation, secondaryAnimation) => const TracksScreen(),
                      transitionsBuilder: (context, animation, secondaryAnimation, child) {
                        return FadeTransition(opacity: animation, child: child);
                      },
                    ),
                  )
              ),
              const SizedBox(height: 30.0),
              buildCategorySection(
                title: AppLocalizations.of(context).translate('albums'),
                items: audioPlayerService.getMostPlayedAlbums(),
                onDetailsTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AlbumsScreen()),
                ),
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
              ),
              const SizedBox(height: 30.0),
              buildCategorySection(
                title: AppLocalizations.of(context).translate('folders'),
                items: audioPlayerService.getThreeFolders(),
                onDetailsTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const FoldersScreen()),
                ),
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
                child: GestureDetector(
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
    } else if (item is Playlist) {  // Changed from PlaylistModel to Playlist
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
                  _onSearchChanged();  // This will clear the search results
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
                child: FadeInAnimation(
                  child: widget,
                ),
              ),
              children: [
                  const SizedBox(height: 20.0),
                  Text(
                    AppLocalizations.of(context).translate('quick_access'),
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 10.0),
                  buildQuickAccessSection(),
                  const SizedBox(height: 30.0),
                  Text(
                    AppLocalizations.of(context).translate('suggested_tracks'),
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 10.0),
                  buildSuggestedTracksSection(),
                  const SizedBox(height: 30.0),
                  Text(
                    AppLocalizations.of(context).translate('suggested_artists'),
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 10.0),
                  buildSuggestedArtistsSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget buildSearchTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            focusNode: _searchFocusNode,
            decoration: InputDecoration(
              hintText: AppLocalizations.of(context).translate('search_hint'),
              prefixIcon: const Icon(Icons.search, color: Colors.white),
              filled: true,
              fillColor: Colors.white.withOpacity(0.2),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide.none,
              ),
              hintStyle: const TextStyle(color: Colors.white70),
            ),
            style: const TextStyle(color: Colors.white),
            onChanged: (_) => _onSearchChanged(),
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
      return const Center(
          child: Text('Start typing to search', style: TextStyle(color: Colors.white70)));
    }

    // Fetch the closest artist that matches the search query
    final closestArtist = _findClosestArtist(_searchController.text);

    return ListView(
      children: [
        // Display the artist card if an artist is found
        if (closestArtist != null)
          FutureBuilder<String>(
            future: _fetchArtistInfo(closestArtist.artist),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done) {
                _artistDescription = snapshot.data ?? 'No information available.';
                return buildArtistCard(closestArtist);
              } else {
                return const Center(child: CircularProgressIndicator());
              }
            },
          ),

        // Display song results
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text('Songs', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        ),
        ..._filteredSongs.map((song) => buildSongListTile(song)),
      ],
    );
  }

  ArtistModel? _findClosestArtist(String query) {
    final lowercaseQuery = query.toLowerCase();

    print('Looking for closest match to: $lowercaseQuery in artists: ${_filteredArtists.map((a) => a.artist).toList()}');

    try {
      final artist = _filteredArtists.firstWhere(
            (artist) => artist.artist.toLowerCase().contains(lowercaseQuery),
      );
      print('Closest artist found: ${artist.artist}');
      return artist;
    } catch (e) {
      print('No artist found for query: $query');
      return null;
    }
  }

  Future<String> _fetchArtistInfo(String artistName) async {
    final apiKey = dotenv.env['LASTFM_API_KEY'];
    final url = Uri.parse('http://ws.audioscrobbler.com/2.0/?method=artist.getinfo&artist=$artistName&api_key=$apiKey&format=json');

    print('Fetching artist info for: $artistName');

    try {
      final response = await http.get(url);

      print('Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Artist data: $data');
        if (data['artist'] != null && data['artist']['bio'] != null) {
          return data['artist']['bio']['summary'] ?? 'No information available.';
        }
      }
    } catch (e) {
      print('Error fetching artist info: $e');
    }

    return 'No information available.';
  }

  Widget buildArtistCard(ArtistModel artist) {
    print('Building artist card for: ${artist.artist}');  // Debugging: Print artist name

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white.withOpacity(0.1),
      ),
      child: Row(
        children: [
          FutureBuilder<String?>(
            future: _artistService.fetchArtistImage(artist.artist),
            builder: (context, snapshot) {
              final imageUrl = snapshot.data;
              return ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
                child: imageUrl != null
                    ? Image.file(
                  File(imageUrl),
                  width: 100,
                  height: 100,
                  fit: BoxFit.cover,
                )
                    : Image.asset(
                  'assets/images/default_artist.jpg',
                  width: 100,
                  height: 100,
                  fit: BoxFit.cover,
                ),
              );
            },
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    artist.artist,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _artistDescription,
                    style: TextStyle(color: Colors.white.withOpacity(0.7)),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget buildSongListTile(SongModel song) {
    return ListTile(
      leading: QueryArtworkWidget(
        id: song.id,
        type: ArtworkType.AUDIO,
        nullArtworkWidget: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.music_note, color: Colors.white),
        ),
      ),
      title: Text(song.title, style: const TextStyle(color: Colors.white)),
      subtitle: Text(song.artist ?? '', style: TextStyle(color: Colors.white.withOpacity(0.7))),
      trailing: const Icon(Icons.favorite_border, color: Colors.white),
      onTap: () => _onSongTap(song),
    );
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();

    print('Search query: $query');

    setState(() {
      _filteredSongs = songs.where((song) =>
      song.title.toLowerCase().contains(query) ||
          (song.artist ?? '').toLowerCase().contains(query)
      ).toList();

      // Ensure the artists list is populated before filtering
      print('Original artists list: ${artists.map((a) => a.artist).toList()}');

      _filteredArtists = artists.where((artist) =>
          artist.artist.toLowerCase().contains(query)
      ).toList();

      print('Filtered artists: ${_filteredArtists.map((a) => a.artist).toList()}');
    });
  }






  Widget buildQuickAccessSection() {
    const favoritesPlaylist = 'Oblíbené';
    final recentlyListenedPlaylists = ['Playlist 1']; // This should be dynamically populated

    if (favoritesPlaylist.isNotEmpty || recentlyListenedPlaylists.isNotEmpty) {
      return AnimationLimiter(
        child: Column(
          children: AnimationConfiguration.toStaggeredList(
            duration: const Duration(milliseconds: 375),
            childAnimationBuilder: (widget) => SlideAnimation(
              verticalOffset: 50.0,
              child: FadeInAnimation(
                child: widget,
              ),
            ),
            children: [
              if (favoritesPlaylist.isNotEmpty)
                glassmorphicContainer(
                  child: ListTile(
                    leading: const Icon(Icons.favorite, color: Colors.pink),
                    title: const Text(favoritesPlaylist, style: TextStyle(color: Colors.white)),
                    onTap: () {
                      // Navigate to the favorites playlist
                    },
                  ),
                ),
              if (recentlyListenedPlaylists.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: glassmorphicContainer(
                    child: ListTile(
                      leading: const Icon(Icons.history, color: Colors.white),
                      title: Text(recentlyListenedPlaylists[0], style: const TextStyle(color: Colors.white)),
                      onTap: () {
                        // Navigate to the recently listened playlist
                      },
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    } else {
      return glassmorphicContainer(
        child: const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('Žádná data k zobrazení', style: TextStyle(color: Colors.white)),
        ),
      );
    }
  }

  Widget buildSuggestedTracksSection() {
    if (randomSongs.isEmpty) {
      return glassmorphicContainer(
        child: const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('No data to display', style: TextStyle(color: Colors.white)),
        ),
      );
    }

    return AnimationLimiter(
      child: Column(
        children: AnimationConfiguration.toStaggeredList(
          duration: const Duration(milliseconds: 375),
          childAnimationBuilder: (widget) => SlideAnimation(
            verticalOffset: 50.0,
            child: FadeInAnimation(
              child: widget,
            ),
          ),
          children: randomSongs.map((song) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: glassmorphicContainer(
                child: ListTile(
                  leading: QueryArtworkWidget(
                    id: song.id,
                    type: ArtworkType.AUDIO,
                    nullArtworkWidget: const Icon(Icons.music_note, color: Colors.white),
                  ),
                  title: Text(song.title, style: const TextStyle(color: Colors.white)),
                  subtitle: Text(splitArtists(song.artist ?? '').join(', '), style: const TextStyle(color: Colors.grey)),
                  trailing: const Icon(Icons.favorite_border, color: Colors.white),
                  onTap: () {
                    _onSongTap(song);
                  },
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget buildSuggestedArtistsSection() {
    if (randomArtists.isEmpty) {
      return glassmorphicContainer(
        child: const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('No data to display', style: TextStyle(color: Colors.white)),
        ),
      );
    }

    return SizedBox(
      height: 150,
      child: AnimationLimiter(
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: randomArtists.length,
          separatorBuilder: (context, index) => const SizedBox(width: 10),
          itemBuilder: (context, index) {
            final artist = randomArtists[index];

            return AnimationConfiguration.staggeredList(
              position: index,
              duration: const Duration(milliseconds: 375),
              child: SlideAnimation(
                horizontalOffset: 50.0,
                child: FadeInAnimation(
                  child: FutureBuilder<String?>(
                    future: _artistService.fetchArtistImage(artist),
                    builder: (context, snapshot) {
                      final imagePath = snapshot.data;
                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ArtistDetailsScreen(
                                artistName: artist,
                                artistImagePath: imagePath,
                              ),
                            ),
                          );
                        },
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
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class ScrollingText extends StatefulWidget {
  final String text;
  final TextStyle style;

  const ScrollingText({super.key, required this.text, required this.style});

  @override
  _ScrollingTextState createState() => _ScrollingTextState();
}

class _ScrollingTextState extends State<ScrollingText> with SingleTickerProviderStateMixin {
  late ScrollController _scrollController;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.position.maxScrollExtent > 0) {
        _animateScroll();
      }
    });
  }

  void _animateScroll() async {
    while (_scrollController.hasClients) {
      await Future.delayed(const Duration(seconds: 1));
      if (_scrollController.hasClients) {
        await _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(seconds: _scrollController.position.maxScrollExtent ~/ 30),
          curve: Curves.linear,
        );
      }
      await Future.delayed(const Duration(seconds: 4));
      if (_scrollController.hasClients) {
        await _scrollController.animateTo(
          0.0,
          duration: Duration(seconds: _scrollController.position.maxScrollExtent ~/ 30),
          curve: Curves.linear,
        );
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      controller: _scrollController,
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Text(
            widget.text,
            style: widget.style,
          );
        },
      ),
    );
  }
}
