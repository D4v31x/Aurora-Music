import 'package:flutter/material.dart';
import 'package:aurora_music_v01/core/constants/font_constants.dart';
import 'package:provider/provider.dart';
import '../../../mixins/providers/theme_provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../mixins/widgets/pill_button.dart';

class InternetUsagePage extends StatefulWidget {
  final VoidCallback onContinue;
  final VoidCallback onBack;

  const InternetUsagePage({
    super.key,
    required this.onContinue,
    required this.onBack,
  });

  @override
  State<InternetUsagePage> createState() => _InternetUsagePageState();
}

class _InternetUsagePageState extends State<InternetUsagePage>
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

    _subtitleFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 0.7, curve: Curves.easeOut),
      ),
    );

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
                        AppLocalizations.of(context)
                            .translate('onboarding_internet_title'),
                        style: TextStyle(
                          fontFamily: FontConstants.fontFamily,
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
                      AppLocalizations.of(context)
                          .translate('onboarding_internet_subtitle'),
                      style: TextStyle(
                        fontFamily: FontConstants.fontFamily,
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
                            _buildInfoCard(
                              context: context,
                              icon: Icons.image_search_rounded,
                              title: AppLocalizations.of(context)
                                  .translate('onboarding_album_artwork'),
                              description: AppLocalizations.of(context)
                                  .translate('onboarding_album_artwork_desc'),
                              isOptional: false,
                              isDark: isDark,
                            ),
                            const SizedBox(height: 16),
                            _buildInfoCard(
                              context: context,
                              icon: Icons.info_outline_rounded,
                              title: AppLocalizations.of(context)
                                  .translate('onboarding_music_metadata'),
                              description: AppLocalizations.of(context)
                                  .translate('onboarding_music_metadata_desc'),
                              isOptional: false,
                              isDark: isDark,
                            ),
                            const SizedBox(height: 16),
                            _buildInfoCard(
                              context: context,
                              icon: Icons.lyrics_rounded,
                              title: AppLocalizations.of(context)
                                  .translate('onboarding_lyrics'),
                              description: AppLocalizations.of(context)
                                  .translate('onboarding_lyrics_desc'),
                              isOptional: false,
                              isDark: isDark,
                            ),
                            const SizedBox(height: 24),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.lock_outline_rounded,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      AppLocalizations.of(context)
                                          .translate('onboarding_privacy_note'),
                                      style: TextStyle(
                                        fontFamily: FontConstants.fontFamily,
                                        fontSize: 13,
                                        color: textColor.withOpacity(0.9),
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

                  // Navigation buttons
                  Padding(
                    padding: const EdgeInsets.only(bottom: 40.0, top: 16.0),
                    child: PillNavigationButtons(
                      backText: AppLocalizations.of(context).translate('back'),
                      continueText: AppLocalizations.of(context)
                          .translate('continueButton'),
                      onBack: () async {
                        await _exitController.forward();
                        widget.onBack();
                      },
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

  Widget _buildInfoCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String description,
    required bool isOptional,
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
    final tagBgColor =
        isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1);
    final tagTextColor =
        isDark ? Colors.white.withOpacity(0.7) : Colors.black.withOpacity(0.7);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: containerColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: borderColor,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontFamily: FontConstants.fontFamily,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: titleColor,
                        ),
                      ),
                    ),
                    if (isOptional)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: tagBgColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          AppLocalizations.of(context)
                              .translate('onboarding_optional'),
                          style: TextStyle(
                            fontFamily: FontConstants.fontFamily,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: tagTextColor,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontFamily: FontConstants.fontFamily,
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
