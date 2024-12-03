import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/aurora_background.dart';
import 'permissions_screen.dart';

class ThemeSelectionScreen extends StatelessWidget {
  const ThemeSelectionScreen({super.key});

  void _setTheme(BuildContext context, bool isDark) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    if (themeProvider.isDarkMode != isDark) {
      themeProvider.toggleTheme();
    }
  }

  void _navigateToPermissions(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const PermissionsScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        return Scaffold(
          body: Stack(
            children: [
              const AuroraBackground(isThemeSelection: true),
              SafeArea(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32.0),
                    child: Column(
                      children: [
                        const Spacer(flex: 1),
                        Text(
                          'Set Your Theme',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ).animate().fadeIn(duration: 600.ms),
                        const SizedBox(height: 8),
                        Text(
                          'Choose your preferred appearance',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.white70,
                          ),
                          textAlign: TextAlign.center,
                        ).animate().fadeIn(delay: 200.ms),
                        const SizedBox(height: 48),
                        Column(
                          children: [
                            _buildThemeOption(
                              context,
                              'Light Mode',
                              Icons.light_mode,
                              !themeProvider.isDarkMode,
                              () => _setTheme(context, false),
                            ).animate().fadeIn(delay: 400.ms),
                            const SizedBox(height: 16),
                            _buildThemeOption(
                              context,
                              'Dark Mode',
                              Icons.dark_mode,
                              themeProvider.isDarkMode,
                              () => _setTheme(context, true),
                            ).animate().fadeIn(delay: 600.ms),
                          ],
                        ),
                        const Spacer(flex: 2),
                        Container(
                          width: double.infinity,
                          height: 56,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(28),
                            color: Colors.white.withOpacity(0.15),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(28),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: ElevatedButton(
                                onPressed: () => _navigateToPermissions(context),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(28),
                                  ),
                                ),
                                child: const Text(
                                  'Next',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ).animate().scale(delay: 800.ms),
                        const Spacer(flex: 1),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildThemeOption(
    BuildContext context,
    String title,
    IconData icon,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: isSelected 
            ? Colors.white.withOpacity(0.2) 
            : Colors.white.withOpacity(0.1),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                child: Row(
                  children: [
                    Icon(
                      icon,
                      color: Colors.white.withOpacity(isSelected ? 1.0 : 0.7),
                      size: 28,
                    ),
                    const SizedBox(width: 16),
                    Text(
                      title,
                      style: TextStyle(
                        color: Colors.white.withOpacity(isSelected ? 1.0 : 0.7),
                        fontSize: 16,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                    const Spacer(),
                    if (isSelected)
                      const Icon(
                        Icons.check_circle,
                        color: Colors.white,
                        size: 24,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}