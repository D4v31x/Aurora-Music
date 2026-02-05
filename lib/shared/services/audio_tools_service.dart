/// Audio tools service.
///
/// Provides equalizer presets, loudness normalization,
/// and ReplayGain support.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Predefined equalizer presets
enum EqualizerPreset {
  off,
  flat,
  bass,
  treble,
  bassAndTreble,
  vocal,
  electronic,
  rock,
  pop,
  jazz,
  classical,
  hiphop,
  acoustic,
  lateNight,
  loudness,
}

/// Equalizer band configuration
class EqualizerBand {
  final int frequency; // Hz
  final double gain; // dB (-12 to +12)

  const EqualizerBand(this.frequency, this.gain);

  Map<String, dynamic> toJson() => {
        'frequency': frequency,
        'gain': gain,
      };

  factory EqualizerBand.fromJson(Map<String, dynamic> json) {
    return EqualizerBand(
      json['frequency'],
      (json['gain'] ?? 0.0).toDouble(),
    );
  }
}

/// Full equalizer configuration
class EqualizerConfig {
  final EqualizerPreset preset;
  final List<EqualizerBand> bands;
  final bool enabled;

  const EqualizerConfig({
    this.preset = EqualizerPreset.off,
    this.bands = const [],
    this.enabled = false,
  });

