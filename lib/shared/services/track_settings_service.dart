/// Per-track playback settings service.
///
/// Provides fine-grained control over individual track playback,
/// including volume normalization, skip settings, and exclusions.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Playback settings for an individual track
class TrackPlaybackSettings {
  /// Volume adjustment (-1.0 to 1.0, where 0.0 is no adjustment)
  final double volumeAdjustment;

  /// Custom playback speed (0.5 to 2.0)
  final double? playbackSpeed;

  /// Seconds to skip at the beginning of the track
  final int skipIntroSeconds;

  /// Seconds to skip at the end of the track
  final int skipOutroSeconds;

  /// Exclude from smart suggestions
  final bool excludeFromSuggestions;

  /// Exclude from "most played" statistics
  final bool excludeFromStats;

  const TrackPlaybackSettings({
    this.volumeAdjustment = 0.0,
    this.playbackSpeed,
    this.skipIntroSeconds = 0,
    this.skipOutroSeconds = 0,
    this.excludeFromSuggestions = false,
    this.excludeFromStats = false,
  });

  bool get hasCustomSettings =>
      volumeAdjustment != 0.0 ||
      playbackSpeed != null ||
      skipIntroSeconds > 0 ||
      skipOutroSeconds > 0 ||
      excludeFromSuggestions ||
      excludeFromStats;

  TrackPlaybackSettings copyWith({
    double? volumeAdjustment,
    double? playbackSpeed,
    bool clearPlaybackSpeed = false,
    int? skipIntroSeconds,
    int? skipOutroSeconds,
    bool? excludeFromSuggestions,
    bool? excludeFromStats,
  }) {
    return TrackPlaybackSettings(
      volumeAdjustment: volumeAdjustment ?? this.volumeAdjustment,
      playbackSpeed:
          clearPlaybackSpeed ? null : (playbackSpeed ?? this.playbackSpeed),
      skipIntroSeconds: skipIntroSeconds ?? this.skipIntroSeconds,
      skipOutroSeconds: skipOutroSeconds ?? this.skipOutroSeconds,
      excludeFromSuggestions:
          excludeFromSuggestions ?? this.excludeFromSuggestions,
      excludeFromStats: excludeFromStats ?? this.excludeFromStats,
    );
  }

  Map<String, dynamic> toJson() => {
        'volumeAdjustment': volumeAdjustment,
        'playbackSpeed': playbackSpeed,
        'skipIntroSeconds': skipIntroSeconds,
        'skipOutroSeconds': skipOutroSeconds,
        'excludeFromSuggestions': excludeFromSuggestions,
        'excludeFromStats': excludeFromStats,
      };

  factory TrackPlaybackSettings.fromJson(Map<String, dynamic> json) {
    return TrackPlaybackSettings(
      volumeAdjustment: (json['volumeAdjustment'] ?? 0.0).toDouble(),
      playbackSpeed: json['playbackSpeed']?.toDouble(),
      skipIntroSeconds: json['skipIntroSeconds'] ?? 0,
      skipOutroSeconds: json['skipOutroSeconds'] ?? 0,
      excludeFromSuggestions: json['excludeFromSuggestions'] ?? false,
      excludeFromStats: json['excludeFromStats'] ?? false,
    );
  }
}

/// Playback settings for an album
class AlbumPlaybackSettings {
  /// Volume adjustment for all tracks in album
  final double volumeAdjustment;

  /// Apply gapless playback within this album
  final bool gaplessWithinAlbum;

  const AlbumPlaybackSettings({
    this.volumeAdjustment = 0.0,
    this.gaplessWithinAlbum = true,
  });

  bool get hasCustomSettings =>
      volumeAdjustment != 0.0 || !gaplessWithinAlbum;

  Map<String, dynamic> toJson() => {
        'volumeAdjustment': volumeAdjustment,
        'gaplessWithinAlbum': gaplessWithinAlbum,
      };

