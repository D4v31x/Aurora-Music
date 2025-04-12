import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:aurora_music_v01/localization/locale_provider.dart';
import 'analytics_consent_screen.dart';

class LanguageSelectionScreen extends StatefulWidget {
  const LanguageSelectionScreen({super.key});

  @override
  State<LanguageSelectionScreen> createState() => _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen> {
  String _selectedLanguage = 'English';
  bool _isExiting = false;

  void _setLanguage(String language) {
    setState(() => _selectedLanguage = language);
    final localeCode = language == 'English' ? 'en' : 'cs';
    LocaleProvider.of(context)?.setLocale(Locale(localeCode));
  }

  void _navigateToAnalyticsConsent(BuildContext context) {
    setState(() => _isExiting = true);
    
    Future.delayed(const Duration(milliseconds: 600), () {
      Navigator.of(context).push(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const AnalyticsConsentScreen(),
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
                    'Choose Your\nLanguage',
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
                  
                  const SizedBox(height: 16),
                  
                  Text(
                    'You can change this later in settings',
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
                            ..rotateY(value * -0.5)
                            ..translate(value * 100.0),
                          alignment: Alignment.centerLeft,
                          child: Opacity(opacity: 1.0 - value, child: child),
                        ),
                    ),

                  const SizedBox(height: 48),

                  // Language options
                  Expanded(
                    flex: 3,
                    child: ListView(
                      children: [
                        _buildLanguageOption('English')
                            .animate()
                            .fadeIn(
                              duration: 300.ms,
                              delay: 800.ms,
                              curve: Curves.easeInOut
                            )
                            .moveY(begin: 20, end: 0),
                        _buildLanguageOption('Čeština')
                            .animate()
                            .fadeIn(
                              duration: 300.ms,
                              delay: 900.ms,
                              curve: Curves.easeInOut
                            )
                            .moveY(begin: 20, end: 0),
                      ],
                    ),
                  ),
                  
                  const Spacer(),
                  
                  // Updated Next button with new style and animations
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
                          onPressed: () => _navigateToAnalyticsConsent(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                          ),
                          child: const Text(
                            'Next',
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

  Widget _buildLanguageOption(String language) {
    final isSelected = _selectedLanguage == language;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isSelected 
              ? Colors.white.withOpacity(0.2) 
              : Colors.white.withOpacity(0.1),
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: ListTile(
              onTap: () => _setLanguage(language),
              leading: isSelected
                  ? const Icon(Icons.check_circle, color: Colors.white)
                  : Icon(Icons.circle_outlined, color: Colors.white.withOpacity(0.7)),
              title: Text(
                language,
                style: TextStyle(
                  color: Colors.white.withOpacity(isSelected ? 1.0 : 0.7),
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}