import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:path_provider/path_provider.dart';
import '../models/utils.dart';
import 'dart:io';
import 'dart:convert';
import '../models/playlist_model.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:audio_session/audio_session.dart';
import 'background_manager_service.dart';
import 'artwork_cache_service.dart';
import 'smart_suggestions_service.dart';

class AudioPlayerService extends ChangeNotifier {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final OnAudioQuery _audioQuery = OnAudioQuery();
  final ArtworkCacheService _artworkCache = ArtworkCacheService();
  final SmartSuggestionsService _smartSuggestions = SmartSuggestionsService();

  // Background manager for mesh gradient colors
  BackgroundManagerService? _backgroundManager;

  List<SongModel> _playlist = [];
  List<Playlist> _playlists = [];
  int _currentIndex = -1;
  bool _isPlaying = false;
  bool _isShuffle = false;
  bool _isRepeat = false;
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
  bool get isRepeat => _isRepeat;
  SongModel? get currentSong =>
      _currentIndex >= 0 && _currentIndex < _playlist.length
          ? _playlist[_currentIndex]
          : null;
  final ValueNotifier<Uint8List?> currentArtwork = ValueNotifier(null);
  final ValueNotifier<SongModel?> currentSongNotifier = ValueNotifier(null);

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
  final ValueNotifier<bool> isRepeatNotifier = ValueNotifier<bool>(false);

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
    _songs = [];
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

