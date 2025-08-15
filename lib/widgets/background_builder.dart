import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:mesh/mesh.dart';
import '../constants/animation_constants.dart';

class BackgroundBuilder {
  static Widget buildBackground(SongModel? currentSong, bool isDarkMode) {
    return RepaintBoundary(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400), // Slightly faster for better responsiveness
        child: OMeshGradient(
          mesh: OMeshRect(
            width: 2,
            height: 2,
            fallbackColor: isDarkMode ? const Color(0xFF1A237E) : const Color(0xFFE3F2FD),
            vertices: [
              // Top-left corner
              (0.0, 0.0).v.to(isDarkMode ? const Color(0xFF1A237E) : const Color(0xFFE3F2FD)),
              // Top-right corner  
              (1.0, 0.0).v.to(isDarkMode ? const Color(0xFF311B92) : const Color(0xFFBBDEFB)),
              // Bottom-left corner
              (0.0, 1.0).v.to(isDarkMode ? const Color(0xFF512DA8) : const Color(0xFF90CAF9)),
              // Bottom-right corner
              (1.0, 1.0).v.to(isDarkMode ? const Color(0xFF7B1FA2) : const Color(0xFF64B5F6)),
            ],
          ),
        ),
      ),
    );
  }
}