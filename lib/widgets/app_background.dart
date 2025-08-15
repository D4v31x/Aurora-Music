import 'package:flutter/material.dart';
import 'package:mesh/mesh.dart';

/// A reusable app background widget that provides consistent mesh gradient backgrounds
class AppBackground extends StatelessWidget {
  final Widget child;
  final bool isDarkMode;

  const AppBackground({
    super.key,
    required this.child,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: OMeshGradient(
            mesh: OMeshRect(
              width: 2,
              height: 2,
              fallbackColor: isDarkMode ? const Color(0xFF1A237E) : const Color(0xFFE3F2FD),
              vertices: [
                // Top-left corner
                (0.0, 0.0).v.to(isDarkMode ? const Color(0xFF1A237E) : const Color(0xFFE3F2FD)),
                // Top-right corner  
                (1.0, 0.0).v.to(isDarkMode ? const Color(0xFF311B92) : const Color(0xFFBBDEFB)),
                // Bottom-left corner
                (0.0, 1.0).v.to(isDarkMode ? const Color(0xFF512DA8) : const Color(0xFF90CAF9)),
                // Bottom-right corner
                (1.0, 1.0).v.to(isDarkMode ? const Color(0xFF7B1FA2) : const Color(0xFF64B5F6)),
              ],
            ),
          ),
        ),
        child,
      ],
    );
  }
}