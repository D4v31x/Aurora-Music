import 'dart:async';
import 'dart:math' show Random;
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:path_provider/path_provider.dart';
import '../models/artist_utils.dart';
import 'dart:io';
import 'dart:convert';
import '../models/playlist_model.dart';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'audio_constants.dart';
import 'background_manager_service.dart';
import 'artwork_cache_service.dart';
import 'home_screen_widget_service.dart';
import 'smart_suggestions_service.dart';
import '../../main.dart' show audioHandler;

part 'audio/playback_controller.dart';
part 'audio/queue_manager.dart';
part 'audio/library_manager.dart';
part 'audio/play_counts.dart';
part 'audio/media_artwork.dart';
part 'audio/queue_persistence.dart';
part 'audio/settings_manager.dart';

/// Enum to track where the current playback originated from
enum PlaybackSource {
  forYou,
  recentlyPlayed,
  recentlyAdded,
  mostPlayed,
  album,
  artist,
  playlist,
  folder,
  search,
  library,
  unknown,
}

/// Model to hold playback source information
class PlaybackSourceInfo {
  final PlaybackSource source;
  final String? name; // Album name, playlist name, artist name, etc.

  const PlaybackSourceInfo({
    this.source = PlaybackSource.unknown,
    this.name,
  });

  static const unknown = PlaybackSourceInfo();
}

class AudioPlayerService extends ChangeNotifier {
  // Use the audio player from the global audio handler
  AudioPlayer get _audioPlayer => audioHandler.player;
  final OnAudioQuery _audioQuery = OnAudioQuery();
  final ArtworkCacheService _artworkCache = ArtworkCacheService();
  final SmartSuggestionsService _smartSuggestions = SmartSuggestionsService();
  final HomeScreenWidgetService _homeWidgetService = HomeScreenWidgetService();

  // Background manager for mesh gradient colors
  BackgroundManagerService? _backgroundManager;

  // Playback source tracking
  PlaybackSourceInfo _playbackSource = PlaybackSourceInfo.unknown;
  PlaybackSourceInfo get playbackSource => _playbackSource;

  List<SongModel> _playlist = [];

  /// Original (pre-shuffle) playlist order; non-empty only while shuffle is on.
  List<SongModel> _originalPlaylist = [];
  List<Playlist> _playlists = [];
  int _currentIndex = -1;
  bool _isPlaying = false;
  bool _isShuffle = false;
  LoopMode _loopMode = LoopMode.off; // Changed from bool to LoopMode
  bool _isLoading = false;
  bool _isSettingPlaylist =
      false; // Guard against currentIndexStream race condition
  Set<String> _librarySet = {};

  // Debounce timer for batching notifications
  Timer? _notifyDebounceTimer;
  bool _notifyScheduled = false;

  // Batch save timer to reduce disk I/O
  Timer? _saveDebounceTimer;
  bool _playcountsDirty = false;
  bool _playlistsDirty = false;

  // Play count tracking
  Map<String, int> _trackPlayCounts = {};
  Map<String, int> _albumPlayCounts = {};
  Map<String, int> _artistPlayCounts = {};
  Map<String, int> _playlistPlayCounts = {};
  Map<String, int> _folderAccessCounts = {};

  // Getters
  AudioPlayer get audioPlayer => _audioPlayer;
  List<SongModel> get playlist => _playlist;
  List<Playlist> get playlists => _playlists;
  int get currentIndex => _currentIndex;
  bool get isPlaying => _isPlaying;
  bool get isShuffle => _isShuffle;
  LoopMode get loopMode => _loopMode;
  // Deprecated: kept for compatibility, use loopMode instead
  bool get isRepeat => _loopMode != LoopMode.off;
  SongModel? get currentSong =>
      _currentIndex >= 0 && _currentIndex < _playlist.length
          ? _playlist[_currentIndex]
          : null;
  final ValueNotifier<Uint8List?> currentArtwork = ValueNotifier(null);
  final ValueNotifier<SongModel?> currentSongNotifier = ValueNotifier(null);

