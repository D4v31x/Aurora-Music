/// Crossfade service for smooth track transitions.
///
/// Provides configurable crossfade duration and smart detection
/// for live tracks, DJ mixes, and continuous tracks.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:path_provider/path_provider.dart';

/// Configuration for crossfade behavior
class CrossfadeConfig {
  /// Whether crossfade is enabled globally
  final bool enabled;

  /// Crossfade duration in seconds (2-5)
  final int durationSeconds;

  /// Whether to auto-detect and skip crossfade for live/continuous tracks
  final bool smartDetection;

  const CrossfadeConfig({
    this.enabled = false,
    this.durationSeconds = 3,
    this.smartDetection = true,
  });

  CrossfadeConfig copyWith({
    bool? enabled,
    int? durationSeconds,
    bool? smartDetection,
  }) {
    return CrossfadeConfig(
      enabled: enabled ?? this.enabled,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      smartDetection: smartDetection ?? this.smartDetection,
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'durationSeconds': durationSeconds,
        'smartDetection': smartDetection,
      };

  factory CrossfadeConfig.fromJson(Map<String, dynamic> json) {
    return CrossfadeConfig(
      enabled: json['enabled'] ?? false,
      durationSeconds: (json['durationSeconds'] ?? 3).clamp(2, 5),
      smartDetection: json['smartDetection'] ?? true,
    );
  }
}

/// Track-specific crossfade settings
class TrackCrossfadeSettings {
  /// Override global crossfade setting for this track
  final bool? crossfadeOverride;

  /// Mark as live recording (no crossfade)
  final bool isLive;

  /// Mark as DJ mix (no crossfade)
  final bool isDJMix;

  /// Mark as continuous/gapless album track
  final bool isContinuous;

  const TrackCrossfadeSettings({
    this.crossfadeOverride,
    this.isLive = false,
    this.isDJMix = false,
    this.isContinuous = false,
  });

  /// Whether crossfade should be disabled for this track
  bool get shouldDisableCrossfade =>
      isLive || isDJMix || isContinuous || crossfadeOverride == false;

  Map<String, dynamic> toJson() => {
        'crossfadeOverride': crossfadeOverride,
        'isLive': isLive,
        'isDJMix': isDJMix,
        'isContinuous': isContinuous,
      };

  factory TrackCrossfadeSettings.fromJson(Map<String, dynamic> json) {
    return TrackCrossfadeSettings(
      crossfadeOverride: json['crossfadeOverride'],
      isLive: json['isLive'] ?? false,
      isDJMix: json['isDJMix'] ?? false,
      isContinuous: json['isContinuous'] ?? false,
    );
  }
}

/// Service for managing crossfade settings and behavior
class CrossfadeService extends ChangeNotifier {
  CrossfadeConfig _config = const CrossfadeConfig();
  final Map<String, TrackCrossfadeSettings> _trackSettings = {};
  bool _initialized = false;

  CrossfadeConfig get config => _config;
  bool get isEnabled => _config.enabled;
  int get durationSeconds => _config.durationSeconds;
  Duration get duration => Duration(seconds: _config.durationSeconds);

  /// Initialize the service and load saved settings
  Future<void> initialize() async {
    if (_initialized) return;
    await _loadSettings();
    _initialized = true;
  }

  /// Enable or disable crossfade globally
  Future<void> setEnabled(bool enabled) async {
    _config = _config.copyWith(enabled: enabled);
    await _saveSettings();
    notifyListeners();
  }

  /// Set crossfade duration (2-5 seconds)
  Future<void> setDuration(int seconds) async {
    _config = _config.copyWith(durationSeconds: seconds.clamp(2, 5));
    await _saveSettings();
    notifyListeners();
  }

  /// Enable or disable smart detection
  Future<void> setSmartDetection(bool enabled) async {
    _config = _config.copyWith(smartDetection: enabled);
    await _saveSettings();
    notifyListeners();
  }

  /// Get track-specific settings
  TrackCrossfadeSettings? getTrackSettings(String trackId) {
    return _trackSettings[trackId];
  }