  factory AlbumPlaybackSettings.fromJson(Map<String, dynamic> json) {
    return AlbumPlaybackSettings(
      volumeAdjustment: (json['volumeAdjustment'] ?? 0.0).toDouble(),
      gaplessWithinAlbum: json['gaplessWithinAlbum'] ?? true,
    );
  }
}

/// Service for managing per-track and per-album playback settings
class TrackSettingsService extends ChangeNotifier {
  final Map<String, TrackPlaybackSettings> _trackSettings = {};
  final Map<String, AlbumPlaybackSettings> _albumSettings = {};
  bool _initialized = false;

  /// Initialize the service and load saved settings
  Future<void> initialize() async {
    if (_initialized) return;
    await _loadSettings();
    _initialized = true;
  }

  /// Get track-specific playback settings
  TrackPlaybackSettings getTrackSettings(String trackId) {
    return _trackSettings[trackId] ?? const TrackPlaybackSettings();
  }

  /// Set track-specific playback settings
  Future<void> setTrackSettings(
      String trackId, TrackPlaybackSettings settings) async {
    if (settings.hasCustomSettings) {
      _trackSettings[trackId] = settings;
    } else {
      _trackSettings.remove(trackId);
    }
    await _saveSettings();
    notifyListeners();
  }

  /// Update a single track setting
  Future<void> updateTrackSetting(
    String trackId, {
    double? volumeAdjustment,
    double? playbackSpeed,
    bool clearPlaybackSpeed = false,
    int? skipIntroSeconds,
    int? skipOutroSeconds,
    bool? excludeFromSuggestions,
    bool? excludeFromStats,
  }) async {
    final current = getTrackSettings(trackId);
    final updated = current.copyWith(
      volumeAdjustment: volumeAdjustment,
      playbackSpeed: playbackSpeed,
      clearPlaybackSpeed: clearPlaybackSpeed,
      skipIntroSeconds: skipIntroSeconds,
      skipOutroSeconds: skipOutroSeconds,
      excludeFromSuggestions: excludeFromSuggestions,
      excludeFromStats: excludeFromStats,
    );
    await setTrackSettings(trackId, updated);
  }

  /// Remove all custom settings for a track
  Future<void> removeTrackSettings(String trackId) async {
    _trackSettings.remove(trackId);
    await _saveSettings();
    notifyListeners();
  }

  /// Get album-specific playback settings
  AlbumPlaybackSettings getAlbumSettings(String albumId) {
    return _albumSettings[albumId] ?? const AlbumPlaybackSettings();
  }

  /// Set album-specific playback settings
  Future<void> setAlbumSettings(
      String albumId, AlbumPlaybackSettings settings) async {
    if (settings.hasCustomSettings) {
      _albumSettings[albumId] = settings;
    } else {
      _albumSettings.remove(albumId);
    }
    await _saveSettings();
    notifyListeners();
  }

  /// Update album volume adjustment
  Future<void> setAlbumVolumeAdjustment(
      String albumId, double adjustment) async {
    final current = getAlbumSettings(albumId);
    await setAlbumSettings(
      albumId,
      AlbumPlaybackSettings(
        volumeAdjustment: adjustment,
        gaplessWithinAlbum: current.gaplessWithinAlbum,
      ),
    );
  }

  /// Check if a track should be excluded from suggestions
  bool isExcludedFromSuggestions(String trackId) {
    return _trackSettings[trackId]?.excludeFromSuggestions ?? false;
  }

  /// Check if a track should be excluded from stats
  bool isExcludedFromStats(String trackId) {
    return _trackSettings[trackId]?.excludeFromStats ?? false;
  }

  /// Get all tracks that are excluded from suggestions
  Set<String> get tracksExcludedFromSuggestions {
    return _trackSettings.entries
        .where((e) => e.value.excludeFromSuggestions)
        .map((e) => e.key)
        .toSet();
  }

