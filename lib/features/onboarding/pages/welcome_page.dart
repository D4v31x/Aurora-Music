import 'package:flutter/material.dart';
import 'package:iconoir_flutter/iconoir_flutter.dart' as iconoir;
import 'package:aurora_music_v01/core/constants/font_constants.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../../shared/providers/providers.dart';

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
  late AnimationController _exitController;
  late AnimationController _textCycleController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _slideUpAnimation;
  late Animation<double> _fadeAnimation2;
  late Animation<Offset> _slideAnimation2;
  late Animation<double> _buttonFadeAnimation;
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
    {
      'title': 'Willkommen bei Aurora Music',
      'subtitle': 'Lass uns dein Erlebnis einrichten'
    },
    {
      'title': 'Bienvenido a Aurora Music',
      'subtitle': 'Configuremos tu experiencia'
    },
    {
      'title': 'Aurora Music में आपका स्वागत है',
      'subtitle': 'आइए आपका अनुभव सेट करें'
    },
    {
      'title': 'Добро пожаловать в Aurora Music',
      'subtitle': 'Давайте настроим ваш опыт'
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
    await _exitController.forward();
    widget.onContinue();
  }

  // Counts wrapped lines for [text] under [style] at [maxWidth].
  int _countTextLines(String text, TextStyle style, double maxWidth) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth);
    return painter.computeLineMetrics().length;
  }

  @override
  void dispose() {
    _textCycleTimer?.cancel();
    _controller.dispose();
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
        isDark ? Colors.white.withValues(alpha: 0.7) : Colors.black.withValues(alpha: 0.7);

    // Size the title area to the actual number of lines (current + incoming)
    // so a single-line title doesn't leave space reserved for a second line.
    const titleTextStyle = TextStyle(
      fontFamily: FontConstants.fontFamily,
      fontSize: 34,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.8,
      height: 1.2,
    );
    final maxTitleWidth = MediaQuery.of(context).size.width - 72; // matches horizontal padding
    final currentTitleLines = _countTextLines(
        _welcomeTexts[_currentLanguageIndex]['title']!, titleTextStyle, maxTitleWidth);
    final nextTitleLines = _countTextLines(
        _welcomeTexts[(_currentLanguageIndex + 1) % _welcomeTexts.length]['title']!,
        titleTextStyle,
        maxTitleWidth);
    final titleLines =
        currentTitleLines > nextTitleLines ? currentTitleLines : nextTitleLines;
    const titleLineHeight = 34 * 1.2;
    final titleBoxHeight = titleLineHeight * titleLines + 8;

    const subtitleTextStyle = TextStyle(
      fontFamily: FontConstants.fontFamily,
      fontSize: 17,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.2,
      height: 1.4,
    );
    final currentSubtitleLines = _countTextLines(
        _welcomeTexts[_currentLanguageIndex]['subtitle']!, subtitleTextStyle, maxTitleWidth);
    final nextSubtitleLines = _countTextLines(
        _welcomeTexts[(_currentLanguageIndex + 1) % _welcomeTexts.length]['subtitle']!,
        subtitleTextStyle,
        maxTitleWidth);
    final subtitleLines =
        currentSubtitleLines > nextSubtitleLines ? currentSubtitleLines : nextSubtitleLines;
    const subtitleLineHeight = 17 * 1.4;
    final subtitleBoxHeight = subtitleLineHeight * subtitleLines + 8;

    return Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Stack(
            children: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 36),
                  child: AnimatedBuilder(
                    animation: Listenable.merge(
                        [_controller, _exitController, _textCycleController]),
                    builder: (context, child) {
                      return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Page icon
                        SlideTransition(
                          position: _exitController.isAnimating ||
                                  _exitController.isCompleted
                              ? _exitSlideAnimation
                              : _slideAnimation,
                          child: FadeTransition(
                            opacity: _exitController.isAnimating ||
                                    _exitController.isCompleted
                                ? _exitFadeAnimation
                                : _fadeAnimation,
                          ),
                        ),

                        const SizedBox(height: 20),

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
                                height: titleBoxHeight,
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
                              height: subtitleBoxHeight,
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
                      child: OutlinedButton(
                        onPressed: _onButtonPressed,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: textColor,
                          side: BorderSide(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.3)
                                : Colors.black.withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                          shape: const CircleBorder(),
                          padding: const EdgeInsets.all(18),
                        ),
                        child: iconoir.NavArrowRight(
                          color: textColor,
                          width: 24,
                          height: 24,
                        ),
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
