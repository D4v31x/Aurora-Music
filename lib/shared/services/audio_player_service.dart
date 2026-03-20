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
  AudioPlayer get _audioPlayer => audioHandler.player;
  final OnAudioQuery _audioQuery = OnAudioQuery();
  final ArtworkCacheService _artworkCache = ArtworkCacheService();
  final SmartSuggestionsService _smartSuggestions = SmartSuggestionsService();
  BackgroundManagerService? _backgroundManager;

  PlaybackSourceInfo _playbackSource = PlaybackSourceInfo.unknown;
  PlaybackSourceInfo get playbackSource => _playbackSource;

  List<SongModel> _playlist = [];
  List<SongModel> _originalPlaylist = [];
  List<Playlist> _playlists = [];
  int _currentIndex = -1;
  int _queueCount = 0;
  bool _isPlaying = false;
  bool _isShuffle = false;
  LoopMode _loopMode = LoopMode.off;
  bool _isLoading = false;
  bool _isSettingPlaylist = false; // Guard against currentIndexStream race condition
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

  /// Songs explicitly queued by the user (via Add to Queue / Play Next).
  /// These play immediately after the current track, before source songs.
  List<SongModel> get queuedSongs {
    if (_currentIndex < 0 || _queueCount <= 0) return [];
    final start = _currentIndex + 1;
    final end = (_currentIndex + 1 + _queueCount).clamp(start, _playlist.length);
    return start < end ? _playlist.sublist(start, end) : [];
  }

  /// Songs that come after all explicitly queued songs (from the source
  /// album / playlist / folder).
  List<SongModel> get sourceUpcoming {
    if (_currentIndex < 0) return [];
    final start = (_currentIndex + 1 + _queueCount).clamp(0, _playlist.length);
    return start < _playlist.length ? _playlist.sublist(start) : [];
  }

  /// Index into [_playlist] where source (non-queued) songs begin.
  /// Equals [_currentIndex] + 1 + [_queueCount].
  int get queueBoundary =>
      (_currentIndex + 1 + _queueCount).clamp(0, _playlist.length);

  /// Number of explicitly queued (user-added) songs upcoming.
  int get queueCount => _queueCount;

  /// Get queue length
  int get queueLength => _playlist.length;

  /// Check if queue has upcoming songs
  bool get hasUpcoming => _currentIndex < _playlist.length - 1;

  final _currentSongController = StreamController<SongModel?>.broadcast();
  Stream<SongModel?> get currentSongStream => _currentSongController.stream;
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

  static const String likedSongsPlaylistId = 'liked_songs';
  String _likedPlaylistName = 'Favorite Songs'; // Default English name

  // New settings properties
  bool _gaplessPlayback = true;
  double _playbackSpeed = 1.0;
  /// When true, pitch shifts with speed (chipmunk effect).
  /// When false, pitch is locked to 1.0 regardless of speed.
  bool _pitchWithSpeed = false;
  String _defaultSortOrder = 'title';
  int _cacheSize = 100; // in MB
  bool _mediaControls = true;

  // Settings getters
  bool get gaplessPlayback => _gaplessPlayback;
  double get playbackSpeed => _playbackSpeed;
  bool get pitchWithSpeed => _pitchWithSpeed;
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

  final Map<int, Uri?> _artworkUriCache = {};

  /// Debounced notification to batch multiple state changes
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
        _savePlayCounts();
      }
      if (_playlistsDirty) {
        _playlistsDirty = false;
        savePlaylists();
      }
    });
  }

  AudioPlayerService() {
    _init();
    _loadSettings();

    // Initialize with empty data first - don't try to load music yet
    _updateSongs([]);
    _likedSongsPlaylist = Playlist(
      id: likedSongsPlaylistId,
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
      androidWillPauseWhenDucked: true,
    ));

    await session.setActive(true);

    await _loadPlayCounts();
    await _loadPlaylists();

    _audioPlayer.playerStateStream.listen((playerState) {
      _isPlaying = playerState.playing;
      isPlayingNotifier.value = _isPlaying;
      _scheduleNotify();
    });

    _audioPlayer.playingStream.listen((playing) {
      if (_isPlaying != playing) {
        _isPlaying = playing;
        isPlayingNotifier.value = playing;
        _scheduleNotify();
      }
    });

    _audioPlayer.currentIndexStream.listen((index) async {
      debugPrint(
          '🎵 [INDEX_STREAM] Index changed: $index (previous: $_currentIndex, shuffle: ${_audioPlayer.shuffleModeEnabled}, loop: ${_audioPlayer.loopMode})');
      if (_isSettingPlaylist) {
        debugPrint('🎵 [INDEX_STREAM] Skipping — setPlaylist in progress');
        return;
      }
      if (!_gaplessPlayback) {
        debugPrint('🎵 [INDEX_STREAM] Skipping — non-gapless mode');
        return;
      }
      if (index != null && index != _currentIndex && index < _playlist.length) {
        final oldIndex = _currentIndex;
        _currentIndex = index;
        _updateQueueCountForIndexChange(oldIndex, index);
        final song = _playlist[_currentIndex];
        debugPrint('🎵 [INDEX_STREAM] Playing: ${song.title}');

        // Update all song-related state
        _currentSongController.add(song);
        currentSongNotifier.value = song;
        _incrementPlayCount(song);

        // Update notification with new media item
        final mediaItem = await _createMediaItem(song);
        audioHandler.updateNotificationMediaItem(mediaItem);

        // Update artwork and background
        unawaited(updateCurrentArtwork());
        unawaited(_updateBackgroundColors());

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
    unawaited(loadQueueState());
  }

  /// Adjusts [_queueCount] when [_currentIndex] transitions from [oldIndex]
  /// to [newIndex]. Moving forward consumes queued songs; moving backward
  /// does not restore them.
  void _updateQueueCountForIndexChange(int oldIndex, int newIndex) {
    if (newIndex > oldIndex && _queueCount > 0) {
      final consumed = newIndex - oldIndex;
      _queueCount = (_queueCount - consumed).clamp(0, _queueCount);
    }
  }

  void _startCacheCleanup() {
    Timer.periodic(const Duration(hours: 24), (timer) async {
      await _manageCacheSize();
    });
  }

  // Sleep timer methods
  bool get isSleepTimerActive => _sleepTimer?.isActive ?? false;

  Duration? get sleepTimerDuration => sleepTimerDurationNotifier.value;

    void startSleepTimer(Duration duration) {
    cancelSleepTimer();
    sleepTimerDurationNotifier.value = duration;
    _sleepTimer = Timer(duration, () {
      stop();
      sleepTimerDurationNotifier.value = null;
    });
  }

  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    sleepTimerDurationNotifier.value = null;
  }

  @override
  void dispose() {
    _notifyDebounceTimer?.cancel();
    _saveDebounceTimer?.cancel();

    currentSongNotifier.dispose();
    isPlayingNotifier.dispose();
    isShuffleNotifier.dispose();
    loopModeNotifier.dispose();
    sleepTimerDurationNotifier.dispose();
    playlistsNotifier.dispose();
    songsNotifier.dispose();
    currentArtwork.dispose();

    _audioPlayer.dispose();

    if (_playcountsDirty) _savePlayCounts();
    if (_playlistsDirty) savePlaylists();

    saveQueueState();

    _currentSongController.close();
    _errorController.close();
    _sleepTimer?.cancel();
    super.dispose();
  }
}
