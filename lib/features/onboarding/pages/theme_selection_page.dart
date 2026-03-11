import 'package:flutter/material.dart';
import 'package:aurora_music_v01/core/constants/font_constants.dart';
import 'package:provider/provider.dart';
import '../../../shared/providers/theme_provider.dart';
import '../../../shared/providers/performance_mode_provider.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/pill_button.dart';
import 'package:iconoir_flutter/iconoir_flutter.dart' as Iconoir;

class ThemeSelectionPage extends StatefulWidget {
  final VoidCallback onContinue;
  final VoidCallback onBack;

  const ThemeSelectionPage({
    super.key,
    required this.onContinue,
    required this.onBack,
  });

  @override
  State<ThemeSelectionPage> createState() => _ThemeSelectionPageState();
}

class _ThemeSelectionPageState extends State<ThemeSelectionPage>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _exitController;
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

    _titleFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _titleSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
      ),
    );

    _subtitleFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.1, 0.6, curve: Curves.easeOut),
      ),
    );

    _contentFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 0.7, curve: Curves.easeOut),
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
        isDark ? Colors.white.withValues(alpha: 0.6) : Colors.black.withValues(alpha: 0.6);

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
                  const SizedBox(height: 48),

                  // Page icon
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
                      child: const Iconoir.Palette(
                        color: Color(0xFF3B82F6),
                        height: 56,
                        width: 56,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

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
                            .onboardingThemeTitle,
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
                          .onboardingThemeSubtitle,
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

                  // Theme options
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
                        child: SingleChildScrollView(
                          child: Column(
                          children: [
                            // Dynamic color toggle
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  themeProvider.toggleDynamicColor();
                                },
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.05)
                                        : Colors.black.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.palette_rounded,
                                        size: 28,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              AppLocalizations.of(context)
                                                  .onboardingDynamicColors,
                                              style: TextStyle(
                                                fontFamily:
                                                    FontConstants.fontFamily,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                                color: textColor,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              AppLocalizations.of(context)
                                                  .onboardingDynamicColorsDesc,
                                              style: TextStyle(
                                                fontFamily:
                                                    FontConstants.fontFamily,
                                                fontSize: 14,
                                                color: subtitleColor,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Switch(
                                        value: themeProvider.useDynamicColor,
                                        onChanged: (_) {
                                          themeProvider.toggleDynamicColor();
                                        },
                                        activeThumbColor: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            // Accent color picker (when Material You is OFF)
                            if (!themeProvider.useDynamicColor) ...
                              _buildAccentColorSection(
                                context: context,
                                isDark: isDark,
                                textColor: textColor,
                                subtitleColor: subtitleColor,
                                themeProvider: themeProvider,
                              ),

                            // Background style option
                            const SizedBox(height: 16),
                            _buildBackgroundStyleSection(
                              context: context,
                              isDark: isDark,
                              textColor: textColor,
                              subtitleColor: subtitleColor,
                              themeProvider: themeProvider,
                            ),
                          ],
                        ),
                        ),
                      ),
                    ),
                  ),

                  // Navigation buttons
                  Padding(
                    padding: const EdgeInsets.only(bottom: 40.0, top: 16.0),
                    child: PillNavigationButtons(
                      backText: AppLocalizations.of(context).back,
                      continueText: AppLocalizations.of(context)
                          .continueButton,
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

  List<Widget> _buildAccentColorSection({
    required BuildContext context,
    required bool isDark,
    required Color textColor,
    required Color subtitleColor,
    required ThemeProvider themeProvider,
  }) {
    final presetColors = [
      Colors.deepPurple,
      Colors.blue,
      Colors.teal,
      Colors.green,
      Colors.orange,
      Colors.red,
      Colors.pink,
    ];

    return [
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Iconoir.ColorPicker(
                  color: Color(0xFF3B82F6),
                  height: 24,
                  width: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  AppLocalizations.of(context).accentColor,
                  style: TextStyle(
                    fontFamily: FontConstants.fontFamily,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              AppLocalizations.of(context).accentColorDesc,
              style: TextStyle(
                fontFamily: FontConstants.fontFamily,
                fontSize: 14,
                color: subtitleColor,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: presetColors.map((color) {
                final isSelected = themeProvider.customSeedColor.toARGB32() ==
                    color.toARGB32();
                return GestureDetector(
                  onTap: () => themeProvider.setCustomSeedColor(color),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(color: Colors.white, width: 3)
                          : Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                              width: 1.5),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 18)
                        : null,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    ];
  }

  Widget _buildBackgroundStyleSection({
    required BuildContext context,
    required bool isDark,
    required Color textColor,
    required Color subtitleColor,
    required ThemeProvider themeProvider,
  }) {
    final performanceProvider =
        Provider.of<PerformanceModeProvider>(context, listen: false);
    final isLowEnd = performanceProvider.isLowEndDevice;
    final isHighEnd = performanceProvider.shouldEnableBlur;

    if (!isLowEnd && !isHighEnd) return const SizedBox.shrink();

    final String title = isLowEnd
        ? AppLocalizations.of(context).backgroundLowEndStyle
        : AppLocalizations.of(context).backgroundHighEndStyle;
    final String subtitle = isLowEnd
        ? AppLocalizations.of(context).backgroundLowEndStyleDesc
        : AppLocalizations.of(context).backgroundHighEndStyleDesc;
    final List<String> options = isLowEnd
        ? [
            AppLocalizations.of(context).backgroundBlobs,
            AppLocalizations.of(context).backgroundSolid,
          ]
        : [
            AppLocalizations.of(context).backgroundBlurredArtwork,
            AppLocalizations.of(context).backgroundSolid,
          ];
    final int selectedIndex = isLowEnd
        ? (themeProvider.lowEndBackground == LowEndBackground.blobs ? 0 : 1)
        : (themeProvider.highEndBackground == HighEndBackground.blurredArtwork
            ? 0
            : 1);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontFamily: FontConstants.fontFamily,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontFamily: FontConstants.fontFamily,
              fontSize: 14,
              color: subtitleColor,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<int>(
              segments: options.asMap().entries.map((entry) {
                return ButtonSegment<int>(
                  value: entry.key,
                  label: Text(
                    entry.value,
                    style: const TextStyle(
                      fontFamily: FontConstants.fontFamily,
                    ),
                  ),
                );
              }).toList(),
              selected: {selectedIndex},
              onSelectionChanged: (selection) {
                if (selection.isEmpty) return;
                final idx = selection.first;
                if (isLowEnd) {
                  themeProvider.setLowEndBackground(
                    idx == 0 ? LowEndBackground.blobs : LowEndBackground.solid,
                  );
                } else {
                  themeProvider.setHighEndBackground(
                    idx == 0
                        ? HighEndBackground.blurredArtwork
                        : HighEndBackground.solid,
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

}
