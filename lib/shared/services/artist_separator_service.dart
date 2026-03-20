import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'artist_aggregator_service.dart';

/// Service for parsing and splitting artist names from metadata.
/// Provides configurable separators and exclusions that persist across app restarts.
class ArtistSeparatorService extends ChangeNotifier {
  static final ArtistSeparatorService _instance =
      ArtistSeparatorService._internal();
  factory ArtistSeparatorService() => _instance;
  ArtistSeparatorService._internal();

  static const String _separatorsKey = 'artist_separators';
  static const String _exclusionsKey = 'artist_exclusions';
  static const String _enabledKey = 'artist_separation_enabled';

  // Default separators - common patterns used to separate multiple artists
  static const List<String> defaultSeparators = [
    '/',
    ',',
    '&',
    ' feat. ',
    ' feat ',
    ' ft. ',
    ' ft ',
    ' featuring ',
    ' with ',
    ' x ',
    ' X ',
    ' vs ',
    ' vs. ',
    ' and ',
  ];

  // Default exclusions - artist names that should NOT be split even if they contain separators
  static const List<String> defaultExclusions = [
    'AC/DC',
    'Simon & Garfunkel',
    'Guns N\' Roses',
    'Crosby, Stills & Nash',
    'Crosby, Stills, Nash & Young',
    'Earth, Wind & Fire',
    'Emerson, Lake & Palmer',
    'Peter, Paul and Mary',
    'Hall & Oates',
    'Tom & Jerry',
    'Kool & The Gang',
  ];

  List<String> _separators = List.from(defaultSeparators);
  List<String> _exclusions = List.from(defaultExclusions);
  bool _enabled = true;
  bool _initialized = false;

  /// Initialize the service and load saved preferences
  Future<void> initialize() async {
    if (_initialized) return;

    final prefs = await SharedPreferences.getInstance();

    // Load enabled state
    _enabled = prefs.getBool(_enabledKey) ?? true;

    // Load separators
    final separatorsJson = prefs.getString(_separatorsKey);
    if (separatorsJson != null) {
      try {
        _separators = List<String>.from(json.decode(separatorsJson));
      } catch (e) {
        _separators = List.from(defaultSeparators);
      }
    }

    // Load exclusions
    final exclusionsJson = prefs.getString(_exclusionsKey);
    if (exclusionsJson != null) {
      try {
        _exclusions = List<String>.from(json.decode(exclusionsJson));
      } catch (e) {
        _exclusions = List.from(defaultExclusions);
      }
    }

    _initialized = true;
  }

  /// Check if artist separation is enabled
  bool get isEnabled => _enabled;

  /// Get current separators
  List<String> get separators => List.unmodifiable(_separators);

  /// Get current exclusions
  List<String> get exclusions => List.unmodifiable(_exclusions);

  /// Enable or disable artist separation
  Future<void> setEnabled(bool enabled) async {
    _enabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, enabled);
    _onConfigChanged();
  }

  /// Add a new separator
  Future<void> addSeparator(String separator) async {
    if (separator.isEmpty || _separators.contains(separator)) return;
    _separators.add(separator);
    await _saveSeparators();
    _onConfigChanged();
  }

  /// Remove a separator
  Future<void> removeSeparator(String separator) async {
    _separators.remove(separator);
    await _saveSeparators();
    _onConfigChanged();
  }

  /// Set all separators at once
  Future<void> setSeparators(List<String> separators) async {
    _separators = List.from(separators);
    await _saveSeparators();
    _onConfigChanged();
  }

  /// Add a new exclusion
  Future<void> addExclusion(String exclusion) async {
    if (exclusion.isEmpty || _exclusions.contains(exclusion)) return;
    _exclusions.add(exclusion);
    await _saveExclusions();
    _onConfigChanged();
  }

  /// Remove an exclusion
  Future<void> removeExclusion(String exclusion) async {
    _exclusions.remove(exclusion);
    await _saveExclusions();
    _onConfigChanged();
  }

  /// Set all exclusions at once
  Future<void> setExclusions(List<String> exclusions) async {
    _exclusions = List.from(exclusions);
    await _saveExclusions();
    _onConfigChanged();
  }

  /// Reset to default settings
  Future<void> resetToDefaults() async {
    _separators = List.from(defaultSeparators);
    _exclusions = List.from(defaultExclusions);
    _enabled = true;
    await _saveSeparators();
    await _saveExclusions();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, true);
    _onConfigChanged();
  }

  Future<void> _saveSeparators() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_separatorsKey, json.encode(_separators));
  }

  Future<void> _saveExclusions() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_exclusionsKey, json.encode(_exclusions));
  }

  /// Called after any config change: clears downstream caches and notifies listeners.
  void _onConfigChanged() {
    ArtistAggregatorService().clearCache();
    notifyListeners();
  }

  /// Split artist string into individual artists
  /// Returns a list of artist names
  List<String> splitArtists(String artistString) {
    if (artistString.isEmpty) return [];

    // If separation is disabled, return the original string
    if (!_enabled) {
      return [artistString.trim()];
    }

    // Build separator regex first
    final sortedSeparators = List<String>.from(_separators)
      ..sort((a, b) => b.length.compareTo(a.length));

    final escapedSeparators =
        sortedSeparators.map((s) => RegExp.escape(s)).join('|');

    if (escapedSeparators.isEmpty) {
      return [artistString.trim()];
    }

    // Replace excluded artist names with stable placeholders so they survive
    // the separator-based split below. This supports partial exclusions, e.g.
    // "AC/DC" stays intact even inside "Artist1/AC/DC".
    String modified = artistString;
    // Map from placeholder → original matched text (preserves original casing)
    final restorations = <String, String>{};

    for (int i = 0; i < _exclusions.length; i++) {
      final exclusion = _exclusions[i];
      if (exclusion.isEmpty) continue;
      final excRegex = RegExp(RegExp.escape(exclusion), caseSensitive: false);
      if (excRegex.hasMatch(modified)) {
        final placeholder = '\x00E$i\x00';
        // Keep the first matched casing for restoration
        restorations[placeholder] =
            excRegex.firstMatch(modified)!.group(0)!;
        modified = modified.replaceAll(excRegex, placeholder);
      }
    }

    // Split by separators
    final sepRegex = RegExp(escapedSeparators, caseSensitive: false);
    final parts = modified
        .split(sepRegex)
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    // Restore placeholders back to original artist names
    final artists = parts.map((part) {
      String restored = part;
      for (final entry in restorations.entries) {
        restored = restored.replaceAll(entry.key, entry.value);
      }
      return restored;
    }).toList();

    return artists.isEmpty ? [artistString.trim()] : artists;
  }

  /// Get the primary (first) artist from an artist string
  String getPrimaryArtist(String artistString) {
    final artists = splitArtists(artistString);
    return artists.isNotEmpty ? artists.first : artistString.trim();
  }

  /// Format a list of artists back into a display string
  String formatArtists(List<String> artists, {String separator = ', '}) {
    return artists.join(separator);
  }

  /// Check if an artist string contains multiple artists
  bool hasMultipleArtists(String artistString) {
    return splitArtists(artistString).length > 1;
  }
}
