import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import '../constants/animation_constants.dart';

class BackgroundBuilder {
  static Widget buildBackground(SongModel? currentSong, bool isDarkMode) {
    return RepaintBoundary(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400), // Slightly faster for better responsiveness
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDarkMode ? [
              // Dark blue to violet gradient for dark mode
              const Color(0xFF1A237E), // Dark blue
              const Color(0xFF311B92), // Dark violet
              const Color(0xFF512DA8), // Medium violet
              const Color(0xFF7B1FA2), // Purple
            ] : [
              // Light blue gradient for light mode
              const Color(0xFFE3F2FD), // Light blue
              const Color(0xFFBBDEFB), // Lighter blue
              const Color(0xFF90CAF9), // Medium light blue
              const Color(0xFF64B5F6), // Blue
            ],
          ),
        ),
      ),
    );
  }
}