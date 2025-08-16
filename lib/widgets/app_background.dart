import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/background_manager_service.dart';
import '../utils/device_capabilities.dart';
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
        // Check if complex backgrounds should be enabled
        final shouldEnableComplexBackground = DeviceCapabilities.shouldEnableBackgroundEffects;
        
        // Use simple gradient for low-end devices
        if (!shouldEnableComplexBackground) {
          return Stack(
            children: [
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: backgroundManager.currentColors.take(2).toList(),
                    ),
                  ),
                ),
              ),
              child,
            ],
          );
        }
        
        return Stack(
          children: [
            // Mesh gradient background using the mesh package
            Positioned.fill(
              child: ClipRect(
                child: enableAnimation
                    ? AnimatedMeshBackground(
                        colors: backgroundManager.currentColors,
                        // Use performance-aware settings
                        animationDuration: DeviceCapabilities.isLowEndDevice 
                            ? const Duration(seconds: 10) 
                            : const Duration(seconds: 7),
                        transitionDuration: const Duration(milliseconds: 400),
                        animationSpeed: DeviceCapabilities.isLowEndDevice 
                            ? 0.8 
                            : 1.2,
                      )
                    : MeshBackground(
                        colors: backgroundManager.currentColors,
                        animated: shouldEnableComplexBackground,
                        animationDuration: const Duration(seconds: 10),
                        animationSpeed: 0.8,
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
