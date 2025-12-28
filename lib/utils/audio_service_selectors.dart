import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:on_audio_query/on_audio_query.dart';
import '../services/audio_player_service.dart';
import '../models/playlist_model.dart';

/// Extension methods for efficient AudioPlayerService access
/// Use these to avoid unnecessary rebuilds by selecting specific properties
extension AudioPlayerServiceSelectors on BuildContext {
  /// Get the current song without listening to all changes
  /// Use this when you only need to react to song changes
  SongModel? watchCurrentSong() {
    return select<AudioPlayerService, SongModel?>((s) => s.currentSong);
  }

  /// Get the playing state efficiently
  bool watchIsPlaying() {
    return select<AudioPlayerService, bool>((s) => s.isPlaying);
  }

  /// Get shuffle state efficiently
  bool watchIsShuffle() {
    return select<AudioPlayerService, bool>((s) => s.isShuffle);
  }

  /// Get repeat state efficiently
  bool watchIsRepeat() {
    return select<AudioPlayerService, bool>((s) => s.isRepeat);
  }

  /// Get the playlist without listening to all changes
  List<SongModel> watchPlaylist() {
    return select<AudioPlayerService, List<SongModel>>((s) => s.playlist);
  }

  /// Get the current index efficiently
  int watchCurrentIndex() {
    return select<AudioPlayerService, int>((s) => s.currentIndex);
  }

  /// Read the service without listening (for callbacks/events)
  AudioPlayerService readAudioService() {
    return read<AudioPlayerService>();
  }
}

/// Widget that efficiently listens only to the current song
class CurrentSongBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, SongModel? song) builder;

  const CurrentSongBuilder({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    return Selector<AudioPlayerService, SongModel?>(
      selector: (_, service) => service.currentSong,
      shouldRebuild: (prev, next) => prev?.id != next?.id,
      builder: (context, song, _) => builder(context, song),
    );
  }
}

/// Widget that efficiently listens only to playing state
class PlayingStateBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, bool isPlaying) builder;

  const PlayingStateBuilder({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    return Selector<AudioPlayerService, bool>(
      selector: (_, service) => service.isPlaying,
      builder: (context, isPlaying, _) => builder(context, isPlaying),
    );
  }
}

/// Widget that uses ValueListenableBuilder for even more efficient updates
/// This bypasses Provider entirely and uses direct ValueNotifier listening
class PlayingStateListenable extends StatelessWidget {
  final Widget Function(BuildContext context, bool isPlaying) builder;

  const PlayingStateListenable({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    final service = context.read<AudioPlayerService>();
    return ValueListenableBuilder<bool>(
      valueListenable: service.isPlayingNotifier,
      builder: (context, isPlaying, _) => builder(context, isPlaying),
    );
  }
}

/// Widget that uses ValueListenableBuilder for current song
class CurrentSongListenable extends StatelessWidget {
  final Widget Function(BuildContext context, SongModel? song) builder;

  const CurrentSongListenable({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    final service = context.read<AudioPlayerService>();
    return ValueListenableBuilder<SongModel?>(
      valueListenable: service.currentSongNotifier,
      builder: (context, song, _) => builder(context, song),
    );
  }
}

/// Efficient builder for shuffle state
class ShuffleStateListenable extends StatelessWidget {
  final Widget Function(BuildContext context, bool isShuffle) builder;

  const ShuffleStateListenable({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    final service = context.read<AudioPlayerService>();
    return ValueListenableBuilder<bool>(
      valueListenable: service.isShuffleNotifier,
      builder: (context, isShuffle, _) => builder(context, isShuffle),
    );
  }
}

/// Efficient builder for repeat state
class RepeatStateListenable extends StatelessWidget {
  final Widget Function(BuildContext context, bool isRepeat) builder;

  const RepeatStateListenable({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    final service = context.read<AudioPlayerService>();
    return ValueListenableBuilder<bool>(
      valueListenable: service.isRepeatNotifier,
      builder: (context, isRepeat, _) => builder(context, isRepeat),
    );
  }
}

/// Combined builder for playback controls (play, shuffle, repeat)
/// More efficient than rebuilding on every service change
class PlaybackControlsBuilder extends StatelessWidget {
  final Widget Function(
    BuildContext context,
    bool isPlaying,
    bool isShuffle,
    bool isRepeat,
  ) builder;

  const PlaybackControlsBuilder({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    final service = context.read<AudioPlayerService>();
    return ValueListenableBuilder<bool>(
      valueListenable: service.isPlayingNotifier,
      builder: (context, isPlaying, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: service.isShuffleNotifier,
          builder: (context, isShuffle, _) {
            return ValueListenableBuilder<bool>(
              valueListenable: service.isRepeatNotifier,
              builder: (context, isRepeat, _) {
                return builder(context, isPlaying, isShuffle, isRepeat);
              },
            );
          },
        );
      },
    );
  }
}

/// Efficient builder for songs list using ValueNotifier
/// Only rebuilds when the songs list actually changes
class SongsListListenable extends StatelessWidget {
  final Widget Function(BuildContext context, List<SongModel> songs) builder;

  const SongsListListenable({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    final service = context.read<AudioPlayerService>();
    return ValueListenableBuilder<List<SongModel>>(
      valueListenable: service.songsNotifier,
      builder: (context, songs, _) => builder(context, songs),
    );
  }
}

/// Efficient builder for playlists using ValueNotifier
class PlaylistsListenable extends StatelessWidget {
  final Widget Function(BuildContext context, List<Playlist> playlists) builder;

  const PlaylistsListenable({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    final service = context.read<AudioPlayerService>();
    return ValueListenableBuilder<List<Playlist>>(
      valueListenable: service.playlistsNotifier,
      builder: (context, playlists, _) => builder(context, playlists),
    );
  }
}