  /// Get the upcoming songs in the queue (songs after current)
  List<SongModel> get upcomingQueue =>
      _currentIndex >= 0 && _currentIndex < _playlist.length - 1
          ? _playlist.sublist(_currentIndex + 1)
          : [];

  /// Get queue length
  int get queueLength => _playlist.length;

  /// Check if queue has upcoming songs
  bool get hasUpcoming => _currentIndex < _playlist.length - 1;

  final _currentSongController = StreamController<SongModel?>.broadcast();
  Stream<SongModel?> get currentSongStream => _currentSongController.stream;
  List<SpotifySongModel> _spotifyPlaylist = [];
  int _currentSpotifyIndex = 0;
  final _errorController = StreamController<String>.broadcast();
  Stream<String> get errorStream => _errorController.stream;

  // Sleep timer
  Timer? _sleepTimer;

  Set<String> _likedSongs = {};
  late Playlist? _likedSongsPlaylist;

  List<SongModel> _songs = [];
  List<SongModel> get songs => _songs;

  /// Update songs list and notify listeners efficiently
  void _updateSongs(List<SongModel> newSongs) {
    _songs = newSongs;
    songsNotifier.value = newSongs;
  }

  static const String LIKED_SONGS_PLAYLIST_ID = 'liked_songs';
  String _likedPlaylistName = 'Favorite Songs'; // Default English name

  // New settings properties
  bool _gaplessPlayback = true;
  bool _volumeNormalization = false;
  double _playbackSpeed = 1.0;
  String _defaultSortOrder = 'title';
  int _cacheSize = 100; // in MB
  bool _mediaControls = true;

  // Settings getters
  bool get gaplessPlayback => _gaplessPlayback;
  bool get volumeNormalization => _volumeNormalization;
  double get playbackSpeed => _playbackSpeed;
  String get defaultSortOrder => _defaultSortOrder;
  int get cacheSize => _cacheSize;
  bool get mediaControls => _mediaControls;

  // Add ValueNotifiers for reactive state
  final ValueNotifier<bool> isPlayingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<List<Playlist>> playlistsNotifier =
      ValueNotifier<List<Playlist>>([]);
  final ValueNotifier<bool> isShuffleNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<LoopMode> loopModeNotifier =
      ValueNotifier<LoopMode>(LoopMode.off);
  final ValueNotifier<Set<String>> likedSongsNotifier =
      ValueNotifier<Set<String>>({});

  // ValueNotifier for songs list to enable efficient rebuilds
  final ValueNotifier<List<SongModel>> songsNotifier =
      ValueNotifier<List<SongModel>>([]);

  // Sleep timer related properties
  final ValueNotifier<Duration?> sleepTimerDurationNotifier =
      ValueNotifier<Duration?>(null);

  // Cache for artwork file URIs to avoid redundant disk I/O
  final Map<int, Uri?> _artworkUriCache = {};

  /// Debounced notification to batch multiple state changes
  /// This prevents excessive rebuilds when multiple changes happen in quick succession
  void _scheduleNotify() {
    if (_notifyScheduled) return;
    _notifyScheduled = true;
    _notifyDebounceTimer?.cancel();
    _notifyDebounceTimer = Timer(const Duration(milliseconds: 16), () {
      _notifyScheduled = false;
      notifyListeners();
    });
  }

  /// Schedule saving play counts with debouncing to reduce disk I/O
  void _scheduleSavePlayCounts() {
    _playcountsDirty = true;
    _saveDebounceTimer?.cancel();
    _saveDebounceTimer = Timer(const Duration(seconds: 2), () {
      if (_playcountsDirty) {
        _playcountsDirty = false;
        this._savePlayCounts();
      }
      if (_playlistsDirty) {
        _playlistsDirty = false;
        this.savePlaylists();
      }
    });
  }

