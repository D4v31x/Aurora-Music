import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import 'final_screen.dart';
import 'shared_animations.dart';
import '../../constants/animation_constants.dart';

class ConnectSocialsScreen extends StatefulWidget {
  const ConnectSocialsScreen({super.key});

  @override
  State<ConnectSocialsScreen> createState() => _ConnectSocialsScreenState();
}

class _ConnectSocialsScreenState extends State<ConnectSocialsScreen> {
  bool _isExiting = false;

  void _navigateToFinal(BuildContext context) {
    setState(() => _isExiting = true);
    
    Future.delayed(AnimationConstants.pageTransition, () {
      Navigator.of(context).push(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const FinalScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          transitionDuration: AnimationConstants.normal,
        ),
      );
    });
  }

  Future<void> _launchUrl(String url) async {
    if (!await launchUrl(Uri.parse(url))) {
      throw Exception('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RepaintBoundary(
        child: Stack(
          children: [
            RepaintBoundary(
              child: Image.asset(
                'assets/images/background/welcome_bg.jpg',
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
              ).animate().blur(duration: AnimationConstants.normal),
            ),
          
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Spacer(flex: 1),
                  Text(
                    'Connect\nwith us',
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
                    'To keep track with us, follow\nus on our socials!',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white70,
                      fontSize: 20,
                      fontFamily: 'Outfit',
                    ),
                  ).addSubtitleAnimations(isExiting: _isExiting),

                  const SizedBox(height: 48),

                  _buildSocialButton(
                    'Instagram',
                    'https://instagram.com/your_handle',
                  ).addContentAnimations(delay: const Duration(milliseconds: 800)),

                  const SizedBox(height: 16),

                  _buildSocialButton(
                    'Web',
                    'https://your-website.com',
                  ).addContentAnimations(delay: const Duration(milliseconds: 900)),

                  const SizedBox(height: 16),

                  _buildSocialButton(
                    'GitHub',
                    'https://github.com/your-repo',
                  ).addContentAnimations(delay: const Duration(milliseconds: 1000)),

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
                          onPressed: () => _navigateToFinal(context),
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
                  ).addButtonAnimations(delay: const Duration(milliseconds: 1100)),
                  
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ],
      ),
    )
    );
  }

  Widget _buildSocialButton(String platform, String url) {
    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
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
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _launchUrl(url),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                  child: Row(
                    children: [
                      Text(
                        platform,
                        style: const TextStyle(
                          color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Outfit',
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.white.withOpacity(0.7),
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ));
  }
}