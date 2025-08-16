import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/background_manager_service.dart';
import 'mesh_background.dart';
import 'animated_mesh_gradient.dart';

/// Centralized app background widget that provides consistent background across the app
/// Replaces all scattered background implementations to prevent stacking
class AppBackground extends StatelessWidget {
  final Widget child;
  final bool enableAnimation;

  const AppBackground({
    super.key,
    required this.child,
    this.enableAnimation = true,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<BackgroundManagerService>(
      builder: (context, backgroundManager, _) {
        return Stack(
          children: [
            // Enhanced animated mesh gradient background with dramatic wave effects
            Positioned.fill(
              child: ClipRect(
                child: enableAnimation
                    ? AnimatedMeshGradient(
                        colors: backgroundManager.currentColors,
                        animationDuration: const Duration(seconds: 3), // Faster for more noticeable movement
                        enableAnimation: true,
                      )
                    : AnimatedMeshGradient(
                        colors: backgroundManager.currentColors,
                        animationDuration: const Duration(seconds: 5),
                        enableAnimation: false,
                      ),
              ),
            ),
            // Content
            child,
          ],
        );
      },
    );
  }
}
