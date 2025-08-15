import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../constants/animation_constants.dart';

extension OnboardingAnimations on Widget {
  Widget addHeadingAnimations({
    required bool isExiting,
    Duration? delay,
  }) {
    return RepaintBoundary(
      child: animate()
          .fadeIn(
            duration: AnimationConstants.normal,
            delay: delay ?? const Duration(milliseconds: 500),
            curve: AnimationConstants.easeInOut,
          )
          .moveX(begin: -AnimationConstants.slideDistance, end: 0)
          .animate(
            target: isExiting ? 1.0 : 0.0,
            autoPlay: false,
          )
          .custom(
            duration: AnimationConstants.slow,
            curve: AnimationConstants.easeInOut,
            builder: (context, value, child) => Transform(
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateY(value * AnimationConstants.halfRotation)
                ..translate(value * AnimationConstants.largeSlideDistance),
              alignment: Alignment.centerRight,
              child: Opacity(
                opacity: AnimationConstants.visibleOpacity - value,
                child: child,
              ),
            ),
          ),
    );
  }

  Widget addDividerAnimations({
    required bool isExiting,
    Duration? delay,
  }) {
    return RepaintBoundary(
      child: animate()
          .scaleX(
            begin: 0,
            end: 1,
            duration: const Duration(milliseconds: 250),
            delay: delay ?? AnimationConstants.longDelay,
            curve: AnimationConstants.easeInOut,
            alignment: Alignment.centerLeft,
          )
          .animate(
            target: isExiting ? 1.0 : 0.0,
            autoPlay: false,
          )
          .custom(
            duration: AnimationConstants.slow,
            curve: AnimationConstants.easeInOut,
            builder: (context, value, child) => Transform.scale(
              scaleX: AnimationConstants.visibleOpacity - value,
              alignment: Alignment.centerRight,
              child: child,
            ),
          ),
    );
  }

  Widget addSubtitleAnimations({
    required bool isExiting,
    Duration? delay,
  }) {
    return RepaintBoundary(
      child: animate()
          .fadeIn(
            duration: AnimationConstants.normal,
            delay: delay ?? const Duration(milliseconds: 700),
            curve: AnimationConstants.easeInOut,
          )
          .moveX(begin: -AnimationConstants.slideDistance, end: 0)
          .animate(
            target: isExiting ? 1.0 : 0.0,
            autoPlay: false,
          )
          .custom(
            duration: AnimationConstants.slow,
            curve: AnimationConstants.easeInOut,
            builder: (context, value, child) => Transform(
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateY(value * AnimationConstants.halfRotation)
                ..translate(value * AnimationConstants.largeSlideDistance),
              alignment: Alignment.centerRight,
              child: Opacity(
                opacity: AnimationConstants.visibleOpacity - value,
                child: child,
              ),
            ),
          ),
    );
  }

  Widget addContentAnimations({
    Duration? delay,
  }) {
    return RepaintBoundary(
      child: animate()
          .fadeIn(
            duration: AnimationConstants.normal,
            delay: delay ?? const Duration(milliseconds: 800),
            curve: AnimationConstants.easeInOut,
          )
          .moveY(begin: 20, end: 0),
    );
  }

  Widget addButtonAnimations({
    Duration? delay,
  }) {
    return RepaintBoundary(
      child: animate()
          .fadeIn(
            duration: AnimationConstants.normal,
            delay: delay ?? const Duration(milliseconds: 1000),
            curve: AnimationConstants.easeInOut,
          )
          .moveY(begin: 20, end: 0),
    );
  }
}