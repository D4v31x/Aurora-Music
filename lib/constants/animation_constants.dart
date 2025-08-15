import 'package:flutter/material.dart';

/// Animation constants for consistent timing and curves throughout the app
class AnimationConstants {
  // Standard animation durations
  static const Duration fast = Duration(milliseconds: 200);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 400);
  static const Duration pageTransition = Duration(milliseconds: 600);
  
  // Standard animation curves for different use cases
  static const Curve easeInOut = Curves.easeInOut;
  static const Curve easeOutQuart = Curves.easeOutQuart;
  static const Curve easeInOutCubic = Curves.easeInOutCubic;
  static const Curve bounceIn = Curves.bounceIn;
  static const Curve linear = Curves.linear;
  
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
  
  // Rotation values (in radians)
  static const double subtleRotation = 0.05;
  static const double halfRotation = 0.5;
}