import 'package:flutter/material.dart';
import 'package:aurora_music_v01/constants/font_constants.dart';
import 'package:provider/provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../services/donation_service.dart';
import '../../../localization/app_localizations.dart';
import '../../../widgets/pill_button.dart';

class DonationPage extends StatefulWidget {
  final VoidCallback onContinue;
  final VoidCallback onBack;

  const DonationPage({
    super.key,
    required this.onContinue,
    required this.onBack,
  });

  @override
  State<DonationPage> createState() => _DonationPageState();
}

class _DonationPageState extends State<DonationPage>
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
                            .translate('support_aurora'),
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
                          .translate('support_aurora_desc'),
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

                  // Donation options
                  Expanded(
                    child: SlideTransition(
                      position: slidePos,
                      child: FadeTransition(
                        opacity: fadeOp,
                        child: ListView(
                          children: [
                            _buildDonationOption(
                              context: context,
                              icon: Icons.coffee_rounded,
                              title: AppLocalizations.of(context)
                                  .translate('buy_me_a_coffee'),
                              color: const Color(0xFFFFDD00),
                              isDark: isDark,
                              onTap: () => DonationService.openBuyMeACoffee(),
                            ),
                            const SizedBox(height: 12),
                            _buildDonationOption(
                              context: context,
                              icon: Icons.favorite_rounded,
                              title: AppLocalizations.of(context)
                                  .translate('kofi'),
                              color: const Color(0xFFFF5E5B),
                              isDark: isDark,
                              onTap: () => DonationService.openKofi(),
                            ),
                            const SizedBox(height: 24),
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
                                      AppLocalizations.of(context)
                                          .translate('donation_note'),
                                      style: TextStyle(
                                        fontFamily: FontConstants.fontFamily,
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

  Widget _buildDonationOption({
    required BuildContext context,
    required IconData icon,
    required String title,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final titleColor = isDark ? Colors.white : Colors.black;

    return Container(
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (isDark ? Colors.white : Colors.black).withOpacity(0.1),
          width: 1.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
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
                    color: color,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
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
                Icon(
                  Icons.open_in_new_rounded,
                  size: 20,
                  color:
                      (isDark ? Colors.white : Colors.black).withOpacity(0.3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
