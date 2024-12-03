import 'package:appwrite/appwrite.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:io';

class AnalyticsService {
  final Client _client;
  late final Databases _databases;
  late final String _databaseId;
  late final String _collectionId;
  String? _deviceId;
  String? _appVersion;
  String? _deviceModel;
  String? _osVersion;

  AnalyticsService(this._client) {
    _databases = Databases(_client);
    _databaseId = 'analytics_db';
    _collectionId = 'app_events';
  }

  Future<void> initialize() async {
    await _initializeDeviceInfo();
    await _initializeAppInfo();
  }

  Future<void> _initializeDeviceInfo() async {
    final deviceInfo = DeviceInfoPlugin();
    
    try {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        _deviceId = androidInfo.id;
        _deviceModel = '${androidInfo.manufacturer} ${androidInfo.model}';
        _osVersion = 'Android ${androidInfo.version.release}';
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        _deviceId = iosInfo.identifierForVendor;
        _deviceModel = iosInfo.model;
        _osVersion = '${iosInfo.systemName} ${iosInfo.systemVersion}';
      } else if (Platform.isWindows) {
        final windowsInfo = await deviceInfo.windowsInfo;
        _deviceId = windowsInfo.deviceId;
        _deviceModel = 'Windows PC';
        _osVersion = windowsInfo.productName;
      }
    } catch (e) {
      _deviceId = 'unknown';
      _deviceModel = 'unknown';
      _osVersion = 'unknown';
    }
  }

  Future<void> _initializeAppInfo() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      _appVersion = packageInfo.version;
    } catch (e) {
      _appVersion = 'unknown';
    }
  }

  Future<void> logEvent(String eventName, {Map<String, dynamic>? parameters}) async {
    try {
      await _databases.createDocument(
        databaseId: _databaseId,
        collectionId: _collectionId,
        documentId: ID.unique(),
        data: {
          'event_name': eventName,
          'timestamp': DateTime.now().toIso8601String(),
          'device_id': _deviceId,
          'app_version': _appVersion,
          'device_model': _deviceModel,
          'os_version': _osVersion,
          'parameters': parameters ?? {},
        },
      );
    } catch (e) {
      // Silently fail for analytics
      print('Analytics error: $e');
    }
  }

  Future<void> logAppStart() async {
    await logEvent('app_start');
  }

  Future<void> logSongPlay(String songId, String songTitle, String artist) async {
    await logEvent(
      'song_play',
      parameters: {
        'song_id': songId,
        'song_title': songTitle,
        'artist': artist,
      },
    );
  }

  Future<void> logPlaylistCreate(String playlistName) async {
    await logEvent(
      'playlist_create',
      parameters: {
        'playlist_name': playlistName,
      },
    );
  }

  Future<void> logSearch(String query) async {
    await logEvent(
      'search',
      parameters: {
        'query': query,
      },
    );
  }

  Future<void> logError(String errorMessage, String stackTrace) async {
    await logEvent(
      'error',
      parameters: {
        'error_message': errorMessage,
        'stack_trace': stackTrace,
      },
    );
  }
} 