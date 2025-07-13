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

class AudioPlayerService extends ChangeNotifier {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final OnAudioQuery _audioQuery = OnAudioQuery();

  List<SongModel> _playlist = [];
  List<Playlist> _playlists = [];
  int _currentIndex = -1;
  bool _isPlaying = false;
  bool _isShuffle = false;
  bool _isRepeat = false;
  Set<String> _librarySet = {};

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

  Timer? _sleepTimer;
  Duration? _remainingTime;
  Duration? _sleepTimerDuration;

  bool get isSleepTimerActive => _sleepTimer?.isActive ?? false;
  Duration? get remainingTime => _remainingTime;
  Duration? get sleepTimerDuration => _sleepTimerDuration;

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
  bool _autoPlaylists = true;
  int _cacheSize = 100; // in MB
  bool _mediaControls = true;

  // Settings getters
  bool get gaplessPlayback => _gaplessPlayback;
  bool get volumeNormalization => _volumeNormalization;
  double get playbackSpeed => _playbackSpeed;
  String get defaultSortOrder => _defaultSortOrder;
  bool get autoPlaylists => _autoPlaylists;
  int get cacheSize => _cacheSize;
  bool get mediaControls => _mediaControls;

  // Add ValueNotifiers for reactive state
  final ValueNotifier<bool> isPlayingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<List<Playlist>> playlistsNotifier =
      ValueNotifier<List<Playlist>>([]);
  final ValueNotifier<bool> isShuffleNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isRepeatNotifier = ValueNotifier<bool>(false);

  

  AudioPlayerService() {
    _init();
    loadLibrary();
    initializeLikedSongsPlaylist();
    _loadSettings();
    audioPlayer.playerStateStream.listen((playerState) {
      notifyListeners();
    });
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
    notifyListeners();
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
  }

  void createPlaylist(String name, List<SongModel> songs) {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final newPlaylist = Playlist(id: id, name: name, songs: songs);
    _playlists.add(newPlaylist);
    savePlaylists();
    notifyListeners();
  }

  void addSongToPlaylist(String playlistId, SongModel song) {
    final playlist = _playlists.firstWhere((p) => p.id == playlistId);
    if (!playlist.songs.contains(song)) {
      playlist.songs.add(song);
      savePlaylists();
      notifyListeners();
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
      savePlaylists();
    }
    notifyListeners();
  }

  void deletePlaylist(Playlist playlist) {
    _playlists.remove(playlist);
    savePlaylists();
    notifyListeners();
  }

  void renamePlaylist(String playlistId, String newName) {
    final playlistIndex = _playlists.indexWhere((p) => p.id == playlistId);
    if (playlistIndex != -1) {
      _playlists[playlistIndex] =
          _playlists[playlistIndex].copyWith(name: newName);
      savePlaylists();
      notifyListeners();
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
      savePlaylists();
    }
    notifyListeners();
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

    _savePlayCounts();
    notifyListeners();
  }

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
      _errorController.add('Invalid playlist or start index');
      return;
    }

    _playlist = songs;
    _currentIndex = startIndex;

    if (_gaplessPlayback) {
      final playlistSource = ConcatenatingAudioSource(
        children: _playlist.map((song) => AudioSource.uri(
          Uri.parse(song.uri ?? song.data),
          tag: MediaItem(
            id: song.id.toString(),
            album: song.album ?? 'Unknown Album',
            title: song.title,
            artist: song.artist ?? 'Unknown Artist',
            duration: Duration(milliseconds: song.duration ?? 0),
          ),
        )).toList(),
      );
      await _audioPlayer.setAudioSource(
        playlistSource,
        initialIndex: _currentIndex,
        initialPosition: Duration.zero,
      );
    }

    await play();
  } catch (e) {
    _errorController.add('Failed to set playlist: $e');
    notifyListeners();
  }
}

