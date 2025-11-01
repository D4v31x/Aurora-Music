import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../widgets/pill_button.dart';

class AppInfoPage extends StatefulWidget {
  final VoidCallback onContinue;
  final VoidCallback onBack;

  const AppInfoPage({
    super.key,
    required this.onContinue,
    required this.onBack,
  });

  @override
  State<AppInfoPage> createState() => _AppInfoPageState();
}

class _AppInfoPageState extends State<AppInfoPage>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _exitController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _titleFadeAnimation;
  late Animation<Offset> _titleSlideAnimation;
  late Animation<double> _subtitleFadeAnimation;
  late Animation<double> _contentFadeAnimation;
  late Animation<Offset> _contentSlideAnimation;
  late Animation<double> _exitFadeAnimation;
  late Animation<Offset> _exitSlideAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
      ),
    );

    // Title animations (slightly delayed)
    _titleFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.1, 0.6, curve: Curves.easeOut),
      ),
    );

    _titleSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.1, 0.7, curve: Curves.easeOutCubic),
      ),
    );

    // Subtitle fade (more delayed)
    _subtitleFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 0.7, curve: Curves.easeOut),
      ),
    );

    // Content animations (last to appear)
    _contentFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 0.8, curve: Curves.easeOut),
      ),
    );

    _contentSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 0.9, curve: Curves.easeOutCubic),
      ),
    );

    // Exit animation controller
    _exitController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _exitFadeAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(
      CurvedAnimation(
        parent: _exitController,
        curve: Curves.easeIn,
      ),
    );

    _exitSlideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, -0.08),
    ).animate(
      CurvedAnimation(
        parent: _exitController,
        curve: Curves.easeInCubic,
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _exitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final textColor = isDark ? Colors.white : Colors.black;
    final subtitleColor =
        isDark ? Colors.white.withOpacity(0.6) : Colors.black.withOpacity(0.6);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: AnimatedBuilder(
            animation: Listenable.merge([_controller, _exitController]),
            builder: (context, child) {
              return Column(
                children: [
                  const SizedBox(height: 80),

                  // Title
                  SlideTransition(
                    position: _exitController.isAnimating ||
                            _exitController.isCompleted
                        ? _exitSlideAnimation
                        : _titleSlideAnimation,
                    child: FadeTransition(
                      opacity: _exitController.isAnimating ||
                              _exitController.isCompleted
                          ? _exitFadeAnimation
                          : _titleFadeAnimation,
                      child: Text(
                        'Welcome to Aurora Music',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 32,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                          letterSpacing: -0.8,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Subtitle
                  FadeTransition(
                    opacity: _exitController.isAnimating ||
                            _exitController.isCompleted
                        ? _exitFadeAnimation
                        : _subtitleFadeAnimation,
                    child: Text(
                      'Your personal music companion',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: subtitleColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  const SizedBox(height: 48),

                  // Features list
                  Expanded(
                    child: SlideTransition(
                      position: _exitController.isAnimating ||
                              _exitController.isCompleted
                          ? _exitSlideAnimation
                          : _contentSlideAnimation,
                      child: FadeTransition(
                        opacity: _exitController.isAnimating ||
                                _exitController.isCompleted
                            ? _exitFadeAnimation
                            : _contentFadeAnimation,
                        child: ListView(
                          children: [
                            _buildFeatureItem(
                              icon: Icons.folder_open_rounded,
                              title: 'Local Music Library',
                              description:
                                  'Play your music files stored on your device',
                              isDark: isDark,
                            ),
                            const SizedBox(height: 16),
                            _buildFeatureItem(
                              icon: Icons.image_rounded,
                              title: 'Beautiful Album Art',
                              description:
                                  'Automatically fetch and display album artwork',
                              isDark: isDark,
                            ),
                            const SizedBox(height: 16),
                            _buildFeatureItem(
                              icon: Icons.palette_rounded,
                              title: 'Material You Design',
                              description:
                                  'Dynamic colors that adapt to your preferences',
                              isDark: isDark,
                            ),
                            const SizedBox(height: 16),
                            _buildFeatureItem(
                              icon: Icons.queue_music_rounded,
                              title: 'Smart Playlists',
                              description:
                                  'Create and manage your music collections',
                              isDark: isDark,
                            ),
                            const SizedBox(height: 16),
                            _buildFeatureItem(
                              icon: Icons.lyrics_rounded,
                              title: 'Lyrics Support',
                              description:
                                  'View synchronized lyrics while listening',
                              isDark: isDark,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Navigation buttons
                  Padding(
                    padding: const EdgeInsets.only(bottom: 40.0, top: 16.0),
                    child: PillNavigationButtons(
                      onBack: widget.onBack,
                      onContinue: () async {
                        await _exitController.forward();
                        widget.onContinue();
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required String title,
    required String description,
    required bool isDark,
  }) {
    final containerColor = isDark
        ? Colors.white.withOpacity(0.05)
        : Colors.black.withOpacity(0.05);
    final borderColor =
        isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1);
    final titleColor = isDark ? Colors.white : Colors.black;
    final descriptionColor =
        isDark ? Colors.white.withOpacity(0.6) : Colors.black.withOpacity(0.6);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: containerColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: borderColor,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: Theme.of(context).colorScheme.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 14,
                    color: descriptionColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
