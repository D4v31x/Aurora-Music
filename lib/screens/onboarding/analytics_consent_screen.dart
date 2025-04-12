import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'permissions_screen.dart';
import 'shared_animations.dart';

class AnalyticsConsentScreen extends StatefulWidget {
  const AnalyticsConsentScreen({super.key});

  @override
  State<AnalyticsConsentScreen> createState() => _AnalyticsConsentScreenState();
}

class _AnalyticsConsentScreenState extends State<AnalyticsConsentScreen> {
  bool _isExiting = false;

  void _navigateToPermissions(BuildContext context) {
    setState(() => _isExiting = true);
    
    Future.delayed(const Duration(milliseconds: 600), () {
      Navigator.of(context).push(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const PermissionsScreen(),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Spacer(flex: 1),
                  Text(
                    'Security on\nfirst place',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      fontSize: 46,
                      fontFamily: 'Outfit',
                    ),
                  ).addHeadingAnimations(isExiting: _isExiting),
                  
                  const SizedBox(height: 16),
                  
                  Container(
                    width: 185,
                    height: 2,
                    color: Colors.white,
                  ).addDividerAnimations(isExiting: _isExiting),
                  
                  const SizedBox(height: 24),
                  
                  Text(
                    'To give you the best experience,\nwe use some data gathered by\nthe app.',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.white70,
                      fontSize: 20,
                      fontFamily: 'Outfit',
                    ),
                  ).addSubtitleAnimations(isExiting: _isExiting),

                  const SizedBox(height: 16),

                  Text(
                    'By using this app, you agree to\nthe Privacy Policy',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white70,
                      fontSize: 16,
                      fontFamily: 'Outfit',
                    ),
                  )
                  .animate()
                    .fadeIn(
                      duration: 300.ms,
                      delay: 800.ms,
                      curve: Curves.easeInOut
                    )
                    .moveX(begin: -30, end: 0),

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
                          onPressed: () => _navigateToPermissions(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                          ),
                          child: const Text(
                            'Continue',
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
                  .addButtonAnimations(),
                  
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