  /// Get all tracks that are excluded from stats
  Set<String> get tracksExcludedFromStats {
    return _trackSettings.entries
        .where((e) => e.value.excludeFromStats)
        .map((e) => e.key)
        .toSet();
  }

  /// Calculate effective volume for a track (considering album settings)
  double getEffectiveVolume(String trackId, String? albumId) {
    double volume = 1.0;

    // Apply album adjustment first
    if (albumId != null) {
      final albumSettings = _albumSettings[albumId];
      if (albumSettings != null) {
        volume += albumSettings.volumeAdjustment;
      }
    }

    // Apply track adjustment
    final trackSettings = _trackSettings[trackId];
    if (trackSettings != null) {
      volume += trackSettings.volumeAdjustment;
    }

    // Clamp to valid range
    return volume.clamp(0.0, 2.0);
  }

  /// Get skip intro duration for a track
  Duration getSkipIntroDuration(String trackId) {
    final settings = _trackSettings[trackId];
    if (settings == null || settings.skipIntroSeconds <= 0) {
      return Duration.zero;
    }
    return Duration(seconds: settings.skipIntroSeconds);
  }

  /// Get skip outro duration for a track
  Duration getSkipOutroDuration(String trackId) {
    final settings = _trackSettings[trackId];
    if (settings == null || settings.skipOutroSeconds <= 0) {
      return Duration.zero;
    }
    return Duration(seconds: settings.skipOutroSeconds);
  }

  /// Get custom playback speed for a track (null = use global)
  double? getCustomPlaybackSpeed(String trackId) {
    return _trackSettings[trackId]?.playbackSpeed;
  }

  /// Export settings as JSON for backup
  Map<String, dynamic> exportSettings() {
    return {
      'trackSettings':
          _trackSettings.map((key, value) => MapEntry(key, value.toJson())),
      'albumSettings':
          _albumSettings.map((key, value) => MapEntry(key, value.toJson())),
      'exportDate': DateTime.now().toIso8601String(),
    };
  }

  /// Import settings from backup JSON
  Future<void> importSettings(Map<String, dynamic> json) async {
    final trackSettingsJson = json['trackSettings'] as Map<String, dynamic>?;
    if (trackSettingsJson != null) {
      _trackSettings.clear();
      for (final entry in trackSettingsJson.entries) {
        _trackSettings[entry.key] =
            TrackPlaybackSettings.fromJson(entry.value);
      }
    }

    final albumSettingsJson = json['albumSettings'] as Map<String, dynamic>?;
    if (albumSettingsJson != null) {
      _albumSettings.clear();
      for (final entry in albumSettingsJson.entries) {
        _albumSettings[entry.key] =
            AlbumPlaybackSettings.fromJson(entry.value);
      }
    }

    await _saveSettings();
    notifyListeners();
  }

  Future<void> _loadSettings() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/track_settings.json');

      if (await file.exists()) {
        final contents = await file.readAsString();
        final json = jsonDecode(contents) as Map<String, dynamic>;

        final trackSettingsJson = json['trackSettings'] as Map<String, dynamic>?;
        if (trackSettingsJson != null) {
          for (final entry in trackSettingsJson.entries) {
            _trackSettings[entry.key] =
                TrackPlaybackSettings.fromJson(entry.value);
          }
        }

        final albumSettingsJson = json['albumSettings'] as Map<String, dynamic>?;
        if (albumSettingsJson != null) {
          for (final entry in albumSettingsJson.entries) {
            _albumSettings[entry.key] =
                AlbumPlaybackSettings.fromJson(entry.value);
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading track settings: $e');
    }
  }

  Future<void> _saveSettings() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/track_settings.json');

      final json = {
        'trackSettings':
            _trackSettings.map((key, value) => MapEntry(key, value.toJson())),
        'albumSettings':
            _albumSettings.map((key, value) => MapEntry(key, value.toJson())),
      };

      await file.writeAsString(jsonEncode(json));
    } catch (e) {
      debugPrint('Error saving track settings: $e');
    }
  }
}
