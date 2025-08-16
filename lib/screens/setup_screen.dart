import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'onboarding/language_selection.dart';
import '../widgets/app_background.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _textController;
  
  int _currentStep = 0; // 0: Welcome text, 1: Setup message, 2: Settings
  bool _isExiting = false;

  @override
  void initState() {
    super.initState();
    
    _mainController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    
    _textController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _startSequence();
  }

  void _startSequence() async {
    // Start the splash fade out (assume splash is already fading)
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Show welcome text
    setState(() => _currentStep = 0);
    _textController.forward();
    
    // Wait 2-3 seconds
    await Future.delayed(const Duration(milliseconds: 2500));
    
    // Move welcome text up and show setup message
    setState(() => _currentStep = 1);
    await _textController.reverse();
    await Future.delayed(const Duration(milliseconds: 200));
    _textController.forward();
    
    // Wait a bit then show settings
    await Future.delayed(const Duration(milliseconds: 1500));
    setState(() => _currentStep = 2);
    _mainController.forward();
  }

  void _navigateToLanguageSelection() {
    setState(() => _isExiting = true);
    
    Future.delayed(const Duration(milliseconds: 600), () {
      Navigator.of(context).push(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const LanguageSelectionScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.0, 0.1),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                )),
                child: child,
              ),
            );
          },
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    });
  }

  @override
  void dispose() {
    _mainController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      enableAnimation: true,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Welcome Text Section
                        if (_currentStep >= 0)
                          AnimatedBuilder(
                            animation: _textController,
                            builder: (context, child) {
                              final opacity = _currentStep == 0 
                                ? _textController.value 
                                : _currentStep == 1 
                                  ? _textController.value
                                  : 0.0;
                              
                              final offset = _currentStep == 1 
                                ? Offset(0, -50 * _textController.value)
                                : Offset.zero;
                              
                              return Transform.translate(
                                offset: offset,
                                child: Opacity(
                                  opacity: opacity,
                                  child: Text(
                                    'Welcome to\nAurora Music!',
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                      fontSize: 48,
                                      fontFamily: 'Outfit',
                                      letterSpacing: -1,
                                      height: 1.1,
                                    ),
                                  ).animate(target: _isExiting ? 1.0 : 0.0)
                                    .custom(
                                      duration: 400.ms,
                                      curve: Curves.easeInOut,
                                      builder: (context, value, child) => 
                                        Transform(
                                          transform: Matrix4.identity()
                                            ..setEntry(3, 2, 0.001)
                                            ..rotateY(value * 0.3)
                                            ..translate(value * 50.0, 0, 0),
                                          alignment: Alignment.center,
                                          child: Opacity(opacity: 1.0 - value, child: child),
                                        ),
                                    ),
                                ),
                              );
                            },
                          ),
                        
                        // Setup Message
                        if (_currentStep >= 1)
                          AnimatedBuilder(
                            animation: _textController,
                            builder: (context, child) {
                              final opacity = _currentStep == 1 ? _textController.value : 1.0;
                              
                              return Opacity(
                                opacity: opacity,
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 24),
                                  child: Text(
                                    "Let's set up your\npersonalized experience",
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                      fontWeight: FontWeight.w400,
                                      color: Colors.white.withOpacity(0.9),
                                      fontSize: 24,
                                      fontFamily: 'Outfit',
                                      height: 1.3,
                                    ),
                                  ).animate(target: _isExiting ? 1.0 : 0.0)
                                    .custom(
                                      duration: 400.ms,
                                      curve: Curves.easeInOut,
                                      builder: (context, value, child) => 
                                        Transform(
                                          transform: Matrix4.identity()
                                            ..setEntry(3, 2, 0.001)
                                            ..rotateY(value * -0.3)
                                            ..translate(value * -50.0, 0, 0),
                                          alignment: Alignment.center,
                                          child: Opacity(opacity: 1.0 - value, child: child),
                                        ),
                                    ),
                                ),
                              );
                            },
                          ),
                        
                        const SizedBox(height: 80),
                        
                        // Settings Preview Section
                        if (_currentStep >= 2)
                          AnimatedBuilder(
                            animation: _mainController,
                            builder: (context, child) {
                              return Opacity(
                                opacity: _mainController.value,
                                child: Transform.translate(
                                  offset: Offset(0, 30 * (1 - _mainController.value)),
                                  child: Column(
                                    children: [
                                      // Quick Setup Options Preview
                                      Container(
                                        padding: const EdgeInsets.all(24),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(20),
                                          color: Colors.white.withOpacity(0.1),
                                          border: Border.all(
                                            color: Colors.white.withOpacity(0.2),
                                            width: 1,
                                          ),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(16),
                                          child: BackdropFilter(
                                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                            child: Column(
                                              children: [
                                                Text(
                                                  'Quick Setup',
                                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.white,
                                                    fontSize: 20,
                                                    fontFamily: 'Outfit',
                                                  ),
                                                ),
                                                const SizedBox(height: 16),
                                                Text(
                                                  'Language • Theme • Permissions • Music Library',
                                                  textAlign: TextAlign.center,
                                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                    color: Colors.white.withOpacity(0.8),
                                                    fontSize: 14,
                                                    fontFamily: 'Outfit',
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ).animate(delay: 300.ms)
                                        .fadeIn(duration: 600.ms, curve: Curves.easeOutCubic)
                                        .slideY(begin: 0.3, end: 0, curve: Curves.easeOutCubic),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
                
                // Start Setup Button
                if (_currentStep >= 2)
                  AnimatedBuilder(
                    animation: _mainController,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _mainController.value,
                        child: Transform.translate(
                          offset: Offset(0, 50 * (1 - _mainController.value)),
                          child: Container(
                            width: double.infinity,
                            height: 56,
                            margin: const EdgeInsets.only(bottom: 48),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(28),
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white.withOpacity(0.2),
                                  Colors.white.withOpacity(0.1),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(28),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                child: ElevatedButton(
                                  onPressed: _navigateToLanguageSelection,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(28),
                                    ),
                                  ),
                                  child: const Text(
                                    "Let's begin setup",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      fontFamily: 'Outfit',
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ).animate(delay: 500.ms)
                            .fadeIn(duration: 600.ms, curve: Curves.easeOutCubic)
                            .slideY(begin: 0.3, end: 0, curve: Curves.easeOutCubic)
                            .then()
                            .shimmer(
                              duration: 2000.ms,
                              color: Colors.white.withOpacity(0.3),
                            ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}