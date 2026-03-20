/// Audio settings service.
///
/// Manages audio player settings and their persistence.
library;

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

// MARK: - Constants

const String _kSettingsFileName = 'settings.json';
const double _kDefaultPlaybackSpeed = 1.0;
const int _kDefaultCacheSize = 100;
const String _kDefaultSortOrder = 'title';

// MARK: - Audio Settings Service

/// Service for managing audio player settings.
///
/// Handles settings like:
/// - Gapless playback
/// - Volume normalization
/// - Playback speed
/// - Sort order
/// - Cache size
/// - Media controls
class AudioSettingsService {
  // MARK: - Settings Fields

  bool _gaplessPlayback = true;
  bool _volumeNormalization = false;
  double _playbackSpeed = _kDefaultPlaybackSpeed;
  String _defaultSortOrder = _kDefaultSortOrder;
  int _cacheSize = _kDefaultCacheSize;
  bool _mediaControls = true;

  // MARK: - Getters

  bool get gaplessPlayback => _gaplessPlayback;
  bool get volumeNormalization => _volumeNormalization;
  double get playbackSpeed => _playbackSpeed;
  String get defaultSortOrder => _defaultSortOrder;
  int get cacheSize => _cacheSize;
  bool get mediaControls => _mediaControls;

  // MARK: - Callback for applying settings

  /// Callback to apply settings to the audio player.
  VoidCallback? onSettingsChanged;

  // MARK: - Persistence

  /// Loads settings from persistent storage.
  Future<void> load() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$_kSettingsFileName');

      if (await file.exists()) {
        final contents = await file.readAsString();
        final json = jsonDecode(contents);

        _gaplessPlayback = json['gaplessPlayback'] ?? true;
        _volumeNormalization = json['volumeNormalization'] ?? false;
        _playbackSpeed = (json['playbackSpeed'] ?? _kDefaultPlaybackSpeed).toDouble();
        _defaultSortOrder = json['defaultSortOrder'] ?? _kDefaultSortOrder;
        _cacheSize = json['cacheSize'] ?? _kDefaultCacheSize;
        _mediaControls = json['mediaControls'] ?? true;
      }
    } catch (e) {
      debugPrint('Error loading settings: $e');
    }
  }

  /// Saves settings to persistent storage.
  Future<void> save() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$_kSettingsFileName');

      final json = {
        'gaplessPlayback': _gaplessPlayback,
        'volumeNormalization': _volumeNormalization,
        'playbackSpeed': _playbackSpeed,
        'defaultSortOrder': _defaultSortOrder,
        'cacheSize': _cacheSize,
        'mediaControls': _mediaControls,
      };

      await file.writeAsString(jsonEncode(json));
    } catch (e) {
      debugPrint('Error saving settings: $e');
    }
  }

  // MARK: - Setters

  /// Sets gapless playback setting.
  Future<void> setGaplessPlayback(bool value) async {
    _gaplessPlayback = value;
    await save();
  }

  /// Sets volume normalization setting.
  Future<void> setVolumeNormalization(bool value) async {
    _volumeNormalization = value;
    await save();
    onSettingsChanged?.call();
  }

  /// Sets playback speed.
  Future<void> setPlaybackSpeed(double value) async {
    _playbackSpeed = value;
    await save();
    onSettingsChanged?.call();
  }

  /// Sets default sort order.
  Future<void> setDefaultSortOrder(String value) async {
    _defaultSortOrder = value;
    await save();
    onSettingsChanged?.call();
  }

  /// Sets cache size in MB.
  Future<void> setCacheSize(int value) async {
    _cacheSize = value;
    await save();
    onSettingsChanged?.call();
  }

  /// Sets media controls enabled.
  Future<void> setMediaControls(bool value) async {
    _mediaControls = value;
    await save();
    onSettingsChanged?.call();
  }
}