  AudioPlayerService() {
    _init();
    this._loadSettings();

    // Initialize with empty data first - don't try to load music yet
    _updateSongs([]);
    _likedSongsPlaylist = Playlist(
      id: LIKED_SONGS_PLAYLIST_ID,
      name: _likedPlaylistName,
      songs: [],
    );

    // Don't do any audio query operations in the constructor
    // All media access will be explicit and user-initiated
  }

  /// Set the background manager service for updating mesh gradient colors
  void setBackgroundManager(BackgroundManagerService backgroundManager) {
    _backgroundManager = backgroundManager;
  }

  Future<void> _init() async {
    // Configure audio session for long-running music playback.
    // Using GAIN (not GAIN_TRANSIENT) tells the system this session
    // is meant to persist — critical for keeping the foreground service
    // alive through the full playback session.
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.playback,
      avAudioSessionCategoryOptions:
          AVAudioSessionCategoryOptions.allowBluetooth,
      avAudioSessionMode: AVAudioSessionMode.defaultMode,
      androidAudioAttributes: AndroidAudioAttributes(
        contentType: AndroidAudioContentType.music,
        flags: AndroidAudioFlags.audibilityEnforced,
        usage: AndroidAudioUsage.media,
      ),
      androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
      androidWillPauseWhenDucked: true,
    ));

    // Re-activate the audio session so audio focus is explicitly requested
    // on startup. This prevents the system from silently reclaiming focus
    // during a long playback session.
    await session.setActive(true);

    await this._loadPlayCounts();
    await this._loadPlaylists();

    // Initialize home screen widget
    unawaited(_homeWidgetService.initialize());

    // Listen to song changes to update home screen widget
    currentSongNotifier.addListener(this._onSongChangedForWidget);
    isPlayingNotifier.addListener(this._onPlayStateChangedForWidget);

    _audioPlayer.playerStateStream.listen((playerState) {
      _isPlaying = playerState.playing;
      isPlayingNotifier.value = _isPlaying;
      // ValueNotifier handles most UI updates, use debounced notify for other listeners
      _scheduleNotify();
    });

    // Also listen to playingStream specifically - this is more reliable for
    // catching play/pause changes from external sources like lock screen controls
    _audioPlayer.playingStream.listen((playing) {
      if (_isPlaying != playing) {
        _isPlaying = playing;
        isPlayingNotifier.value = playing;
        _scheduleNotify();
      }
    });

    // Listen to track index changes for gapless playback
    // This fires when just_audio automatically transitions to the next track.
    // IMPORTANT: Only process these events in gapless mode. In non-gapless mode,
    // we load a single song via setAudioSource, so the player's currentIndex is
    // always 0, which does NOT correspond to _currentIndex in _playlist.
    _audioPlayer.currentIndexStream.listen((index) async {
      debugPrint(
          '🎵 [INDEX_STREAM] Index changed: $index (previous: $_currentIndex, shuffle: ${_audioPlayer.shuffleModeEnabled}, loop: ${_audioPlayer.loopMode})');
      // Skip index updates while setPlaylist is in progress to avoid race condition
      // where intermediate index 0 overrides the correct startIndex
      if (_isSettingPlaylist) {
        debugPrint('🎵 [INDEX_STREAM] Skipping — setPlaylist in progress');
        return;
      }
      // In non-gapless mode, the player only has a single song loaded, so
      // its currentIndex (always 0) is meaningless for our _playlist tracking.
      if (!_gaplessPlayback) {
        debugPrint('🎵 [INDEX_STREAM] Skipping — non-gapless mode');
        return;
      }
      if (index != null && index != _currentIndex && index < _playlist.length) {
        _currentIndex = index;
        final song = _playlist[_currentIndex];
        debugPrint('🎵 [INDEX_STREAM] Playing: ${song.title}');

        // Update all song-related state
        _currentSongController.add(song);
        currentSongNotifier.value = song;
        this._incrementPlayCount(song);

        // Update notification with new media item
        final mediaItem = await this._createMediaItem(song);
        audioHandler.updateNotificationMediaItem(mediaItem);

        // Update artwork and background
        unawaited(this.updateCurrentArtwork());
        unawaited(this._updateBackgroundColors());

        _scheduleNotify();
      }
    });

    // Listen for when playback completes (end of playlist with no loop)
    _audioPlayer.processingStateStream.listen((state) {
      debugPrint(
          '🎵 [PROCESSING_STATE] State changed: $state (loopMode: $_loopMode)');
      if (state == ProcessingState.completed) {
        debugPrint('🎵 [PROCESSING_STATE] Playback completed!');
        // Playback completed - if loop mode is off and we're at end, stop
        if (_loopMode == LoopMode.off) {
          debugPrint('🎵 [PROCESSING_STATE] Loop OFF, stopping playback');
          _isPlaying = false;
          isPlayingNotifier.value = false;
          _scheduleNotify();
        } else {
          debugPrint(
              '🎵 [PROCESSING_STATE] Loop mode: $_loopMode, should loop automatically');
        }
      }
    });

    _startCacheCleanup();

    // Restore the queue from the previous session (non-blocking).
    unawaited(this.loadQueueState());
  }

  void _startCacheCleanup() {
    Timer.periodic(const Duration(hours: 24), (timer) async {
      await this._manageCacheSize();
    });
  }

  // Sleep timer methods
  bool get isSleepTimerActive => _sleepTimer?.isActive ?? false;

  Duration? get sleepTimerDuration => sleepTimerDurationNotifier.value;

  void startSleepTimer(Duration duration) {
    // Cancel any existing timer first
    cancelSleepTimer();

    // Set the sleep timer duration for the UI
    sleepTimerDurationNotifier.value = duration;

    // Create a new timer
    _sleepTimer = Timer(duration, () {
      // When timer completes, stop playback
      this.stop();
      // Reset the timer notification
      sleepTimerDurationNotifier.value = null;
    });
    // ValueNotifier handles UI updates - no notifyListeners needed
  }

  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    sleepTimerDurationNotifier.value = null;
    // ValueNotifier handles UI updates - no notifyListeners needed
  }

  @override
  void dispose() {
    // Cancel debounce timers
    _notifyDebounceTimer?.cancel();
    _saveDebounceTimer?.cancel();

    // Dispose notifiers
    currentSongNotifier.dispose();
    isPlayingNotifier.dispose();
    isShuffleNotifier.dispose();
    loopModeNotifier.dispose();
    sleepTimerDurationNotifier.dispose();
    playlistsNotifier.dispose();
    songsNotifier.dispose();
    currentArtwork.dispose();

    _audioPlayer.dispose();

    // Save any pending data synchronously before disposing
    if (_playcountsDirty) {
      this._savePlayCounts();
    }
    if (_playlistsDirty) {
      this.savePlaylists();
    }

    // Persist queue state synchronously so it is available on next launch.
    this.saveQueueState();

    // Clean up widget listeners and service
    currentSongNotifier.removeListener(this._onSongChangedForWidget);
    isPlayingNotifier.removeListener(this._onPlayStateChangedForWidget);
    _homeWidgetService.dispose();

    _currentSongController.close();
    _errorController.close();
    _sleepTimer?.cancel();
    super.dispose();
  }
}

class SpotifySongModel {
  final String id;
  final String title;
  final String artist;
  final String album;
  final int duration;
  final String uri;
  final String artworkUrl;

  SpotifySongModel({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.duration,
    required this.uri,
    required this.artworkUrl,
  });

  MediaItem toMediaItem() {
    return MediaItem(
      id: id,
      album: album,
      title: title,
      artist: artist,
      duration: Duration(milliseconds: duration),
      artUri: Uri.parse(artworkUrl),
    );
  }
}
