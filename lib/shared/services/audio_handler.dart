import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query/on_audio_query.dart';
import '../models/playlist_model.dart';
import 'audio_constants.dart';

/// Custom audio handler that provides background playback with customized notification
/// Shows only: previous, play/pause, next (NO stop button)
class AuroraAudioHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer player;

  /// Guard to prevent intermediate currentIndexStream events from
  /// overriding the correct mediaItem during setAudioSource calls.
  bool _suppressIndexUpdates = false;

  // ── Android Auto browse-tree categories ──────────────────────────────────
  static const String _aaSongs = '__aa_songs__';
  static const String _aaAlbums = '__aa_albums__';
  static const String _aaArtists = '__aa_artists__';
  static const String _aaPlaylists = '__aa_playlists__';

  // Callbacks wired from AudioPlayerService._init() to avoid a circular import.
  List<SongModel> Function()? _aaGetSongs;
  List<Playlist> Function()? _aaGetPlaylists;
  bool Function()? _aaGetIsShuffle;
  LoopMode Function()? _aaGetLoopMode;
  Future<void> Function(List<SongModel> songs, int index)? _aaPlaySongs;
  Future<void> Function()? _aaResume;
  void Function()? _aaToggleShuffle;
  void Function()? _aaToggleRepeat;

  AuroraAudioHandler(this.player) {
    // Broadcast playback state changes.
    // playbackEventStream covers processingState, position, and buffered
    // position changes; playingStream covers play/pause toggles.
    // processingStateStream is intentionally omitted — it is a strict subset
    // of playbackEventStream and subscribing to all three caused _broadcastState
    // to fire 2-3× per state change, flooding the system notification pipeline.
    player.playbackEventStream.listen((_) {
      _broadcastState();
    });

    player.playingStream.listen((_) {
      _broadcastState();
    });

    // Broadcast current media item changes based on index
    player.currentIndexStream.listen((index) {
      if (_suppressIndexUpdates) return;
      if (index != null &&
          queue.value.isNotEmpty &&
          index < queue.value.length) {
        mediaItem.add(queue.value[index]);
      }
    });
  }

  /// Suppress automatic mediaItem updates from currentIndexStream.
  /// Call before setAudioSource to prevent intermediate index 0 from
  /// overriding the correct mediaItem.
  void suppressIndexUpdates() {
    _suppressIndexUpdates = true;
  }

  /// Resume automatic mediaItem updates from currentIndexStream.
  void resumeIndexUpdates() {
    _suppressIndexUpdates = false;
  }

  /// Broadcast current playback state to notification
  void _broadcastState() {
    playbackState.add(PlaybackState(
      // Only these 3 controls - NO stop button!
      controls: [
        MediaControl.skipToPrevious,
        if (player.playing) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      // Show all 3 buttons in compact notification view
      androidCompactActionIndices: const [0, 1, 2],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[player.processingState]!,
      playing: player.playing,
      updatePosition: player.position,
      bufferedPosition: player.bufferedPosition,
      speed: player.speed,
      queueIndex: player.currentIndex,
      // Reflect shuffle/repeat so Android Auto controls stay in sync
      shuffleMode: (_aaGetIsShuffle?.call() ?? false)
          ? AudioServiceShuffleMode.all
          : AudioServiceShuffleMode.none,
      repeatMode: switch (_aaGetLoopMode?.call() ?? LoopMode.off) {
        LoopMode.one => AudioServiceRepeatMode.one,
        LoopMode.all => AudioServiceRepeatMode.all,
        _ => AudioServiceRepeatMode.none,
      },
    ));
  }

  @override
  Future<void> play() => player.play();

  @override
  Future<void> pause() => player.pause();

  @override
  Future<void> seek(Duration position) => player.seek(position);

  @override
  Future<void> skipToNext() async {
    final currentIndex = player.currentIndex ?? 0;
    final queueLength = queue.value.length;

    if (player.loopMode == LoopMode.one) {
      // Repeat ONE: restart the current track.
      await player.seek(Duration.zero);
      return;
    }

    if (currentIndex < queueLength - 1) {
      await player.seek(Duration.zero, index: currentIndex + 1);
    } else if (player.loopMode == LoopMode.all && queueLength > 0) {
      // Repeat ALL: wrap back to the beginning.
      await player.seek(Duration.zero, index: 0);
      // play() in just_audio ^0.10.x completes when interrupted, not when
      // it starts, so fire-and-forget to avoid blocking the handler.
      unawaited(player.play());
    }
    // Repeat OFF at end: do nothing — let the completion handler stop playback.
  }

  @override
  Future<void> skipToPrevious() async {
    final currentIndex = player.currentIndex ?? 0;
    final position = player.position;

    // If more than the threshold has elapsed, restart the current track.
    if (position.inSeconds > kPreviousThresholdSeconds) {
      await player.seek(Duration.zero);
      return;
    }

    if (currentIndex > 0) {
      await player.seek(Duration.zero, index: currentIndex - 1);
    } else if (player.loopMode == LoopMode.all && queue.value.isNotEmpty) {
      // Repeat ALL at the first track: jump to the last track.
      await player.seek(Duration.zero, index: queue.value.length - 1);
    } else {
      // Repeat OFF / ONE at the first track: restart.
      await player.seek(Duration.zero);
    }
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index >= 0 && index < queue.value.length) {
      await player.seek(Duration.zero, index: index);
    }
  }

  @override
  Future<void> setSpeed(double speed) => player.setSpeed(speed);

  @override
  Future<void> stop() async {
    await player.stop();
    await super.stop();
  }

  /// Set the audio source with queue
  Future<void> setAudioSource(AudioSource source,
      {int initialIndex = 0}) async {
    await player.setAudioSource(source, initialIndex: initialIndex);
  }

  /// Wire up Android Auto delegate callbacks.
  /// Must be called from AudioPlayerService after it is fully initialised.
  void attachAndroidAutoCallbacks({
    required List<SongModel> Function() getSongs,
    required List<Playlist> Function() getPlaylists,
    required bool Function() getIsShuffle,
    required LoopMode Function() getLoopMode,
    required Future<void> Function(List<SongModel> songs, int index) playSongs,
    required Future<void> Function() resume,
    required void Function() toggleShuffle,
    required void Function() toggleRepeat,
  }) {
    _aaGetSongs = getSongs;
    _aaGetPlaylists = getPlaylists;
    _aaGetIsShuffle = getIsShuffle;
    _aaGetLoopMode = getLoopMode;
    _aaPlaySongs = playSongs;
    _aaResume = resume;
    _aaToggleShuffle = toggleShuffle;
    _aaToggleRepeat = toggleRepeat;
  }

  // ── Android Auto: browse tree ─────────────────────────────────────────────

  @override
  Future<List<MediaItem>> getChildren(
    String parentMediaId, [
    Map<String, dynamic>? options,
  ]) async {
    final songs = _aaGetSongs?.call() ?? [];
    final playlists = _aaGetPlaylists?.call() ?? [];
    final aoq = OnAudioQuery();

    switch (parentMediaId) {
      // Root: four top-level categories shown in Android Auto
      case AudioService.browsableRootId:
        return [
          const MediaItem(
            id: _aaSongs,
            title: 'Songs',
            playable: false,
            extras: {'android.media.browse.CONTENT_STYLE_BROWSABLE_HINT': 2},
          ),
          const MediaItem(
            id: _aaAlbums,
            title: 'Albums',
            playable: false,
            extras: {'android.media.browse.CONTENT_STYLE_BROWSABLE_HINT': 1},
          ),
          const MediaItem(
            id: _aaArtists,
            title: 'Artists',
            playable: false,
            extras: {'android.media.browse.CONTENT_STYLE_BROWSABLE_HINT': 2},
          ),
          const MediaItem(
            id: _aaPlaylists,
            title: 'Playlists',
            playable: false,
            extras: {'android.media.browse.CONTENT_STYLE_BROWSABLE_HINT': 2},
          ),
        ];

      // Recent: current queue (shown on Android Auto home screen)
      case AudioService.recentRootId:
        return queue.value.take(10).toList();

      // All songs
      case _aaSongs:
        return songs
            .map((s) => _aaMediaItemFromSong(s, prefix: 'song'))
            .toList();

      // All albums
      case _aaAlbums:
        final albums = await aoq.queryAlbums(
          sortType: AlbumSortType.ALBUM,
          orderType: OrderType.ASC_OR_SMALLER,
          uriType: UriType.EXTERNAL,
        );
        return albums
            .map((album) => MediaItem(
                  id: 'album/${album.id}',
                  title: album.album,
                  artist: album.artist,
                  playable: false,
                  artUri: Uri.parse(
                    'content://media/external/audio/albumart/${album.id}',
                  ),
                  extras: {'trackCount': album.numOfSongs},
                ))
            .toList();

      // All artists
      case _aaArtists:
        final artists = await aoq.queryArtists(
          sortType: ArtistSortType.ARTIST,
          orderType: OrderType.ASC_OR_SMALLER,
          uriType: UriType.EXTERNAL,
        );
        return artists
            .map((artist) {
              // Find a representative song to use for artwork (grid view requires it)
              final candidates = songs.where((s) => s.artistId == artist.id);
              final rep = candidates.isEmpty ? null : candidates.first;
              return MediaItem(
                id: 'artist/${artist.id}',
                title: artist.artist,
                playable: false,
                artUri: rep?.albumId != null
                    ? Uri.parse(
                        'content://media/external/audio/albumart/${rep!.albumId}')
                    : null,
                extras: {'trackCount': artist.numberOfTracks ?? 0},
              );
            })
            .toList();

      // All playlists
      case _aaPlaylists:
        return playlists
            .map((pl) => MediaItem(
                  id: 'playlist/${pl.id}',
                  title: pl.name,
                  playable: false,
                  extras: {'trackCount': pl.songs.length},
                ))
            .toList();

      default:
        // Songs inside an album
        if (parentMediaId.startsWith('album/')) {
          final albumIdStr = parentMediaId.substring('album/'.length);
          final albumId = int.tryParse(albumIdStr);
          if (albumId == null) return [];
          var albumSongs =
              songs.where((s) => s.albumId == albumId).toList();
          if (albumSongs.isEmpty) {
            final all = await aoq.querySongs(
              orderType: OrderType.ASC_OR_SMALLER,
              uriType: UriType.EXTERNAL,
            );
            albumSongs = all.where((s) => s.albumId == albumId).toList();
          }
          return albumSongs
              .map((s) => _aaMediaItemFromSong(s, prefix: 'album/$albumIdStr'))
              .toList();
        }

        // Songs by an artist
        if (parentMediaId.startsWith('artist/')) {
          final artistIdStr = parentMediaId.substring('artist/'.length);
          final artistId = int.tryParse(artistIdStr);
          if (artistId == null) return [];
          var artistSongs =
              songs.where((s) => s.artistId == artistId).toList();
          if (artistSongs.isEmpty) {
            final all = await aoq.querySongs(
              orderType: OrderType.ASC_OR_SMALLER,
              uriType: UriType.EXTERNAL,
            );
            artistSongs = all.where((s) => s.artistId == artistId).toList();
          }
          return artistSongs
              .map(
                  (s) => _aaMediaItemFromSong(s, prefix: 'artist/$artistIdStr'))
              .toList();
        }

        // Songs in a playlist
        if (parentMediaId.startsWith('playlist/')) {
          final playlistId = parentMediaId.substring('playlist/'.length);
          final playlist =
              playlists.where((p) => p.id == playlistId).firstOrNull;
          if (playlist == null) return [];
          return playlist.songs
              .map((s) =>
                  _aaMediaItemFromSong(s, prefix: 'playlist/$playlistId'))
              .toList();
        }

        return [];
    }
  }

  MediaItem _aaMediaItemFromSong(SongModel song, {required String prefix}) {
    return MediaItem(
      id: '$prefix/${song.id}',
      title: song.title,
      artist: song.artist ?? 'Unknown Artist',
      album: song.album,
      duration: Duration(milliseconds: song.duration ?? 0),
      artUri: song.albumId != null
          ? Uri.parse(
              'content://media/external/audio/albumart/${song.albumId}',
            )
          : null,
    );
  }

  // ── Android Auto: start playback from browse selection ───────────────────

  @override
  Future<void> playFromMediaId(
    String mediaId, [
    Map<String, dynamic>? extras,
  ]) async {
    final playSongs = _aaPlaySongs;
    final resume = _aaResume;
    if (playSongs == null || resume == null) return;

    final parts = mediaId.split('/');
    if (parts.length < 2) return;
    final prefix = parts[0];
    final aoq = OnAudioQuery();

    switch (prefix) {
      case 'song':
        final songId = int.tryParse(parts[1]);
        if (songId == null) return;
        final allSongs = _aaGetSongs?.call() ?? [];
        final index = allSongs.indexWhere((s) => s.id == songId);
        if (index == -1) return;
        await playSongs(allSongs, index);
        await resume();

      case 'album':
        if (parts.length < 3) return;
        final albumId = int.tryParse(parts[1]);
        final songId = int.tryParse(parts[2]);
        if (albumId == null || songId == null) return;
        var albumSongs =
            (_aaGetSongs?.call() ?? []).where((s) => s.albumId == albumId).toList();
        if (albumSongs.isEmpty) {
          final all = await aoq.querySongs(
            orderType: OrderType.ASC_OR_SMALLER,
            uriType: UriType.EXTERNAL,
          );
          albumSongs = all.where((s) => s.albumId == albumId).toList();
        }
        if (albumSongs.isEmpty) return;
        final albumIdx = albumSongs.indexWhere((s) => s.id == songId);
        await playSongs(albumSongs, albumIdx.clamp(0, albumSongs.length - 1));
        await resume();

      case 'artist':
        if (parts.length < 3) return;
        final artistId = int.tryParse(parts[1]);
        final songId = int.tryParse(parts[2]);
        if (artistId == null || songId == null) return;
        var artistSongs = (_aaGetSongs?.call() ?? [])
            .where((s) => s.artistId == artistId)
            .toList();
        if (artistSongs.isEmpty) {
          final all = await aoq.querySongs(
            orderType: OrderType.ASC_OR_SMALLER,
            uriType: UriType.EXTERNAL,
          );
          artistSongs = all.where((s) => s.artistId == artistId).toList();
        }
        if (artistSongs.isEmpty) return;
        final artistIdx = artistSongs.indexWhere((s) => s.id == songId);
        await playSongs(artistSongs, artistIdx.clamp(0, artistSongs.length - 1));
        await resume();

      case 'playlist':
        if (parts.length < 3) return;
        final playlistId = parts[1];
        final songId = int.tryParse(parts[2]);
        if (songId == null) return;
        final playlist = (_aaGetPlaylists?.call() ?? [])
            .where((p) => p.id == playlistId)
            .firstOrNull;
        if (playlist == null || playlist.songs.isEmpty) return;
        final plIdx = playlist.songs.indexWhere((s) => s.id == songId);
        await playSongs(
            playlist.songs, plIdx.clamp(0, playlist.songs.length - 1));
        await resume();
    }
  }

  // ── Android Auto: shuffle & repeat controls ────────────────────────────────

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    final toggle = _aaToggleShuffle;
    if (toggle == null) return;
    final wantShuffle = shuffleMode != AudioServiceShuffleMode.none;
    if (wantShuffle != (_aaGetIsShuffle?.call() ?? false)) toggle();
    _broadcastState();
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    final toggle = _aaToggleRepeat;
    if (toggle == null) return;
    final target = switch (repeatMode) {
      AudioServiceRepeatMode.one => LoopMode.one,
      AudioServiceRepeatMode.all ||
      AudioServiceRepeatMode.group =>
        LoopMode.all,
      _ => LoopMode.off,
    };
    // Cycle toggleRepeat (3 states) until we reach the target.
    for (var i = 0;
        (_aaGetLoopMode?.call() ?? LoopMode.off) != target && i < 3;
        i++) {
      toggle();
    }
    _broadcastState();
  }

  /// Update the notification with new media item
  void updateNotificationMediaItem(MediaItem item) {
    mediaItem.add(item);
    _broadcastState();
  }

  /// Update the queue for notification
  void updateNotificationQueue(List<MediaItem> items) {
    queue.add(items);
  }
}
