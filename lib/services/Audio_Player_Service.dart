import 'dart:async';
import 'package:aurora_music_v01/services/spotify_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:path_provider/path_provider.dart';
import '../models/utils.dart';
import 'dart:io';
import 'dart:convert';
import '../models/playlist_model.dart';
import 'package:just_audio_background/just_audio_background.dart';

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
  SongModel? get currentSong => _currentIndex >= 0 && _currentIndex < _playlist.length ? _playlist[_currentIndex] : null;
  final ValueNotifier<Uint8List?> currentArtwork = ValueNotifier(null);

  final StreamController<SongModel?> _currentSongController = StreamController<SongModel?>.broadcast();
  Stream<SongModel?> get currentSongStream => _currentSongController.stream;
  List<SpotifySongModel> _spotifyPlaylist = [];
  int _currentSpotifyIndex = 0;

  Timer? _sleepTimer;
  Duration? _remainingTime;
  Duration? _sleepTimerDuration;

  bool get isSleepTimerActive => _sleepTimer?.isActive ?? false;
  Duration? get remainingTime => _remainingTime;
  Duration? get sleepTimerDuration => _sleepTimerDuration;

  Set<String> _likedSongs = {};
  Playlist? _likedSongsPlaylist;

  AudioPlayerService() {
    _init();
    loadLibrary();
    initializeLikedSongsPlaylist();
    audioPlayer.playerStateStream.listen((playerState) {
      notifyListeners();
    });
  }

  Future<void> _init() async {
    await _loadPlayCounts();
    await _loadPlaylists();

    _audioPlayer.playerStateStream.listen((playerState) {
      _isPlaying = playerState.playing;
      notifyListeners();
    });

    _audioPlayer.positionStream.listen((position) {
      final duration = _audioPlayer.duration;
      if (duration != null && position >= duration) {
        skip();
      }
    });
  }

  // Playlist Management
  Future<void> _loadPlaylists() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/playlists.json');

    if (await file.exists()) {
      final contents = await file.readAsString();
      final json = jsonDecode(contents) as List;
      _playlists = json.map((playlistJson) => Playlist(
        id: playlistJson['id'],
        name: playlistJson['name'],
        songs: (playlistJson['songs'] as List).map((songJson) =>
            SongModel(songJson)).toList(),
      )).toList();
    }
  }

  Future<void> savePlaylists() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/playlists.json');

    final json = _playlists.map((playlist) => {
      'id': playlist.id,
      'name': playlist.name,
      'songs': playlist.songs.map((song) => song.getMap).toList(),
    }).toList();

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
      _playlists[playlistIndex] = _playlists[playlistIndex].copyWith(name: newName);
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
    _trackPlayCounts[song.id.toString()] = (_trackPlayCounts[song.id.toString()] ?? 0) + 1;

    if (song.albumId != null) {
      _albumPlayCounts[song.albumId.toString()] = (_albumPlayCounts[song.albumId.toString()] ?? 0) + 1;
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
      ..sort((a, b) => (_trackPlayCounts[b.id.toString()] ?? 0).compareTo(_trackPlayCounts[a.id.toString()] ?? 0));
    return sortedTracks.take(10).toList();
  }

  Future<List<AlbumModel>> getMostPlayedAlbums() async {
    final albums = await _audioQuery.queryAlbums();
    albums.sort((a, b) => (_albumPlayCounts[b.id.toString()] ?? 0).compareTo(_albumPlayCounts[a.id.toString()] ?? 0));
    return albums.take(10).toList();
  }

  Future<List<ArtistModel>> getMostPlayedArtists() async {
    final allArtists = await _audioQuery.queryArtists();
    final artistPlayCounts = <String, int>{};

    for (var artist in allArtists) {
      final artistNames = splitArtists(artist.artist ?? '');
      for (var name in artistNames) {
        artistPlayCounts[name] = (_artistPlayCounts[name] ?? 0);
      }
    }

    final sortedArtists = allArtists
      ..sort((a, b) => (artistPlayCounts[b.artist] ?? 0).compareTo(artistPlayCounts[a.artist] ?? 0));

    return sortedArtists.take(10).toList();
  }

  List<Playlist> getThreePlaylists() {
    final sortedPlaylists = _playlists.toList()
      ..sort((a, b) => (_playlistPlayCounts[b.id] ?? 0).compareTo(_playlistPlayCounts[a.id] ?? 0));
    return sortedPlaylists.take(3).toList();
  }

  List<String> getThreeFolders() {
    final sortedFolders = _folderAccessCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sortedFolders.take(3).map((entry) => entry.key).toList();
  }

  // Playback Control
  Future<void> setPlaylist(List<SongModel> songs, int initialIndex) async {
    _playlist = songs;
    _currentIndex = initialIndex;
    await play();
  }

  Future<void> play({int? index}) async {
    if (index != null) {
      _currentIndex = index;
    }
    if (_currentIndex >= 0 && _currentIndex < _playlist.length) {
      final song = _playlist[_currentIndex];
      final url = song.uri;

      if (url != null) {
        // Fetch artwork if available, otherwise default to null
        final artworkBytes = await getCurrentSongArtwork();
        Uri? artUri;
        if (artworkBytes != null) {
          // Store artwork locally and create a file Uri for it
          final directory = await getApplicationDocumentsDirectory();
          final filePath = '${directory.path}/${song.id}_artwork.jpg';
          final file = File(filePath);
          await file.writeAsBytes(artworkBytes);
          artUri = Uri.file(filePath);
        }

        // Create the MediaItem with actual artwork or null
        final mediaItem = MediaItem(
          id: song.id.toString(),
          album: song.album ?? 'Unknown Album',
          title: song.title ?? 'Unknown Title',
          artist: song.artist ?? 'Unknown Artist',
          artUri: artUri, // Use the local artwork Uri or null if not available
          duration: Duration(milliseconds: song.duration ?? 0),
        );

        // Set the audio source with the media item tag
        await _audioPlayer.setAudioSource(
          AudioSource.uri(
            Uri.parse(url),
            tag: mediaItem,
          ),
          preload: true,
        );

        // Start playback
        await _audioPlayer.play();

        // Track play count, update the current artwork, and notify listeners
        _isPlaying = true;
        _incrementPlayCount(song);
        await updateCurrentArtwork();
        _currentSongController.add(song);
        notifyListeners();
      } else {
        
      }
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
      children: _spotifyPlaylist.map((song) =>
          AudioSource.uri(
              Uri.parse(song.uri),
              tag: song.toMediaItem()
          )
      ).toList(),
    );

    audioPlayer.setAudioSource(playlist, initialIndex: _currentSpotifyIndex);
  }

  Future<void> playSpotifySong() async {
    if (_spotifyPlaylist.isEmpty) return;

    final currentSong = _spotifyPlaylist[_currentSpotifyIndex];
    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/${currentSong.id}.mp3';
    final file = File(filePath);

    if (!await file.exists()) {
      final downloadedFilePath = await SpotifyService().downloadSpotifySong(currentSong.id);
      if (downloadedFilePath != null) {
        final mediaItem = MediaItem(
          id: currentSong.id,
          album: currentSong.album,
          title: currentSong.title,
          artist: currentSong.artist,
          duration: Duration(milliseconds: currentSong.duration),
          artUri: Uri.parse(currentSong.artworkUrl),
        );
        await audioPlayer.setAudioSource(AudioSource.uri(Uri.file(downloadedFilePath), tag: mediaItem));
      } else {
        
        return;
      }
    } else {
      final mediaItem = MediaItem(
        id: currentSong.id,
        album: currentSong.album,
        title: currentSong.title,
        artist: currentSong.artist,
        duration: Duration(milliseconds: currentSong.duration),
        artUri: Uri.parse(currentSong.artworkUrl),
      );
      await audioPlayer.setAudioSource(AudioSource.uri(Uri.file(filePath), tag: mediaItem));
    }

    await audioPlayer.play();
    notifyListeners();
  }

  Future<void> pause() async {
    await _audioPlayer.pause();
    _isPlaying = false;
    notifyListeners();
  }

  Future<void> resume() async {
    if (_audioPlayer.playing) return;
    await _audioPlayer.play();
    _isPlaying = true;
    notifyListeners();
  }

  Future<void> stop() async {
    await _audioPlayer.stop();
    _isPlaying = false;
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
    notifyListeners();
  }

  void toggleRepeat() {
    _isRepeat = !_isRepeat;
    notifyListeners();
  }

  int _getRandomIndex() {
    if (_playlist.length <= 1) return _currentIndex;
    int newIndex;
    do {
      newIndex = (DateTime.now().millisecondsSinceEpoch % _playlist.length).toInt();
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
    final likedSongs = allSongs.where((song) => _likedSongs.contains(song.id.toString())).toList();
    
    _likedSongsPlaylist = Playlist(
      id: 'liked_songs',
      name: 'Oblíbené skladby',
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

  @override
  void dispose() {
    _audioPlayer.dispose();
    _savePlayCounts();
    savePlaylists();
    _currentSongController.close();
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