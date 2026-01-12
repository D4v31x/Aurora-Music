import 'package:flutter/material.dart';
import 'package:aurora_music_v01/constants/font_constants.dart';
import 'package:provider/provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../localization/app_localizations.dart';
import '../../../widgets/pill_button.dart';

class BetaWelcomePage extends StatefulWidget {
  final VoidCallback onContinue;
  final VoidCallback onBack;

  const BetaWelcomePage({
    super.key,
    required this.onContinue,
    required this.onBack,
  });

  @override
  State<BetaWelcomePage> createState() => _BetaWelcomePageState();
}

class _BetaWelcomePageState extends State<BetaWelcomePage>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _exitController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
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
                        AppLocalizations.of(context)
                            .translate('beta_welcome_title'),
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
                    opacity: fadeOp,
                    child: Text(
                      AppLocalizations.of(context)
                          .translate('beta_welcome_thanks'),
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

                  // Info cards
                  Expanded(
                    child: SlideTransition(
                      position: slidePos,
                      child: FadeTransition(
                        opacity: fadeOp,
                        child: ListView(
                          children: [
                            _buildInfoCard(
                              context,
                              icon: Icons.bug_report_outlined,
                              titleKey: 'beta_expect_bugs_title',
                              descriptionKey: 'beta_expect_bugs_desc',
                              color: Colors.orange,
                              isDark: isDark,
                            ),
                            const SizedBox(height: 12),
                            _buildInfoCard(
                              context,
                              icon: Icons.feedback_outlined,
                              titleKey: 'beta_feedback_title',
                              descriptionKey: 'beta_feedback_desc',
                              color: Colors.green,
                              isDark: isDark,
                            ),
                            const SizedBox(height: 12),
                            _buildInfoCard(
                              context,
                              icon: Icons.update_outlined,
                              titleKey: 'beta_updates_title',
                              descriptionKey: 'beta_updates_desc',
                              color: Colors.purple,
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

  Widget _buildInfoCard(
    BuildContext context, {
    required IconData icon,
    required String titleKey,
    required String descriptionKey,
    required Color color,
    required bool isDark,
  }) {
    final titleColor = isDark ? Colors.white : Colors.black;
    final descriptionColor =
        isDark ? Colors.white.withOpacity(0.6) : Colors.black.withOpacity(0.6);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (isDark ? Colors.white : Colors.black).withOpacity(0.1),
          width: 1.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 24,
              color: color,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context).translate(titleKey),
                  style: TextStyle(
                    fontFamily: FontConstants.fontFamily,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  AppLocalizations.of(context).translate(descriptionKey),
                  style: TextStyle(
                    fontFamily: FontConstants.fontFamily,
                    fontSize: 13,
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
