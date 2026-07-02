import 'dart:async';
import 'dart:math' show Random, cos, sin, pi;
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
import 'folder_filter_service.dart';
import 'smart_suggestions_service.dart';
import 'audio/replay_gain_reader.dart';
import 'playlist_m3u_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../main.dart' show audioHandler;

part 'audio/playback_controller.dart';
part 'audio/queue_manager.dart';
part 'audio/library_manager.dart';
part 'audio/play_counts.dart';
part 'audio/media_artwork.dart';
part 'audio/queue_persistence.dart';
part 'audio/settings_manager.dart';
part 'audio/playlist_m3u_sync.dart';
part 'audio/crossfade_controller.dart';

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

  /// Number of songs immediately after [_currentIndex] that were explicitly
  /// added to the queue via [addToQueue] or [playNext]. These are displayed
  /// separately from the "source" (album/playlist) continuation songs.
  int _queueCount = 0;
  bool _isPlaying = false;
  bool _isShuffle = false;
  LoopMode _loopMode = LoopMode.off; // Changed from bool to LoopMode
  bool _isLoading = false;
  bool _isSettingPlaylist =
      false; // Guard against currentIndexStream race condition
  Set<String> _librarySet = {};

  // ── Real listen-time tracking ──────────────────────────────────────────────
  // Tracks how far into the *current* song the user has actually listened, so
  // that when the song is switched/stopped we record the real listened time
  // (e.g. stopped at 1:25 → 85000ms) rather than the song's full length.
  String? _currentListenTrackId;
  int _currentListenMaxPositionMs = 0;

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
    final end =
        (_currentIndex + 1 + _queueCount).clamp(start, _playlist.length);
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

  void _addError(String msg) {
    if (!_errorController.isClosed) _errorController.add(msg);
  }

  // Sleep timer
  Timer? _sleepTimer;

  Set<String> _likedSongs = {};
  late Playlist? _likedSongsPlaylist;

  List<SongModel> _songs = [];
  List<SongModel> get songs => _songs;

  bool _libraryInitialized = false;
  Future<bool>? _libraryInitializationFuture;
  bool get isLibraryInitialized => _libraryInitialized;

  /// Unfiltered song list from MediaStore.  Kept so we can instantly
  /// re-filter when folder exclusions change, without a fresh MediaStore query.
  List<SongModel> _rawSongs = [];

  /// Update songs list and notify listeners efficiently
  void _updateSongs(List<SongModel> newSongs) {
    debugPrint(
        '🎵 [LIBRARY] Song library updated: ${newSongs.length} songs total');
    _songs = newSongs;
    songsNotifier.value = newSongs;
  }

  static const String likedSongsPlaylistId = 'liked_songs';
  String _likedPlaylistName = 'Favorite Songs'; // Default English name

  // New settings properties
  bool _gaplessPlayback = true;
  bool _volumeNormalization = false;
  double _playbackSpeed = 1.0;

  /// When true, pitch shifts with speed (chipmunk effect).
  /// When false, pitch is locked to 1.0 regardless of speed.
  bool _pitchWithSpeed = false;
  String _defaultSortOrder = 'title';
  int _cacheSize = 100; // in MB
  bool _mediaControls = true;

  // ── True timed crossfade (see audio/crossfade_controller.dart) ───────────
  bool _crossfadeEnabled = false;
  int _crossfadeDurationMs = 6000; // 1000-12000ms, user-configurable
  bool _crossfading = false;
  AudioPlayer? _standbyPlayer;
  Timer? _crossfadeRampTimer;
  StreamSubscription<Duration>? _crossfadeWatchSub;
  AudioPipeline Function()? _crossfadePipelineFactory;

  // Settings getters
  bool get gaplessPlayback => _gaplessPlayback;
  bool get volumeNormalization => _volumeNormalization;
  double get playbackSpeed => _playbackSpeed;
  bool get pitchWithSpeed => _pitchWithSpeed;
  String get defaultSortOrder => _defaultSortOrder;
  int get cacheSize => _cacheSize;
  bool get mediaControls => _mediaControls;
  bool get crossfadeEnabled => _crossfadeEnabled;
  int get crossfadeDurationMs => _crossfadeDurationMs;
  Duration get crossfadeDuration => Duration(milliseconds: _crossfadeDurationMs);

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
        usage: AndroidAudioUsage.media,
      ),
      androidWillPauseWhenDucked: true,
    ));

    await _loadPlayCounts();
    await _loadPlaylists();

    // Initialize home screen widget
    unawaited(_homeWidgetService.initialize());

    // Listen to song changes to update home screen widget
    currentSongNotifier.addListener(_onSongChangedForWidget);
    isPlayingNotifier.addListener(_onPlayStateChangedForWidget);

    // Apply volume normalization whenever the current song changes
    currentSongNotifier.addListener(() {
      if (_volumeNormalization) {
        unawaited(_applyNormalizationForCurrentSong());
      }
    });

    _bindCorePlayerListeners();

    _startCacheCleanup();


    // Restore the queue from the previous session (non-blocking).
    unawaited(loadQueueState());

    // Re-filter the library immediately whenever the user changes folder
    // exclusions, so search and playlists update without a manual refresh.
    FolderFilterService().addListener(_onFolderFilterChanged);

    // Wire Android Auto browse-tree callbacks into the audio handler.
    // Closures are evaluated lazily so they always reflect the current state.
    audioHandler.attachAndroidAutoCallbacks(
      getSongs: () => _songs,
      getPlaylists: () => _playlists,
      getIsShuffle: () => _isShuffle,
      getLoopMode: () => _loopMode,
      playSongs: (songs, index) => setPlaylist(songs, index),
      resume: resume,
      toggleShuffle: toggleShuffle,
      toggleRepeat: toggleRepeat,
    );

    // Start the crossfade engine's position watcher (no-op while disabled).
    _initCrossfadeEngine();
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

  StreamSubscription<PlayerState>? _playerStateSub;
  StreamSubscription<Duration>? _maxPositionSub;
  StreamSubscription<bool>? _playingSub;
  StreamSubscription<int?>? _currentIndexSub;
  StreamSubscription<ProcessingState>? _processingStateSub;

  /// Binds the 5 core `_audioPlayer`-scoped listeners that drive playback
  /// bookkeeping (play/pause state, listened-time tracking, gapless index
  /// advancement, and end-of-queue handling).
  ///
  /// Extracted from [_init] so it can be re-run whenever the active player
  /// instance changes — currently only done by the crossfade engine
  /// (audio/crossfade_controller.dart) after handing off playback from an
  /// outgoing player to a newly-swapped-in standby player in non-gapless
  /// crossfade mode. Without re-binding, these listeners would remain
  /// attached to the disposed outgoing player and silently stop firing.
  void _bindCorePlayerListeners() {
    _playerStateSub?.cancel();
    _maxPositionSub?.cancel();
    _playingSub?.cancel();
    _currentIndexSub?.cancel();
    _processingStateSub?.cancel();

    _playerStateSub = _audioPlayer.playerStateStream.listen((playerState) {
      _isPlaying = playerState.playing;
      isPlayingNotifier.value = _isPlaying;
      // ValueNotifier handles most UI updates, use debounced notify for other listeners
      _scheduleNotify();
    });

    // Track the furthest position reached in the current song so that the real
    // listened time can be recorded when the song is switched/stopped. Using
    // the max position keeps the outgoing song's value intact even after the
    // position stream resets to ~0 for the next track.
    _maxPositionSub = _audioPlayer.positionStream.listen((position) {
      final ms = position.inMilliseconds;
      if (ms > _currentListenMaxPositionMs) {
        _currentListenMaxPositionMs = ms;
      }
    });

    // Also listen to playingStream specifically - this is more reliable for
    // catching play/pause changes from external sources like lock screen controls
    _playingSub = _audioPlayer.playingStream.listen((playing) {
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
    _currentIndexSub = _audioPlayer.currentIndexStream.listen((index) async {
      // Drop duplicate events up-front: just_audio re-emits the current index
      // on many player state changes, which previously triggered redundant
      // logging, notification and widget churn on every emission.
      if (index == null || index == _currentIndex) return;
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
      if (index < _playlist.length) {
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
        // Persist the new index so a restart always restores the correct song.
        unawaited(saveQueueState());
      }
    });

    // Listen for when playback completes (end of playlist with no loop)
    _processingStateSub = _audioPlayer.processingStateStream.listen((state) {
      debugPrint(
          '🎵 [PROCESSING_STATE] State changed: $state (loopMode: $_loopMode)');
      if (state == ProcessingState.completed) {
        debugPrint('🎵 [PROCESSING_STATE] Playback completed!');
        if (_loopMode == LoopMode.off) {
          if (!_gaplessPlayback && _currentIndex + 1 < _playlist.length) {
            // Non-gapless mode: each individual song triggers completed.
            // Advance to the next song rather than stopping.
            debugPrint(
                '🎵 [PROCESSING_STATE] Non-gapless: advancing to next song '
                '(${_currentIndex + 1} / ${_playlist.length - 1})');
            unawaited(play(index: _currentIndex + 1));
          } else {
            // Gapless (playlist truly finished) or non-gapless at last song.
            debugPrint('🎵 [PROCESSING_STATE] Loop OFF, stopping playback');
            // The current song played to its end — commit its real listened time.
            _finalizeListenTime();
            _isPlaying = false;
            isPlayingNotifier.value = false;
            // Pause the underlying player so player.playing becomes false.
            // This causes _broadcastState() to fire with playing:false, which
            // clears the "playing" indicator in the notification / media controls.
            unawaited(_audioPlayer.pause());
            _scheduleNotify();
          }
        } else {
          debugPrint(
              '🎵 [PROCESSING_STATE] Loop mode: $_loopMode, should loop automatically');
        }
      }
    });
  }

  void _startCacheCleanup() {
    Timer.periodic(const Duration(hours: 24), (timer) async {
      await _manageCacheSize();
    });
  }

  /// Called when the current song changes — pushes info to the home screen widget.
  /// Kept as a class method (not an extension) so the tearoff is stable for
  /// addListener / removeListener.
  /// Commit the real listened time for the song currently being tracked, then
  /// re-arm the tracker. Called when the playing song changes or playback
  /// stops. Pass [nextTrackId] when a new song is starting (use null when
  /// playback is just stopping) so the next song is counted separately.
  void _finalizeListenTime({String? nextTrackId}) {
    final outgoingId = _currentListenTrackId;
    if (outgoingId != null) {
      _smartSuggestions.recordListenDuration(
          outgoingId, _currentListenMaxPositionMs);
    }
    _currentListenTrackId = nextTrackId;
    _currentListenMaxPositionMs = 0;
  }

  void _onSongChangedForWidget() {
    final song = currentSongNotifier.value;
    if (song != null) {
      _homeWidgetService.updateSongInfo(
        title: song.title,
        artist: song.artist ?? 'Unknown Artist',
        isPlaying: isPlayingNotifier.value,
        songId: song.id,
        artworkBytes: currentArtwork.value,
        source: _playbackSource.name != null
            ? 'Playing from ${_playbackSource.name}'
            : 'Aurora Music',
        currentPosition: _audioPlayer.position,
        totalDuration: _audioPlayer.duration ?? Duration.zero,
      );
      _homeWidgetService.updateQueue(upcomingQueue.take(6).toList());
      if (isPlayingNotifier.value) {
        _homeWidgetService.startProgressUpdates(
          getCurrentPosition: () => _audioPlayer.position,
          getTotalDuration: () => _audioPlayer.duration ?? Duration.zero,
        );
      }
    } else {
      _homeWidgetService.clearWidget();
    }
  }

  /// Called when play/pause state changes — updates the widget icon.
  /// Kept as a class method (not an extension) so the tearoff is stable for
  /// addListener / removeListener.
  void _onPlayStateChangedForWidget() {
    _homeWidgetService.updatePlayingState(isPlayingNotifier.value);
    if (isPlayingNotifier.value) {
      _homeWidgetService.startProgressUpdates(
        getCurrentPosition: () => _audioPlayer.position,
        getTotalDuration: () => _audioPlayer.duration ?? Duration.zero,
      );
    } else {
      _homeWidgetService.stopProgressUpdates();
    }
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
      stop();
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

  /// Called whenever [FolderFilterService] exclusions change.
  /// Re-filters [_rawSongs] immediately without a new MediaStore query.
  void _onFolderFilterChanged() {
    if (_rawSongs.isEmpty) return;
    final filterService = FolderFilterService();
    final filtered = filterService.filterSongs(_rawSongs);
    _updateSongs(filtered);
    // Remove excluded songs from user-created playlists and persist.
    _filterExcludedSongsFromPlaylists(filterService.excludedFolders);
    // Rebuild the liked-songs playlist from the updated filtered list.
    final likedSongs =
        filtered.where((s) => _likedSongs.contains(s.id.toString())).toList();
    _likedSongsPlaylist = Playlist(
      id: likedSongsPlaylistId,
      name: _likedPlaylistName,
      songs: likedSongs,
    );
    // Clear smart-suggestions cache so next refresh excludes filtered folders.
    _smartSuggestions.invalidateSuggestionCache();
    // Regenerate auto playlists (Most Played, Recently Added) from the updated
    // filtered songs list so they no longer contain excluded tracks.
    _updateAutoPlaylists();
    _scheduleNotify();
  }

  @override
  void dispose() {
    FolderFilterService().removeListener(_onFolderFilterChanged);
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

    // Save any pending data before the audio player is disposed — saveQueueState
    // reads _audioPlayer.position, so it must run before _audioPlayer.dispose().
    if (_playcountsDirty) {
      _savePlayCounts();
    }
    if (_playlistsDirty) {
      savePlaylists();
    }

    // Best-effort: persist the final playback position before the player dies.
    // (The current-song index was already saved on every auto-advance / manual play.)
    saveQueueState();

    _crossfadeWatchSub?.cancel();
    _crossfadeRampTimer?.cancel();
    _standbyPlayer?.dispose();

    _audioPlayer.dispose();

    // Clean up widget listeners and service
    currentSongNotifier.removeListener(_onSongChangedForWidget);
    isPlayingNotifier.removeListener(_onPlayStateChangedForWidget);
    _homeWidgetService.dispose();

    _currentSongController.close();
    _errorController.close();
    _sleepTimer?.cancel();
    super.dispose();
  }
}
