import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import 'final_screen.dart';

class ConnectSocialsScreen extends StatefulWidget {
  const ConnectSocialsScreen({super.key});

  @override
  State<ConnectSocialsScreen> createState() => _ConnectSocialsScreenState();
}

class _ConnectSocialsScreenState extends State<ConnectSocialsScreen> {
  bool _isExiting = false;

  void _navigateToFinal(BuildContext context) {
    setState(() => _isExiting = true);
    
    Future.delayed(const Duration(milliseconds: 600), () {
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
          transitionDuration: const Duration(milliseconds: 300),
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
                    'Connect\nwith us',
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
                    'To keep track with us, follow\nus on our socials!',
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

                  const SizedBox(height: 48),

                  _buildSocialButton(
                    'Instagram',
                    'https://instagram.com/your_handle',
                  ).animate()
                    .fadeIn(
                      duration: 300.ms,
                      delay: 800.ms,
                      curve: Curves.easeInOut
                    )
                    .moveY(begin: 20, end: 0),

                  const SizedBox(height: 16),

                  _buildSocialButton(
                    'Web',
                    'https://your-website.com',
                  ).animate()
                    .fadeIn(
                      duration: 300.ms,
                      delay: 900.ms,
                      curve: Curves.easeInOut
                    )
                    .moveY(begin: 20, end: 0),

                  const SizedBox(height: 16),

                  _buildSocialButton(
                    'GitHub',
                    'https://github.com/your-repo',
                  ).animate()
                    .fadeIn(
                      duration: 300.ms,
                      delay: 1000.ms,
                      curve: Curves.easeInOut
                    )
                    .moveY(begin: 20, end: 0),

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
                  )
                  .animate()
                    .fadeIn(
                      duration: 300.ms,
                      delay: 1100.ms,
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

  Widget _buildSocialButton(String platform, String url) {
    return Container(
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
    );
  }
}