import 'package:flutter/material.dart';

/// Animation constants for consistent timing and curves throughout the app
class AnimationConstants {
  // Standard animation durations
  static const Duration fastest = Duration(milliseconds: 150);
  static const Duration fast = Duration(milliseconds: 200);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration normalDuration = normal; // Alias for compatibility
  static const Duration slow = Duration(milliseconds: 400);
  static const Duration pageTransition = Duration(milliseconds: 600);
  static const Duration splash = Duration(milliseconds: 2000);
  
  // Standard animation curves for different use cases
  static const Curve easeInOut = Curves.easeInOut;
  static const Curve easeInOutCurve = easeInOut; // Alias for compatibility
  static const Curve easeOutQuart = Curves.easeOutQuart;
  static const Curve easeInOutCubic = Curves.easeInOutCubic;
  static const Curve bounceIn = Curves.bounceIn;
  static const Curve linear = Curves.linear;
  static const Curve decelerate = Curves.decelerate;
  static const Curve fastOutSlowIn = Curves.fastOutSlowIn;
  
  // Standard animation delays
  static const Duration shortDelay = Duration(milliseconds: 100);
  static const Duration mediumDelay = Duration(milliseconds: 200);
  static const Duration longDelay = Duration(milliseconds: 400);
  
  // Movement distances for slide animations
  static const double slideDistance = 30.0;
  static const double largeSlideDistance = 100.0;
  
  // Opacity values
  static const double hiddenOpacity = 0.0;
  static const double visibleOpacity = 1.0;
  static const double dimOpacity = 0.7;
  static const double subtleOpacity = 0.8;
  
  // Rotation values (in radians)
  static const double subtleRotation = 0.05;
  static const double halfRotation = 0.5;
  static const double fullRotation = 6.28318; // 2π
  
  // Scale values
  static const double scaleDown = 0.95;
  static const double scaleNormal = 1.0;
  static const double scaleUp = 1.05;
  
  // Blur values
  static const double noBlur = 0.0;
  static const double subtleBlur = 2.0;
  static const double normalBlur = 5.0;
  static const double strongBlur = 10.0;
  
  // Stagger timing for lists
  static const Duration staggerDelay = Duration(milliseconds: 50);
  static const Duration staggerDelayLong = Duration(milliseconds: 100);
}