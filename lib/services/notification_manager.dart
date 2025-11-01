import 'dart:async';
import 'package:flutter/material.dart';

class NotificationManager {
  Timer? _notificationTimer;
  final StreamController<String> _notificationController =
      StreamController<String>.broadcast();
  bool _isShowingProgress = false;

  Stream<String> get notificationStream => _notificationController.stream;

  void showNotification(
    String message, {
    Duration duration = const Duration(seconds: 3),
    bool isProgress = false,
    VoidCallback? onComplete,
  }) {
    if (isProgress && _isShowingProgress) {
      _notificationController.add(message);
      return;
    }

    _notificationTimer?.cancel();
    _isShowingProgress = isProgress;
    _notificationController.add(message);

    if (!isProgress) {
      _notificationTimer = Timer(duration, () {
        onComplete?.call();
      });
    }
  }

  void showDefaultTitle() {
    _isShowingProgress = false;
    _notificationController.add('');
  }

  void dispose() {
    _notificationTimer?.cancel();
    _notificationController.close();
  }
}
