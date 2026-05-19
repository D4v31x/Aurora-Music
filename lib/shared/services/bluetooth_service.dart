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
  StreamSubscription? _noisySubscription;
  StreamSubscription? _devicesSubscription;
  bool _hasBluetoothPermission = false;

  bool get isBluetoothConnected => _isBluetoothConnected;
  String get connectedDeviceName => _connectedDeviceName;
  bool get hasBluetoothPermission => _hasBluetoothPermission;

  /// Initialize Bluetooth monitoring
  Future<void> initialize() async {
    await _checkBluetoothPermission();

    if (_hasBluetoothPermission) {
      await _startMonitoringWithStreams();
    }
  }

  Future<void> _startMonitoringWithStreams() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
      _setupStreamListeners(session);
      final devices = await session.getDevices();
      _updateFromDevices(devices);
    } catch (e) {
      debugPrint('⚠️ Error setting up Bluetooth stream monitoring: $e');
    }
  }

  void _setupStreamListeners(AudioSession session) {
    _noisySubscription?.cancel();
    _devicesSubscription?.cancel();

    _noisySubscription = session.becomingNoisyEventStream.listen((_) {
      updateBluetoothStatus(false, '');
    });

    _devicesSubscription = session.devicesChangedEventStream.listen((_) async {
      final devices = await session.getDevices();
      _updateFromDevices(devices);
    });
  }

  void _updateFromDevices(Iterable<AudioDevice> devices) {
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
        await _startMonitoringWithStreams();
      }

      notifyListeners();
      return _hasBluetoothPermission;
    } catch (e) {
      debugPrint('⚠️ Error requesting Bluetooth permission: $e');
      return false;
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
  void stopMonitoring() {
    _noisySubscription?.cancel();
    _noisySubscription = null;
    _devicesSubscription?.cancel();
    _devicesSubscription = null;
  }

  @override
  void dispose() {
    stopMonitoring();
    super.dispose();
  }
}
