import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../widgets/pill_button.dart';

class DownloadChoicePage extends StatefulWidget {
  final VoidCallback onContinue;
  final VoidCallback onBack;
  final Function(bool downloadLyrics, bool downloadArtwork) onChoiceSelected;

  const DownloadChoicePage({
    super.key,
    required this.onContinue,
    required this.onBack,
    required this.onChoiceSelected,
  });

  @override
  State<DownloadChoicePage> createState() => _DownloadChoicePageState();
}

class _DownloadChoicePageState extends State<DownloadChoicePage>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _exitController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _exitFadeAnimation;
  late Animation<Offset> _exitSlideAnimation;

  bool _downloadLyrics = true;
  bool _downloadArtwork = true;

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
        curve: Curves.easeOut,
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ),
    );

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

  Future<void> _handleContinue() async {
    await _exitController.forward();
    widget.onChoiceSelected(_downloadLyrics, _downloadArtwork);
    widget.onContinue();
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
              final slidePos =
                  _exitController.isAnimating || _exitController.isCompleted
                      ? _exitSlideAnimation
                      : _slideAnimation;
              final fadeOp =
                  _exitController.isAnimating || _exitController.isCompleted
                      ? _exitFadeAnimation
                      : _fadeAnimation;

              return Column(
                children: [
                  const SizedBox(height: 80),

                  // Title
                  SlideTransition(
                    position: slidePos,
                    child: FadeTransition(
                      opacity: fadeOp,
                      child: Text(
                        'Download Content?',
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
                    opacity: fadeOp,
                    child: Text(
                      'Pre-download lyrics and artwork for offline use',
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

                  // Options
                  Expanded(
                    child: SlideTransition(
                      position: slidePos,
                      child: FadeTransition(
                        opacity: fadeOp,
                        child: ListView(
                          children: [
                            _buildOption(
                              icon: Icons.lyrics_rounded,
                              title: 'Download Lyrics',
                              subtitle: 'Synced lyrics for all songs',
                              value: _downloadLyrics,
                              onChanged: (value) {
                                setState(() {
                                  _downloadLyrics = value;
                                });
                              },
                              isDark: isDark,
                            ),
                            const SizedBox(height: 16),
                            _buildOption(
                              icon: Icons.image_rounded,
                              title: 'Download Artwork',
                              subtitle: 'Album covers and artist images',
                              value: _downloadArtwork,
                              onChanged: (value) {
                                setState(() {
                                  _downloadArtwork = value;
                                });
                              },
                              isDark: isDark,
                            ),
                            const SizedBox(height: 24),

                            // Info card
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: (isDark ? Colors.white : Colors.black)
                                    .withOpacity(0.05),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: (isDark ? Colors.white : Colors.black)
                                      .withOpacity(0.1),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline_rounded,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Note: Downloads require storage permissions. Grant them in the next step to enable downloading.',
                                      style: TextStyle(
                                        fontFamily: 'Outfit',
                                        fontSize: 13,
                                        fontWeight: FontWeight.w400,
                                        color: subtitleColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Navigation buttons
                  SlideTransition(
                    position: slidePos,
                    child: FadeTransition(
                      opacity: fadeOp,
                      child: Padding(
                        padding: const EdgeInsets.only(
                            bottom: 40.0, left: 24.0, right: 24.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: PillButton(
                                text: 'Back',
                                onPressed: () async {
                                  await _exitController.forward();
                                  widget.onBack();
                                },
                                isPrimary: false,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 2,
                              child: PillButton(
                                text: (_downloadLyrics || _downloadArtwork)
                                    ? 'Download Now'
                                    : 'Skip',
                                onPressed: _handleContinue,
                                isPrimary: true,
                              ),
                            ),
                          ],
                        ),
                      ),
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

  Widget _buildOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required bool isDark,
  }) {
    final titleColor = isDark ? Colors.white : Colors.black;
    final subtitleColor =
        isDark ? Colors.white.withOpacity(0.5) : Colors.black.withOpacity(0.5);

    return Container(
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: value
              ? Theme.of(context).colorScheme.primary.withOpacity(0.3)
              : (isDark ? Colors.white : Colors.black).withOpacity(0.1),
          width: 1.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onChanged(!value),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: value
                        ? Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.15)
                        : (isDark ? Colors.white : Colors.black)
                            .withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: value
                        ? Theme.of(context).colorScheme.primary
                        : (isDark ? Colors.white : Colors.black)
                            .withOpacity(0.5),
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
                        subtitle,
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: subtitleColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: value,
                  onChanged: onChanged,
                  activeThumbColor: Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
