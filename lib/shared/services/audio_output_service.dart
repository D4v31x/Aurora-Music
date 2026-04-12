// ignore_for_file: experimental_member_use
import 'dart:async';
import 'dart:io';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Represents an available audio output device.
class AudioOutputDevice {
  final String id;
  final String name;
  final AudioOutputType type;
  final bool isActive;
  /// Battery level 0–100, or -1 if unavailable.
  final int batteryLevel;

  const AudioOutputDevice({
    required this.id,
    required this.name,
    required this.type,
    this.isActive = false,
    this.batteryLevel = -1,
  });

  AudioOutputDevice copyWith({bool? isActive, int? batteryLevel}) =>
      AudioOutputDevice(
        id: id,
        name: name,
        type: type,
        isActive: isActive ?? this.isActive,
        batteryLevel: batteryLevel ?? this.batteryLevel,
      );
}

/// Types of audio output.
enum AudioOutputType {
  phone,
  bluetooth,
  wiredHeadset,
  speaker,
  usb,
  unknown,
}

/// Service for discovering and switching between audio output devices.
///
/// Uses the `audio_session` package to enumerate connected devices and
/// a platform channel to request audio routing changes on Android.
class AudioOutputService extends ChangeNotifier {
  static final AudioOutputService _instance = AudioOutputService._internal();
  factory AudioOutputService() => _instance;
  AudioOutputService._internal();

  static const _channel = MethodChannel('com.aurorasoftware.music/audio_output');
  static const _prefKey = 'preferred_audio_output_type';

  List<AudioOutputDevice> _devices = [];
  String _activeDeviceId = '';
  StreamSubscription<void>? _devicesChangedSub;
  bool _initialized = false;
  /// The user's preferred output type, persisted across sessions.
  AudioOutputType? _preferredType;

  List<AudioOutputDevice> get devices => _devices;
  String get activeDeviceId => _activeDeviceId;

  AudioOutputDevice? get activeDevice {
    try {
      return _devices.firstWhere((d) => d.id == _activeDeviceId);
    } catch (_) {
      return _devices.isNotEmpty ? _devices.first : null;
    }
  }

  /// Initialize and start listening for device changes.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    if (!Platform.isAndroid) return;

