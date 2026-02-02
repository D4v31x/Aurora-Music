import 'dart:async';
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
import 'background_manager_service.dart';
import 'artwork_cache_service.dart';
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

  // Background manager for mesh gradient colors
  BackgroundManagerService? _backgroundManager;

  // Playback source tracking
  PlaybackSourceInfo _playbackSource = PlaybackSourceInfo.unknown;
  PlaybackSourceInfo get playbackSource => _playbackSource;

  List<SongModel> _playlist = [];
  List<Playlist> _playlists = [];
  int _currentIndex = -1;
  bool _isPlaying = false;
  bool _isShuffle = false;
  LoopMode _loopMode = LoopMode.off; // Changed from bool to LoopMode
  bool _isLoading = false;
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
      await _backgroundManager!.updateColorsFromSong(currentSong);
    }
  }

  /// Get artwork URI for media notification
  /// Saves artwork to a temp file and returns the file URI
  Future<Uri?> _getArtworkUri(int songId) async {
    try {
      final artwork = await _artworkCache.getArtwork(songId);
      if (artwork == null || artwork.isEmpty) return null;

      final tempDir = await getTemporaryDirectory();
      final artworkFile = File('${tempDir.path}/notification_art_$songId.jpg');

      // Always write the file to ensure it's available
      await artworkFile.writeAsBytes(artwork);

      // Return file URI - must use Uri.parse with file:// prefix for Android
      return Uri.parse('file://${artworkFile.path}');
    } catch (e) {
      debugPrint('Error getting artwork URI: $e');
      return null;
    }
  }

  /// Create MediaItem with artwork for a song
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

  Future<void> _init() async {
    // Configure audio session
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.playback,
      androidAudioAttributes: AndroidAudioAttributes(
        contentType: AndroidAudioContentType.music,
        usage: AndroidAudioUsage.media,
      ),
      androidWillPauseWhenDucked: true,
    ));

    await _loadPlayCounts();
    await _loadPlaylists();

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
    // This fires when just_audio automatically transitions to the next track
    _audioPlayer.currentIndexStream.listen((index) async {
      debugPrint(
          '🎵 [INDEX_STREAM] Index changed: $index (previous: $_currentIndex, shuffle: ${_audioPlayer.shuffleModeEnabled}, loop: ${_audioPlayer.loopMode})');
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

      debugPrint(
          'Setting playlist with ${songs.length} songs, starting at index $startIndex');

      if (_gaplessPlayback) {
        try {
          // Pre-fetch artwork for all songs in parallel for better notification experience
          final mediaItems = await Future.wait(
            _playlist.map((song) => _createMediaItem(song)),
          );

          // Update audio handler queue for notification
          audioHandler.updateNotificationQueue(mediaItems);

          final playlistSource = ConcatenatingAudioSource(
            children: _playlist.asMap().entries.map((entry) {
              final song = entry.value;
              final mediaItem = mediaItems[entry.key];
              final uri = song.uri ?? song.data;
              return AudioSource.uri(
                Uri.parse(uri),
                tag: mediaItem,
              );
            }).toList(),
          );

          await _audioPlayer.setAudioSource(
            playlistSource,
            initialIndex: _currentIndex,
            initialPosition: Duration.zero,
          );

          // Apply current shuffle and loop settings to the player
          debugPrint(
              '🎵 [AUDIO_SOURCE] Applying shuffle: $_isShuffle, loopMode: $_loopMode');
          await _audioPlayer.setShuffleModeEnabled(_isShuffle);
          await _audioPlayer.setLoopMode(_loopMode);
          debugPrint(
              '🎵 [AUDIO_SOURCE] Player state - shuffle: ${_audioPlayer.shuffleModeEnabled}, loop: ${_audioPlayer.loopMode}');

          // Update current media item in notification
          audioHandler.updateNotificationMediaItem(mediaItems[_currentIndex]);

          await _audioPlayer.play();

          // Batch all state updates
          _isPlaying = true;
          isPlayingNotifier.value = true;
          _incrementPlayCount(_playlist[_currentIndex]);
          _currentSongController.add(_playlist[_currentIndex]);
          currentSongNotifier.value = _playlist[_currentIndex];

          // Fire and forget UI updates
          unawaited(updateCurrentArtwork());
          unawaited(_updateBackgroundColors());

          // Single debounced notification
          _scheduleNotify();
        } catch (e) {
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
        // For non-gapless playback, just call play() once
        await play();
      }
    } catch (e) {
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
        // Pre-fetch artwork for all songs
        final mediaItems = await Future.wait(
          newSongs.map((song) => _createMediaItem(song)),
        );

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

          await _audioPlayer.setAudioSource(
            AudioSource.uri(Uri.parse(url), tag: mediaItem),
          );
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
        final mediaItem = await _createMediaItem(song);
        final uri = song.uri ?? song.data;
        await source.add(AudioSource.uri(Uri.parse(uri), tag: mediaItem));

        // Update notification queue
        final mediaItems =
            await Future.wait(_playlist.map((s) => _createMediaItem(s)));
        audioHandler.updateNotificationQueue(mediaItems);
      } catch (e) {
        debugPrint('Error adding song to queue: $e');
      }
    }

    _scheduleNotify();
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
            await Future.wait(songs.map((song) => _createMediaItem(song)));

        for (var i = 0; i < songs.length; i++) {
          final song = songs[i];
          final uri = song.uri ?? song.data;
          await source.add(AudioSource.uri(Uri.parse(uri), tag: mediaItems[i]));
        }

        // Update notification queue
        final allMediaItems =
            await Future.wait(_playlist.map((s) => _createMediaItem(s)));
        audioHandler.updateNotificationQueue(allMediaItems);
      } catch (e) {
        debugPrint('Error adding songs to queue: $e');
      }
    }

    _scheduleNotify();
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
        final mediaItem = await _createMediaItem(song);
        final uri = song.uri ?? song.data;
        await source.insert(
            insertIndex, AudioSource.uri(Uri.parse(uri), tag: mediaItem));

        // Update notification queue
        final mediaItems =
            await Future.wait(_playlist.map((s) => _createMediaItem(s)));
        audioHandler.updateNotificationQueue(mediaItems);
      } catch (e) {
        debugPrint('Error inserting song to play next: $e');
      }
    }

    _scheduleNotify();
  }

  /// Remove a song from the queue by index
  Future<void> removeFromQueue(int index) async {
    if (index < 0 || index >= _playlist.length) return;

    // Don't allow removing the currently playing song via this method
    if (index == _currentIndex) {
      debugPrint('Cannot remove currently playing song');
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

        // Update notification queue
        final mediaItems =
            await Future.wait(_playlist.map((s) => _createMediaItem(s)));
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

        // Update notification queue
        final mediaItems =
            await Future.wait(_playlist.map((s) => _createMediaItem(s)));
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

        // Update notification queue
        final mediaItems =
            await Future.wait(_playlist.map((s) => _createMediaItem(s)));
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
  void syncPlaybackState() {
    final actuallyPlaying = _audioPlayer.playing;
    if (_isPlaying != actuallyPlaying) {
      _isPlaying = actuallyPlaying;
      isPlayingNotifier.value = actuallyPlaying;
      _scheduleNotify();
    }
  }

  void skip() async {
    _isLoading = false; // Reset loading flag to allow new song to play

    debugPrint(
        '⏭️ [SKIP] Called - hasNext: ${_audioPlayer.hasNext}, currentIndex: $_currentIndex, shuffle: $_isShuffle, loopMode: $_loopMode');

    // Use just_audio's built-in seekToNext which respects shuffle mode
    if (_audioPlayer.hasNext) {
      debugPrint('⏭️ [SKIP] Seeking to next track');
      await _audioPlayer.seekToNext();
    } else if (_loopMode == LoopMode.all) {
      // If loop all is on and we're at the end, go back to start
      debugPrint('⏭️ [SKIP] At end with loop ALL, going to start');
      await _audioPlayer.seek(Duration.zero, index: 0);
      await _audioPlayer.play();
    } else {
      debugPrint(
          '⏭️ [SKIP] At end, staying on current song (loopMode: $_loopMode)');
    }
    // If no next and no repeat, just stay on current song
  }

  void back() async {
    _isLoading = false; // Reset loading flag to allow new song to play

    // Check if more than 5 seconds have elapsed
    final currentPosition = _audioPlayer.position;
    if (currentPosition.inSeconds >= 5) {
      // Restart current song
      await _audioPlayer.seek(Duration.zero);
      return;
    }

    // Use just_audio's built-in seekToPrevious which respects shuffle mode
    if (_audioPlayer.hasPrevious) {
      await _audioPlayer.seekToPrevious();
    } else if (_loopMode == LoopMode.all) {
      // If loop all is on and we're at the start, go to end
      await _audioPlayer.seek(Duration.zero, index: _playlist.length - 1);
      await _audioPlayer.play();
    }
    // If no previous and no repeat, just restart current song
    else {
      await _audioPlayer.seek(Duration.zero);
    }
  }

  void toggleShuffle() {
    _isShuffle = !_isShuffle;
    isShuffleNotifier.value = _isShuffle;
    debugPrint('🔀 [SHUFFLE] Toggled shuffle: $_isShuffle');
    // Apply shuffle mode to the audio player
    _audioPlayer.setShuffleModeEnabled(_isShuffle);
    debugPrint(
        '🔀 [SHUFFLE] Applied to player, shuffleModeEnabled: ${_audioPlayer.shuffleModeEnabled}');
    notifyListeners();
  }

  void toggleRepeat() {
    // Cycle through: off → one → all → off
    switch (_loopMode) {
      case LoopMode.off:
        _loopMode = LoopMode.one;
        break;
      case LoopMode.one:
        _loopMode = LoopMode.all;
        break;
      case LoopMode.all:
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
    } catch (e) {
      currentArtwork.value = null;
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
        // Pre-fetch artwork for all songs
        final mediaItems = await Future.wait(
          _playlist.map((song) => _createMediaItem(song)),
        );

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

    // Update the audio session configuration
    final session = await AudioSession.instance;
    if (!_mediaControls) {
      // Disable media notifications
      await session.configure(const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.music,
          usage: AndroidAudioUsage.media,
        ),
        androidWillPauseWhenDucked: true,
      ));
    } else {
      // Enable media notifications
      await session.configure(const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.music,
          usage: AndroidAudioUsage.media,
        ),
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