Future<void> updatePlaylist(List<SongModel> newSongs) async {
  try {
    if (_gaplessPlayback && _audioPlayer.audioSource is ConcatenatingAudioSource) {
      final newSource = ConcatenatingAudioSource(
        children: newSongs.map((song) => AudioSource.uri(
          Uri.parse(song.uri ?? song.data),
          tag: MediaItem(
            id: song.id.toString(),
            album: song.album ?? 'Unknown Album',
            title: song.title,
            artist: song.artist ?? 'Unknown Artist',
            duration: Duration(milliseconds: song.duration ?? 0),
          ),
        )).toList(),
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
      notifyListeners();
    } else {
      _playlist = newSongs;
      _currentIndex = 0;
      await setPlaylist(newSongs, 0);
    }
  } catch (e) {
    _errorController.add('Failed to update playlist: $e');
    notifyListeners();
  }
}

  Future<void> play({int? index}) async {
    try {
      if (index != null) {
        _currentIndex = index;
      }

      if (_currentIndex >= 0 && _currentIndex < _playlist.length) {
        final song = _playlist[_currentIndex];

        if (_gaplessPlayback) {
          await _audioPlayer.seek(Duration.zero, index: _currentIndex);
          await _audioPlayer.play();
        } else {
          final url = song.uri ?? song.data;
          final artworkBytes = await getCurrentSongArtwork();
          Uri? artUri;
          if (artworkBytes != null) {
            final directory = await getApplicationDocumentsDirectory();
            final filePath = '${directory.path}/${song.id}_artwork.jpg';
            final file = File(filePath);
            await file.writeAsBytes(artworkBytes);
            artUri = Uri.file(filePath);
          }

          final mediaItem = MediaItem(
            id: song.id.toString(),
            album: song.album ?? 'Unknown Album',
            title: song.title,
            artist: song.artist ?? 'Unknown Artist',
            artUri: artUri,
            duration: Duration(milliseconds: song.duration ?? 0),
          );

          await _audioPlayer.setAudioSource(
            AudioSource.uri(Uri.parse(url), tag: mediaItem),
            preload: true,
          );
          await _audioPlayer.play();
        }

        _isPlaying = true;
        _incrementPlayCount(song);
        await updateCurrentArtwork();
        _currentSongController.add(song);
        currentSongNotifier.value = song;
        notifyListeners();
      }
    } catch (e) {
      _isPlaying = false;
      isPlayingNotifier.value = false;
      _currentSongController.addError('Failed to play song: $e');
      notifyListeners();
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
    notifyListeners();
  }

  Future<void> resume() async {
    if (_audioPlayer.playing) return;
    await _audioPlayer.play();
    _isPlaying = true;
    isPlayingNotifier.value = true;
    notifyListeners();
  }

  Future<void> stop() async {
    await _audioPlayer.stop();
    _isPlaying = false;
    isPlayingNotifier.value = false;
    notifyListeners();
  }

  void skip() async {
    int nextIndex = _currentIndex + 1;
    if (_isShuffle) {
      nextIndex = _getRandomIndex();
    } else if (nextIndex >= _playlist.length) {
      nextIndex = _isRepeat ? 0 : _currentIndex;
    }
    await play(index: nextIndex);
  }

  void back() async {
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
    notifyListeners();
  }

  void toggleRepeat() {
    _isRepeat = !_isRepeat;
    isRepeatNotifier.value = _isRepeat;
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
      return await _audioQuery.queryArtwork(
        currentSong!.id,
        ArtworkType.AUDIO,
        format: ArtworkFormat.JPEG,
        size: 1000,
      );
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
      final artwork = await _audioQuery.queryArtwork(
        currentSong!.id,
        ArtworkType.AUDIO,
        format: ArtworkFormat.JPEG,
        size: 1000,
      );
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

  void setSleepTimer(Duration duration) {
    cancelSleepTimer();
    _remainingTime = duration;
    _sleepTimerDuration = duration;
    _sleepTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingTime != null) {
        _remainingTime = _remainingTime! - const Duration(seconds: 1);
        if (_remainingTime!.inSeconds <= 0) {
          pause();
          cancelSleepTimer();
        }
        notifyListeners();
      }
    });
    notifyListeners();
  }

  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _remainingTime = null;
    _sleepTimerDuration = null;
    notifyListeners();
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

  void _updateLikedSongsPlaylist() async {
    final allSongs = await _audioQuery.querySongs();
    final likedSongs = allSongs
        .where((song) => _likedSongs.contains(song.id.toString()))
        .toList();

    _likedSongsPlaylist = Playlist(
      id: LIKED_SONGS_PLAYLIST_ID,
      name: _likedPlaylistName,
      songs: likedSongs,
    );

    notifyListeners();
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
    notifyListeners();
  }

  Playlist? get likedSongsPlaylist => _likedSongsPlaylist;

  Future<void> initializeWithSongs(List<SongModel> initialSongs) async {
    _songs = initialSongs;
    notifyListeners();
  }

  @override
  void dispose() {
    currentSongNotifier.dispose();
    _audioPlayer.dispose();
    _savePlayCounts();
    savePlaylists();
    _currentSongController.close();
    _errorController.close();
    _sleepTimer?.cancel();
    super.dispose();
  }

  // Ensure that _folderAccessCounts is correctly populated
  void _incrementFolderAccessCount(String folderPath) {
    _folderAccessCounts[folderPath] =
        (_folderAccessCounts[folderPath] ?? 0) + 1;
    notifyListeners();
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
      notifyListeners();
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
      _autoPlaylists = json['autoPlaylists'] ?? true;
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
      'autoPlaylists': _autoPlaylists,
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
                      artist: song.artist ?? 'Unknown Artist',
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
    notifyListeners();
  }

  Future<void> setVolumeNormalization(bool value) async {
    _volumeNormalization = value;
    await _applySettings();
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setPlaybackSpeed(double value) async {
    _playbackSpeed = value;
    await _applySettings();
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setDefaultSortOrder(String value) async {
    _defaultSortOrder = value;
    await _saveSettings();
    _sortPlaylist();
    notifyListeners();
  }

  Future<void> setAutoPlaylists(bool value) async {
    _autoPlaylists = value;
    await _saveSettings();
    if (_autoPlaylists) {
      _updateAutoPlaylists();
    } else {
      // Remove auto-generated playlists
      _playlists.removeWhere(
          (p) => p.id == 'most_played' || p.id == 'recently_added');
      savePlaylists();
    }
    notifyListeners();
  }

  Future<void> setCacheSize(int value) async {
    _cacheSize = value;
    await _saveSettings();
    await _manageCacheSize();
    notifyListeners();
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
                artist: currentSong.artist ?? 'Unknown Artist',
                artUri: Uri.parse('file://${currentSong.data}'),
              ),
            ),
          );
        }
      }
    }

    notifyListeners();
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
  final spotifyCacheDir = Directory('${directory.path}');

  int totalSize = 0;

  // Clean artwork cache
  if (await cacheDir.exists()) {
    final files = await cacheDir.list().toList();
    totalSize += files.fold<int>(0, (sum, file) =>
        sum + (file is File ? file.lengthSync() : 0));

    if (totalSize > _cacheSize * 1024 * 1024) {
      files.sort((a, b) => a.statSync().accessed.compareTo(b.statSync().accessed));
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
    final spotifyFiles = files.where((file) => file is File && file.path.endsWith('.mp3')).toList();
    totalSize += spotifyFiles.fold<int>(0, (sum, file) =>
        sum + (file is File ? file.lengthSync() : 0));

    if (totalSize > _cacheSize * 1024 * 1024) {
      spotifyFiles.sort((a, b) => a.statSync().accessed.compareTo(b.statSync().accessed));
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
    if (!_autoPlaylists) return;

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

      savePlaylists();
      notifyListeners();
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

      savePlaylists();
      notifyListeners();
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