    try {
      // Restore the user's preferred output type from disk.
      final prefs = await SharedPreferences.getInstance();
      final savedType = prefs.getString(_prefKey);
      if (savedType != null) {
        _preferredType = AudioOutputType.values.asNameMap()[savedType];
      }

      final session = await AudioSession.instance;
      _devicesChangedSub = session.devicesChangedEventStream.listen((_) {
        refreshDevices();
      });
      await refreshDevices();

      // If the user had a preferred output and a matching device is
      // connected, switch to it now so the choice survives app restarts.
      if (_preferredType != null) {
        final preferred = _devices.where((d) => d.type == _preferredType);
        if (preferred.isNotEmpty && preferred.first.id != _activeDeviceId) {
          await switchTo(preferred.first.id);
        }
      }
    } catch (e) {
      debugPrint('AudioOutputService init error: $e');
    }
  }

  /// Re-query the list of output devices from the audio session.
  Future<void> refreshDevices() async {
    if (!Platform.isAndroid) return;

    try {
      final session = await AudioSession.instance;
      final rawDevices = await session.getDevices();

      // Ask the platform which device TYPE is currently active.
      // Returns "bluetooth", "wired", or "phone_speaker".
      String activeTypeHint = '';
      try {
        final result = await _channel.invokeMethod<String>('getActiveOutput');
        activeTypeHint = result ?? '';
      } catch (_) {
        // Platform channel not available, fall back to heuristic
      }

      final outputDevices = <AudioOutputDevice>[];
      bool hasBluetooth = false;
      bool hasWired = false;

      for (final d in rawDevices) {
        if (!d.isOutput) continue;

        final type = _mapType(d.type);
        // Skip unknown/irrelevant output types (e.g. built-in earpiece)
        if (type == AudioOutputType.unknown) continue;

        if (type == AudioOutputType.bluetooth) hasBluetooth = true;
        if (type == AudioOutputType.wiredHeadset) hasWired = true;

        outputDevices.add(AudioOutputDevice(
          id: d.id.isNotEmpty ? d.id : '${d.type.name}_${d.name}',
          name: d.name.isNotEmpty ? d.name : _fallbackName(type),
          type: type,
        ));
      }

      // Always include the phone speaker as a fallback
      final hasPhone = outputDevices.any((d) => d.type == AudioOutputType.phone);
      if (!hasPhone) {
        outputDevices.insert(
          0,
          const AudioOutputDevice(
            id: 'phone_speaker',
            name: 'Phone speaker',
            type: AudioOutputType.phone,
          ),
        );
      }

      // Match active device by TYPE, not by raw ID string.
      // The platform returns a type hint ("bluetooth"/<bt name>, "wired",
      // or "phone_speaker") which we match against our AudioOutputType.
      //
      // Priority: user's explicit preference > platform hint > heuristic.
      // The platform hint only tells us which device is *connected*, not
      // which one the user deliberately chose via switchTo().
      String matchedActiveId = '';

      // 1. Honour the user's persisted preference when the device is still
      //    available.  This keeps the selection stable across refreshes and
      //    app restarts.
      if (_preferredType != null) {
        final preferred =
            outputDevices.where((d) => d.type == _preferredType);
        if (preferred.isNotEmpty) {
          matchedActiveId = preferred.first.id;
        }
      }

      // 2. Fall back to the platform's active-output hint.
      if (matchedActiveId.isEmpty) {
        if (activeTypeHint == 'wired') {
          final wired = outputDevices.where((d) => d.type == AudioOutputType.wiredHeadset);
          if (wired.isNotEmpty) matchedActiveId = wired.first.id;
        } else if (activeTypeHint == 'phone_speaker') {
          final phone = outputDevices.where((d) => d.type == AudioOutputType.phone);
          if (phone.isNotEmpty) matchedActiveId = phone.first.id;
        } else if (activeTypeHint.isNotEmpty) {
          final bt = outputDevices.where((d) => d.type == AudioOutputType.bluetooth);
          if (bt.isNotEmpty) matchedActiveId = bt.first.id;
        }
      }

      // 3. Last resort: infer from connected devices.
      if (matchedActiveId.isEmpty) {
        if (hasBluetooth) {
          matchedActiveId = outputDevices.firstWhere((d) => d.type == AudioOutputType.bluetooth).id;
        } else if (hasWired) {
          matchedActiveId = outputDevices.firstWhere((d) => d.type == AudioOutputType.wiredHeadset).id;
        } else {
          matchedActiveId = outputDevices.firstWhere(
            (d) => d.type == AudioOutputType.phone,
            orElse: () => outputDevices.first,
          ).id;
        }
      }

      // Fetch Bluetooth battery level (best-effort).
      int btBattery = -1;
      if (hasBluetooth) {
        try {
          final level =
              await _channel.invokeMethod<int>('getBluetoothBattery');
          btBattery = level ?? -1;
        } catch (_) {}
      }

      _activeDeviceId = matchedActiveId;
      _devices = outputDevices.map((d) {
        return d.copyWith(
          isActive: d.id == matchedActiveId,
          batteryLevel: d.type == AudioOutputType.bluetooth ? btBattery : -1,
        );
      }).toList();

      notifyListeners();
    } catch (e) {
      debugPrint('AudioOutputService refresh error: $e');
    }
  }

  /// Switch audio output to the device with [deviceId].
  Future<bool> switchTo(String deviceId) async {
    if (!Platform.isAndroid) return false;

    final device = _devices.firstWhere(
      (d) => d.id == deviceId,
      orElse: () => const AudioOutputDevice(
        id: '',
        name: '',
        type: AudioOutputType.unknown,
      ),
    );
    if (device.id.isEmpty) return false;

    // Update UI immediately so the selection feels responsive.
    _activeDeviceId = deviceId;
    _devices = _devices.map((d) {
      return d.copyWith(isActive: d.id == deviceId);
    }).toList();
    notifyListeners();

    // Request the platform to switch the actual audio route.
    try {
      await _channel.invokeMethod<bool>('switchOutput', {
        'deviceId': deviceId,
        'type': device.type.name,
      });

      // Persist the user's choice so it survives app restarts.
      _preferredType = device.type;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, device.type.name);
    } catch (e) {
      debugPrint('AudioOutputService switch error: $e');
    }
    return true;
  }

  AudioOutputType _mapType(AudioDeviceType type) {
    switch (type) {
      case AudioDeviceType.bluetoothA2dp:
      case AudioDeviceType.bluetoothSco:
      case AudioDeviceType.bluetoothLe:
        return AudioOutputType.bluetooth;
      case AudioDeviceType.wiredHeadset:
      case AudioDeviceType.wiredHeadphones:
        return AudioOutputType.wiredHeadset;
      case AudioDeviceType.builtInSpeaker:
        return AudioOutputType.phone;
      case AudioDeviceType.usbAudio:
        return AudioOutputType.usb;
      default:
        return AudioOutputType.unknown;
    }
  }

  String _fallbackName(AudioOutputType type) {
    switch (type) {
      case AudioOutputType.phone:
        return 'Phone speaker';
      case AudioOutputType.bluetooth:
        return 'Bluetooth';
      case AudioOutputType.wiredHeadset:
        return 'Wired headphones';
      case AudioOutputType.usb:
        return 'USB audio';
      case AudioOutputType.speaker:
        return 'Speaker';
      case AudioOutputType.unknown:
        return 'Unknown';
    }
  }

  @override
  void dispose() {
    _devicesChangedSub?.cancel();
    super.dispose();
  }
}
