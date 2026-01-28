import 'dart:async';
import 'package:flutter/foundation.dart';

/// Performance optimization utilities for Aurora Music
/// 
/// This file contains helper functions and classes to optimize
/// rebuild behavior, state management, and rendering performance.

/// Debouncer for expensive operations
class Debouncer {
  final Duration delay;
  Timer? _timer;

  Debouncer({required this.delay});

  void call(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}

/// Throttler for rate-limiting expensive operations
class Throttler {
  final Duration interval;
  Timer? _timer;
  bool _isRunning = false;
  VoidCallback? _pendingAction;

  Throttler({required this.interval});

  void call(VoidCallback action) {
    if (_isRunning) {
      _pendingAction = action;
      return;
    }

    _isRunning = true;
    action();

    _timer = Timer(interval, () {
      _isRunning = false;
      if (_pendingAction != null) {
        final pending = _pendingAction!;
        _pendingAction = null;
        call(pending);
      }
    });
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
    _pendingAction = null;
    _isRunning = false;
  }
}

/// Memoizer for expensive computations
class Memoizer<T> {
  T? _cachedValue;
  Object? _lastInput;

  T call(Object? input, T Function() computation) {
    if (_lastInput != input || _cachedValue == null) {
      _lastInput = input;
      _cachedValue = computation();
    }
    return _cachedValue!;
  }

  void clear() {
    _cachedValue = null;
    _lastInput = null;
  }
}

/// Granular notifier for a single field
/// Use this to isolate state updates to specific fields
class FieldNotifier<T> extends ChangeNotifier implements ValueListenable<T> {
  T _value;

  FieldNotifier(this._value);

  @override
  T get value => _value;

  set value(T newValue) {
    if (_value != newValue) {
      _value = newValue;
      notifyListeners();
    }
  }

  /// Update only if the new value is different
  void updateIfChanged(T newValue) {
    if (_value != newValue) {
      _value = newValue;
      notifyListeners();
    }
  }
}

/// Batch notifier to reduce notification frequency
class BatchNotifier extends ChangeNotifier {
  Timer? _batchTimer;
  bool _hasPendingNotification = false;
  final Duration batchDuration;

  BatchNotifier({this.batchDuration = const Duration(milliseconds: 16)});

  @override
  void notifyListeners() {
    if (_hasPendingNotification) return;

    _hasPendingNotification = true;
    _batchTimer?.cancel();
    _batchTimer = Timer(batchDuration, () {
      _hasPendingNotification = false;
      super.notifyListeners();
    });
  }

  /// Force immediate notification
  void notifyListenersImmediately() {
    _batchTimer?.cancel();
    _hasPendingNotification = false;
    super.notifyListeners();
  }

  @override
  void dispose() {
    _batchTimer?.cancel();
    super.dispose();
  }
}

/// Compute expensive operations off the UI thread
Future<T> computeIfNeeded<T>(
  T Function() computation, {
  Duration threshold = const Duration(milliseconds: 10),
  bool forceIsolate = false,
}) async {
  if (kIsWeb || !forceIsolate) {
    // On web or if not forcing, run synchronously
    // In the future, we can measure time and decide
    return computation();
  }

  // For now, run synchronously but this can be extended
  // to use compute() for heavy operations
  return computation();
}
