import 'dart:async';
import 'package:flutter/material.dart';

/// Specialized controller for sleep timer that prevents unnecessary rebuilds
/// Only widgets specifically interested in timer updates will rebuild
class SleepTimerController extends ChangeNotifier {
  Timer? _sleepTimer;
  Duration? _remainingTime;
  Duration? _sleepTimerDuration;
  
  bool get isActive => _sleepTimer?.isActive ?? false;
  Duration? get remainingTime => _remainingTime;
  Duration? get duration => _sleepTimerDuration;

  void startTimer(Duration duration, VoidCallback onComplete) {
    cancelTimer();
    _remainingTime = duration;
    _sleepTimerDuration = duration;
    
    _sleepTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingTime != null) {
        _remainingTime = _remainingTime! - const Duration(seconds: 1);
        
        if (_remainingTime!.inSeconds <= 0) {
          onComplete();
          cancelTimer();
        } else {
          // Only notify listeners interested in timer updates
          notifyListeners();
        }
      }
    });
    
    // Initial notification when timer starts
    notifyListeners();
  }

  void cancelTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _remainingTime = null;
    _sleepTimerDuration = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _sleepTimer?.cancel();
    super.dispose();
  }
}