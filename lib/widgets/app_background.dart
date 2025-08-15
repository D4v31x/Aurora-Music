import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/background_manager_service.dart';
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
            // Animated mesh gradient background
            Positioned.fill(
              child: AnimatedMeshGradient(
                colors: backgroundManager.currentColors,
                enableAnimation: enableAnimation,
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
