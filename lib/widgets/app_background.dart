import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/background_manager_service.dart';
import 'mesh_background.dart';
import 'animated_mesh_background.dart';

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
            // Mesh gradient background using the mesh package
            Positioned.fill(
              child: ClipRect(
                child: enableAnimation
                    ? AnimatedMeshBackground(
                        colors: backgroundManager.currentColors,
                        animationDuration: const Duration(seconds: 7),
                        transitionDuration: const Duration(milliseconds: 400),
                        animationSpeed: 1.2, // Slightly reduced from 1.5 to prevent artifacts
                      )
                    : MeshBackground(
                        colors: backgroundManager.currentColors,
                        animated: true,
                        animationDuration: const Duration(seconds: 10),
                        animationSpeed: 0.8, // Slightly reduced from 1.0 to prevent artifacts
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
