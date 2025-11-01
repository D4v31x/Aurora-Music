import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'dart:ui' as ui;
import '../../../localization/locale_provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../widgets/pill_button.dart';

class LanguageSelectionPage extends StatefulWidget {
  final VoidCallback onContinue;
  final VoidCallback onBack;

  const LanguageSelectionPage({
    super.key,
    required this.onContinue,
    required this.onBack,
  });

  @override
  State<LanguageSelectionPage> createState() => _LanguageSelectionPageState();
}

class _LanguageSelectionPageState extends State<LanguageSelectionPage>
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

  String _selectedLanguage = 'en';

  final List<Map<String, String>> _languages = [
    {'code': 'en', 'name': 'English', 'native': 'English'},
    {'code': 'cs', 'name': 'Czech', 'native': 'Čeština'},
  ];

  @override
  void initState() {
    super.initState();
    _loadCurrentLanguage();

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

    // Exit animation
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

  Future<void> _loadCurrentLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedLanguage = prefs.getString('languageCode') ?? 'en';
    });
  }

  Future<void> _setLanguage(String languageCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('languageCode', languageCode);

    setState(() {
      _selectedLanguage = languageCode;
    });

    // Update locale in the app
    if (mounted) {
      final localeProvider = LocaleProvider.of(context);
      localeProvider?.setLocale(ui.Locale(languageCode));
    }
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
                        'Choose Your Language',
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
                      'Select your preferred language',
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

                  // Language options
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
                        child: ListView.builder(
                          itemCount: _languages.length,
                          itemBuilder: (context, index) {
                            final language = _languages[index];
                            final isSelected =
                                _selectedLanguage == language['code'];

                            final containerColor = isDark
                                ? Colors.white.withOpacity(0.05)
                                : Colors.black.withOpacity(0.05);
                            final borderColor = isDark
                                ? Colors.white.withOpacity(0.1)
                                : Colors.black.withOpacity(0.1);
                            final primaryTextColor = isDark
                                ? Colors.white.withOpacity(0.9)
                                : Colors.black.withOpacity(0.9);
                            final secondaryTextColor = isDark
                                ? Colors.white.withOpacity(0.6)
                                : Colors.black.withOpacity(0.6);

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12.0),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () => _setLanguage(language['code']!),
                                  borderRadius: BorderRadius.circular(16),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? Theme.of(context)
                                              .colorScheme
                                              .primary
                                              .withOpacity(0.15)
                                          : containerColor,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: isSelected
                                            ? Theme.of(context)
                                                .colorScheme
                                                .primary
                                            : borderColor,
                                        width: 2,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                language['native']!,
                                                style: TextStyle(
                                                  fontFamily: 'Outfit',
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w600,
                                                  color: isSelected
                                                      ? Theme.of(context)
                                                          .colorScheme
                                                          .primary
                                                      : primaryTextColor,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                language['name']!,
                                                style: TextStyle(
                                                  fontFamily: 'Outfit',
                                                  fontSize: 14,
                                                  color: secondaryTextColor,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        AnimatedOpacity(
                                          duration:
                                              const Duration(milliseconds: 300),
                                          opacity: isSelected ? 1.0 : 0.0,
                                          child: Icon(
                                            Icons.check_circle,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary,
                                            size: 28,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),

                  // Navigation buttons
                  Padding(
                    padding: const EdgeInsets.only(bottom: 40.0, top: 16.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: PillButton(
                            text: 'Back',
                            onPressed: widget.onBack,
                            isPrimary: false,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: PillButton(
                            text: 'Continue',
                            onPressed: () async {
                              await _exitController.forward();
                              widget.onContinue();
                            },
                            isPrimary: true,
                          ),
                        ),
                      ],
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
}
