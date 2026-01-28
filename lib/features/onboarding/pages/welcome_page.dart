import 'package:flutter/material.dart';
import 'package:aurora_music_v01/core/constants/font_constants.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../../shared/providers/theme_provider.dart';
import '../../../shared/widgets/pill_button.dart';
import '../../../l10n/app_localizations.dart';

class WelcomePage extends StatefulWidget {
  final VoidCallback onContinue;

  const WelcomePage({
    super.key,
    required this.onContinue,
  });

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _glowController;
  late AnimationController _exitController;
  late AnimationController _textCycleController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _slideUpAnimation;
  late Animation<double> _fadeAnimation2;
  late Animation<Offset> _slideAnimation2;
  late Animation<double> _buttonFadeAnimation;
  late Animation<double> _glowAnimation;
  late Animation<double> _exitFadeAnimation;
  late Animation<Offset> _exitSlideAnimation;

  // Text cycle animations for title
  late Animation<double> _textFadeOutAnimation;
  late Animation<double> _textSlideOutAnimation;
  late Animation<double> _textFadeInAnimation;
  late Animation<double> _textSlideInAnimation;

  // Text cycle animations for subtitle (staggered)
  late Animation<double> _subtitleFadeOutAnimation;
  late Animation<double> _subtitleSlideOutAnimation;
  late Animation<double> _subtitleFadeInAnimation;
  late Animation<double> _subtitleSlideInAnimation;

  Timer? _textCycleTimer;
  int _currentLanguageIndex = 0;
  bool _isTransitioning = false;

