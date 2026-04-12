// ignore_for_file: experimental_member_use
import 'dart:async';
import 'dart:io';
import 'package:audio_session/audio_session.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

class BluetoothService extends ChangeNotifier {
  static final BluetoothService _instance = BluetoothService._internal();
  factory BluetoothService() => _instance;
  BluetoothService._internal();

  bool _isBluetoothConnected = false;
  String _connectedDeviceName = '';
  bool _hasBluetoothPermission = false;
  StreamSubscription<void>? _noisySub;
  StreamSubscription<void>? _devicesChangedSub;

  bool get isBluetoothConnected => _isBluetoothConnected;
  String get connectedDeviceName => _connectedDeviceName;
  bool get hasBluetoothPermission => _hasBluetoothPermission;

  /// Initialize Bluetooth monitoring
  Future<void> initialize() async {
    await _checkBluetoothPermission();

    if (_hasBluetoothPermission) {
      // Start periodic checking for Bluetooth connectivity
      await _startMonitoring();
    }
  }

  /// Check if Bluetooth permission is granted
  Future<void> _checkBluetoothPermission() async {
    if (!Platform.isAndroid) {
      _hasBluetoothPermission = false;
      return;
    }

    try {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;

      // Android 12+ uses BLUETOOTH_CONNECT permission
      if (androidInfo.version.sdkInt >= 31) {
        final status = await Permission.bluetoothConnect.status;
        _hasBluetoothPermission = status.isGranted;
      } else {
        // Android 11 and below use BLUETOOTH permission
        final status = await Permission.bluetooth.status;
        _hasBluetoothPermission = status.isGranted;
      }

      debugPrint('🔵 Bluetooth permission granted: $_hasBluetoothPermission');
    } catch (e) {
      debugPrint('⚠️ Error checking Bluetooth permission: $e');
      _hasBluetoothPermission = false;
    }

    notifyListeners();
  }

  /// Request Bluetooth permissions
  Future<bool> requestBluetoothPermission() async {
    if (!Platform.isAndroid) return false;

    try {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;

      PermissionStatus status;

      // Android 12+ uses BLUETOOTH_CONNECT permission
      if (androidInfo.version.sdkInt >= 31) {
        status = await Permission.bluetoothConnect.request();
      } else {
        // Android 11 and below use BLUETOOTH permission
        status = await Permission.bluetooth.request();
      }

      _hasBluetoothPermission = status.isGranted;

      if (_hasBluetoothPermission) {
        await _startMonitoring();
      }

      notifyListeners();
      return _hasBluetoothPermission;
    } catch (e) {
      debugPrint('⚠️ Error requesting Bluetooth permission: $e');
      return false;
    }
  }

  /// Start monitoring Bluetooth connectivity via reactive streams
  Future<void> _startMonitoring() async {
    _stopMonitoring();

    try {
      final session = await AudioSession.instance;

      // Subscribe ONCE to audio route changes
      _noisySub = session.becomingNoisyEventStream.listen((_) {
        updateBluetoothStatus(false, '');
      });

      _devicesChangedSub = session.devicesChangedEventStream.listen((_) async {
        await _checkCurrentDevices(session);
      });

      // Initial device check
      await _checkCurrentDevices(session);
    } catch (e) {
      debugPrint('⚠️ Error starting Bluetooth monitoring: $e');
    }
  }

  /// Check current audio devices for Bluetooth
  Future<void> _checkCurrentDevices(AudioSession session) async {
    if (!_hasBluetoothPermission) return;

    try {
      final devices = await session.getDevices();
      final bluetoothDevice = devices.firstWhere(
        (d) =>
            d.type == AudioDeviceType.bluetoothA2dp ||
            d.type == AudioDeviceType.bluetoothSco,
        orElse: () => AudioDevice(
          id: '',
          name: '',
          type: AudioDeviceType.unknown,
          isInput: false,
          isOutput: false,
        ),
      );

      if (bluetoothDevice.id.isNotEmpty) {
        updateBluetoothStatus(true, bluetoothDevice.name);
      } else {
        updateBluetoothStatus(false, '');
      }
    } catch (e) {
      debugPrint('⚠️ Error checking Bluetooth connectivity: $e');
    }
  }

  /// Update Bluetooth connection status (to be called from platform-specific code)
  void updateBluetoothStatus(bool isConnected, String deviceName) {
    if (_isBluetoothConnected != isConnected ||
        _connectedDeviceName != deviceName) {
      _isBluetoothConnected = isConnected;
      _connectedDeviceName = deviceName;
      notifyListeners();

      debugPrint(
          '🔵 Bluetooth ${isConnected ? "connected to" : "disconnected from"} $deviceName');
    }
  }

  /// Stop monitoring Bluetooth
  void _stopMonitoring() {
    _noisySub?.cancel();
    _noisySub = null;
    _devicesChangedSub?.cancel();
    _devicesChangedSub = null;
  }

  @override
  void dispose() {
    _stopMonitoring();
    super.dispose();
  }
}