  EqualizerConfig copyWith({
    EqualizerPreset? preset,
    List<EqualizerBand>? bands,
    bool? enabled,
  }) {
    return EqualizerConfig(
      preset: preset ?? this.preset,
      bands: bands ?? this.bands,
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, dynamic> toJson() => {
        'preset': preset.index,
        'bands': bands.map((b) => b.toJson()).toList(),
        'enabled': enabled,
      };

  factory EqualizerConfig.fromJson(Map<String, dynamic> json) {
    return EqualizerConfig(
      preset: EqualizerPreset.values[json['preset'] ?? 0],
      bands: (json['bands'] as List?)
              ?.map((b) => EqualizerBand.fromJson(b))
              .toList() ??
          [],
      enabled: json['enabled'] ?? false,
    );
  }
}

/// Audio tools configuration
class AudioToolsConfig {
  final EqualizerConfig equalizer;
  final bool loudnessNormalization;
  final bool replayGainEnabled;
  final double replayGainPreamp; // dB adjustment
  final bool preventClipping;

  const AudioToolsConfig({
    this.equalizer = const EqualizerConfig(),
    this.loudnessNormalization = false,
    this.replayGainEnabled = true,
    this.replayGainPreamp = 0.0,
    this.preventClipping = true,
  });

  AudioToolsConfig copyWith({
    EqualizerConfig? equalizer,
    bool? loudnessNormalization,
    bool? replayGainEnabled,
    double? replayGainPreamp,
    bool? preventClipping,
  }) {
    return AudioToolsConfig(
      equalizer: equalizer ?? this.equalizer,
      loudnessNormalization:
          loudnessNormalization ?? this.loudnessNormalization,
      replayGainEnabled: replayGainEnabled ?? this.replayGainEnabled,
      replayGainPreamp: replayGainPreamp ?? this.replayGainPreamp,
      preventClipping: preventClipping ?? this.preventClipping,
    );
  }

  Map<String, dynamic> toJson() => {
        'equalizer': equalizer.toJson(),
        'loudnessNormalization': loudnessNormalization,
        'replayGainEnabled': replayGainEnabled,
        'replayGainPreamp': replayGainPreamp,
        'preventClipping': preventClipping,
      };

  factory AudioToolsConfig.fromJson(Map<String, dynamic> json) {
    return AudioToolsConfig(
      equalizer: json['equalizer'] != null
          ? EqualizerConfig.fromJson(json['equalizer'])
          : const EqualizerConfig(),
      loudnessNormalization: json['loudnessNormalization'] ?? false,
      replayGainEnabled: json['replayGainEnabled'] ?? true,
      replayGainPreamp: (json['replayGainPreamp'] ?? 0.0).toDouble(),
      preventClipping: json['preventClipping'] ?? true,
    );
  }
}

/// Service for managing audio tools
class AudioToolsService extends ChangeNotifier {
  AudioToolsConfig _config = const AudioToolsConfig();
  bool _initialized = false;

  // Standard EQ frequencies (5-band)
  static const List<int> standardFrequencies = [60, 230, 910, 3600, 14000];

  AudioToolsConfig get config => _config;
  EqualizerConfig get equalizerConfig => _config.equalizer;
  bool get isEqualizerEnabled => _config.equalizer.enabled;
  EqualizerPreset get currentPreset => _config.equalizer.preset;
  bool get isLoudnessNormalizationEnabled => _config.loudnessNormalization;
  bool get isReplayGainEnabled => _config.replayGainEnabled;

  /// Initialize the service
  Future<void> initialize() async {
    if (_initialized) return;
    await _loadConfig();
    _initialized = true;
  }

  /// Enable or disable the equalizer
  Future<void> setEqualizerEnabled(bool enabled) async {
    _config = _config.copyWith(
      equalizer: _config.equalizer.copyWith(enabled: enabled),
    );
    await _saveConfig();
    notifyListeners();
  }

  /// Set the equalizer preset
  Future<void> setEqualizerPreset(EqualizerPreset preset) async {
    final bands = _getPresetBands(preset);
    _config = _config.copyWith(
      equalizer: _config.equalizer.copyWith(
        preset: preset,
        bands: bands,
        enabled: preset != EqualizerPreset.off,
      ),
    );
    await _saveConfig();
    notifyListeners();
  }

  /// Enable or disable loudness normalization
  Future<void> setLoudnessNormalization(bool enabled) async {
    _config = _config.copyWith(loudnessNormalization: enabled);
    await _saveConfig();
    notifyListeners();
  }

  /// Enable or disable ReplayGain
  Future<void> setReplayGainEnabled(bool enabled) async {
    _config = _config.copyWith(replayGainEnabled: enabled);
    await _saveConfig();
    notifyListeners();
  }

  /// Set ReplayGain preamp adjustment
  Future<void> setReplayGainPreamp(double dB) async {
    _config = _config.copyWith(replayGainPreamp: dB.clamp(-12.0, 12.0));
    await _saveConfig();
    notifyListeners();
  }

  /// Set prevent clipping option
  Future<void> setPreventClipping(bool enabled) async {
    _config = _config.copyWith(preventClipping: enabled);
    await _saveConfig();
    notifyListeners();
  }

  /// Get human-readable name for a preset
  String getPresetName(EqualizerPreset preset) {
    switch (preset) {
      case EqualizerPreset.off:
        return 'Off';
      case EqualizerPreset.flat:
        return 'Flat';
      case EqualizerPreset.bass:
        return 'Bass Boost';
      case EqualizerPreset.treble:
        return 'Treble Boost';
      case EqualizerPreset.bassAndTreble:
        return 'Bass & Treble';
      case EqualizerPreset.vocal:
        return 'Vocal';
      case EqualizerPreset.electronic:
        return 'Electronic';
      case EqualizerPreset.rock:
        return 'Rock';
      case EqualizerPreset.pop:
        return 'Pop';
      case EqualizerPreset.jazz:
        return 'Jazz';
      case EqualizerPreset.classical:
        return 'Classical';
      case EqualizerPreset.hiphop:
        return 'Hip Hop';
      case EqualizerPreset.acoustic:
        return 'Acoustic';
      case EqualizerPreset.lateNight:
        return 'Late Night';
      case EqualizerPreset.loudness:
        return 'Loudness';
    }
  }

  /// Get all available presets
  List<EqualizerPreset> get availablePresets => EqualizerPreset.values;

  /// Get equalizer bands for a preset
  List<EqualizerBand> _getPresetBands(EqualizerPreset preset) {
    switch (preset) {
      case EqualizerPreset.off:
      case EqualizerPreset.flat:
        return [
          const EqualizerBand(60, 0),
          const EqualizerBand(230, 0),
          const EqualizerBand(910, 0),
          const EqualizerBand(3600, 0),
          const EqualizerBand(14000, 0),
        ];

      case EqualizerPreset.bass:
        return [
          const EqualizerBand(60, 6),
          const EqualizerBand(230, 4),
          const EqualizerBand(910, 0),
          const EqualizerBand(3600, 0),
          const EqualizerBand(14000, 0),
        ];

      case EqualizerPreset.treble:
        return [
          const EqualizerBand(60, 0),
          const EqualizerBand(230, 0),
          const EqualizerBand(910, 0),
          const EqualizerBand(3600, 4),
          const EqualizerBand(14000, 6),
        ];

      case EqualizerPreset.bassAndTreble:
        return [
          const EqualizerBand(60, 5),
          const EqualizerBand(230, 3),
          const EqualizerBand(910, -2),
          const EqualizerBand(3600, 3),
          const EqualizerBand(14000, 5),
        ];

      case EqualizerPreset.vocal:
        return [
          const EqualizerBand(60, -2),
          const EqualizerBand(230, 0),
          const EqualizerBand(910, 4),
          const EqualizerBand(3600, 4),
          const EqualizerBand(14000, 2),
        ];

      case EqualizerPreset.electronic:
        return [
          const EqualizerBand(60, 5),
          const EqualizerBand(230, 4),
          const EqualizerBand(910, 0),
          const EqualizerBand(3600, 2),
          const EqualizerBand(14000, 5),
        ];

      case EqualizerPreset.rock:
        return [
          const EqualizerBand(60, 5),
          const EqualizerBand(230, 3),
          const EqualizerBand(910, -1),
          const EqualizerBand(3600, 3),
          const EqualizerBand(14000, 5),
        ];

      case EqualizerPreset.pop:
        return [
          const EqualizerBand(60, -1),
          const EqualizerBand(230, 2),
          const EqualizerBand(910, 4),
          const EqualizerBand(3600, 3),
          const EqualizerBand(14000, 0),
        ];

      case EqualizerPreset.jazz:
        return [
          const EqualizerBand(60, 3),
          const EqualizerBand(230, 0),
          const EqualizerBand(910, 2),
          const EqualizerBand(3600, 3),
          const EqualizerBand(14000, 4),
        ];

      case EqualizerPreset.classical:
        return [
          const EqualizerBand(60, 4),
          const EqualizerBand(230, 2),
          const EqualizerBand(910, -2),
          const EqualizerBand(3600, 2),
          const EqualizerBand(14000, 4),
        ];

      case EqualizerPreset.hiphop:
        return [
          const EqualizerBand(60, 6),
          const EqualizerBand(230, 4),
          const EqualizerBand(910, 0),
          const EqualizerBand(3600, 2),
          const EqualizerBand(14000, 3),
        ];

      case EqualizerPreset.acoustic:
        return [
          const EqualizerBand(60, 4),
          const EqualizerBand(230, 2),
          const EqualizerBand(910, 1),
          const EqualizerBand(3600, 3),
          const EqualizerBand(14000, 3),
        ];

      case EqualizerPreset.lateNight:
        return [
          const EqualizerBand(60, 4),
          const EqualizerBand(230, 2),
          const EqualizerBand(910, 0),
          const EqualizerBand(3600, -2),
          const EqualizerBand(14000, -3),
        ];

      case EqualizerPreset.loudness:
        return [
          const EqualizerBand(60, 5),
          const EqualizerBand(230, 3),
          const EqualizerBand(910, 0),
          const EqualizerBand(3600, 0),
          const EqualizerBand(14000, 5),
        ];
    }
  }

  /// Calculate volume adjustment for ReplayGain
  /// Returns a multiplier (1.0 = no change)
  double calculateReplayGainVolume(double? trackGainDb, double? albumGainDb) {
    if (!_config.replayGainEnabled) return 1.0;

    // Prefer track gain, fall back to album gain
    final gainDb = trackGainDb ?? albumGainDb;
    if (gainDb == null) return 1.0;

    // Apply preamp
    final totalGainDb = gainDb + _config.replayGainPreamp;

    // Convert dB to linear
    double volume = _dbToLinear(totalGainDb);

    // Prevent clipping
    if (_config.preventClipping && volume > 1.0) {
      volume = 1.0;
    }

    return volume.clamp(0.0, 2.0);
  }

  double _dbToLinear(double dB) {
    return pow(10, dB / 20).toDouble();
  }

  static double pow(num x, num exponent) {
    return x.toDouble().pow(exponent.toDouble());
  }

  Future<void> _loadConfig() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/audio_tools.json');

      if (await file.exists()) {
        final contents = await file.readAsString();
        _config = AudioToolsConfig.fromJson(jsonDecode(contents));
      }
    } catch (e) {
      debugPrint('Error loading audio tools config: $e');
    }
  }

  Future<void> _saveConfig() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/audio_tools.json');
      await file.writeAsString(jsonEncode(_config.toJson()));
    } catch (e) {
      debugPrint('Error saving audio tools config: $e');
    }
  }
}

extension DoublePow on double {
  double pow(double exponent) {
    return (this as num).toDouble() * (1.0 + (exponent - 1) * (this.abs() > 1 ? 1 : -1));
  }
}
