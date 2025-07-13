import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

extension OnboardingAnimations on Widget {
  Widget addHeadingAnimations({
    required bool isExiting,
    Duration? delay,
  }) {
    return animate()
        .fadeIn(
          duration: 300.ms,
          delay: delay ?? 500.ms,
          curve: Curves.easeInOut,
        )
        .moveX(begin: -30, end: 0)
        .animate(
          target: isExiting ? 1.0 : 0.0,
          autoPlay: false,
        )
        .custom(
          duration: 400.ms,
          curve: Curves.easeInOut,
          builder: (context, value, child) => Transform(
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(value * 0.5)
              ..translate(value * 100.0),
            alignment: Alignment.centerRight,
            child: Opacity(opacity: 1.0 - value, child: child),
          ),
        );
  }

  Widget addDividerAnimations({
    required bool isExiting,
    Duration? delay,
  }) {
    return animate()
        .scaleX(
          begin: 0,
          end: 1,
          duration: 250.ms,
          delay: delay ?? 400.ms,
          curve: Curves.easeInOut,
          alignment: Alignment.centerLeft,
        )
        .animate(
          target: isExiting ? 1.0 : 0.0,
          autoPlay: false,
        )
        .custom(
          duration: 400.ms,
          curve: Curves.easeInOut,
          builder: (context, value, child) => Transform.scale(
            scaleX: 1.0 - value,
            alignment: Alignment.centerRight,
            child: child,
          ),
        );
  }

  Widget addSubtitleAnimations({
    required bool isExiting,
    Duration? delay,
  }) {
    return animate()
        .fadeIn(
          duration: 300.ms,
          delay: delay ?? 700.ms,
          curve: Curves.easeInOut,
        )
        .moveX(begin: -30, end: 0)
        .animate(
          target: isExiting ? 1.0 : 0.0,
          autoPlay: false,
        )
        .custom(
          duration: 400.ms,
          curve: Curves.easeInOut,
          builder: (context, value, child) => Transform(
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(value * 0.5)
              ..translate(value * 100.0),
            alignment: Alignment.centerRight,
            child: Opacity(opacity: 1.0 - value, child: child),
          ),
        );
  }

  Widget addContentAnimations({
    Duration? delay,
  }) {
    return animate()
        .fadeIn(
          duration: 300.ms,
          delay: delay ?? 800.ms,
          curve: Curves.easeInOut,
        )
        .moveY(begin: 20, end: 0);
  }

  Widget addButtonAnimations({
    Duration? delay,
  }) {
    return animate()
        .fadeIn(
          duration: 300.ms,
          delay: delay ?? 1000.ms,
          curve: Curves.easeInOut,
        )
        .moveY(begin: 20, end: 0);
  }
} 