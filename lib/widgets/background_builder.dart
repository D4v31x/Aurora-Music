import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'app_background.dart';

/// @deprecated Use AppBackground widget directly for consistent backgrounds
class BackgroundBuilder {
  static Widget buildBackground(SongModel? currentSong, bool isDarkMode) {
    // This method is deprecated. Use AppBackground widget directly.
    return AppBackground(
      child: Container(), // Empty container as the background is provided by AppBackground
    );
  }
}