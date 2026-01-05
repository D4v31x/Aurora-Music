import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:on_audio_query/on_audio_query.dart';
import '../../services/audio_player_service.dart';

/// A mixin that provides common playback functionality for song lists.
/// 
/// This mixin handles:
/// - Playing all songs
/// - Shuffling songs
/// - Playing a specific song from a list
/// 
/// Usage:
/// ```dart
/// class _MyScreenState extends State<MyScreen> with PlaybackMixin {
///   @override
///   List<SongModel> get playableSongs => _allSongs;
/// }
/// ```
mixin PlaybackMixin<T extends StatefulWidget> on State<T> {
  /// The list of songs that can be played. Must be implemented.
  List<SongModel> get playableSongs;

  /// Play all songs starting from the first.
  void playAllSongs() {
    if (playableSongs.isEmpty) return;
    
    final audioService = Provider.of<AudioPlayerService>(context, listen: false);
    audioService.setPlaylist(playableSongs, 0);
  }
  
  /// Shuffle and play all songs.
  void shuffleAllSongs() {
    if (playableSongs.isEmpty) return;
    
    final shuffledSongs = List<SongModel>.from(playableSongs)..shuffle();
    final audioService = Provider.of<AudioPlayerService>(context, listen: false);
    audioService.setPlaylist(shuffledSongs, 0);
  }
  
  /// Play a specific song from the list.
  void playSong(SongModel song) {
    final audioService = Provider.of<AudioPlayerService>(context, listen: false);
    final songIndex = playableSongs.indexWhere((s) => s.id == song.id);
    
    if (songIndex >= 0) {
      audioService.setPlaylist(playableSongs, songIndex);
    }
  }
  
  /// Get the audio player service.
  AudioPlayerService get audioPlayerService {
    return Provider.of<AudioPlayerService>(context, listen: false);
  }
}
