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
                  Color.lerp(
                    const Color(0xFF3400CE),
                    const Color(0xFF1E0077),
                    value,
                  )!,
                  Color.lerp(
                    const Color(0xFF7144FF),
                    const Color(0xFF000000),
                    value,
                  )!,
                ] : [
                  Color.lerp(
                    const Color(0xFF007BDE),
                    const Color(0xFF00BCD4),
                    value,
                  )!,
                  Color.lerp(
                    const Color(0xFF0018A6),
                    const Color(0xFF581B8C),
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
                        Color.lerp(
                          const Color(0xFF3400CE),
                          const Color(0xFF1E0077),
                          (value * 0.5 + 0.5).abs(),
                        )!,
                        Color.lerp(
                          const Color(0xFF7144FF),
                          const Color(0xFF000000),
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
                        Color.lerp(
                          const Color(0xFF007BDE),
                          const Color(0xFF00BCD4),
                          (value * 0.5 + 0.5).abs(),
                        )!,
                        Color.lerp(
                          const Color(0xFF0018A6),
                          const Color(0xFF581B8C),
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