  // Welcome text in different languages (title and subtitle)
  final List<Map<String, String>> _welcomeTexts = [
    {
      'title': 'Welcome to Aurora Music',
      'subtitle': "Let's set up your experience"
    },
    {
      'title': 'Vítejte v Aurora Music',
      'subtitle': 'Pojďme nastavit váš zážitek'
    },
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    // Staggered fade animations for smoother appearance
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.15), // Reduced distance for subtlety
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
      ),
    );

    // Smooth upward shift
    _slideUpAnimation = Tween<double>(
      begin: 0.0,
      end: -8.0, // Subtle movement
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 0.7, curve: Curves.easeInOut),
      ),
    );

    // Second text with delay for stagger effect
    _fadeAnimation2 = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 0.8, curve: Curves.easeOut),
      ),
    );

    _slideAnimation2 = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 0.8, curve: Curves.easeOutCubic),
      ),
    );

    // Button fades in last
    _buttonFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
      ),
    );

    // Glow animation controller for button press
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _glowAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _glowController,
        curve: Curves.easeInOut,
      ),
    );

    // Exit animation - smooth and quick
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
      end: const Offset(0, -0.08), // Subtle upward exit
    ).animate(
      CurvedAnimation(
        parent: _exitController,
        curve: Curves.easeInCubic,
      ),
    );

    // Text cycle animation controller - smooth ease transition
    _textCycleController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // Fade out and slide up for outgoing TITLE text - starts first
    _textFadeOutAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(
      CurvedAnimation(
        parent: _textCycleController,
        curve: const Interval(0.0, 0.35, curve: Curves.ease),
      ),
    );

    _textSlideOutAnimation = Tween<double>(
      begin: 0.0,
      end: -20.0,
    ).animate(
      CurvedAnimation(
        parent: _textCycleController,
        curve: const Interval(0.0, 0.35, curve: Curves.ease),
      ),
    );

    // Fade in and slide up for incoming TITLE text
    _textFadeInAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _textCycleController,
        curve: const Interval(0.5, 0.85, curve: Curves.ease),
      ),
    );

    _textSlideInAnimation = Tween<double>(
      begin: 20.0,
      end: 0.0,
    ).animate(
      CurvedAnimation(
        parent: _textCycleController,
        curve: const Interval(0.5, 0.85, curve: Curves.ease),
      ),
    );

    // Fade out and slide up for outgoing SUBTITLE text - starts slightly after title
    _subtitleFadeOutAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(
      CurvedAnimation(
        parent: _textCycleController,
        curve: const Interval(0.1, 0.45, curve: Curves.ease),
      ),
    );

    _subtitleSlideOutAnimation = Tween<double>(
      begin: 0.0,
      end: -20.0,
    ).animate(
      CurvedAnimation(
        parent: _textCycleController,
        curve: const Interval(0.1, 0.45, curve: Curves.ease),
      ),
    );

    // Fade in and slide up for incoming SUBTITLE text - starts slightly after title
    _subtitleFadeInAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _textCycleController,
        curve: const Interval(0.6, 1.0, curve: Curves.ease),
      ),
    );

    _subtitleSlideInAnimation = Tween<double>(
      begin: 20.0,
      end: 0.0,
    ).animate(
      CurvedAnimation(
        parent: _textCycleController,
        curve: const Interval(0.6, 1.0, curve: Curves.ease),
      ),
    );

    _controller.forward();

    // Start the text cycling after initial animation completes
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _startTextCycle();
      }
    });
  }

  void _startTextCycle() {
    _textCycleTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!mounted || _isTransitioning) return;
      _cycleText();
    });
  }

  void _cycleText() async {
    if (_isTransitioning) return;
    _isTransitioning = true;

    // Start the animation
    await _textCycleController.forward();

    // Update the index at the middle of the animation
    setState(() {
      _currentLanguageIndex =
          (_currentLanguageIndex + 1) % _welcomeTexts.length;
    });

    // Reset the controller for next cycle
    _textCycleController.reset();
    _isTransitioning = false;
  }

  void _onButtonPressed() async {
    _textCycleTimer?.cancel();
    _glowController.forward(from: 0.0);
    await _exitController.forward();
    widget.onContinue();
  }

  Color _getRainbowColor(double value) {
    // Create a subtle rainbow effect that shifts through colors
    // Using HSL to create smooth transitions
    final hue = (value * 360) % 360;
    return HSLColor.fromAHSL(1.0, hue, 0.6, 0.7).toColor();
  }

  @override
  void dispose() {
    _textCycleTimer?.cancel();
    _controller.dispose();
    _glowController.dispose();
    _exitController.dispose();
    _textCycleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final textColor = isDark ? Colors.white : Colors.black;
    final subtitleColor =
        isDark ? Colors.white.withOpacity(0.7) : Colors.black.withOpacity(0.7);

    return Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Stack(
            children: [
              Center(
                child: AnimatedBuilder(
                  animation: Listenable.merge(
                      [_controller, _exitController, _textCycleController]),
                  builder: (context, child) {
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Animated "Welcome to Aurora Music" text that cycles through languages
                        Transform.translate(
                          offset: Offset(0, _slideUpAnimation.value),
                          child: SlideTransition(
                            position: _exitController.isAnimating ||
                                    _exitController.isCompleted
                                ? _exitSlideAnimation
                                : _slideAnimation,
                            child: FadeTransition(
                              opacity: _exitController.isAnimating ||
                                      _exitController.isCompleted
                                  ? _exitFadeAnimation
                                  : _fadeAnimation,
                              child: SizedBox(
                                height:
                                    50, // Fixed height to prevent layout jumps
                                child: ClipRect(
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      // Current title (fades out and slides up)
                                      Transform.translate(
                                        offset: Offset(
                                            0, _textSlideOutAnimation.value),
                                        child: Opacity(
                                          opacity: _textFadeOutAnimation.value,
                                          child: Text(
                                            _welcomeTexts[_currentLanguageIndex]
                                                ['title']!,
                                            style: TextStyle(
                                              fontFamily: FontConstants.fontFamily,
                                              fontSize: 34,
                                              fontWeight: FontWeight.w600,
                                              color: textColor,
                                              letterSpacing: -0.8,
                                              height: 1.2,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ),
                                      // Next title (fades in and slides up from below)
                                      if (_textCycleController.value > 0.0)
                                        Transform.translate(
                                          offset: Offset(
                                              0, _textSlideInAnimation.value),
                                          child: Opacity(
                                            opacity: _textFadeInAnimation.value,
                                            child: Text(
                                              _welcomeTexts[
                                                  (_currentLanguageIndex + 1) %
                                                      _welcomeTexts
                                                          .length]['title']!,
                                              style: TextStyle(
                                                fontFamily: FontConstants.fontFamily,
                                                fontSize: 34,
                                                fontWeight: FontWeight.w600,
                                                color: textColor,
                                                letterSpacing: -0.8,
                                                height: 1.2,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Spacing
                        SizedBox(height: 12 * _fadeAnimation2.value),

                        // Second text - "Let's set up your experience" - also cycles
                        SlideTransition(
                          position: _exitController.isAnimating ||
                                  _exitController.isCompleted
                              ? _exitSlideAnimation
                              : _slideAnimation2,
                          child: FadeTransition(
                            opacity: _exitController.isAnimating ||
                                    _exitController.isCompleted
                                ? _exitFadeAnimation
                                : _fadeAnimation2,
                            child: SizedBox(
                              height:
                                  30, // Fixed height to prevent layout jumps
                              child: ClipRect(
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    // Current subtitle (fades out and slides up - slightly after title)
                                    Transform.translate(
                                      offset: Offset(
                                          0, _subtitleSlideOutAnimation.value),
                                      child: Opacity(
                                        opacity:
                                            _subtitleFadeOutAnimation.value,
                                        child: Text(
                                          _welcomeTexts[_currentLanguageIndex]
                                              ['subtitle']!,
                                          style: TextStyle(
                                            fontFamily: FontConstants.fontFamily,
                                            fontSize: 17,
                                            fontWeight: FontWeight.w400,
                                            color: subtitleColor,
                                            letterSpacing: 0.2,
                                            height: 1.4,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                    // Next subtitle (fades in and slides up from below - slightly after title)
                                    if (_textCycleController.value > 0.0)
                                      Transform.translate(
                                        offset: Offset(
                                            0, _subtitleSlideInAnimation.value),
                                        child: Opacity(
                                          opacity:
                                              _subtitleFadeInAnimation.value,
                                          child: Text(
                                            _welcomeTexts[
                                                (_currentLanguageIndex + 1) %
                                                    _welcomeTexts
                                                        .length]['subtitle']!,
                                            style: TextStyle(
                                              fontFamily: FontConstants.fontFamily,
                                              fontSize: 17,
                                              fontWeight: FontWeight.w400,
                                              color: subtitleColor,
                                              letterSpacing: 0.2,
                                              height: 1.4,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

              // Continue button
              Positioned(
                bottom: 40,
                left: 0,
                right: 0,
                child: FadeTransition(
                  opacity: _buttonFadeAnimation,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32.0),
                      child: AnimatedBuilder(
                        animation: _glowAnimation,
                        builder: (context, child) {
                          return DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(100),
                              boxShadow: _glowAnimation.value > 0
                                  ? [
                                      BoxShadow(
                                        color: _getRainbowColor(
                                                _glowAnimation.value)
                                            .withOpacity(
                                                0.4 * _glowAnimation.value),
                                        blurRadius: 20 * _glowAnimation.value,
                                        spreadRadius: 2 * _glowAnimation.value,
                                      ),
                                      BoxShadow(
                                        color: _getRainbowColor(
                                                _glowAnimation.value + 0.3)
                                            .withOpacity(
                                                0.3 * _glowAnimation.value),
                                        blurRadius: 30 * _glowAnimation.value,
                                        spreadRadius: 1 * _glowAnimation.value,
                                      ),
                                    ]
                                  : [],
                            ),
                            child: PillButton(
                              text: AppLocalizations.of(context)
                                  .translate('get_started'),
                              onPressed: _onButtonPressed,
                              isPrimary: false,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 48, vertical: 18),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ));
  }
}