  /// Set track-specific crossfade settings
  Future<void> setTrackSettings(
      String trackId, TrackCrossfadeSettings settings) async {
    _trackSettings[trackId] = settings;
    await _saveSettings();
    notifyListeners();
  }

  /// Remove track-specific settings
  Future<void> removeTrackSettings(String trackId) async {
    _trackSettings.remove(trackId);
    await _saveSettings();
    notifyListeners();
  }

  /// Determine if crossfade should be applied between two tracks
  bool shouldCrossfade(SongModel? current, SongModel? next) {
    if (!_config.enabled) return false;
    if (current == null || next == null) return false;

    // Check current track settings
    final currentSettings = _trackSettings[current.id.toString()];
    if (currentSettings != null && currentSettings.shouldDisableCrossfade) {
      return false;
    }

    // Check next track settings
    final nextSettings = _trackSettings[next.id.toString()];
    if (nextSettings != null && nextSettings.shouldDisableCrossfade) {
      return false;
    }

    // Smart detection based on metadata
    if (_config.smartDetection) {
      if (_isLiveTrack(current) || _isLiveTrack(next)) return false;
      if (_isDJMix(current) || _isDJMix(next)) return false;
      if (_isContinuousAlbum(current, next)) return false;
    }

    return true;
  }

  /// Detect if a track appears to be a live recording
  bool _isLiveTrack(SongModel song) {
    final title = song.title.toLowerCase();
    final album = (song.album ?? '').toLowerCase();

    final liveIndicators = [
      'live',
      '(live)',
      '[live]',
      'concert',
      'in concert',
      'live at',
      'unplugged',
    ];

    for (final indicator in liveIndicators) {
      if (title.contains(indicator) || album.contains(indicator)) {
        return true;
      }
    }
    return false;
  }

  /// Detect if a track appears to be from a DJ mix
  bool _isDJMix(SongModel song) {
    final title = song.title.toLowerCase();
    final album = (song.album ?? '').toLowerCase();
    final artist = (song.artist ?? '').toLowerCase();

    final mixIndicators = [
      'dj mix',
      'continuous mix',
      'mixed by',
      'non-stop',
      'megamix',
    ];

    for (final indicator in mixIndicators) {
      if (title.contains(indicator) ||
          album.contains(indicator) ||
          artist.contains(indicator)) {
        return true;
      }
    }
    return false;
  }

  /// Detect if two tracks are from the same album and likely continuous
  bool _isContinuousAlbum(SongModel current, SongModel next) {
    // Same album check
    if (current.albumId != next.albumId) return false;

    // Check for known continuous album patterns
    final album = (current.album ?? '').toLowerCase();
    final continuousAlbumIndicators = [
      'dark side of the moon',
      'the wall',
      'abbey road',
      'sgt. pepper',
      'concept album',
    ];

    for (final indicator in continuousAlbumIndicators) {
      if (album.contains(indicator)) {
        return true;
      }
    }

    return false;
  }

  Future<void> _loadSettings() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/crossfade_settings.json');

      if (await file.exists()) {
        final contents = await file.readAsString();
        final json = jsonDecode(contents) as Map<String, dynamic>;

        _config = CrossfadeConfig.fromJson(json['config'] ?? {});

        final trackSettingsJson = json['trackSettings'] as Map<String, dynamic>?;
        if (trackSettingsJson != null) {
          for (final entry in trackSettingsJson.entries) {
            _trackSettings[entry.key] =
                TrackCrossfadeSettings.fromJson(entry.value);
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading crossfade settings: $e');
    }
  }

  Future<void> _saveSettings() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/crossfade_settings.json');

      final json = {
        'config': _config.toJson(),
        'trackSettings': _trackSettings
            .map((key, value) => MapEntry(key, value.toJson())),
      };

      await file.writeAsString(jsonEncode(json));
    } catch (e) {
      debugPrint('Error saving crossfade settings: $e');
    }
  }
}
