import 'package:appwrite/appwrite.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:io';

class ErrorReportingService {
  final Client _client;
  late final Databases _databases;
  late final String _databaseId;
  late final String _collectionId;
  String? _deviceId;
  String? _appVersion;
  String? _deviceModel;
  String? _osVersion;

  ErrorReportingService(this._client) {
    _databases = Databases(_client);
    _databaseId = 'error_reports_db';
    _collectionId = 'errors';
    _initializeDeviceInfo();
    _initializeAppInfo();
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

  Future<void> reportError(dynamic error, StackTrace stackTrace) async {
    try {
      await _databases.createDocument(
        databaseId: _databaseId,
        collectionId: _collectionId,
        documentId: ID.unique(),
        data: {
          'error_message': error.toString(),
          'stack_trace': stackTrace.toString(),
          'timestamp': DateTime.now().toIso8601String(),
          'device_id': _deviceId,
          'app_version': _appVersion,
          'device_model': _deviceModel,
          'os_version': _osVersion,
        },
      );
    } catch (e) {
      // If we can't report the error, print it to console as last resort
      print('Error reporting failed: $e');
      print('Original error: $error');
      print('Original stack trace: $stackTrace');
    }
  }

  Future<void> reportWarning(String message, {Map<String, dynamic>? additionalData}) async {
    try {
      await _databases.createDocument(
        databaseId: _databaseId,
        collectionId: _collectionId,
        documentId: ID.unique(),
        data: {
          'type': 'warning',
          'message': message,
          'additional_data': additionalData,
          'timestamp': DateTime.now().toIso8601String(),
          'device_id': _deviceId,
          'app_version': _appVersion,
          'device_model': _deviceModel,
          'os_version': _osVersion,
        },
      );
    } catch (e) {
      print('Warning reporting failed: $e');
    }
  }
} 