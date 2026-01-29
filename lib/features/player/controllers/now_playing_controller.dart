/// Now Playing screen controller.
///
/// Manages business logic for the Now Playing screen including:
/// - Lyrics loading and synchronization
/// - Artwork management
/// - Song change handling
library;

import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import '../../../shared/models/timed_lyrics.dart';
import '../../../shared/services/artwork_cache_service.dart';
import '../../../shared/services/audio_player_service.dart';
import '../../../shared/services/lyrics_service.dart';

// MARK: - Now Playing Controller

/// Controller for managing Now Playing screen state and logic.
///
/// Handles lyrics loading, artwork caching, and song change detection.
/// UI components should use this controller to avoid embedding business
/// logic directly in widget classes.
class NowPlayingController {
  // MARK: - Private Fields

  final AudioPlayerService _audioPlayerService;
  final ArtworkCacheService _artworkService;

  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<SongModel?>? _songChangeSubscription;

  int? _lastSongId;
  int? _pendingSongLoadId;

  // MARK: - Public State

  /// Current timed lyrics for the song.
  List<TimedLyric>? timedLyrics;

  /// Current lyric index notifier for UI updates.
  final ValueNotifier<int> currentLyricIndexNotifier = ValueNotifier<int>(0);

  /// Current artwork provider.
  ImageProvider<Object>? currentArtwork;

  /// Callback when artwork changes.
  VoidCallback? onArtworkChanged;

  /// Callback when lyrics change.
  VoidCallback? onLyricsChanged;

  // MARK: - Constructor

  NowPlayingController({
    required AudioPlayerService audioPlayerService,
    ArtworkCacheService? artworkService,
  })  : _audioPlayerService = audioPlayerService,
        _artworkService = artworkService ?? ArtworkCacheService();

  // MARK: - Public Methods

  /// Initializes the controller and starts listening for song changes.
  void initialize() {
    final currentSong = _audioPlayerService.currentSong;
    if (currentSong != null) {
      _lastSongId = currentSong.id;
      _initializeTimedLyrics();
      _updateArtwork(currentSong);
    }

    // Listen to song changes
    _songChangeSubscription =
        _audioPlayerService.currentSongStream.listen((song) {
      if (song != null && song.id != _lastSongId) {
        _lastSongId = song.id;
        _pendingSongLoadId = song.id;
        _updateArtwork(song);
        _initializeTimedLyrics();
      }
    });
  }

  /// Disposes of resources.
  void dispose() {
    currentLyricIndexNotifier.dispose();
    _positionSubscription?.cancel();
    _songChangeSubscription?.cancel();
    _pendingSongLoadId = null;
  }

  /// Gets the current song ID.
  int? get currentSongId => _lastSongId;

  /// Whether lyrics are available.
  bool get hasLyrics => timedLyrics != null && timedLyrics!.isNotEmpty;

  // MARK: - Lyrics Management

  /// Loads and initializes timed lyrics for the current song.
  Future<void> _initializeTimedLyrics() async {
    final song = _audioPlayerService.currentSong;
    if (song == null) return;
    _pendingSongLoadId = song.id;

    final timedLyricsService = TimedLyricsService();
    final artistRaw = song.artist ?? '';
    final titleRaw = song.title;
    final artist = artistRaw.trim().isEmpty ? 'Unknown' : artistRaw.trim();
    final title = titleRaw.trim().isEmpty ? 'Unknown' : titleRaw.trim();

    debugPrint('🎵 [NOW_PLAYING] Requesting lyrics for: "$title" by "$artist"');

    // Load from cache first
    var lyrics = await timedLyricsService.loadLyricsFromFile(artist, title);
    if (song.id != _pendingSongLoadId) return;

    if (lyrics == null) {
      debugPrint('🎵 [NOW_PLAYING] Cache miss, fetching from API');
      lyrics = await timedLyricsService.fetchTimedLyrics(
        artist,
        title,
        songDuration: _audioPlayerService.audioPlayer.duration,
      );
    } else {
      debugPrint(
          '🎵 [NOW_PLAYING] ✓ Using cached lyrics (${lyrics.length} lines)');
    }

    if (song.id != _pendingSongLoadId) return;

    timedLyrics = lyrics;
    currentLyricIndexNotifier.value = 0;
    onLyricsChanged?.call();

    // Set up position stream for lyric sync
    _positionSubscription?.cancel();
    _positionSubscription =
        _audioPlayerService.audioPlayer.positionStream.listen(_updateCurrentLyric);
  }

  /// Updates the current lyric index based on playback position.
  void _updateCurrentLyric(Duration position) {
    if (timedLyrics == null || timedLyrics!.isEmpty) return;

    for (int i = 0; i < timedLyrics!.length; i++) {
      if (position < timedLyrics![i].time) {
        final newIndex = i > 0 ? i - 1 : 0;
        if (newIndex != currentLyricIndexNotifier.value) {
          currentLyricIndexNotifier.value = newIndex;
        }
        break;
      }
      if (i == timedLyrics!.length - 1) {
        if (currentLyricIndexNotifier.value != i) {
          currentLyricIndexNotifier.value = i;
        }
      }
    }
  }

  // MARK: - Artwork Management

  /// Updates artwork for a song.
  Future<void> _updateArtwork(SongModel song) async {
    try {
      final provider =
          await _artworkService.getCachedImageProvider(song.id, highQuality: true);
      currentArtwork = provider;
      onArtworkChanged?.call();
    } catch (e) {
      currentArtwork = const AssetImage('assets/images/logo/default_art.png');
      onArtworkChanged?.call();
    }
  }
}

// MARK: - Lyrics Selection Dialog

/// Shows a dialog for selecting lyrics when multiple results are found.
Future<Map<String, dynamic>?> showLyricsSelectionDialog(
  BuildContext context,
  List<Map<String, dynamic>> results,
) async {
  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (context) => BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: AlertDialog(
        backgroundColor: Colors.grey[900]?.withOpacity(0.9),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        title: Row(
          children: [
            Icon(Icons.lyrics, color: Colors.purple[300]),
            const SizedBox(width: 8),
            const Text(
              'Choose Lyrics',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Multiple lyrics found. Select the correct version:',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: results.length > 10 ? 10 : results.length,
                  itemBuilder: (context, index) {
                    final result = results[index];
                    return _LyricsSelectionItem(
                      result: result,
                      onTap: () => Navigator.pop(context, result),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ],
      ),
    ),
  );
}

/// A single lyrics selection item in the dialog.
class _LyricsSelectionItem extends StatelessWidget {
  final Map<String, dynamic> result;
  final VoidCallback onTap;

  const _LyricsSelectionItem({
    required this.result,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final trackName = result['trackName'] ?? 'Unknown';
    final artistName = result['artistName'] ?? 'Unknown';
    final albumName = result['albumName'] ?? '';

    return Card(
      color: Colors.grey[850],
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                trackName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                artistName,
                style: TextStyle(
                  color: Colors.purple[300],
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (albumName.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  albumName,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
