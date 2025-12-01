import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';

/// Represents different song moods/vibes
enum SongMood {
  chill,      // Relaxed, ambient, lo-fi
  energetic,  // Upbeat, dance, pop
  aggressive, // Metal, hard rock, intense
  dnb,        // Drum and bass, fast electronic
  synthwave,  // Retro, 80s synth, vaporwave
  melancholic,// Sad, emotional, slow
  neutral,    // Default/unknown
}

/// Visual characteristics for each mood
class MoodTheme {
  final List<Color> accentColors;
  final double animationSpeed;
  final double blurIntensity;
  final double overlayOpacity;
  final Color overlayTint;

  const MoodTheme({
    required this.accentColors,
    required this.animationSpeed,
    required this.blurIntensity,
    required this.overlayOpacity,
    required this.overlayTint,
  });

  static MoodTheme forMood(SongMood mood) {
    switch (mood) {
      case SongMood.chill:
        return const MoodTheme(
          accentColors: [Color(0xFF4DB6AC), Color(0xFF81C784), Color(0xFF64B5F6)],
          animationSpeed: 0.3,
          blurIntensity: 50.0,
          overlayOpacity: 0.3,
          overlayTint: Color(0xFF1A237E),
        );
      case SongMood.energetic:
        return const MoodTheme(
          accentColors: [Color(0xFFFF7043), Color(0xFFFFCA28), Color(0xFFFF4081)],
          animationSpeed: 1.5,
          blurIntensity: 35.0,
          overlayOpacity: 0.2,
          overlayTint: Color(0xFFE65100),
        );
      case SongMood.aggressive:
        return const MoodTheme(
          accentColors: [Color(0xFFD32F2F), Color(0xFF8E24AA), Color(0xFF212121)],
          animationSpeed: 2.0,
          blurIntensity: 30.0,
          overlayOpacity: 0.4,
          overlayTint: Color(0xFF4A0000),
        );
      case SongMood.dnb:
        return const MoodTheme(
          accentColors: [Color(0xFF00BCD4), Color(0xFF7C4DFF), Color(0xFF00E676)],
          animationSpeed: 2.5,
          blurIntensity: 25.0,
          overlayOpacity: 0.25,
          overlayTint: Color(0xFF1A1A2E),
        );
      case SongMood.synthwave:
        return const MoodTheme(
          accentColors: [Color(0xFFE040FB), Color(0xFF00FFFF), Color(0xFFFF6EC7)],
          animationSpeed: 0.8,
          blurIntensity: 40.0,
          overlayOpacity: 0.35,
          overlayTint: Color(0xFF2D1B4E),
        );
      case SongMood.melancholic:
        return const MoodTheme(
          accentColors: [Color(0xFF5C6BC0), Color(0xFF78909C), Color(0xFF90A4AE)],
          animationSpeed: 0.2,
          blurIntensity: 55.0,
          overlayOpacity: 0.4,
          overlayTint: Color(0xFF263238),
        );
      case SongMood.neutral:
        return const MoodTheme(
          accentColors: [Color(0xFF7986CB), Color(0xFF9575CD), Color(0xFF64B5F6)],
          animationSpeed: 0.5,
          blurIntensity: 45.0,
          overlayOpacity: 0.3,
          overlayTint: Color(0xFF1A1A2E),
        );
    }
  }
}

/// Service that detects the mood/vibe of a song based on metadata
class MoodDetectionService extends ChangeNotifier {
  SongMood _currentMood = SongMood.neutral;
  MoodTheme _currentTheme = MoodTheme.forMood(SongMood.neutral);

  SongMood get currentMood => _currentMood;
  MoodTheme get currentTheme => _currentTheme;

  /// Keywords associated with each mood for genre/title matching
  static const Map<SongMood, List<String>> _moodKeywords = {
    SongMood.chill: [
      'chill', 'lofi', 'lo-fi', 'ambient', 'relaxing', 'calm', 'jazz',
      'acoustic', 'soft', 'smooth', 'easy listening', 'downtempo',
      'trip-hop', 'chillout', 'bossa', 'meditation', 'sleep', 'study',
    ],
    SongMood.energetic: [
      'dance', 'pop', 'edm', 'house', 'party', 'upbeat', 'disco',
      'funk', 'energy', 'workout', 'fitness', 'club', 'electro',
      'techno', 'trance', 'rave', 'bounce', 'happy',
    ],
    SongMood.aggressive: [
      'metal', 'heavy', 'death', 'black', 'thrash', 'hardcore',
      'hard rock', 'grindcore', 'deathcore', 'metalcore', 'nu-metal',
      'industrial', 'angry', 'rage', 'scream', 'brutal', 'doom',
    ],
    SongMood.dnb: [
      'drum and bass', 'dnb', 'd&b', 'jungle', 'breakbeat', 'liquid',
      'neurofunk', 'jump up', 'drumstep', 'breakcore', 'drill',
      'bass', 'dubstep', 'riddim', 'brostep', '170', '174',
    ],
    SongMood.synthwave: [
      'synthwave', 'synth', 'retro', '80s', 'vaporwave', 'outrun',
      'retrowave', 'darksynth', 'cyberpunk', 'neon', 'electronic',
      'new wave', 'electropop', 'chiptune', 'future funk',
    ],
    SongMood.melancholic: [
      'sad', 'melancholy', 'emotional', 'ballad', 'slow', 'blues',
      'heartbreak', 'lonely', 'dark', 'moody', 'somber', 'grief',
      'depressing', 'crying', 'tear', 'pain', 'emo',
    ],
  };

  /// Analyze a song and detect its mood
  Future<SongMood> analyzeSong(SongModel? song) async {
    if (song == null) {
      _setMood(SongMood.neutral);
      return SongMood.neutral;
    }

    final mood = _detectMoodFromMetadata(song);
    _setMood(mood);
    return mood;
  }

  /// Detect mood from song metadata (genre, title, artist, album)
  SongMood _detectMoodFromMetadata(SongModel song) {
    // Combine all searchable text
    final searchText = [
      song.genre ?? '',
      song.title,
      song.artist ?? '',
      song.album ?? '',
    ].join(' ').toLowerCase();

    // Count matches for each mood
    final moodScores = <SongMood, int>{};

    for (final entry in _moodKeywords.entries) {
      int score = 0;
      for (final keyword in entry.value) {
        if (searchText.contains(keyword.toLowerCase())) {
          // Longer keywords get higher scores (more specific)
          score += keyword.length;
        }
      }
      if (score > 0) {
        moodScores[entry.key] = score;
      }
    }

    // Return the mood with highest score, or neutral if none found
    if (moodScores.isEmpty) {
      return SongMood.neutral;
    }

    return moodScores.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
  }

  /// Set the current mood and notify listeners
  void _setMood(SongMood mood) {
    if (_currentMood != mood) {
      _currentMood = mood;
      _currentTheme = MoodTheme.forMood(mood);
      notifyListeners();
    }
  }

  /// Manually set mood (for testing or user override)
  void setMood(SongMood mood) {
    _setMood(mood);
  }

  /// Reset to neutral mood
  void reset() {
    _setMood(SongMood.neutral);
  }
}
