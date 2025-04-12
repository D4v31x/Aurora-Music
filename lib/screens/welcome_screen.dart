import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'onboarding/language_selection.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  _WelcomeScreenState createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _isExiting = false;

  void _navigateToLanguageSelection(BuildContext context) {
    setState(() => _isExiting = true);
    
    Future.delayed(const Duration(milliseconds: 600), () {
      Navigator.of(context).push(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const LanguageSelectionScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 300),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Image.asset(
            'assets/images/background/welcome_bg.jpg',
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          ).animate().blur(duration: 300.ms),
          
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Spacer(),
                  Image.asset(
                    'assets/images/logo/Music_full_logo.png',
                    height: 50,
                  ).animate()
                    .fadeIn(duration: 600.ms)
                    .then(delay: 50.ms)
                    .custom(
                      duration: 300.ms,
                      builder: (context, value, child) => 
                        _isExiting ? Opacity(opacity: 1.0 - value, child: child) : child,
                    ),
                  
                  const SizedBox(height: 48),
                  
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your Music',
                        style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          fontSize: 46,
                          fontFamily: 'Outfit',
                        ),
                      ).animate()
                        .fadeIn(
                          duration: 300.ms, 
                          delay: 500.ms,
                          curve: Curves.easeInOut
                        )
                        .moveX(
                          begin: -30, 
                          end: 0,
                          curve: Curves.easeInOut
                        )
                        .animate(
                          target: _isExiting ? 1.0 : 0.0,
                          autoPlay: false,
                        )
                        .custom(
                          duration: 400.ms,
                          curve: Curves.easeInOut,
                          builder: (context, value, child) => 
                            Transform(
                              transform: Matrix4.identity()
                                ..setEntry(3, 2, 0.001)
                                ..rotateY(value * 0.5)
                                ..translate(value * 100.0),
                              alignment: Alignment.centerRight,
                              child: Opacity(opacity: 1.0 - value, child: child),
                            ),
                        ),
                      
                      Text(
                        'Your Rules',
                        style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          fontSize: 46,
                          fontFamily: 'Outfit',
                        ),
                      ).animate()
                        .fadeIn(
                          duration: 300.ms, 
                          delay: 500.ms,
                          curve: Curves.easeInOut
                        )
                        .moveX(
                          begin: -30, 
                          end: 0,
                          curve: Curves.easeInOut
                        )
                        .animate(
                          target: _isExiting ? 1.0 : 0.0,
                          autoPlay: false,
                        )
                        .custom(
                          duration: 400.ms,
                          curve: Curves.easeInOut,
                          builder: (context, value, child) => 
                            Transform(
                              transform: Matrix4.identity()
                                ..setEntry(3, 2, 0.001)
                                ..rotateY(value * 0.5)
                                ..translate(value * 100.0),
                              alignment: Alignment.centerRight,
                              child: Opacity(opacity: 1.0 - value, child: child),
                            ),
                        ),
                      
                      const SizedBox(height: 16),
                      
                      Container(
                        width: 185,
                        height: 2,
                        color: Colors.white,
                      ).animate()
                        .scaleX(
                          begin: 0, 
                          end: 1,
                          duration: 250.ms,
                          delay: 400.ms,
                          curve: Curves.easeInOut,
                          alignment: Alignment.centerLeft
                        )
                        .animate(
                          target: _isExiting ? 1.0 : 0.0,
                          autoPlay: false,
                        )
                        .custom(
                          duration: 400.ms,
                          curve: Curves.easeInOut,
                          builder: (context, value, child) => 
                            Transform.scale(
                              scaleX: 1.0 - value,
                              alignment: Alignment.centerRight,
                              child: child,
                            ),
                        ),
                      
                      const SizedBox(height: 16),
                      
                      Text(
                        'Modern way to enjoy your\nfavorite songs',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.white70,
                          fontSize: 20,
                          fontFamily: 'Outfit',
                        ),
                      )
                      .animate()
                        .fadeIn(
                          duration: 300.ms,
                          delay: 700.ms,
                          curve: Curves.easeInOut
                        )
                        .moveX(
                          begin: -30, 
                          end: 0, 
                          duration: 300.ms,
                          delay: 700.ms,
                          curve: Curves.easeOutCubic
                        )
                      .animate(
                        target: _isExiting ? 1.0 : 0.0,
                        autoPlay: false,
                      )
                        .custom(
                          duration: 400.ms,
                          builder: (context, value, child) => 
                            Transform(
                              transform: Matrix4.identity()
                                ..setEntry(3, 2, 0.001)
                                ..rotateY(value * -0.5)
                                ..translate(value * 100.0),
                              alignment: Alignment.centerLeft,
                              child: Opacity(opacity: 1.0 - value, child: child),
                            ),
                        ),
                    ],
                  ),
                  
                  const Spacer(),
                  
                  Container(
                    width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      color: Colors.white.withOpacity(0.15),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: ElevatedButton(
                          onPressed: () => _navigateToLanguageSelection(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                          ),
                          child: const Text(
                            "Let's begin!",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Outfit',
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                  .animate()
                    .fadeIn(
                      duration: 300.ms,
                      delay: 900.ms,
                      curve: Curves.easeInOut
                    )
                    .moveY(begin: 20, end: 0),
                  
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}