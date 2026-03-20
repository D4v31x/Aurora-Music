import 'dart:async';
import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import '../../../shared/models/models.dart';
import '../../../shared/services/artwork_cache_service.dart';
import '../../../shared/services/audio_player_service.dart';
import '../../../shared/services/lyrics_service.dart';

// Now Playing Controller

/// Controller for managing Now Playing screen state and logic.
class NowPlayingController {
  // Private Fields

  final AudioPlayerService _audioPlayerService;
  final ArtworkCacheService _artworkService;

  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<SongModel?>? _songChangeSubscription;

  int? _lastSongId;
  int? _pendingSongLoadId;

  // Public State
  List<TimedLyric>? timedLyrics;
  final ValueNotifier<int> currentLyricIndexNotifier = ValueNotifier<int>(0);
  ImageProvider<Object>? currentArtwork;
  VoidCallback? onArtworkChanged;
  VoidCallback? onLyricsChanged;

  // Constructor

  NowPlayingController({
    required AudioPlayerService audioPlayerService,
    ArtworkCacheService? artworkService,
  })  : _audioPlayerService = audioPlayerService,
        _artworkService = artworkService ?? ArtworkCacheService();

  // Public Methods

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
    unawaited(_positionSubscription?.cancel());
    _songChangeSubscription?.cancel();
    _pendingSongLoadId = null;
  }

  /// Gets the current song ID.
  int? get currentSongId => _lastSongId;

  /// Whether lyrics are available.
  bool get hasLyrics => timedLyrics != null && timedLyrics!.isNotEmpty;

  // Lyrics Management

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
    await _positionSubscription?.cancel();
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

  // Artwork Management

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
