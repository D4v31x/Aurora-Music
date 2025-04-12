import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../home_screen.dart';

class FinalScreen extends StatefulWidget {
  const FinalScreen({super.key});

  @override
  State<FinalScreen> createState() => _FinalScreenState();
}

class _FinalScreenState extends State<FinalScreen> {
  bool _isExiting = false;

  void _navigateToHome(BuildContext context) async {
    // Mark onboarding as completed
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);

    setState(() => _isExiting = true);
    
    Future.delayed(const Duration(milliseconds: 600), () {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.0, 0.3),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                )),
                child: const HomeScreen(),
              ),
            );
          },
          transitionDuration: const Duration(milliseconds: 800),
          reverseTransitionDuration: const Duration(milliseconds: 600),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Spacer(flex: 1),
                  Text(
                    'Setup\ncomplete',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      fontSize: 46,
                      fontFamily: 'Outfit',
                    ),
                  )
                  .animate()
                    .fadeIn(
                      duration: 300.ms,
                      delay: 500.ms,
                      curve: Curves.easeInOut
                    )
                    .moveX(begin: -30, end: 0)
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
                  )
                  .animate()
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
                  
                  const SizedBox(height: 24),
                  
                  Text(
                    'Setup is complete! Enjoy your\nnew listening journey!',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
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
                    .moveX(begin: -30, end: 0)
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

                  const Spacer(flex: 2),
                  
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
                          onPressed: () => _navigateToHome(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                          ),
                          child: const Text(
                            'Begin',
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
                      delay: 1000.ms,
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