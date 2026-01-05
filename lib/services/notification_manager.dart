import 'dart:async';
import 'package:flutter/material.dart';
import '../widgets/toast_notification.dart';

class NotificationManager {
  Timer? _notificationTimer;
  final StreamController<String> _notificationController =
      StreamController<String>.broadcast();
  bool _isShowingProgress = false;

  /// The context to use for showing toast notifications
  /// This should be set by the home screen
  static BuildContext? _toastContext;

  /// Whether the app bar is currently visible (not scrolled)
  static bool _isAppBarVisible = true;

  /// Set the context for toast notifications
  static void setToastContext(BuildContext context) {
    _toastContext = context;
  }

  /// Update whether the app bar is visible
  static void setAppBarVisible(bool visible) {
    _isAppBarVisible = visible;
    // If app bar becomes visible, hide any existing toast
    if (visible) {
      ToastNotification.hide();
    }
  }

  Stream<String> get notificationStream => _notificationController.stream;

  void showNotification(
    String message, {
    Duration duration = const Duration(seconds: 3),
    bool isProgress = false,
    VoidCallback? onComplete,
    IconData? icon,
    bool showToast = true,
  }) {
    if (isProgress && _isShowingProgress) {
      _notificationController.add(message);
      // Also update the toast if showing and app bar not visible
      if (showToast && _toastContext != null && !_isAppBarVisible) {
        ToastNotification.show(
          _toastContext!,
          message,
          duration: duration,
          icon: icon,
          isProgress: true,
        );
      }
      return;
    }

    _notificationTimer?.cancel();
    _isShowingProgress = isProgress;
    _notificationController.add(message);

    // Only show toast notification when app bar is NOT visible (scrolled down)
    if (showToast &&
        _toastContext != null &&
        message.isNotEmpty &&
        !_isAppBarVisible) {
      ToastNotification.show(
        _toastContext!,
        message,
        duration: duration,
        icon: icon,
        isProgress: isProgress,
      );
    }

    if (!isProgress) {
      _notificationTimer = Timer(duration, () {
        onComplete?.call();
      });
    }
  }

  void showDefaultTitle() {
    _isShowingProgress = false;
    _notificationController.add('');
    // Hide the toast when returning to default
    ToastNotification.hide();
  }

  void dispose() {
    _notificationTimer?.cancel();
    _notificationController.close();
  }
}
