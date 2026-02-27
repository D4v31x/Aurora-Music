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
      id: LIKED_SONGS_PLAYLIST_ID,
      name: _likedPlaylistName,
      songs: [],
    );

    // Don't do any audio query operations in the constructor
    // All media access will be explicit and user-initiated
  }

  // Check permissions safely without crashing the app
  Future<bool> _checkPermissionStatus() async {
    try {
      return await _audioQuery.permissionsStatus();
    } catch (e) {
      debugPrint('Permission check error: $e');
      return false;
    }
  }

  // Scan common music directories to update MediaStore with new files
  Future<void> _scanMusicDirectories() async {
    try {
      // Common music directories on Android
      final musicPaths = [
        '/storage/emulated/0/Music',
        '/storage/emulated/0/Download',
        '/storage/emulated/0/Downloads',
        '/storage/emulated/0/DCIM',
        '/storage/emulated/0/Podcasts',
        '/storage/emulated/0/Ringtones',
        '/storage/emulated/0/Notifications',
        '/storage/emulated/0/Alarms',
        '/sdcard/Music',
        '/sdcard/Download',
        '/sdcard/Downloads',
      ];

      debugPrint('Scanning music directories for new files...');
      int scannedCount = 0;

      for (final basePath in musicPaths) {
        final dir = Directory(basePath);
        if (await dir.exists()) {
          try {
            await for (final entity
                in dir.list(recursive: true, followLinks: false)) {
              if (entity is File) {
                final path = entity.path.toLowerCase();
                // Check for common audio file extensions
                if (path.endsWith('.mp3') ||
                    path.endsWith('.m4a') ||
                    path.endsWith('.flac') ||
                    path.endsWith('.wav') ||
                    path.endsWith('.aac') ||
                    path.endsWith('.ogg') ||
                    path.endsWith('.wma') ||
                    path.endsWith('.opus')) {
                  await _audioQuery.scanMedia(entity.path);
                  scannedCount++;
                }
              }
            }
          } catch (e) {
            debugPrint('Error scanning $basePath: $e');
          }
        }
      }

      debugPrint('Scanned $scannedCount audio files');

      // Give MediaStore a moment to process the scanned files
      await Future.delayed(const Duration(milliseconds: 500));
    } catch (e) {
      debugPrint('Error scanning music directories: $e');
    }
  }

  // Public method to initialize music library - should be called only from HomeScreen
  Future<bool> initializeMusicLibrary({bool forceRescan = false}) async {
    try {
      final hasPermissions = await _checkPermissionStatus();

      if (!hasPermissions) {
        debugPrint('No permissions yet - library remains empty');
        return false;
      }

      // Only load from cache if not forcing a rescan
      if (!forceRescan) {
        await loadLibrary();
      } else {
        // Clear the library set to force fresh query
        _librarySet.clear();
        debugPrint('Force rescan: cleared library cache');

        // Scan common music directories to update MediaStore
        await _scanMusicDirectories();
      }

      // Try to load songs - always query fresh from MediaStore
      try {
        // Query with proper parameters to get all songs from external storage
        final songs = await _audioQuery.querySongs(
          orderType: OrderType.ASC_OR_SMALLER,
          uriType: UriType.EXTERNAL,
          ignoreCase: true,
        );
        debugPrint('Queried ${songs.length} songs from storage');
        _updateSongs(songs);

        // Save the updated library
        if (forceRescan) {
          await saveLibrary();
        }

        // Initialize the liked songs playlist
        await loadLikedSongs();
        final likedSongs = songs
            .where((song) => _likedSongs.contains(song.id.toString()))
            .toList();

        _likedSongsPlaylist = Playlist(
          id: LIKED_SONGS_PLAYLIST_ID,
          name: _likedPlaylistName,
          songs: likedSongs,
        );

        // Update auto playlists (Most Played, Recently Added)
        _updateAutoPlaylists();

        notifyListeners();
        return true;
      } catch (e) {
        debugPrint('Error loading songs: $e');
        return false;
      }
    } catch (e) {
      debugPrint('Error initializing music library: $e');
      return false;
    }
  }

  // Public method to request permissions from UI
  Future<bool> requestPermissions() async {
    try {
      final permissionStatus = await _audioQuery.permissionsStatus();

      if (!permissionStatus) {
        // Only request if needed
        final granted = await _audioQuery.permissionsRequest();

        // If permissions were just granted, initialize the library
        if (granted) {
          await Future.delayed(const Duration(milliseconds: 500));
          await initializeMusicLibrary();
        }

        return granted;
      }

      return permissionStatus;
    } catch (e) {
      debugPrint('Permission request error: $e');
      return false;
    }
  }

  /// Set the background manager service for updating mesh gradient colors
  void setBackgroundManager(BackgroundManagerService backgroundManager) {
    _backgroundManager = backgroundManager;
  }

  /// Update background colors based on current song
  Future<void> _updateBackgroundColors() async {
    if (_backgroundManager != null && currentSong != null) {
      if (kDebugMode) {
        debugPrint(
            '🎨 [BG_SYNC] Request background update for song: "${currentSong!.title}" (id: ${currentSong!.id})');
      }
      await _backgroundManager!.updateColorsFromSong(currentSong);
      if (kDebugMode) {
        debugPrint(
            '🎨 [BG_SYNC] Background update call completed for song id: ${currentSong!.id}');
      }
    }
  }

  // Cache for artwork file URIs to avoid redundant disk I/O
  final Map<int, Uri?> _artworkUriCache = {};

  /// Get artwork URI for media notification
  /// Saves artwork to a temp file and returns the file URI.
  /// Results are cached to avoid redundant disk writes.
  Future<Uri?> _getArtworkUri(int songId) async {
    // Return cached URI if available
    if (_artworkUriCache.containsKey(songId)) {
      return _artworkUriCache[songId];
    }
    try {
      final artwork = await _artworkCache.getArtwork(songId);
      if (artwork == null || artwork.isEmpty) {
        _artworkUriCache[songId] = null;
        return null;
      }

      final tempDir = await getTemporaryDirectory();
      final artworkFile = File('${tempDir.path}/notification_art_$songId.jpg');

      // Only write if file doesn't already exist
      if (!await artworkFile.exists()) {
        await artworkFile.writeAsBytes(artwork);
      }

      final uri = Uri.parse('file://${artworkFile.path}');
      _artworkUriCache[songId] = uri;
      return uri;
    } catch (e) {
      debugPrint('Error getting artwork URI: $e');
      _artworkUriCache[songId] = null;
      return null;
    }
  }

  /// Create a lightweight MediaItem WITHOUT artwork (instant, no I/O)
  MediaItem _createMediaItemSync(SongModel song) {
    return MediaItem(
      id: song.id.toString(),
      album: song.album ?? 'Unknown Album',
      title: song.title,
      artist: splitArtists(song.artist ?? 'Unknown Artist').join(', '),
      duration: Duration(milliseconds: song.duration ?? 0),
    );
  }

  /// Create MediaItem with artwork for a song (async, involves I/O)
  Future<MediaItem> _createMediaItem(SongModel song) async {
    final artUri = await _getArtworkUri(song.id);
    return MediaItem(
      id: song.id.toString(),
      album: song.album ?? 'Unknown Album',
      title: song.title,
      artist: splitArtists(song.artist ?? 'Unknown Artist').join(', '),
      duration: Duration(milliseconds: song.duration ?? 0),
      artUri: artUri,
    );
  }

  /// Load artwork for remaining songs in background and update notification queue
  Future<void> _loadRemainingArtworkInBackground(List<SongModel> songs) async {
    try {
      // Process in small batches to avoid blocking
      const batchSize = 5;
      for (var i = 0; i < songs.length; i += batchSize) {
        final end = (i + batchSize).clamp(0, songs.length);
        final batch = songs.sublist(i, end);
        await Future.wait(batch.map((song) => _getArtworkUri(song.id)));
      }

      // Update notification queue with full artwork after loading
      if (_playlist.isNotEmpty && _currentIndex >= 0) {
        final mediaItems = await Future.wait(
          _playlist.map((song) => _createMediaItem(song)),
        );
        audioHandler.updateNotificationQueue(mediaItems);
        // Update current item's notification with artwork
        if (_currentIndex < mediaItems.length) {
          audioHandler.updateNotificationMediaItem(mediaItems[_currentIndex]);
        }
      }
    } catch (e) {
      debugPrint('Error loading background artwork: $e');
    }
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

    await _loadPlayCounts();
    await _loadPlaylists();

    // Initialize home screen widget
    unawaited(_homeWidgetService.initialize());

    // Listen to song changes to update home screen widget
    currentSongNotifier.addListener(_onSongChangedForWidget);
    isPlayingNotifier.addListener(_onPlayStateChangedForWidget);

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

  void _startCacheCleanup() {
    Timer.periodic(const Duration(hours: 24), (timer) async {
      await _manageCacheSize();
    });
  }

  // Playlist Management
  Future<void> _loadPlaylists() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/playlists.json');

    if (await file.exists()) {
      final contents = await file.readAsString();
      final json = jsonDecode(contents) as List;
      _playlists = json
          .map((playlistJson) => Playlist(
                id: playlistJson['id'],
                name: playlistJson['name'],
                songs: (playlistJson['songs'] as List)
                    .map((songJson) => SongModel(songJson))
                    .toList(),
              ))
          .toList();
    }
  }

  Future<void> savePlaylists() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/playlists.json');

    final json = _playlists
        .map((playlist) => {
              'id': playlist.id,
              'name': playlist.name,
              'songs': playlist.songs.map((song) => song.getMap).toList(),
            })
        .toList();

    await file.writeAsString(jsonEncode(json));
    // Update the notifier for reactive widgets
    playlistsNotifier.value = List.from(_playlists);
  }

  void createPlaylist(String name, List<SongModel> songs) {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final newPlaylist = Playlist(id: id, name: name, songs: songs);
    _playlists.add(newPlaylist);
    _playlistsDirty = true;
    _scheduleSavePlayCounts(); // Will also save playlists
    _scheduleNotify();
  }

  void addSongToPlaylist(String playlistId, SongModel song) {
    final playlist = _playlists.firstWhere((p) => p.id == playlistId);
    if (!playlist.songs.contains(song)) {
      playlist.songs.add(song);
      _playlistsDirty = true;
      _scheduleSavePlayCounts();
      _scheduleNotify();
    }
  }

  void removeSongFromPlaylist(String playlistId, SongModel song) {
    if (playlistId == 'liked_songs') {
      _likedSongs.remove(song.id.toString());
      saveLikedSongs();
      _updateLikedSongsPlaylist();
    } else {
      final playlist = _playlists.firstWhere((p) => p.id == playlistId);
      playlist.songs.remove(song);
      _playlistsDirty = true;
      _scheduleSavePlayCounts();
    }
    _scheduleNotify();
  }

  void deletePlaylist(Playlist playlist) {
    _playlists.remove(playlist);
    _playlistsDirty = true;
    _scheduleSavePlayCounts();
    _scheduleNotify();
  }

  void renamePlaylist(String playlistId, String newName) {
    final playlistIndex = _playlists.indexWhere((p) => p.id == playlistId);
    if (playlistIndex != -1) {
      _playlists[playlistIndex] =
          _playlists[playlistIndex].copyWith(name: newName);
      _playlistsDirty = true;
      _scheduleSavePlayCounts();
      _scheduleNotify();
    }
  }

  void addSongsToPlaylist(String playlistId, List<SongModel> songs) {
    if (playlistId == 'liked_songs') {
      for (final song in songs) {
        if (!_likedSongs.contains(song.id.toString())) {
          _likedSongs.add(song.id.toString());
        }
      }
      saveLikedSongs();
      _updateLikedSongsPlaylist();
    } else {
      final playlist = _playlists.firstWhere((p) => p.id == playlistId);
      for (final song in songs) {
        if (!playlist.songs.contains(song)) {
          playlist.songs.add(song);
        }
      }
      _playlistsDirty = true;
      _scheduleSavePlayCounts();
    }
    _scheduleNotify();
  }

  Future<void> _loadPlayCounts() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/play_counts.json');

    if (await file.exists()) {
      final contents = await file.readAsString();
      final json = jsonDecode(contents);

      _trackPlayCounts = Map<String, int>.from(json['tracks']);
      _albumPlayCounts = Map<String, int>.from(json['albums']);
      _artistPlayCounts = Map<String, int>.from(json['artists']);
      _playlistPlayCounts = Map<String, int>.from(json['playlists']);
      _folderAccessCounts = Map<String, int>.from(json['folders']);
    }
  }

  Future<void> _savePlayCounts() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/play_counts.json');

    final json = {
      'tracks': _trackPlayCounts,
      'albums': _albumPlayCounts,
      'artists': _artistPlayCounts,
      'playlists': _playlistPlayCounts,
      'folders': _folderAccessCounts,
    };

    await file.writeAsString(jsonEncode(json));
  }

  void _incrementPlayCount(SongModel song) {
    _trackPlayCounts[song.id.toString()] =
        (_trackPlayCounts[song.id.toString()] ?? 0) + 1;

    if (song.albumId != null) {
      _albumPlayCounts[song.albumId.toString()] =
          (_albumPlayCounts[song.albumId.toString()] ?? 0) + 1;
    }

    if (song.artistId != null) {
      final artistNames = splitArtists(song.artist ?? '');
      for (final artist in artistNames) {
        _artistPlayCounts[artist] = (_artistPlayCounts[artist] ?? 0) + 1;
      }
    }

    final folder = File(song.data).parent.path;
    _folderAccessCounts[folder] = (_folderAccessCounts[folder] ?? 0) + 1;

    if (song.artist != null) {
      final artistNames = splitArtists(song.artist!);
      for (final artist in artistNames) {
        _artistPlayCounts[artist] = (_artistPlayCounts[artist] ?? 0) + 1;
      }
    }

    // Record to smart suggestions service for personalized recommendations
    _smartSuggestions.recordPlay(song);

    // Use debounced save to reduce disk I/O
    _scheduleSavePlayCounts();
  }

  /// Get smart suggested tracks based on listening patterns and time of day
  Future<List<SongModel>> getSuggestedTracks({int count = 3}) async {
    await _smartSuggestions.initialize();
    return _smartSuggestions.getSuggestedTracks(count: count);
  }

  /// Get smart suggested artists based on listening patterns and time of day
  Future<List<String>> getSuggestedArtists({int count = 3}) async {
    await _smartSuggestions.initialize();
    return _smartSuggestions.getSuggestedArtists(count: count);
  }

  /// Check if user has enough listening history for smart suggestions
  bool hasListeningHistory() => _smartSuggestions.hasListeningHistory();

  // Most Played Queries
  Future<List<SongModel>> getMostPlayedTracks() async {
    final allSongs = await _audioQuery.querySongs(
      orderType: OrderType.ASC_OR_SMALLER,
      uriType: UriType.EXTERNAL,
      ignoreCase: true,
    );
    final sortedTracks = allSongs
      ..sort((a, b) => (_trackPlayCounts[b.id.toString()] ?? 0)
          .compareTo(_trackPlayCounts[a.id.toString()] ?? 0));
    return sortedTracks.take(10).toList();
  }

  Future<List<AlbumModel>> getMostPlayedAlbums() async {
    final albums = await _audioQuery.queryAlbums();
    albums.sort((a, b) => (_albumPlayCounts[b.id.toString()] ?? 0)
        .compareTo(_albumPlayCounts[a.id.toString()] ?? 0));
    return albums.take(10).toList();
  }

  Future<List<ArtistModel>> getMostPlayedArtists() async {
    final allArtists = await _audioQuery.queryArtists();
    final artistPlayCounts = <String, int>{};

    for (final artist in allArtists) {
      final artistNames = splitArtists(artist.artist);
      for (final name in artistNames) {
        artistPlayCounts[name] = (_artistPlayCounts[name] ?? 0);
      }
    }

    final sortedArtists = allArtists
      ..sort((a, b) => (artistPlayCounts[b.artist] ?? 0)
          .compareTo(artistPlayCounts[a.artist] ?? 0));

    return sortedArtists.take(10).toList();
  }

  List<Playlist> getThreePlaylists() {
    final sortedPlaylists = _playlists.toList()
      ..sort((a, b) => (_playlistPlayCounts[b.id] ?? 0)
          .compareTo(_playlistPlayCounts[a.id] ?? 0));
    return sortedPlaylists.take(3).toList();
  }

  List<String> getThreeFolders() {
    final folderAccessCounts = _folderAccessCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return folderAccessCounts.take(3).map((entry) => entry.key).toList();
  }

  // Playback Control
  Future<void> setPlaylist(
    List<SongModel> songs,
    int startIndex, {
    PlaybackSourceInfo? source,
  }) async {
    // Update playback source
    _playbackSource = source ?? PlaybackSourceInfo.unknown;

    try {
      if (songs.isEmpty || startIndex < 0 || startIndex >= songs.length) {
        debugPrint('Invalid playlist or start index');
        _errorController.add('Invalid playlist or start index');
        return;
      }

      // Reset loading flag when setting a new playlist
      _isLoading = false;

      _playlist = songs;
      _currentIndex = startIndex;

      // When shuffle is active, the new queue must also be shuffled.
      // Reset _originalPlaylist to the freshly loaded songs, then shuffle.
      if (_isShuffle) {
        _originalPlaylist = List<SongModel>.from(_playlist);
        final current = _playlist[_currentIndex];
        final rest = List<SongModel>.from(_playlist)..removeAt(_currentIndex);
        rest.shuffle(Random());
        _playlist = [current, ...rest];
        _currentIndex = 0;
      } else {
        _originalPlaylist = [];
      }

      _isSettingPlaylist = true; // Guard against currentIndexStream race

      debugPrint(
          'Setting playlist with ${songs.length} songs, starting at index $startIndex');

      if (_gaplessPlayback) {
        try {
          // Create lightweight MediaItems WITHOUT artwork for instant startup
          final lightMediaItems =
              _playlist.map((song) => _createMediaItemSync(song)).toList();

          // Only fetch artwork for the starting song (fast, usually cached)
          final startSong = _playlist[_currentIndex];
          final startMediaItem = await _createMediaItem(startSong);
          lightMediaItems[_currentIndex] = startMediaItem;

          // Update audio handler queue for notification
          audioHandler.updateNotificationQueue(lightMediaItems);

          final playlistSource = ConcatenatingAudioSource(
            children: _playlist.asMap().entries.map((entry) {
              final song = entry.value;
              final mediaItem = lightMediaItems[entry.key];
              final uri = song.uri ?? song.data;
              return AudioSource.uri(
                Uri.parse(uri),
                tag: mediaItem,
              );
            }).toList(),
          );

          // Suppress automatic mediaItem updates during source setup
          // to prevent intermediate index 0 from overriding the correct item
          audioHandler.suppressIndexUpdates();

          await _audioPlayer.setAudioSource(
            playlistSource,
            initialIndex: _currentIndex,
            initialPosition: Duration.zero,
          );

          // Apply current shuffle and loop settings to the player.
          // We manage shuffle ordering ourselves by reordering _playlist, so
          // just_audio's internal shuffle mode is always kept off.
          debugPrint(
              '🎵 [AUDIO_SOURCE] Applying loopMode: $_loopMode (shuffle managed in _playlist)');
          await _audioPlayer.setShuffleModeEnabled(false);
          await _audioPlayer.setLoopMode(_loopMode);

          // Resume automatic mediaItem updates
          audioHandler.resumeIndexUpdates();

          await _audioPlayer.play();

          // Sync _currentIndex with the player's actual index to prevent
          // stale currentIndexStream events from overriding it after the
          // guard is released.
          final actualIndex = _audioPlayer.currentIndex ?? _currentIndex;
          if (actualIndex >= 0 && actualIndex < _playlist.length) {
            _currentIndex = actualIndex;
          }

          // Update current media item in notification (after index sync)
          audioHandler.updateNotificationMediaItem(startMediaItem);

          // Batch all state updates
          _isPlaying = true;
          isPlayingNotifier.value = true;
          _incrementPlayCount(_playlist[_currentIndex]);
          _currentSongController.add(_playlist[_currentIndex]);
          currentSongNotifier.value = _playlist[_currentIndex];

          // Fire and forget UI updates
          unawaited(updateCurrentArtwork());
          unawaited(_updateBackgroundColors());

          // Load remaining artwork in background (non-blocking)
          unawaited(_loadRemainingArtworkInBackground(_playlist));

          // Release guard AFTER all state is consistent — this prevents
          // stale currentIndexStream events from overriding _currentIndex
          _isSettingPlaylist = false;

          // Single debounced notification
          _scheduleNotify();
          unawaited(saveQueueState());
        } catch (e) {
          _isSettingPlaylist = false; // Release guard on error
          audioHandler.resumeIndexUpdates(); // Resume notification updates
          // "Loading interrupted" is expected when rapidly changing songs - don't treat as error
          if (e.toString().contains('Loading interrupted')) {
            debugPrint('Audio load interrupted (new song selected)');
            return;
          }
          debugPrint('Error setting audio source: $e');
          _isPlaying = false;
          isPlayingNotifier.value = false;
          _scheduleNotify();
          rethrow;
        }
      } else {
        // For non-gapless playback, keep the guard active during play()
        // because play() calls setAudioSource for a single song which resets
        // the player's currentIndex to 0, but _currentIndex refers to the
        // position in the full _playlist.
        try {
          await play();
        } finally {
          _isSettingPlaylist = false;
        }
      }
    } catch (e) {
      _isSettingPlaylist = false; // Release guard on error
      audioHandler.resumeIndexUpdates(); // Resume notification updates
      // "Loading interrupted" is expected when rapidly changing songs - don't treat as error
      if (e.toString().contains('Loading interrupted')) {
        debugPrint('Audio load interrupted (new song selected)');
        return;
      }
      debugPrint('Failed to set playlist: $e');
      _errorController.add('Failed to set playlist: $e');
      _isPlaying = false;
      isPlayingNotifier.value = false;
      _isLoading = false;
      _scheduleNotify();
    }
  }

  Future<void> updatePlaylist(List<SongModel> newSongs) async {
    try {
      if (_gaplessPlayback &&
          _audioPlayer.audioSource is ConcatenatingAudioSource) {
        // Use lightweight MediaItems for instant rebuild
        final mediaItems =
            newSongs.map((song) => _createMediaItemSync(song)).toList();

        final newSource = ConcatenatingAudioSource(
          children: newSongs
              .asMap()
              .entries
              .map((entry) => AudioSource.uri(
                    Uri.parse(entry.value.uri ?? entry.value.data),
                    tag: mediaItems[entry.key],
                  ))
              .toList(),
        );

        // Preserve current playback position
        final currentPosition = _audioPlayer.position;
        final currentIndex = _audioPlayer.currentIndex ?? _currentIndex;

        await _audioPlayer.setAudioSource(
          newSource,
          initialIndex: currentIndex,
          initialPosition: currentPosition,
        );

        _playlist = newSongs;
        _currentIndex = currentIndex;

        // Load artwork in background
        unawaited(_loadRemainingArtworkInBackground(newSongs));

        _scheduleNotify();
      } else {
        _playlist = newSongs;
        _currentIndex = 0;
        await setPlaylist(newSongs, 0);
      }
    } catch (e) {
      _errorController.add('Failed to update playlist: $e');
      _scheduleNotify();
    }
  }

  Future<void> play({int? index}) async {
    // If an explicit index is provided (user selected a song), allow it
    // even if a previous load is in progress — the user's intent takes priority.
    if (index != null) {
      _isLoading = false;
    }

    // Prevent concurrent play calls
    if (_isLoading) {
      debugPrint('Already loading, ignoring play request');
      return;
    }

    _isLoading = true;

    try {
      if (index != null) {
        _currentIndex = index;
      }

      debugPrint(
          'Play called with index: $index, current index: $_currentIndex, playlist length: ${_playlist.length}');

      if (_currentIndex >= 0 && _currentIndex < _playlist.length) {
        final song = _playlist[_currentIndex];
        debugPrint('Playing song: ${song.title} by ${song.artist}');

        if (_gaplessPlayback) {
          debugPrint(
              'Using gapless playback, seeking to index: $_currentIndex');
          await _audioPlayer.seek(Duration.zero, index: _currentIndex);
          await _audioPlayer.play();

          // Update notification with current media item
          final mediaItem = await _createMediaItem(song);
          audioHandler.updateNotificationMediaItem(mediaItem);
        } else {
          final url = song.uri ?? song.data;
          debugPrint('Non-gapless playback, loading URL: $url');

          final mediaItem = await _createMediaItem(song);

          // Update notification
          audioHandler.updateNotificationMediaItem(mediaItem);

          // Suppress index stream events during setAudioSource — loading a
          // single song resets the player index to 0, but _currentIndex
          // refers to the position in the full _playlist.
          final wasSettingPlaylist = _isSettingPlaylist;
          _isSettingPlaylist = true;
          audioHandler.suppressIndexUpdates();
          try {
            await _audioPlayer.setAudioSource(
              AudioSource.uri(Uri.parse(url), tag: mediaItem),
            );
          } finally {
            _isSettingPlaylist = wasSettingPlaylist;
            audioHandler.resumeIndexUpdates();
          }
          await _audioPlayer.play();
        }

        // Batch all state updates after playback starts
        _isPlaying = true;
        isPlayingNotifier.value = true;
        _incrementPlayCount(song);
        _currentSongController.add(song);
        currentSongNotifier.value = song;

        // Fire and forget - don't await these UI updates
        unawaited(updateCurrentArtwork());
        unawaited(_updateBackgroundColors());

        // Single notification at the end
        _scheduleNotify();
      } else {
        debugPrint('Invalid index or empty playlist');
      }
    } catch (e, stackTrace) {
      debugPrint('Failed to play song: $e');
      debugPrint('Stack trace: $stackTrace');
      _isPlaying = false;
      isPlayingNotifier.value = false;
      _currentSongController.addError('Failed to play song: $e');
      _scheduleNotify();
    } finally {
      _isLoading = false;
    }
  }

  void setSpotifyPlaylist(List<SpotifySongModel> playlist, int initialIndex) {
    _spotifyPlaylist = playlist;
    _currentSpotifyIndex = initialIndex;
    _setAudioSource();
  }

  void _setAudioSource() {
    if (_spotifyPlaylist.isEmpty) return;

    final playlist = ConcatenatingAudioSource(
      children: _spotifyPlaylist
          .map((song) =>
              AudioSource.uri(Uri.parse(song.uri), tag: song.toMediaItem()))
          .toList(),
    );

    audioPlayer.setAudioSource(playlist, initialIndex: _currentSpotifyIndex);
  }

  Future<void> pause() async {
    await _audioPlayer.pause();
    _isPlaying = false;
    isPlayingNotifier.value = false;
    // No need for notifyListeners - ValueNotifier handles UI updates
  }

  Future<void> resume() async {
    if (_audioPlayer.playing) return;
    await _audioPlayer.play();
    _isPlaying = true;
    isPlayingNotifier.value = true;
    // No need for notifyListeners - ValueNotifier handles UI updates
  }

  Future<void> stop() async {
    await _audioPlayer.stop();
    _isPlaying = false;
    isPlayingNotifier.value = false;
    // No need for notifyListeners - ValueNotifier handles UI updates
  }

  // MARK: - Queue Management

  /// Add a single song to the end of the queue
  Future<void> addToQueue(SongModel song) async {
    if (_playlist.isEmpty) {
      // If no playlist, create one with this song
      await setPlaylist([song], 0);
      return;
    }

    _playlist.add(song);

    if (_gaplessPlayback &&
        _audioPlayer.audioSource is ConcatenatingAudioSource) {
      try {
        final source = _audioPlayer.audioSource as ConcatenatingAudioSource;
        final mediaItem = _createMediaItemSync(song);
        final uri = song.uri ?? song.data;
        await source.add(AudioSource.uri(Uri.parse(uri), tag: mediaItem));

        // Update notification queue with lightweight items
        final mediaItems =
            _playlist.map((s) => _createMediaItemSync(s)).toList();
        audioHandler.updateNotificationQueue(mediaItems);

        // Load artwork in background
        unawaited(_loadRemainingArtworkInBackground(_playlist));
      } catch (e) {
        debugPrint('Error adding song to queue: $e');
      }
    }

    _scheduleNotify();
    unawaited(saveQueueState());
  }

  /// Add multiple songs to the end of the queue
  Future<void> addMultipleToQueue(List<SongModel> songs) async {
    if (songs.isEmpty) return;

    if (_playlist.isEmpty) {
      // If no playlist, create one with these songs
      await setPlaylist(songs, 0);
      return;
    }

    _playlist.addAll(songs);

    if (_gaplessPlayback &&
        _audioPlayer.audioSource is ConcatenatingAudioSource) {
      try {
        final source = _audioPlayer.audioSource as ConcatenatingAudioSource;
        final mediaItems =
            songs.map((song) => _createMediaItemSync(song)).toList();

        for (var i = 0; i < songs.length; i++) {
          final song = songs[i];
          final uri = song.uri ?? song.data;
          await source.add(AudioSource.uri(Uri.parse(uri), tag: mediaItems[i]));
        }

        // Update notification queue with lightweight items
        final allMediaItems =
            _playlist.map((s) => _createMediaItemSync(s)).toList();
        audioHandler.updateNotificationQueue(allMediaItems);

        // Load artwork in background
        unawaited(_loadRemainingArtworkInBackground(_playlist));
      } catch (e) {
        debugPrint('Error adding songs to queue: $e');
      }
    }

    _scheduleNotify();
    unawaited(saveQueueState());
  }

  /// Add a song to play next (right after current song)
  Future<void> playNext(SongModel song) async {
    if (_playlist.isEmpty) {
      await setPlaylist([song], 0);
      return;
    }

    final insertIndex = _currentIndex + 1;
    _playlist.insert(insertIndex, song);

    if (_gaplessPlayback &&
        _audioPlayer.audioSource is ConcatenatingAudioSource) {
      try {
        final source = _audioPlayer.audioSource as ConcatenatingAudioSource;
        final mediaItem = _createMediaItemSync(song);
        final uri = song.uri ?? song.data;
        await source.insert(
            insertIndex, AudioSource.uri(Uri.parse(uri), tag: mediaItem));

        // Update notification queue with lightweight items
        final mediaItems =
            _playlist.map((s) => _createMediaItemSync(s)).toList();
        audioHandler.updateNotificationQueue(mediaItems);

        // Load artwork in background
        unawaited(_loadRemainingArtworkInBackground(_playlist));
      } catch (e) {
        debugPrint('Error inserting song to play next: $e');
      }
    }

    _scheduleNotify();
    unawaited(saveQueueState());
  }

  /// Remove a song from the queue by index.
  /// If the currently playing track is removed, playback skips to the next
  /// available track (or stops when the queue becomes empty).
  Future<void> removeFromQueue(int index) async {
    if (index < 0 || index >= _playlist.length) return;

    if (index == _currentIndex) {
      if (_playlist.length == 1) {
        // Only song — clear the queue and stop.
        await stop();
        _playlist = [];
        _currentIndex = -1;
        _scheduleNotify();
        unawaited(saveQueueState());
        return;
      }
      // Remove from both the in-memory list and the audio source first, then
      // determine which track to play next (calculated after removal so the
      // index arithmetic is always based on the updated list length).
      if (_gaplessPlayback &&
          _audioPlayer.audioSource is ConcatenatingAudioSource) {
        try {
          final source = _audioPlayer.audioSource as ConcatenatingAudioSource;
          // Remove from the audio source before updating _playlist so that the
          // index is still valid for the unmodified source.
          await source.removeAt(index);
        } catch (e) {
          debugPrint(
              'Error removing currently playing song from audio source: $e');
        }
      }
      _playlist.removeAt(index);
      // After removal: play the song now at `index` (the former next song),
      // or the new last song if we removed the end of the queue.
      _currentIndex = index < _playlist.length ? index : _playlist.length - 1;

      if (_gaplessPlayback &&
          _audioPlayer.audioSource is ConcatenatingAudioSource) {
        try {
          await _audioPlayer.seek(Duration.zero, index: _currentIndex);
          if (!_isPlaying) await _audioPlayer.play();
          final mediaItems =
              _playlist.map((s) => _createMediaItemSync(s)).toList();
          audioHandler.updateNotificationQueue(mediaItems);
        } catch (e) {
          debugPrint('Error seeking after removing currently playing song: $e');
        }
      } else {
        await play(index: _currentIndex);
      }

      // Update song notifiers.
      final song = _playlist[_currentIndex];
      _currentSongController.add(song);
      currentSongNotifier.value = song;
      _scheduleNotify();
      unawaited(saveQueueState());
      return;
    }

    _playlist.removeAt(index);

    // Adjust current index if needed
    if (index < _currentIndex) {
      _currentIndex--;
    }

    if (_gaplessPlayback &&
        _audioPlayer.audioSource is ConcatenatingAudioSource) {
      try {
        final source = _audioPlayer.audioSource as ConcatenatingAudioSource;
        await source.removeAt(index);

        // Update notification queue with lightweight items
        final mediaItems =
            _playlist.map((s) => _createMediaItemSync(s)).toList();
        audioHandler.updateNotificationQueue(mediaItems);
      } catch (e) {
        debugPrint('Error removing song from queue: $e');
      }
    }

    _scheduleNotify();
  }

  /// Move a song within the queue
  Future<void> moveInQueue(int oldIndex, int newIndex) async {
    if (oldIndex < 0 || oldIndex >= _playlist.length) return;
    if (newIndex < 0 || newIndex >= _playlist.length) return;
    if (oldIndex == newIndex) return;

    final song = _playlist.removeAt(oldIndex);
    _playlist.insert(newIndex, song);

    // Adjust current index
    if (oldIndex == _currentIndex) {
      _currentIndex = newIndex;
    } else if (oldIndex < _currentIndex && newIndex >= _currentIndex) {
      _currentIndex--;
    } else if (oldIndex > _currentIndex && newIndex <= _currentIndex) {
      _currentIndex++;
    }

    if (_gaplessPlayback &&
        _audioPlayer.audioSource is ConcatenatingAudioSource) {
      try {
        final source = _audioPlayer.audioSource as ConcatenatingAudioSource;
        await source.move(oldIndex, newIndex);

        // Update notification queue with lightweight items
        final mediaItems =
            _playlist.map((s) => _createMediaItemSync(s)).toList();
        audioHandler.updateNotificationQueue(mediaItems);
      } catch (e) {
        debugPrint('Error moving song in queue: $e');
      }
    }

    _scheduleNotify();
  }

  /// Clear the entire queue except the currently playing song
  Future<void> clearQueue() async {
    if (_playlist.isEmpty) return;

    final currentSong = this.currentSong;
    if (currentSong != null) {
      // Keep only the current song
      _playlist = [currentSong];
      _currentIndex = 0;

      if (_gaplessPlayback) {
        try {
          final mediaItem = await _createMediaItem(currentSong);
          final uri = currentSong.uri ?? currentSong.data;
          final position = _audioPlayer.position;

          final newSource = ConcatenatingAudioSource(
            children: [
              AudioSource.uri(Uri.parse(uri), tag: mediaItem),
            ],
          );

          await _audioPlayer.setAudioSource(
            newSource,
            initialIndex: 0,
            initialPosition: position,
          );

          audioHandler.updateNotificationQueue([mediaItem]);
        } catch (e) {
          debugPrint('Error clearing queue: $e');
        }
      }
    } else {
      _playlist = [];
      _currentIndex = -1;
    }

    _scheduleNotify();
  }

  /// Clear upcoming songs only (songs after current)
  Future<void> clearUpcoming() async {
    if (_playlist.isEmpty || _currentIndex >= _playlist.length - 1) return;

    // Remove all songs after current
    _playlist = _playlist.sublist(0, _currentIndex + 1);

    if (_gaplessPlayback &&
        _audioPlayer.audioSource is ConcatenatingAudioSource) {
      try {
        final source = _audioPlayer.audioSource as ConcatenatingAudioSource;
        // Remove from end to avoid index shifting issues
        while (source.length > _currentIndex + 1) {
          await source.removeAt(source.length - 1);
        }

        // Update notification queue with lightweight items
        final mediaItems =
            _playlist.map((s) => _createMediaItemSync(s)).toList();
        audioHandler.updateNotificationQueue(mediaItems);
      } catch (e) {
        debugPrint('Error clearing upcoming queue: $e');
      }
    }

    _scheduleNotify();
  }

  /// Sync the internal playing state with the actual audio player state.
  /// Call this when the app comes back to foreground to ensure UI reflects
  /// any changes made via lock screen or notification controls.
  /// Always forces a UI refresh since stream events may have been missed
  /// while the Flutter engine was paused in the background.
  void syncPlaybackState() {
    final actuallyPlaying = _audioPlayer.playing;
    _isPlaying = actuallyPlaying;
    // Unconditionally assign the value. If it differs, ValueNotifier fires
    // normally. If it is the same, we still call _scheduleNotify() below to
    // refresh any Provider-based consumers that may be stale.
    isPlayingNotifier.value = actuallyPlaying;
    // Force Provider listeners (e.g. Selector, Consumer) to re-evaluate even
    // when ValueNotifier did not fire (value unchanged).
    notifyListeners();
  }

  void skip() async {
    _isLoading = false; // Reset loading flag to allow new song to play

    debugPrint(
        '⏭️ [SKIP] Called - hasNext: ${_audioPlayer.hasNext}, currentIndex: $_currentIndex, shuffle: $_isShuffle, loopMode: $_loopMode');

    if (_loopMode == LoopMode.one) {
      // Repeat ONE: restart the current track.
      debugPrint('⏭️ [SKIP] Repeat ONE — restarting current track');
      await _audioPlayer.seek(Duration.zero);
      return;
    }

    if (_audioPlayer.hasNext) {
      // Normal case: advance to the next track.
      debugPrint('⏭️ [SKIP] Seeking to next track');
      await _audioPlayer.seekToNext();
    } else {
      // Last song in the queue.
      if (_loopMode == LoopMode.all) {
        debugPrint('⏭️ [SKIP] At end of queue, wrapping to start (repeat ALL)');
        await _audioPlayer.seek(Duration.zero, index: 0);
        await _audioPlayer.play();
      } else {
        // Repeat OFF: stop playback.
        debugPrint('⏭️ [SKIP] At end of queue, stopping (repeat OFF)');
        await _audioPlayer.pause();
        await _audioPlayer.seek(Duration.zero);
        _isPlaying = false;
        isPlayingNotifier.value = false;
        _scheduleNotify();
      }
    }
  }

  void back() async {
    _isLoading = false; // Reset loading flag to allow new song to play

    final currentPosition = _audioPlayer.position;

    // If more than 3 seconds have elapsed, restart the current track.
    if (currentPosition > const Duration(seconds: kPreviousThresholdSeconds)) {
      debugPrint(
          '⏮️ [BACK] Past 3s — restarting current song (position: ${currentPosition.inSeconds}s)');
      await _audioPlayer.seek(Duration.zero);
      return;
    }

    // Within 3 seconds: move to the previous track.
    if (_audioPlayer.hasPrevious) {
      debugPrint('⏮️ [BACK] Within 3s and has previous — seeking to previous');
      await _audioPlayer.seekToPrevious();
    } else {
      // At the very first track in the queue.
      if (_loopMode == LoopMode.all && _playlist.isNotEmpty) {
        // Repeat ALL: jump to the last track.
        debugPrint('⏮️ [BACK] At first track, repeat ALL — jumping to last');
        await _audioPlayer.seek(Duration.zero, index: _playlist.length - 1);
      } else {
        // Repeat OFF / ONE at first track: restart.
        debugPrint(
            '⏮️ [BACK] At first track (position: ${currentPosition.inSeconds}s) — restarting');
        await _audioPlayer.seek(Duration.zero);
      }
    }
  }

  void toggleShuffle() {
    _isShuffle = !_isShuffle;
    isShuffleNotifier.value = _isShuffle;
    debugPrint('🔀 [SHUFFLE] Toggled shuffle: $_isShuffle');

    if (_isShuffle) {
      // Save the current order and shuffle the queue in-place, keeping the
      // current track at position 0 so playback is uninterrupted.
      _originalPlaylist = List<SongModel>.from(_playlist);
      _shuffleQueue();
    } else {
      // Restore the original queue order.
      _restoreOriginalQueue();
    }

    // We manage shuffle ourselves — always keep just_audio's internal shuffle
    // mode disabled so the player follows our explicit _playlist order.
    _audioPlayer.setShuffleModeEnabled(false);
    debugPrint(
        '🔀 [SHUFFLE] Queue reordered, playlist length: ${_playlist.length}');
    unawaited(saveQueueState());
    notifyListeners();
  }

  /// Shuffles _playlist in-place, moving the current track to index 0 so that
  /// ongoing playback is preserved and the audio source can be rebuilt with the
  /// same initial index (0).
  void _shuffleQueue() {
    if (_playlist.length <= 1) return;
    final current = _playlist[_currentIndex];
    final rest = List<SongModel>.from(_playlist)..removeAt(_currentIndex);
    rest.shuffle(Random());
    _playlist = [current, ...rest];
    _currentIndex = 0;
    unawaited(_rebuildAudioSourcePreservingPosition());
  }

  /// Restores the pre-shuffle queue order while keeping the current track's
  /// position accurate.
  void _restoreOriginalQueue() {
    if (_originalPlaylist.isEmpty) return;
    final current = currentSong;
    _playlist = List<SongModel>.from(_originalPlaylist);
    _originalPlaylist = [];
    if (current != null) {
      final restoredIndex = _playlist.indexWhere((s) => s.id == current.id);
      _currentIndex = restoredIndex != -1 ? restoredIndex : 0;
    }
    unawaited(_rebuildAudioSourcePreservingPosition());
  }

  /// Rebuilds the gapless ConcatenatingAudioSource with the current _playlist
  /// order, preserving the playback position of the active track.
  Future<void> _rebuildAudioSourcePreservingPosition() async {
    if (!_gaplessPlayback) return;
    try {
      final position = _audioPlayer.position;
      final mediaItems = _playlist.map((s) => _createMediaItemSync(s)).toList();
      final newSource = ConcatenatingAudioSource(
        children: _playlist.asMap().entries.map((entry) {
          final song = entry.value;
          final uri = song.uri ?? song.data;
          return AudioSource.uri(Uri.parse(uri), tag: mediaItems[entry.key]);
        }).toList(),
      );

      audioHandler.suppressIndexUpdates();
      await _audioPlayer.setAudioSource(
        newSource,
        initialIndex: _currentIndex,
        initialPosition: position,
      );
      audioHandler.resumeIndexUpdates();
      // Re-disable just_audio's internal shuffle; we manage ordering ourselves.
      await _audioPlayer.setShuffleModeEnabled(false);
      await _audioPlayer.setLoopMode(_loopMode);

      audioHandler.updateNotificationQueue(mediaItems);
      if (_currentIndex < mediaItems.length) {
        audioHandler.updateNotificationMediaItem(mediaItems[_currentIndex]);
      }

      if (_isPlaying) {
        await _audioPlayer.play();
      }
    } catch (e) {
      audioHandler.resumeIndexUpdates();
      debugPrint('Error rebuilding audio source: $e');
    }
  }

  void toggleRepeat() {
    // Cycle through: off → all → one → off
    switch (_loopMode) {
      case LoopMode.off:
        _loopMode = LoopMode.all;
        break;
      case LoopMode.all:
        _loopMode = LoopMode.one;
        break;
      case LoopMode.one:
      default:
        _loopMode = LoopMode.off;
        break;
    }
    loopModeNotifier.value = _loopMode;
    debugPrint('🔁 [REPEAT] Cycled loop mode: $_loopMode');
    // Apply loop mode to the audio player
    _audioPlayer.setLoopMode(_loopMode);
    debugPrint(
        '🔁 [REPEAT] Applied to player, current loopMode: ${_audioPlayer.loopMode}');
    unawaited(saveQueueState());
    notifyListeners();
  }

  int _getRandomIndex() {
    if (_playlist.length <= 1) return _currentIndex;
    int newIndex;
    do {
      newIndex =
          (DateTime.now().millisecondsSinceEpoch % _playlist.length).toInt();
    } while (newIndex == _currentIndex);
    return newIndex;
  }

  Future<Uint8List?> getCurrentSongArtwork() async {
    if (currentSong == null) return null;
    try {
      // Use cached artwork service instead of querying directly
      return await _artworkCache.getArtwork(currentSong!.id);
    } catch (e) {
      return null;
    }
  }

  Future<void> updateCurrentArtwork() async {
    if (currentSong == null) {
      currentArtwork.value = null;
      return;
    }
    try {
      // Use cached artwork service for better performance
      final artwork = await _artworkCache.getArtwork(currentSong!.id);
      currentArtwork.value = artwork;

      // Also push artwork to home screen widget
      if (artwork != null && artwork.isNotEmpty) {
        _homeWidgetService.updateSongInfo(
          title: currentSong!.title,
          artist: currentSong!.artist ?? 'Unknown Artist',
          isPlaying: isPlayingNotifier.value,
          artworkBytes: artwork,
        );
      }
    } catch (e) {
      currentArtwork.value = null;
    }
  }

  /// Called when the current song changes — pushes info to the home screen widget.
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
      // Update queue (next 4 songs)
      _homeWidgetService.updateQueue(upcomingQueue.take(6).toList());
      // Start progress updates when a new song starts
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

  Future<void> addSongToLibrary(SongModel song) async {
    if (!_librarySet.contains(song.id.toString())) {
      _librarySet.add(song.id.toString());
      // You might want to perform additional processing here
      // such as extracting metadata or updating play counts
    }
  }

  Future<void> saveLibrary() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/library.json');

    final json = {
      'songs': _librarySet.toList(),
    };

    await file.writeAsString(jsonEncode(json));
  }

  Future<void> loadLibrary() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/library.json');

    if (await file.exists()) {
      final contents = await file.readAsString();
      final json = jsonDecode(contents);
      _librarySet = Set<String>.from(json['songs']);
    }
  }

  Future<void> initializeLikedSongsPlaylist() async {
    await loadLikedSongs();
    _updateLikedSongsPlaylist();
  }

  Future<void> loadLikedSongs() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/liked_songs.json');

    if (await file.exists()) {
      final contents = await file.readAsString();
      final json = jsonDecode(contents);
      _likedSongs = Set<String>.from(json['liked_songs']);
      // Update notifier for reactive UI
      likedSongsNotifier.value = Set<String>.from(_likedSongs);
    }
  }

  Future<void> saveLikedSongs() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/liked_songs.json');

    final json = {
      'liked_songs': _likedSongs.toList(),
    };

    await file.writeAsString(jsonEncode(json));
  }

  void _updateLikedSongsPlaylist() {
    // Don't try to query audio directly - just use the songs we already have
    if (_songs.isEmpty) {
      _likedSongsPlaylist = Playlist(
        id: LIKED_SONGS_PLAYLIST_ID,
        name: _likedPlaylistName,
        songs: [],
      );
      return;
    }

    try {
      final likedSongs = _songs
          .where((song) => _likedSongs.contains(song.id.toString()))
          .toList();

      _likedSongsPlaylist = Playlist(
        id: LIKED_SONGS_PLAYLIST_ID,
        name: _likedPlaylistName,
        songs: likedSongs,
      );

      _scheduleNotify();
    } catch (e) {
      // Handle errors by keeping the current playlist or creating an empty one
      _likedSongsPlaylist ??= Playlist(
        id: LIKED_SONGS_PLAYLIST_ID,
        name: _likedPlaylistName,
        songs: [],
      );
      debugPrint('Error updating liked songs playlist: $e');
    }
  }

  bool isLiked(SongModel song) {
    return _likedSongs.contains(song.id.toString());
  }

  Future<void> toggleLike(SongModel song) async {
    if (_likedSongs.contains(song.id.toString())) {
      _likedSongs.remove(song.id.toString());
    } else {
      _likedSongs.add(song.id.toString());
    }

    // Update notifier for reactive UI
    likedSongsNotifier.value = Set<String>.from(_likedSongs);

    await saveLikedSongs();
    _updateLikedSongsPlaylist();
    _scheduleNotify();
  }

  Playlist? get likedSongsPlaylist => _likedSongsPlaylist;

  Future<void> initializeWithSongs(List<SongModel> initialSongs) async {
    _updateSongs(initialSongs);
    _scheduleNotify();
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
      _savePlayCounts();
    }
    if (_playlistsDirty) {
      savePlaylists();
    }

    // Persist queue state synchronously so it is available on next launch.
    saveQueueState();

    // Clean up widget listeners and service
    currentSongNotifier.removeListener(_onSongChangedForWidget);
    isPlayingNotifier.removeListener(_onPlayStateChangedForWidget);
    _homeWidgetService.dispose();

    _currentSongController.close();
    _errorController.close();
    _sleepTimer?.cancel();
    super.dispose();
  }

  // Ensure that _folderAccessCounts is correctly populated
  void _incrementFolderAccessCount(String folderPath) {
    _folderAccessCounts[folderPath] =
        (_folderAccessCounts[folderPath] ?? 0) + 1;
    _scheduleSavePlayCounts();
  }

  // Call this method whenever a song from a folder is played
  void playSongFromFolder(SongModel song) {
    final folderPath = File(song.data).parent.path;
    _incrementFolderAccessCount(folderPath);
    // Proceed to play the song
    setPlaylist([song], 0);
    play();
  }

  // Method to update playlist name when language changes
  void updateLikedPlaylistName(String newName) {
    _likedPlaylistName = newName;
    if (_likedSongsPlaylist != null) {
      _likedSongsPlaylist = Playlist(
        id: LIKED_SONGS_PLAYLIST_ID,
        name: _likedPlaylistName,
        songs: _likedSongsPlaylist!.songs,
      );
      _scheduleNotify();
    }
  }

  // Getter for the playlist name
  String get likedPlaylistName => _likedPlaylistName;

  Future<void> _loadSettings() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/settings.json');

    if (await file.exists()) {
      final contents = await file.readAsString();
      final json = jsonDecode(contents);

      _gaplessPlayback = json['gaplessPlayback'] ?? true;
      _volumeNormalization = json['volumeNormalization'] ?? false;
      _playbackSpeed = (json['playbackSpeed'] ?? 1.0).toDouble();
      _defaultSortOrder = json['defaultSortOrder'] ?? 'title';
      _cacheSize = json['cacheSize'] ?? 100;
      _mediaControls = json['mediaControls'] ?? true;

      // Apply settings to audio player
      await _applySettings();
    }
  }

  Future<void> _saveSettings() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/settings.json');

    final json = {
      'gaplessPlayback': _gaplessPlayback,
      'volumeNormalization': _volumeNormalization,
      'playbackSpeed': _playbackSpeed,
      'defaultSortOrder': _defaultSortOrder,
      'cacheSize': _cacheSize,
      'mediaControls': _mediaControls,
    };

    await file.writeAsString(jsonEncode(json));
  }

  Future<void> _applySettings() async {
    // Apply playback speed
    await _audioPlayer.setSpeed(_playbackSpeed);

    // Apply volume normalization using regular volume control
    if (_volumeNormalization) {
      await _audioPlayer.setVolume(1.0);
    }

    // Configure gapless playback
    if (_gaplessPlayback) {
      // Create a concatenating audio source for gapless playback
      if (_playlist.isNotEmpty) {
        // Use lightweight MediaItems for instant startup
        final mediaItems =
            _playlist.map((song) => _createMediaItemSync(song)).toList();

        final playlist = ConcatenatingAudioSource(
          children: _playlist
              .asMap()
              .entries
              .map((entry) => AudioSource.uri(
                    Uri.parse(entry.value.uri ?? entry.value.data),
                    tag: mediaItems[entry.key],
                  ))
              .toList(),
        );

        // Set the audio source with the current index
        await _audioPlayer.setAudioSource(
          playlist,
          initialIndex: _currentIndex,
          initialPosition: _audioPlayer.position,
        );

        // Load artwork in background
        unawaited(_loadRemainingArtworkInBackground(_playlist));
      }
    }
  }

  // Settings update methods
  Future<void> setGaplessPlayback(bool value) async {
    _gaplessPlayback = value;
    await _saveSettings();
    // Settings changes are infrequent, direct notify is fine
  }

  Future<void> setVolumeNormalization(bool value) async {
    _volumeNormalization = value;
    await _applySettings();
    await _saveSettings();
  }

  Future<void> setPlaybackSpeed(double value) async {
    _playbackSpeed = value;
    // Apply speed directly without reloading audio source
    await _audioPlayer.setSpeed(_playbackSpeed);
    await _saveSettings();
  }

  Future<void> setDefaultSortOrder(String value) async {
    _defaultSortOrder = value;
    await _saveSettings();
    _sortPlaylist();
    _scheduleNotify();
  }

  Future<void> setCacheSize(int value) async {
    _cacheSize = value;
    await _saveSettings();
    unawaited(_manageCacheSize()); // Don't block on cache management
  }

  Future<void> setMediaControls(bool value) async {
    _mediaControls = value;
    await _saveSettings();

    // Update the audio session configuration.
    // Both branches use the same long-running music config so that
    // audio focus type (GAIN) is never accidentally downgraded.
    final session = await AudioSession.instance;
    if (!_mediaControls) {
      // Disable media notifications (audio focus config stays the same)
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
    } else {
      // Enable media notifications
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

      // Re-initialize the audio service if needed
      if (_audioPlayer.playing) {
        // Update the current media item to refresh the notification
        final currentSong = this.currentSong;
        if (currentSong != null) {
          final mediaItem = await _createMediaItem(currentSong);
          await _audioPlayer.setAudioSource(
            AudioSource.uri(
              Uri.parse(currentSong.data),
              tag: mediaItem,
            ),
          );
        }
      }
    }
    // No need for notifyListeners - UI doesn't depend on this setting directly
  }

  void _sortPlaylist() {
    switch (_defaultSortOrder) {
      case 'title':
        _playlist.sort((a, b) => (a.title).compareTo(b.title));
        break;
      case 'artist':
        _playlist.sort((a, b) => (a.artist ?? '').compareTo(b.artist ?? ''));
        break;
      case 'album':
        _playlist.sort((a, b) => (a.album ?? '').compareTo(b.album ?? ''));
        break;
      case 'date_added':
        // Implement date added sorting if you track this information
        break;
    }
  }

  Future<void> _manageCacheSize() async {
    final directory = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${directory.path}/artwork_cache');
    final spotifyCacheDir = Directory(directory.path);

    int totalSize = 0;

    // Clean artwork cache
    if (await cacheDir.exists()) {
      final files = await cacheDir.list().toList();
      totalSize += files.fold<int>(
          0, (sum, file) => sum + (file is File ? file.lengthSync() : 0));

      if (totalSize > _cacheSize * 1024 * 1024) {
        files.sort(
            (a, b) => a.statSync().accessed.compareTo(b.statSync().accessed));
        var currentSize = totalSize;
        for (final file in files) {
          if (currentSize <= _cacheSize * 1024 * 1024) break;
          if (file is File) {
            final fileSize = file.lengthSync();
            await file.delete();
            currentSize -= fileSize;
          }
        }
      }
    }

    // Clean Spotify song cache
    if (await spotifyCacheDir.exists()) {
      final files = await spotifyCacheDir.list().toList();
      final spotifyFiles = files
          .where((file) => file is File && file.path.endsWith('.mp3'))
          .toList();
      totalSize += spotifyFiles.fold<int>(
          0, (sum, file) => sum + (file is File ? file.lengthSync() : 0));

      if (totalSize > _cacheSize * 1024 * 1024) {
        spotifyFiles.sort(
            (a, b) => a.statSync().accessed.compareTo(b.statSync().accessed));
        var currentSize = totalSize;
        for (final file in spotifyFiles) {
          if (currentSize <= _cacheSize * 1024 * 1024) break;
          if (file is File) {
            final fileSize = file.lengthSync();
            await file.delete();
            currentSize -= fileSize;
          }
        }
      }
    }
  }

  /// Replaces a single song entry in the in-memory song list, playlist queue,
  /// and current-song notifiers without reloading the entire library.
  /// Called after metadata has been edited and MediaStore has been rescanned.
  void refreshSongInPlaylist(SongModel updatedSong) {
    // 1. Replace in the master songs list
    final songIdx = _songs.indexWhere((s) => s.id == updatedSong.id);
    if (songIdx != -1) {
      final updated = List<SongModel>.from(_songs);
      updated[songIdx] = updatedSong;
      _updateSongs(updated);
    }

    // 2. Replace in the active playback queue
    final queueIdx = _playlist.indexWhere((s) => s.id == updatedSong.id);
    if (queueIdx != -1) {
      _playlist[queueIdx] = updatedSong;
    }

    // 3. If this is the currently playing song, update all notifiers
    if (currentSong?.id == updatedSong.id) {
      _currentSongController.add(updatedSong);
      currentSongNotifier.value = updatedSong;
    }

    _scheduleNotify();
  }

  void _updateAutoPlaylists() {
    // Auto playlists are always enabled

    // Create "Most Played" playlist
    getMostPlayedTracks().then((tracks) {
      final existingIndex =
          _playlists.indexWhere((p) => p.name == 'Most Played');

      if (existingIndex != -1) {
        // Update existing playlist
        _playlists[existingIndex] = Playlist(
          id: 'most_played',
          name: 'Most Played',
          songs: tracks,
        );
      } else {
        // Create new playlist
        _playlists.add(Playlist(
          id: 'most_played',
          name: 'Most Played',
          songs: tracks,
        ));
      }

      _playlistsDirty = true;
      _scheduleSavePlayCounts();
      _scheduleNotify();
    });

    // Create "Recently Added" playlist
    _audioQuery
        .querySongs(
      sortType: SongSortType.DATE_ADDED,
      orderType: OrderType.DESC_OR_GREATER,
    )
        .then((tracks) {
      final existingIndex =
          _playlists.indexWhere((p) => p.name == 'Recently Added');

      if (existingIndex != -1) {
        // Update existing playlist
        _playlists[existingIndex] = Playlist(
          id: 'recently_added',
          name: 'Recently Added',
          songs: tracks,
        );
      } else {
        // Create new playlist
        _playlists.add(Playlist(
          id: 'recently_added',
          name: 'Recently Added',
          songs: tracks,
        ));
      }

      _playlistsDirty = true;
      _scheduleSavePlayCounts();
      _scheduleNotify();
    });
  }

  /// Get recently played songs sorted by play count
  /// [count] - number of songs to return (default 3, use -1 for all)
  Future<List<SongModel>> getRecentlyPlayed({int count = 3}) async {
    final allSongs = await _audioQuery.querySongs(
      orderType: OrderType.ASC_OR_SMALLER,
      uriType: UriType.EXTERNAL,
      ignoreCase: true,
    );
    final recentlyPlayedSongs = allSongs
        .where((song) => _trackPlayCounts.containsKey(song.id.toString()))
        .toList();

    recentlyPlayedSongs.sort((a, b) => (_trackPlayCounts[b.id.toString()] ?? 0)
        .compareTo(_trackPlayCounts[a.id.toString()] ?? 0));

    if (count == -1) {
      return recentlyPlayedSongs;
    }
    return recentlyPlayedSongs.take(count).toList();
  }

  /// Get all recently played songs (full list for playback)
  Future<List<SongModel>> getAllRecentlyPlayed() async {
    return getRecentlyPlayed(count: -1);
  }

  /// Get all recently added songs (full list for playback)
  Future<List<SongModel>> getAllRecentlyAdded() async {
    final allSongs = await _audioQuery.querySongs(
      sortType: SongSortType.DATE_ADDED,
      orderType: OrderType.DESC_OR_GREATER,
      uriType: UriType.EXTERNAL,
      ignoreCase: true,
    );
    return allSongs;
  }

  /// Get all most played tracks (full list for playback)
  Future<List<SongModel>> getAllMostPlayedTracks() async {
    final allSongs = await _audioQuery.querySongs(
      orderType: OrderType.ASC_OR_SMALLER,
      uriType: UriType.EXTERNAL,
      ignoreCase: true,
    );
    final playedSongs = allSongs
        .where((song) => (_trackPlayCounts[song.id.toString()] ?? 0) > 0)
        .toList();

    playedSongs.sort((a, b) => (_trackPlayCounts[b.id.toString()] ?? 0)
        .compareTo(_trackPlayCounts[a.id.toString()] ?? 0));
    return playedSongs;
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

  // MARK: - Queue State Persistence

  /// Persists the current queue (songs, index, position, shuffle/repeat state)
  /// to disk so it can be restored on the next app launch.
  Future<void> saveQueueState() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$kQueueStateFileName');

      final json = {
        'queue': _playlist.map((song) => song.getMap).toList(),
        'originalQueue': _originalPlaylist.map((song) => song.getMap).toList(),
        'currentIndex': _currentIndex,
        'positionMs': _audioPlayer.position.inMilliseconds,
        'isShuffle': _isShuffle,
        'loopMode': _loopMode.name,
      };

      await file.writeAsString(jsonEncode(json));
    } catch (e) {
      debugPrint('Error saving queue state: $e');
    }
  }

  /// Restores the queue state that was saved by [saveQueueState].
  /// Only restores metadata — playback is NOT automatically started.
  Future<void> loadQueueState() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$kQueueStateFileName');

      if (!await file.exists()) return;

      final contents = await file.readAsString();
      final json = jsonDecode(contents) as Map<String, dynamic>;

      final queueMaps = json['queue'] as List? ?? [];
      if (queueMaps.isEmpty) return;

      // Reconstruct songs and filter out any that no longer exist on disk.
      List<SongModel> buildQueueFromMaps(List maps) {
        return maps
            .map((m) => SongModel(Map<String, dynamic>.from(m as Map)))
            .where((song) {
          try {
            return File(song.data).existsSync();
          } catch (_) {
            return false;
          }
        }).toList();
      }

      final queue = buildQueueFromMaps(queueMaps);
      if (queue.isEmpty) return;

      final originalQueueMaps = json['originalQueue'] as List? ?? [];
      final originalQueue = buildQueueFromMaps(originalQueueMaps);

      final savedIndex =
          (json['currentIndex'] as int? ?? 0).clamp(0, queue.length - 1);
      final isShuffle = json['isShuffle'] as bool? ?? false;
      final loopModeName = json['loopMode'] as String? ?? '';
      final loopMode = LoopMode.values.firstWhere(
        (m) => m.name == loopModeName,
        orElse: () => LoopMode.off,
      );

      _playlist = queue;
      _originalPlaylist = originalQueue;
      _currentIndex = savedIndex;
      _isShuffle = isShuffle;
      _loopMode = loopMode;

      isShuffleNotifier.value = _isShuffle;
      loopModeNotifier.value = _loopMode;

      // Update current song notifiers without starting playback.
      final song = _playlist[_currentIndex];
      _currentSongController.add(song);
      currentSongNotifier.value = song;

      debugPrint(
          'Queue state restored: ${_playlist.length} songs, index: $_currentIndex, '
          'shuffle: $_isShuffle, loopMode: $_loopMode');

      // Prime the audio source so that tapping Play immediately works.
      // We load the source at the saved position but do NOT call play().
      await _primeAudioSourceAfterRestore(
          savedIndex, Duration(milliseconds: json['positionMs'] as int? ?? 0));

      _scheduleNotify();
    } catch (e) {
      debugPrint('Error loading queue state: $e');
    }
  }

  /// Loads the audio source into the player after a queue-state restore,
  /// positioned at [savedIndex] / [savedPosition], without starting playback.
  /// This ensures the first tap on Play works immediately.
  Future<void> _primeAudioSourceAfterRestore(
      int savedIndex, Duration savedPosition) async {
    try {
      if (_gaplessPlayback) {
        final mediaItems =
            _playlist.map((s) => _createMediaItemSync(s)).toList();
        final source = ConcatenatingAudioSource(
          children: _playlist
              .asMap()
              .entries
              .map((e) => AudioSource.uri(
                    Uri.parse(e.value.uri ?? e.value.data),
                    tag: mediaItems[e.key],
                  ))
              .toList(),
        );
        await _audioPlayer.setAudioSource(
          source,
          initialIndex: savedIndex,
          initialPosition: savedPosition,
        );
        // Pause immediately so we don't auto-play on restore.
        await _audioPlayer.pause();
        unawaited(_loadRemainingArtworkInBackground(_playlist));
      } else {
        // Non-gapless: prime with just the current song.
        final song = _playlist[savedIndex];
        final mediaItem = _createMediaItemSync(song);
        await _audioPlayer.setAudioSource(
          AudioSource.uri(
            Uri.parse(song.uri ?? song.data),
            tag: mediaItem,
          ),
          initialPosition: savedPosition,
        );
        await _audioPlayer.pause();
      }
      // Notify the audio handler so the lock-screen / notification
      // shows the restored song without starting playback.
      audioHandler.updateNotificationMediaItem(
          _createMediaItemSync(_playlist[savedIndex]));
      debugPrint('Audio source primed after queue restore.');
    } catch (e) {
      // Non-fatal: if priming fails the user will see an error when they tap
      // Play, but the rest of the app is still usable.
      debugPrint('Error priming audio source after queue restore: $e');
    }
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
