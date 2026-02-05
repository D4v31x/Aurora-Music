/// Offline mode service.
///
/// Manages offline behavior and network availability.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Configuration for offline mode and download behavior
class OfflineConfig {
  /// Whether offline mode is manually enabled
  final bool offlineModeEnabled;

  /// Download metadata only on Wi-Fi
  final bool downloadOnWifiOnly;

  /// Download only while charging
  final bool downloadWhileChargingOnly;

  const OfflineConfig({
    this.offlineModeEnabled = false,
    this.downloadOnWifiOnly = true,
    this.downloadWhileChargingOnly = false,
  });

  OfflineConfig copyWith({
    bool? offlineModeEnabled,
    bool? downloadOnWifiOnly,
    bool? downloadWhileChargingOnly,
  }) {
    return OfflineConfig(
      offlineModeEnabled: offlineModeEnabled ?? this.offlineModeEnabled,
      downloadOnWifiOnly: downloadOnWifiOnly ?? this.downloadOnWifiOnly,
      downloadWhileChargingOnly:
          downloadWhileChargingOnly ?? this.downloadWhileChargingOnly,
    );
  }

  Map<String, dynamic> toJson() => {
        'offlineModeEnabled': offlineModeEnabled,
        'downloadOnWifiOnly': downloadOnWifiOnly,
        'downloadWhileChargingOnly': downloadWhileChargingOnly,
      };

  factory OfflineConfig.fromJson(Map<String, dynamic> json) {
    return OfflineConfig(
      offlineModeEnabled: json['offlineModeEnabled'] ?? false,
      downloadOnWifiOnly: json['downloadOnWifiOnly'] ?? true,
      downloadWhileChargingOnly: json['downloadWhileChargingOnly'] ?? false,
    );
  }
}

/// Content types that may be unavailable offline
enum OfflineContentType {
  lyrics,
  artistInfo,
  albumArt,
  metadata,
  updates,
}

/// Service for managing offline mode
class OfflineModeService extends ChangeNotifier {
  OfflineConfig _config = const OfflineConfig();
  bool _initialized = false;

  // Cache of content availability
  final Set<String> _cachedLyrics = {};
  final Set<String> _cachedArtwork = {};

  OfflineConfig get config => _config;
  bool get isOfflineMode => _config.offlineModeEnabled;
  bool get downloadOnWifiOnly => _config.downloadOnWifiOnly;
  bool get downloadWhileChargingOnly => _config.downloadWhileChargingOnly;

  /// Initialize the service
  Future<void> initialize() async {
    if (_initialized) return;
    await _loadConfig();
    await _scanCachedContent();
    _initialized = true;
  }

  /// Enable or disable offline mode
  Future<void> setOfflineMode(bool enabled) async {
    _config = _config.copyWith(offlineModeEnabled: enabled);
    await _saveConfig();
    notifyListeners();
  }

  /// Set download on Wi-Fi only preference
  Future<void> setDownloadOnWifiOnly(bool enabled) async {
    _config = _config.copyWith(downloadOnWifiOnly: enabled);
    await _saveConfig();
    notifyListeners();
  }

  /// Set download while charging only preference
  Future<void> setDownloadWhileChargingOnly(bool enabled) async {
    _config = _config.copyWith(downloadWhileChargingOnly: enabled);
    await _saveConfig();
    notifyListeners();
  }

  /// Check if a specific content type is available for a track
  bool isContentAvailable(OfflineContentType type, String trackId) {
    if (!_config.offlineModeEnabled) {
      // When not in offline mode, assume content can be fetched
      return true;
    }

    switch (type) {
      case OfflineContentType.lyrics:
        return _cachedLyrics.contains(trackId);
      case OfflineContentType.albumArt:
        return _cachedArtwork.contains(trackId);
      case OfflineContentType.artistInfo:
      case OfflineContentType.metadata:
      case OfflineContentType.updates:
        // These typically require network
        return false;
    }
  }

  /// Check if network operations should be blocked
  bool shouldBlockNetwork() {
    return _config.offlineModeEnabled;
  }

  /// Check if download should proceed based on current conditions
  /// Note: In a real app, you'd check actual Wi-Fi and charging status
  bool canDownload({bool isWifi = true, bool isCharging = false}) {
    if (_config.offlineModeEnabled) return false;
    if (_config.downloadOnWifiOnly && !isWifi) return false;
    if (_config.downloadWhileChargingOnly && !isCharging) return false;
    return true;
  }

  /// Mark content as cached/available offline
  void markContentCached(OfflineContentType type, String trackId) {
    switch (type) {
      case OfflineContentType.lyrics:
        _cachedLyrics.add(trackId);
        break;
      case OfflineContentType.albumArt:
        _cachedArtwork.add(trackId);
        break;
      default:
        break;
    }
    notifyListeners();
  }

  /// Get the offline status message for a content type
  String getOfflineMessage(OfflineContentType type) {
    switch (type) {
      case OfflineContentType.lyrics:
        return 'Lyrics unavailable offline';
      case OfflineContentType.artistInfo:
        return 'Artist info unavailable offline';
      case OfflineContentType.albumArt:
        return 'Album art unavailable offline';
      case OfflineContentType.metadata:
        return 'Metadata unavailable offline';
      case OfflineContentType.updates:
        return 'Updates unavailable offline';
    }
  }

  /// Scan for cached content
  Future<void> _scanCachedContent() async {
    try {
      final directory = await getApplicationDocumentsDirectory();

      // Scan lyrics cache
      final lyricsDir = Directory('${directory.path}/lyrics_cache');
      if (await lyricsDir.exists()) {
        await for (final entity in lyricsDir.list()) {
          if (entity is File) {
            final name = entity.path.split('/').last;
            // Extract track ID from filename
            _cachedLyrics.add(name.replaceAll('.json', ''));
          }
        }
      }

      // Scan artwork cache
      final artworkDir = Directory('${directory.path}/artwork_cache');
      if (await artworkDir.exists()) {
        await for (final entity in artworkDir.list()) {
          if (entity is File) {
            final name = entity.path.split('/').last;
            _cachedArtwork.add(name.replaceAll(RegExp(r'\.\w+$'), ''));
          }
        }
      }
    } catch (e) {
      debugPrint('Error scanning cached content: $e');
    }
  }

  Future<void> _loadConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final configJson = prefs.getString('offline_config');
      if (configJson != null) {
        _config = OfflineConfig.fromJson(jsonDecode(configJson));
      }
    } catch (e) {
      debugPrint('Error loading offline config: $e');
    }
  }

  Future<void> _saveConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('offline_config', jsonEncode(_config.toJson()));
    } catch (e) {
      debugPrint('Error saving offline config: $e');
    }
  }
}
