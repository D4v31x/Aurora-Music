import 'dart:async';
import 'package:aurora_music_v01/core/constants/font_constants.dart';
import 'package:iconoir_flutter/iconoir_flutter.dart' as Iconoir;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../shared/models/models.dart';
import '../widgets/lyrics/lyrics_widgets.dart';
import '../../../shared/services/audio_player_service.dart';
import '../../../shared/services/notification_manager.dart';
import '../../../shared/services/lyrics_service.dart';
import '../../../shared/services/lyrics_translation_service.dart';
import '../../../shared/widgets/app_background.dart';
import '../../../l10n/generated/app_localizations.dart';

enum _TranslationState { idle, loading, done, error }

class FullscreenLyricsScreen extends StatefulWidget {
  final void Function(List<TimedLyric>)? onLyricsChanged;

  const FullscreenLyricsScreen({super.key, this.onLyricsChanged});

  @override
  State<FullscreenLyricsScreen> createState() => _FullscreenLyricsScreenState();
}

class _FullscreenLyricsScreenState extends State<FullscreenLyricsScreen>
    with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();

  int _currentLyricIndex = 0;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<SongModel?>? _songChangeSubscription;

  late AnimationController _fadeController;

  final GlobalKey _scrollKey = GlobalKey();
  Map<int, GlobalKey> _lyricKeys = {};

  List<TimedLyric>? _currentLyrics;
  int? _lastSongId;
  bool _isLoadingLyrics = false;

  // Translation
  _TranslationState _translationState = _TranslationState.idle;
  List<String?> _translatedLines = [];
  bool _showTranslated = false;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnim;

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
      duration: kLyricsFadeDuration,
      vsync: this,
    )..forward();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _pulseAnim = Tween<double>(begin: 1.0, end: 0.25).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final audioService =
          Provider.of<AudioPlayerService>(context, listen: false);
      _loadLyricsForCurrentSong(audioService);

      _positionSubscription =
          audioService.audioPlayer.positionStream.listen((position) {
        if (mounted) _updateCurrentLyric(position);
      });

      _songChangeSubscription = audioService.currentSongStream.listen((song) {
        if (mounted && song != null && song.id != _lastSongId) {
          _loadLyricsForCurrentSong(audioService);
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

    // Reset translation whenever new lyrics are loaded for a different song.
    _pulseController.stop();
    _pulseController.reset();

    setState(() {
      _currentLyrics = lyrics;
      _currentLyricIndex = 0;
      _isLoadingLyrics = false;
      _lyricKeys = {};
      _translationState = _TranslationState.idle;
      _translatedLines = [];
      _showTranslated = false;
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
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final audioService =
        Provider.of<AudioPlayerService>(context, listen: false);

    return AppBackground(
      child: Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Content
          SafeArea(
            child: Column(
              children: [
                // Only rebuild the header when the current song changes
                ValueListenableBuilder<SongModel?>(
                  valueListenable: audioService.currentSongNotifier,
                  builder: (context, song, _) =>
                      _buildHeader(audioService),
                ),
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

          // Translate button — bottom-right, above controls
          if (_currentLyrics != null && _currentLyrics!.isNotEmpty)
            Positioned(
              right: 16,
              bottom: MediaQuery.of(context).padding.bottom + 152,
              child: _buildFloatingTranslateButton(),
            ),
        ],
      ),
      ),
    );
  }

  Widget _buildHeader(AudioPlayerService audioService) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Iconoir.NavArrowDown(
                color: Colors.white, width: 32, height: 32),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  audioService.currentSong?.title ?? '',
                  style: const TextStyle(
                    fontFamily: FontConstants.fontFamily,
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
                    fontFamily: FontConstants.fontFamily,
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
                  AppLocalizations.of(context).refreshLyrics,
                  'refresh'),
              _buildMenuItem(
                  Icons.search,
                  AppLocalizations.of(context).searchLyrics,
                  'search'),
              _buildMenuItem(
                  Icons.timer_outlined,
                  AppLocalizations.of(context).adjustSync,
                  'sync'),
              _buildMenuItem(
                  Icons.text_fields,
                  AppLocalizations.of(context).fontSize,
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
              fontFamily: FontConstants.fontFamily,
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

  Future<void> _handleTranslateButton() async {
    final lyrics = _currentLyrics;
    if (lyrics == null || lyrics.isEmpty) return;

    // Already translated — just toggle visibility.
    if (_translationState == _TranslationState.done) {
      setState(() => _showTranslated = !_showTranslated);
      return;
    }

    if (_translationState == _TranslationState.loading) return;

    setState(() => _translationState = _TranslationState.loading);
    _pulseController.repeat(reverse: true);

    try {
      final targetLang = Localizations.localeOf(context).languageCode;
      final audioService =
          Provider.of<AudioPlayerService>(context, listen: false);
      final song = audioService.currentSong;
      final lyricsTexts = lyrics.map((l) => l.text).toList();
      final lyricsFingerprint = lyricsTexts.join().hashCode;
      final cacheKey = '${song?.artist ?? ""}|${song?.title ?? ""}|$lyricsFingerprint';

      final translated = await LyricsTranslationService.translateLines(
        texts: lyricsTexts,
        targetLang: targetLang,
        cacheKey: cacheKey,
      );

      if (!mounted) return;
      setState(() {
        _translatedLines = translated;
        _translationState = _TranslationState.done;
        _showTranslated = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _translationState = _TranslationState.error);
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && _translationState == _TranslationState.error) {
          setState(() => _translationState = _TranslationState.idle);
        }
      });
    } finally {
      _pulseController
        ..stop()
        ..reset();
    }
  }

  void _showSearchLyricsDialog(AudioPlayerService audioService) {
    final song = audioService.currentSong;
    final artistController = TextEditingController(text: song?.artist ?? '');
    final titleController = TextEditingController(text: song?.title ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
          backgroundColor: Colors.grey[900]?.withValues(alpha: 0.9),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
          title: Text(
            AppLocalizations.of(context).searchLyrics,
            style: const TextStyle(
              fontFamily: FontConstants.fontFamily,
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
                    color: Colors.white, fontFamily: FontConstants.fontFamily),
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context).artists,
                  labelStyle: const TextStyle(
                      color: Colors.white70,
                      fontFamily: FontConstants.fontFamily),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.white24),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: titleController,
                style: const TextStyle(
                    color: Colors.white, fontFamily: FontConstants.fontFamily),
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context).title,
                  labelStyle: const TextStyle(
                      color: Colors.white70,
                      fontFamily: FontConstants.fontFamily),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.white24),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                AppLocalizations.of(context).cancel,
                style: const TextStyle(
                    color: Colors.white70,
                    fontFamily: FontConstants.fontFamily),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                final artist = artistController.text.trim();
                final title = titleController.text.trim();
                if (artist.isNotEmpty && title.isNotEmpty) {
                  unawaited(_performLyricsSearch(artist, title));
                }
              },
              child: Text(
                AppLocalizations.of(context).search,
                style: const TextStyle(
                    color: Colors.white,
                    fontFamily: FontConstants.fontFamily,
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
          NotificationManager.showMessage(
            context,
            AppLocalizations.of(context).noLyricsFound,
          );
          return;
        }

        // Show results dialog
        setState(() => _isLoadingLyrics = false);
        _showLyricsResultsDialog(syncedResults.cast<Map<String, dynamic>>());
      } else {
        setState(() => _isLoadingLyrics = false);
        if (mounted) {
          NotificationManager.showMessage(
            context,
            AppLocalizations.of(context).searchFailed,
          );
        }
      }
    } catch (e) {
      setState(() => _isLoadingLyrics = false);
      if (mounted) {
        NotificationManager.showMessage(
          context,
          AppLocalizations.of(context).searchFailed,
        );
      }
    }
  }

  void _showLyricsResultsDialog(List<Map<String, dynamic>> results) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
          backgroundColor: Colors.grey[900]?.withValues(alpha: 0.9),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
          title: Text(
            '${AppLocalizations.of(context).results} (${results.length})',
            style: const TextStyle(
              fontFamily: FontConstants.fontFamily,
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
                  color: Colors.white.withValues(alpha: 0.1),
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
                        fontFamily: FontConstants.fontFamily,
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
                            fontFamily: FontConstants.fontFamily,
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
                              fontFamily: FontConstants.fontFamily,
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        duration,
                        style: const TextStyle(
                          fontFamily: FontConstants.fontFamily,
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
                AppLocalizations.of(context).cancel,
                style: const TextStyle(
                    color: Colors.white70,
                    fontFamily: FontConstants.fontFamily),
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
      final artistRaw = song.artist ?? '';
      final artist = artistRaw.trim().isEmpty ? 'Unknown' : artistRaw.trim();
      timedLyricsService.saveLyricsToCache(
        artist,
        song.title,
        lrcContent,
      );
    }

    // Notify now-playing screen so it updates its mini lyrics view
    widget.onLyricsChanged?.call(lyrics);
  }

  void _showSyncAdjustDialog() {
    int tempOffset = _syncOffset;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            backgroundColor: Colors.grey[900]?.withValues(alpha: 0.9),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
            title: Text(
              AppLocalizations.of(context).adjustSync,
              style: const TextStyle(
                fontFamily: FontConstants.fontFamily,
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
                    fontFamily: FontConstants.fontFamily,
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  tempOffset > 0
                      ? AppLocalizations.of(context).lyricsAhead
                      : tempOffset < 0
                          ? AppLocalizations.of(context)
                              .lyricsBehind
                          : AppLocalizations.of(context)
                              .lyricsSynced,
                  style: const TextStyle(
                    fontFamily: FontConstants.fontFamily,
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
                    AppLocalizations.of(context).reset,
                    style: const TextStyle(
                        color: Colors.white70,
                        fontFamily: FontConstants.fontFamily),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  AppLocalizations.of(context).cancel,
                  style: const TextStyle(
                      color: Colors.white70,
                      fontFamily: FontConstants.fontFamily),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _saveSyncOffset(tempOffset);
                },
                child: Text(
                  AppLocalizations.of(context).save,
                  style: const TextStyle(
                      color: Colors.white,
                      fontFamily: FontConstants.fontFamily,
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
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontFamily: FontConstants.fontFamily,
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
          backgroundColor: Colors.grey[900]?.withValues(alpha: 0.9),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
          title: Text(
            AppLocalizations.of(context).fontSize,
            style: const TextStyle(
              fontFamily: FontConstants.fontFamily,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildFontSizeOption(
                  AppLocalizations.of(context).small, 0.8),
              _buildFontSizeOption(
                  AppLocalizations.of(context).medium, 1.0),
              _buildFontSizeOption(
                  AppLocalizations.of(context).large, 1.2),
              _buildFontSizeOption(
                  AppLocalizations.of(context).extraLarge, 1.4),
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
          fontFamily: FontConstants.fontFamily,
          color: isSelected ? Colors.white : Colors.white70,
          fontSize: 16,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildLyricsView() {
    return RepaintBoundary(
      child: ShaderMask(
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
            horizontal: kLyricsHorizontalPadding,
            vertical: MediaQuery.of(context).size.height * 0.3,
          ),
          itemCount: _currentLyrics!.length + (_showTranslated ? 1 : 0),
          // Optimize list performance with cacheExtent
          cacheExtent: 1000,
          itemBuilder: (context, index) {
            if (_showTranslated && index == 0) {
              return _buildTranslationDisclaimerHeader();
            }
            return _buildLyricLine(_showTranslated ? index - 1 : index);
          },
        ),
      ),
    );
  }

  Widget _buildFloatingTranslateButton() {
    final isActive =
        _translationState == _TranslationState.done && _showTranslated;
    final isLoading = _translationState == _TranslationState.loading;
    final isError = _translationState == _TranslationState.error;

    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (context, child) => Opacity(
        opacity: isLoading ? _pulseAnim.value : 1.0,
        child: child,
      ),
      child: Tooltip(
        message: isError
            ? 'Translation failed — tap to retry'
            : isActive
                ? 'Show original'
                : _translationState == _TranslationState.done
                    ? 'Show translation'
                    : 'Translate lyrics',
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: isActive
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.85)
                : Colors.black.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isError
                  ? Colors.orangeAccent.withValues(alpha: 0.6)
                  : isActive
                      ? Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.0)
                      : Colors.white.withValues(alpha: 0.18),
            ),
          ),
          child: isLoading
              ? const Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white70,
                    ),
                  ),
                )
              : InkWell(
                  onTap: _handleTranslateButton,
                  borderRadius: BorderRadius.circular(22),
                  child: Center(
                    child: Icon(
                      isError
                          ? Icons.warning_amber_rounded
                          : Icons.translate_rounded,
                      size: 20,
                      color: isError ? Colors.orangeAccent : Colors.white,
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildTranslationDisclaimerHeader() {    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.auto_awesome_rounded,
              size: 12, color: Colors.white30),
          const SizedBox(width: 5),
          Text(
            'AI translated \u00b7 accuracy may vary',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: FontConstants.fontFamily,
              fontSize: 11,
              color: Colors.white30,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLyricLine(int index) {
    final lyric = _currentLyrics![index];
    final isCurrent = index == _currentLyricIndex;
    final isPast = index < _currentLyricIndex;

    final baseFontSize = isCurrent ? 24.0 : 18.0;
    final adjustedFontSize = baseFontSize * _fontSize;

    final mainColor = isCurrent
        ? Colors.white
        : isPast
            ? Colors.white.withValues(alpha: 0.4)
            : Colors.white.withValues(alpha: 0.6);

    final translatedText =
        (_showTranslated && index < _translatedLines.length)
            ? _translatedLines[index]
            : null;

    return RepaintBoundary(
      child: GestureDetector(
        key: _lyricKeys[index],
        onTap: () => _seekToLyric(index),
        child: AnimatedContainer(
          duration: kLyricsScrollDuration,
          curve: Curves.easeOut,
          padding: EdgeInsets.symmetric(vertical: isCurrent ? 14 : 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Main text: translated if available, otherwise original
              AnimatedDefaultTextStyle(
                duration: kLyricsScrollDuration,
                style: TextStyle(
                  fontFamily: FontConstants.fontFamily,
                  fontSize: adjustedFontSize,
                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.w400,
                  color: mainColor,
                  height: 1.4,
                ),
                child: Text(
                  translatedText ?? lyric.text,
                  textAlign: TextAlign.center,
                ),
              ),
              // Original subtitle — slides in/out when translation is active
              AnimatedSize(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeInOut,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 320),
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: SizeTransition(
                      sizeFactor: anim,
                      axisAlignment: -1,
                      child: child,
                    ),
                  ),
                  child: translatedText != null
                      ? Padding(
                          key: const ValueKey('orig'),
                          padding: const EdgeInsets.only(top: 4),
                          child: Center(
                            child: Text(
                              lyric.text,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: FontConstants.fontFamily,
                                fontSize:
                                    (adjustedFontSize * 0.65).clamp(10.0, 14.0),
                                fontStyle: FontStyle.italic,
                                color: mainColor.withValues(alpha: 0.5),
                                height: 1.3,
                              ),
                            ),
                          ),
                        )
                      : const SizedBox.shrink(key: ValueKey('empty')),
                ),
              ),
            ],
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
          const Icon(
            Icons.lyrics_outlined,
            size: 64,
            color: Colors.white38,
          ),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context).noLyrics,
            style: const TextStyle(
              fontFamily: FontConstants.fontFamily,
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context).noLyricsDesc,
            style: const TextStyle(
              fontFamily: FontConstants.fontFamily,
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
                                          color: Colors.white.withValues(alpha: 0.3),
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
                              fontFamily: FontConstants.fontFamily,
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 11,
                            ),
                          ),
                          Text(
                            _formatDuration(duration),
                            style: TextStyle(
                              fontFamily: FontConstants.fontFamily,
                              color: Colors.white.withValues(alpha: 0.7),
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
                icon: const Icon(
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
                icon: const Icon(
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
