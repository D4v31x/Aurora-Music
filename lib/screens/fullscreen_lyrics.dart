import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/timed_lyrics.dart';
import '../services/audio_player_service.dart';
import '../services/lyrics_service.dart';
import '../services/artwork_cache_service.dart';
import '../localization/app_localizations.dart';

class FullscreenLyricsScreen extends StatefulWidget {
  const FullscreenLyricsScreen({super.key});

  @override
  State<FullscreenLyricsScreen> createState() => _FullscreenLyricsScreenState();
}

class _FullscreenLyricsScreenState extends State<FullscreenLyricsScreen>
    with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  final ArtworkCacheService _artworkService = ArtworkCacheService();

  int _currentLyricIndex = 0;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<SongModel?>? _songChangeSubscription;

  late AnimationController _fadeController;

  final GlobalKey _scrollKey = GlobalKey();
  Map<int, GlobalKey> _lyricKeys = {};

  List<TimedLyric>? _currentLyrics;
  int? _lastSongId;
  bool _isLoadingLyrics = false;

  ImageProvider? _artworkProvider;
  bool _hasArtwork = false;

  // Settings
  double _fontSize = 1.0; // Multiplier: 0.8, 1.0, 1.2, 1.4
  int _syncOffset = 0; // In milliseconds

  static const String _fontSizeKey = 'lyrics_font_size';
  static const String _syncOffsetKey = 'lyrics_sync_offset';

  @override
  void initState() {
    super.initState();
    _loadSettings();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    )..forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final audioService =
          Provider.of<AudioPlayerService>(context, listen: false);
      _loadLyricsForCurrentSong(audioService);
      _loadArtwork(audioService);

      _positionSubscription =
          audioService.audioPlayer.positionStream.listen((position) {
        if (mounted) _updateCurrentLyric(position);
      });

      _songChangeSubscription = audioService.currentSongStream.listen((song) {
        if (mounted && song != null && song.id != _lastSongId) {
          _loadLyricsForCurrentSong(audioService);
          _loadArtwork(audioService);
        }
      });
    });
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _fontSize = prefs.getDouble(_fontSizeKey) ?? 1.0;
      _syncOffset = prefs.getInt(_syncOffsetKey) ?? 0;
    });
  }

  Future<void> _saveFontSize(double size) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_fontSizeKey, size);
    setState(() => _fontSize = size);
  }

  Future<void> _saveSyncOffset(int offset) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_syncOffsetKey, offset);
    setState(() => _syncOffset = offset);
  }

  Future<void> _loadArtwork(AudioPlayerService audioService) async {
    final song = audioService.currentSong;
    if (song == null) return;

    try {
      final provider = await _artworkService.getCachedImageProvider(song.id);
      if (!mounted) return;

      setState(() {
        _artworkProvider = provider;
        _hasArtwork = provider is! AssetImage;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _hasArtwork = false);
      }
    }
  }

  Future<void> _loadLyricsForCurrentSong(
      AudioPlayerService audioService) async {
    final song = audioService.currentSong;
    if (song == null) return;

    if (_lastSongId == song.id && _currentLyrics != null) return;

    setState(() {
      _isLoadingLyrics = true;
      _lastSongId = song.id;
    });

    final timedLyricsService = TimedLyricsService();
    final artistRaw = song.artist ?? '';
    final titleRaw = song.title;
    final artist = artistRaw.trim().isEmpty ? 'Unknown' : artistRaw.trim();
    final title = titleRaw.trim().isEmpty ? 'Unknown' : titleRaw.trim();

    var lyrics = await timedLyricsService.loadLyricsFromFile(artist, title);
    if (!mounted || audioService.currentSong?.id != song.id) return;

    lyrics ??= await timedLyricsService.fetchTimedLyrics(artist, title);
    if (!mounted || audioService.currentSong?.id != song.id) return;

    setState(() {
      _currentLyrics = lyrics;
      _currentLyricIndex = 0;
      _isLoadingLyrics = false;
      _lyricKeys = {};
      if (_currentLyrics != null) {
        for (int i = 0; i < _currentLyrics!.length; i++) {
          _lyricKeys[i] = GlobalKey();
        }
      }
    });

    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  void _updateCurrentLyric(Duration position) {
    if (_currentLyrics == null || _currentLyrics!.isEmpty) return;

    // Apply sync offset
    final adjustedPosition = position + Duration(milliseconds: _syncOffset);
    int newIndex = _currentLyricIndex;

    for (int i = 0; i < _currentLyrics!.length; i++) {
      if (adjustedPosition < _currentLyrics![i].time) {
        newIndex = i > 0 ? i - 1 : 0;
        break;
      }
      if (i == _currentLyrics!.length - 1) {
        newIndex = i;
      }
    }

    if (newIndex != _currentLyricIndex) {
      setState(() => _currentLyricIndex = newIndex);
      _scrollToCurrentLyric();
    }
  }

  void _scrollToCurrentLyric() {
    if (!_scrollController.hasClients) return;

    final RenderBox? renderBox = _lyricKeys[_currentLyricIndex]
        ?.currentContext
        ?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final RenderBox? scrollBox =
        _scrollKey.currentContext?.findRenderObject() as RenderBox?;
    if (scrollBox == null) return;

    final position = renderBox.localToGlobal(Offset.zero, ancestor: scrollBox);
    final itemHeight = renderBox.size.height;
    final scrollBoxHeight = scrollBox.size.height;

    final targetOffset = _scrollController.offset +
        position.dy -
        (scrollBoxHeight / 2) +
        (itemHeight / 2);

    _scrollController.animateTo(
      targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _songChangeSubscription?.cancel();
    _scrollController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final audioService = Provider.of<AudioPlayerService>(context);

    if (audioService.currentSong != null &&
        audioService.currentSong!.id != _lastSongId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _loadLyricsForCurrentSong(audioService);
          _loadArtwork(audioService);
        }
      });
    }

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background
          _buildBackground(),

          // Content
          SafeArea(
            child: Column(
              children: [
                _buildHeader(audioService),
                Expanded(
                  child: FadeTransition(
                    opacity: _fadeController,
                    child: _isLoadingLyrics
                        ? _buildLoadingView()
                        : (_currentLyrics == null || _currentLyrics!.isEmpty)
                            ? _buildNoLyricsView()
                            : _buildLyricsView(),
                  ),
                ),
                _buildControls(audioService),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Artwork blur or gradient
        if (_hasArtwork && _artworkProvider != null)
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
            child: Image(
              image: _artworkProvider!,
              fit: BoxFit.cover,
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.grey.shade900,
                  Colors.black,
                ],
              ),
            ),
          ),
        // Dark overlay
        Container(color: Colors.black.withValues(alpha: 0.6)),
      ],
    );
  }

  Widget _buildHeader(AudioPlayerService audioService) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down,
                color: Colors.white, size: 32),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  audioService.currentSong?.title ?? '',
                  style: const TextStyle(
                    fontFamily: 'ProductSans',
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  audioService.currentSong?.artist ?? '',
                  style: const TextStyle(
                    fontFamily: 'ProductSans',
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white, size: 24),
            color: Colors.grey.shade900,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (value) => _handleMenuAction(value, audioService),
            itemBuilder: (context) => [
              _buildMenuItem(
                  Icons.refresh,
                  AppLocalizations.of(context).translate('refresh_lyrics'),
                  'refresh'),
              _buildMenuItem(
                  Icons.search,
                  AppLocalizations.of(context).translate('search_lyrics'),
                  'search'),
              _buildMenuItem(
                  Icons.timer_outlined,
                  AppLocalizations.of(context).translate('adjust_sync'),
                  'sync'),
              _buildMenuItem(
                  Icons.text_fields,
                  AppLocalizations.of(context).translate('font_size'),
                  'font_size'),
            ],
          ),
        ],
      ),
    );
  }

  PopupMenuItem<String> _buildMenuItem(
      IconData icon, String text, String value) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 20),
          const SizedBox(width: 12),
          Text(
            text,
            style: const TextStyle(
              fontFamily: 'ProductSans',
              color: Colors.white,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  void _handleMenuAction(String action, AudioPlayerService audioService) {
    switch (action) {
      case 'refresh':
        setState(() {
          _lastSongId = null;
        });
        _loadLyricsForCurrentSong(audioService);
        break;
      case 'search':
        _showSearchLyricsDialog(audioService);
        break;
      case 'sync':
        _showSyncAdjustDialog();
        break;
      case 'font_size':
        _showFontSizeDialog();
        break;
    }
  }

  void _showSearchLyricsDialog(AudioPlayerService audioService) {
    final song = audioService.currentSong;
    final artistController = TextEditingController(text: song?.artist ?? '');
    final titleController = TextEditingController(text: song?.title ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          AppLocalizations.of(context).translate('search_lyrics'),
          style: const TextStyle(
            fontFamily: 'ProductSans',
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: artistController,
              style: const TextStyle(
                  color: Colors.white, fontFamily: 'ProductSans'),
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).translate('artists'),
                labelStyle: const TextStyle(
                    color: Colors.white70, fontFamily: 'ProductSans'),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white24),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: titleController,
              style: const TextStyle(
                  color: Colors.white, fontFamily: 'ProductSans'),
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).translate('title'),
                labelStyle: const TextStyle(
                    color: Colors.white70, fontFamily: 'ProductSans'),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white24),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              AppLocalizations.of(context).translate('cancel'),
              style: const TextStyle(
                  color: Colors.white70, fontFamily: 'ProductSans'),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final artist = artistController.text.trim();
              final title = titleController.text.trim();
              if (artist.isNotEmpty && title.isNotEmpty) {
                _performLyricsSearch(artist, title);
              }
            },
            child: Text(
              AppLocalizations.of(context).translate('search'),
              style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'ProductSans',
                  fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _performLyricsSearch(String artist, String title) async {
    setState(() => _isLoadingLyrics = true);

    // Fetch search results from the API
    try {
      final searchUrl =
          Uri.parse('https://lrclib.net/api/search').replace(queryParameters: {
        'artist_name': artist,
        'track_name': title,
      });

      final response = await http.get(
        searchUrl,
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'AuroraMusic v0.0.85'
        },
      );

      if (response.statusCode == 200) {
        final List results = json.decode(utf8.decode(response.bodyBytes));
        final syncedResults =
            results.where((r) => r['syncedLyrics'] != null).toList();

        if (!mounted) return;

        if (syncedResults.isEmpty) {
          setState(() => _isLoadingLyrics = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  AppLocalizations.of(context).translate('no_lyrics_found')),
              backgroundColor: Colors.grey.shade800,
            ),
          );
          return;
        }

        // Show results dialog
        setState(() => _isLoadingLyrics = false);
        _showLyricsResultsDialog(syncedResults.cast<Map<String, dynamic>>());
      } else {
        setState(() => _isLoadingLyrics = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text(AppLocalizations.of(context).translate('search_failed')),
              backgroundColor: Colors.grey.shade800,
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isLoadingLyrics = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(AppLocalizations.of(context).translate('search_failed')),
            backgroundColor: Colors.grey.shade800,
          ),
        );
      }
    }
  }

  void _showLyricsResultsDialog(List<Map<String, dynamic>> results) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          '${AppLocalizations.of(context).translate('results')} (${results.length})',
          style: const TextStyle(
            fontFamily: 'ProductSans',
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: results.length,
            itemBuilder: (context, index) {
              final result = results[index];
              final trackName = result['trackName'] ?? 'Unknown';
              final artistName = result['artistName'] ?? 'Unknown';
              final albumName = result['albumName'] ?? '';
              final duration =
                  _parseLyricsDuration(result['syncedLyrics'] as String?);

              return Card(
                color: Colors.white.withOpacity(0.1),
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  onTap: () => _selectLyricsResult(result),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  title: Text(
                    trackName,
                    style: const TextStyle(
                      fontFamily: 'ProductSans',
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        artistName,
                        style: const TextStyle(
                          fontFamily: 'ProductSans',
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (albumName.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          albumName,
                          style: TextStyle(
                            fontFamily: 'ProductSans',
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                  trailing: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      duration,
                      style: const TextStyle(
                        fontFamily: 'ProductSans',
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              AppLocalizations.of(context).translate('cancel'),
              style: const TextStyle(
                  color: Colors.white70, fontFamily: 'ProductSans'),
            ),
          ),
        ],
      ),
    );
  }

  String _parseLyricsDuration(String? syncedLyrics) {
    if (syncedLyrics == null || syncedLyrics.isEmpty) return '--:--';

    final lines = syncedLyrics.split('\n');
    Duration lastTime = Duration.zero;

    for (final line in lines.reversed) {
      final match = RegExp(r'\[(\d{2}):(\d{2})\.(\d{2,3})\]').firstMatch(line);
      if (match != null) {
        final minutes = int.parse(match.group(1)!);
        final seconds = int.parse(match.group(2)!);
        lastTime = Duration(minutes: minutes, seconds: seconds);
        break;
      }
    }

    final mins = lastTime.inMinutes;
    final secs = lastTime.inSeconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  void _selectLyricsResult(Map<String, dynamic> result) {
    Navigator.pop(context);

    final lrcContent = result['syncedLyrics'] as String;
    final timedLyricsService = TimedLyricsService();
    final lyrics = timedLyricsService.parseLrcContent(lrcContent);

    setState(() {
      _currentLyrics = lyrics;
      _currentLyricIndex = 0;
      _lyricKeys = {};
      if (_currentLyrics != null) {
        for (int i = 0; i < _currentLyrics!.length; i++) {
          _lyricKeys[i] = GlobalKey();
        }
      }
    });

    // Save to cache for future use
    final audioService =
        Provider.of<AudioPlayerService>(context, listen: false);
    final song = audioService.currentSong;
    if (song != null) {
      timedLyricsService.saveLyricsToCache(
        song.artist ?? 'Unknown',
        song.title,
        lrcContent,
      );
    }
  }

  void _showSyncAdjustDialog() {
    int tempOffset = _syncOffset;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.grey.shade900,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            AppLocalizations.of(context).translate('adjust_sync'),
            style: const TextStyle(
              fontFamily: 'ProductSans',
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${tempOffset >= 0 ? '+' : ''}${tempOffset}ms',
                style: const TextStyle(
                  fontFamily: 'ProductSans',
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                tempOffset > 0
                    ? AppLocalizations.of(context).translate('lyrics_ahead')
                    : tempOffset < 0
                        ? AppLocalizations.of(context)
                            .translate('lyrics_behind')
                        : AppLocalizations.of(context)
                            .translate('lyrics_synced'),
                style: const TextStyle(
                  fontFamily: 'ProductSans',
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildSyncButton(
                      '-500', () => setDialogState(() => tempOffset -= 500)),
                  _buildSyncButton(
                      '-100', () => setDialogState(() => tempOffset -= 100)),
                  _buildSyncButton(
                      '+100', () => setDialogState(() => tempOffset += 100)),
                  _buildSyncButton(
                      '+500', () => setDialogState(() => tempOffset += 500)),
                ],
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => setDialogState(() => tempOffset = 0),
                child: Text(
                  AppLocalizations.of(context).translate('reset'),
                  style: const TextStyle(
                      color: Colors.white70, fontFamily: 'ProductSans'),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                AppLocalizations.of(context).translate('cancel'),
                style: const TextStyle(
                    color: Colors.white70, fontFamily: 'ProductSans'),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _saveSyncOffset(tempOffset);
              },
              child: Text(
                AppLocalizations.of(context).translate('save'),
                style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'ProductSans',
                    fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncButton(String label, VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontFamily: 'ProductSans',
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  void _showFontSizeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          AppLocalizations.of(context).translate('font_size'),
          style: const TextStyle(
            fontFamily: 'ProductSans',
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildFontSizeOption(
                AppLocalizations.of(context).translate('small'), 0.8),
            _buildFontSizeOption(
                AppLocalizations.of(context).translate('medium'), 1.0),
            _buildFontSizeOption(
                AppLocalizations.of(context).translate('large'), 1.2),
            _buildFontSizeOption(
                AppLocalizations.of(context).translate('extra_large'), 1.4),
          ],
        ),
      ),
    );
  }

  Widget _buildFontSizeOption(String label, double size) {
    final isSelected = (_fontSize - size).abs() < 0.01;
    return ListTile(
      onTap: () {
        Navigator.pop(context);
        _saveFontSize(size);
      },
      leading: Icon(
        isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
        color: isSelected ? Colors.white : Colors.white54,
      ),
      title: Text(
        label,
        style: TextStyle(
          fontFamily: 'ProductSans',
          color: isSelected ? Colors.white : Colors.white70,
          fontSize: 16,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildLyricsView() {
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          Colors.white,
          Colors.white,
          Colors.transparent
        ],
        stops: [0.0, 0.08, 0.92, 1.0],
      ).createShader(bounds),
      blendMode: BlendMode.dstIn,
      child: ListView.builder(
        key: _scrollKey,
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.symmetric(
          horizontal: 24,
          vertical: MediaQuery.of(context).size.height * 0.3,
        ),
        itemCount: _currentLyrics!.length,
        itemBuilder: (context, index) => _buildLyricLine(index),
      ),
    );
  }

  Widget _buildLyricLine(int index) {
    final lyric = _currentLyrics![index];
    final isCurrent = index == _currentLyricIndex;
    final isPast = index < _currentLyricIndex;

    // Apply font size multiplier
    final baseFontSize = isCurrent ? 24.0 : 18.0;
    final adjustedFontSize = baseFontSize * _fontSize;

    return GestureDetector(
      key: _lyricKeys[index],
      onTap: () => _seekToLyric(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        padding: EdgeInsets.symmetric(vertical: isCurrent ? 14 : 8),
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 300),
          style: TextStyle(
            fontFamily: 'ProductSans',
            fontSize: adjustedFontSize,
            fontWeight: isCurrent ? FontWeight.bold : FontWeight.w400,
            color: isCurrent
                ? Colors.white
                : isPast
                    ? Colors.white.withValues(alpha: 0.4)
                    : Colors.white.withValues(alpha: 0.6),
            height: 1.4,
          ),
          child: Text(
            lyric.text,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingView() {
    return const Center(
      child: CircularProgressIndicator(
        color: Colors.white,
        strokeWidth: 2,
      ),
    );
  }

  Widget _buildNoLyricsView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.lyrics_outlined,
            size: 64,
            color: Colors.white38,
          ),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context).translate('no_lyrics'),
            style: const TextStyle(
              fontFamily: 'ProductSans',
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context).translate('no_lyrics_desc'),
            style: const TextStyle(
              fontFamily: 'ProductSans',
              color: Colors.white54,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls(AudioPlayerService audioService) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(50, 8, 50, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Progress bar matching now playing design
          StreamBuilder<Duration?>(
            stream: audioService.audioPlayer.durationStream,
            builder: (context, durationSnapshot) {
              final duration = durationSnapshot.data ?? Duration.zero;
              return StreamBuilder<Duration>(
                stream: audioService.audioPlayer.positionStream,
                builder: (context, positionSnapshot) {
                  final position = positionSnapshot.data ?? Duration.zero;
                  final progress = duration.inMilliseconds > 0
                      ? (position.inMilliseconds / duration.inMilliseconds)
                          .clamp(0.0, 1.0)
                      : 0.0;

                  return Column(
                    children: [
                      SizedBox(
                        height: 20,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final width = constraints.maxWidth;
                            return GestureDetector(
                              behavior: HitTestBehavior.translucent,
                              onTapDown: (details) {
                                final tapPos = details.localPosition;
                                final percentage =
                                    (tapPos.dx / width).clamp(0.0, 1.0);
                                final newPosition = duration * percentage;
                                audioService.audioPlayer.seek(newPosition);
                              },
                              child: Center(
                                child: SizedBox(
                                  width: width,
                                  height: 3.0,
                                  child: Stack(
                                    children: [
                                      Container(
                                        width: width,
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.3),
                                          borderRadius:
                                              BorderRadius.circular(1.5),
                                        ),
                                      ),
                                      Container(
                                        width: width * progress,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(1.5),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatDuration(position),
                            style: TextStyle(
                              fontFamily: 'ProductSans',
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 11,
                            ),
                          ),
                          Text(
                            _formatDuration(duration),
                            style: TextStyle(
                              fontFamily: 'ProductSans',
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              );
            },
          ),
          const SizedBox(height: 16),
          // Controls - plain icons without background circles
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: Icon(
                  Icons.skip_previous_rounded,
                  color: Colors.white,
                  size: 36,
                ),
                onPressed: audioService.back,
              ),
              IconButton(
                icon: Icon(
                  audioService.isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 52,
                ),
                onPressed: () {
                  if (audioService.isPlaying) {
                    audioService.pause();
                  } else {
                    audioService.resume();
                  }
                },
              ),
              IconButton(
                icon: Icon(
                  Icons.skip_next_rounded,
                  color: Colors.white,
                  size: 36,
                ),
                onPressed: audioService.skip,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _seekToLyric(int index) {
    if (_currentLyrics == null || index >= _currentLyrics!.length) return;
    final audioService =
        Provider.of<AudioPlayerService>(context, listen: false);
    audioService.audioPlayer.seek(_currentLyrics![index].time);
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
}
