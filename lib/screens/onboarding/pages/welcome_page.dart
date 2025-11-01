import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../widgets/pill_button.dart';

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
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _slideUpAnimation;
  late Animation<double> _fadeAnimation2;
  late Animation<Offset> _slideAnimation2;
  late Animation<double> _buttonFadeAnimation;
  late Animation<double> _glowAnimation;
  late Animation<double> _exitFadeAnimation;
  late Animation<Offset> _exitSlideAnimation;

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

    _controller.forward();
  }

  void _onButtonPressed() async {
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
    _controller.dispose();
    _glowController.dispose();
    _exitController.dispose();
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
                  animation: Listenable.merge([_controller, _exitController]),
                  builder: (context, child) {
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // First text - "Welcome to Aurora Music"
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
                              child: Text(
                                'Welcome to Aurora Music',
                                style: TextStyle(
                                  fontFamily: 'Outfit',
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
                        ),

                        // Spacing
                        SizedBox(height: 12 * _fadeAnimation2.value),

                        // Second text - "Let's set up your experience"
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
                            child: Text(
                              "Let's set up your experience",
                              style: TextStyle(
                                fontFamily: 'Outfit',
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
                          return Container(
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
                              text: 'Get Started',
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