  // Public method to initialize music library - should be called only from HomeScreen
  Future<bool> initializeMusicLibrary() async {
    try {
      final hasPermissions = await _checkPermissionStatus();

      if (!hasPermissions) {
        debugPrint('No permissions yet - library remains empty');
        return false;
      }

      // Load library from cache first
      await loadLibrary();

      // Try to load songs
      try {
        final songs = await _audioQuery.querySongs();
        _songs = songs;

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

  Future<void> _init() async {
    // Configure audio session
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.playback,
      androidAudioAttributes: AndroidAudioAttributes(
        contentType: AndroidAudioContentType.music,
        usage: AndroidAudioUsage.media,
      ),
      androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
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

    _audioPlayer.positionStream.listen((position) {
      final duration = _audioPlayer.duration;
      if (duration != null && position >= duration) {
        skip();
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
      for (var song in songs) {
        if (!_likedSongs.contains(song.id.toString())) {
          _likedSongs.add(song.id.toString());
        }
      }
      saveLikedSongs();
      _updateLikedSongsPlaylist();
    } else {
      final playlist = _playlists.firstWhere((p) => p.id == playlistId);
      for (var song in songs) {
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
      for (var artist in artistNames) {
        _artistPlayCounts[artist] = (_artistPlayCounts[artist] ?? 0) + 1;
      }
    }

    final folder = File(song.data).parent.path;
    _folderAccessCounts[folder] = (_folderAccessCounts[folder] ?? 0) + 1;

    if (song.artist != null) {
      final artistNames = splitArtists(song.artist!);
      for (var artist in artistNames) {
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
    final allSongs = await _audioQuery.querySongs();
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

    for (var artist in allArtists) {
      final artistNames = splitArtists(artist.artist);
      for (var name in artistNames) {
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
  Future<void> setPlaylist(List<SongModel> songs, int startIndex) async {
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
          final playlistSource = ConcatenatingAudioSource(
            children: _playlist.map((song) {
              final uri = song.uri ?? song.data;
              return AudioSource.uri(
                Uri.parse(uri),
                tag: MediaItem(
                  id: song.id.toString(),
                  album: song.album ?? 'Unknown Album',
                  title: song.title,
                  artist: splitArtists(song.artist ?? 'Unknown Artist').join(', '),
                  duration: Duration(milliseconds: song.duration ?? 0),
                ),
              );
            }).toList(),
          );

          await _audioPlayer.setAudioSource(
            playlistSource,
            initialIndex: _currentIndex,
            initialPosition: Duration.zero,
          );
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
        final newSource = ConcatenatingAudioSource(
          children: newSongs
              .map((song) => AudioSource.uri(
                    Uri.parse(song.uri ?? song.data),
                    tag: MediaItem(
                      id: song.id.toString(),
                      album: song.album ?? 'Unknown Album',
                      title: song.title,
                      artist: splitArtists(song.artist ?? 'Unknown Artist').join(', '),
                      duration: Duration(milliseconds: song.duration ?? 0),
                    ),
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
        } else {
          final url = song.uri ?? song.data;
          debugPrint('Non-gapless playback, loading URL: $url');

          final mediaItem = MediaItem(
            id: song.id.toString(),
            album: song.album ?? 'Unknown Album',
            title: song.title,
            artist: splitArtists(song.artist ?? 'Unknown Artist').join(', '),
            duration: Duration(milliseconds: song.duration ?? 0),
          );

          await _audioPlayer.setAudioSource(
            AudioSource.uri(Uri.parse(url), tag: mediaItem),
            preload: true,
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

  void skip() async {
    _isLoading = false; // Reset loading flag to allow new song to play
    int nextIndex = _currentIndex + 1;
    if (_isShuffle) {
      nextIndex = _getRandomIndex();
    } else if (nextIndex >= _playlist.length) {
      nextIndex = _isRepeat ? 0 : _currentIndex;
    }
    await play(index: nextIndex);
  }

  void back() async {
    _isLoading = false; // Reset loading flag to allow new song to play
    int prevIndex = _currentIndex - 1;
    if (_isShuffle) {
      prevIndex = _getRandomIndex();
    } else if (prevIndex < 0) {
      prevIndex = _isRepeat ? _playlist.length - 1 : _currentIndex;
    }
    await play(index: prevIndex);
  }

  void toggleShuffle() {
    _isShuffle = !_isShuffle;
    isShuffleNotifier.value = _isShuffle;
    // ValueNotifier handles reactive updates - no notifyListeners needed
  }

  void toggleRepeat() {
    _isRepeat = !_isRepeat;
    isRepeatNotifier.value = _isRepeat;
    // ValueNotifier handles reactive updates - no notifyListeners needed
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

    await saveLikedSongs();
    _updateLikedSongsPlaylist();
    _scheduleNotify();
  }

  Playlist? get likedSongsPlaylist => _likedSongsPlaylist;

  Future<void> initializeWithSongs(List<SongModel> initialSongs) async {
    _songs = initialSongs;
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
    isRepeatNotifier.dispose();
    sleepTimerDurationNotifier.dispose();
    playlistsNotifier.dispose();
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
        final playlist = ConcatenatingAudioSource(
          children: _playlist
              .map((song) => AudioSource.uri(
                    Uri.parse(song.uri ?? song.data),
                    tag: MediaItem(
                      id: song.id.toString(),
                      album: song.album ?? 'Unknown Album',
                      title: song.title,
                      artist: splitArtists(song.artist ?? 'Unknown Artist').join(', '),
                      duration: Duration(milliseconds: song.duration ?? 0),
                    ),
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
    await _applySettings();
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
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
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
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        androidWillPauseWhenDucked: true,
      ));

      // Re-initialize the audio service if needed
      if (_audioPlayer.playing) {
        // Update the current media item to refresh the notification
        final currentSong = this.currentSong;
        if (currentSong != null) {
          await _audioPlayer.setAudioSource(
            AudioSource.uri(
              Uri.parse(currentSong.data),
              tag: MediaItem(
                id: currentSong.id.toString(),
                album: currentSong.album ?? '',
                title: currentSong.title,
                artist: splitArtists(currentSong.artist ?? 'Unknown Artist').join(', '),
                artUri: Uri.parse('file://${currentSong.data}'),
              ),
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
        for (var file in files) {
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
        for (var file in spotifyFiles) {
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

  // Add this new method
  Future<List<SongModel>> getRecentlyPlayed() async {
    final allSongs = await _audioQuery.querySongs();
    final recentlyPlayedSongs = allSongs
        .where((song) => _trackPlayCounts.containsKey(song.id.toString()))
        .toList();

    recentlyPlayedSongs.sort((a, b) => (_trackPlayCounts[b.id.toString()] ?? 0)
        .compareTo(_trackPlayCounts[a.id.toString()] ?? 0));

    return recentlyPlayedSongs.take(3).toList();
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
