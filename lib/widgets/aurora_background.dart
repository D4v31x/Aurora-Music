import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:simple_animations/simple_animations.dart';
import 'package:supercharged/supercharged.dart';
import '../providers/theme_provider.dart';

class AuroraBackground extends StatelessWidget {
  final bool isThemeSelection;
  
  const AuroraBackground({
    super.key, 
    this.isThemeSelection = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

    if (isThemeSelection) {
      return _ThemeSelectionBackground(isDarkMode: isDarkMode);
    }

    return SizedBox.expand(
      child: CustomAnimationBuilder<double>(
        tween: 0.0.tweenTo(1.0),
        duration: 3.seconds,
        builder: (context, value, child) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDarkMode ? [
                  // Dark blue to violet gradient for dark mode
                  Color.lerp(
                    const Color(0xFF1A237E), // Dark blue
                    const Color(0xFF311B92), // Dark violet
                    value,
                  )!,
                  Color.lerp(
                    const Color(0xFF512DA8), // Medium violet
                    const Color(0xFF7B1FA2), // Purple
                    value,
                  )!,
                ] : [
                  // Light blue gradient for light mode
                  Color.lerp(
                    const Color(0xFFE3F2FD), // Light blue
                    const Color(0xFFBBDEFB), // Lighter blue
                    value,
                  )!,
                  Color.lerp(
                    const Color(0xFF90CAF9), // Medium light blue
                    const Color(0xFF64B5F6), // Blue
                    value,
                  )!,
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ThemeSelectionBackground extends StatelessWidget {
  final bool isDarkMode;

  const _ThemeSelectionBackground({
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Stack(
        children: [
          // Dark theme gradient
          AnimatedOpacity(
            opacity: isDarkMode ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 500),
            child: CustomAnimationBuilder<double>(
              tween: 0.0.tweenTo(1.0),
              duration: 5.seconds,
              builder: (context, value, child) {
                return Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft.add(Alignment(value * 0.2, value * 0.2)),
                      end: Alignment.bottomRight.add(Alignment(-value * 0.2, -value * 0.2)),
                      colors: [
                        // Dark blue to violet gradient
                        Color.lerp(
                          const Color(0xFF1A237E), // Dark blue
                          const Color(0xFF311B92), // Dark violet
                          (value * 0.5 + 0.5).abs(),
                        )!,
                        Color.lerp(
                          const Color(0xFF512DA8), // Medium violet
                          const Color(0xFF7B1FA2), // Purple
                          value,
                        )!,
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          // Light theme gradient
          AnimatedOpacity(
            opacity: isDarkMode ? 0.0 : 1.0,
            duration: const Duration(milliseconds: 500),
            child: CustomAnimationBuilder<double>(
              tween: 0.0.tweenTo(1.0),
              duration: 5.seconds,
              builder: (context, value, child) {
                return Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft.add(Alignment(-value * 0.2, -value * 0.2)),
                      end: Alignment.bottomRight.add(Alignment(value * 0.2, value * 0.2)),
                      colors: [
                        // Light blue gradient
                        Color.lerp(
                          const Color(0xFFE3F2FD), // Light blue
                          const Color(0xFFBBDEFB), // Lighter blue
                          (value * 0.5 + 0.5).abs(),
                        )!,
                        Color.lerp(
                          const Color(0xFF90CAF9), // Medium light blue
                          const Color(0xFF64B5F6), // Blue
                          value,
                        )!,
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}