import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'theme_selection.dart';

class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  bool _isExiting = false;
  bool _mediaPermission = false;
  bool _notificationPermission = false;

  void _navigateToThemeSelection(BuildContext context) {
    setState(() => _isExiting = true);
    
    Future.delayed(const Duration(milliseconds: 600), () {
      Navigator.of(context).push(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const ThemeSelectionScreen(),
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
                    'Permissions\nSet up',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      fontSize: 46,
                      fontFamily: 'Outfit',
                    ),
                  )
                  .animate()
                    .fadeIn(duration: 300.ms, delay: 500.ms, curve: Curves.easeInOut)
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
                    'To make sure the app works properly,\nallow following permissions:',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white70,
                      fontSize: 20,
                      fontFamily: 'Outfit',
                    ),
                  )
                  .animate()
                    .fadeIn(duration: 300.ms, delay: 700.ms, curve: Curves.easeInOut)
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

                  _buildPermissionTile(
                    'Media Library',
                    'For access to your audio files',
                    _mediaPermission,
                    (value) => setState(() => _mediaPermission = value),
                  ).animate()
                    .fadeIn(duration: 300.ms, delay: 800.ms, curve: Curves.easeInOut)
                    .moveY(begin: 20, end: 0)
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

                  _buildPermissionTile(
                    'Notifications',
                    'For background service',
                    _notificationPermission,
                    (value) => setState(() => _notificationPermission = value),
                  ).animate()
                    .fadeIn(duration: 300.ms, delay: 900.ms, curve: Curves.easeInOut)
                    .moveY(begin: 20, end: 0)
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
                          onPressed: () => _navigateToThemeSelection(context),
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
                    .fadeIn(duration: 300.ms, delay: 1000.ms, curve: Curves.easeInOut)
                    .moveY(begin: 20, end: 0)
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionTile(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
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
          child: ListTile(
            title: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                fontFamily: 'Outfit',
              ),
            ),
            subtitle: Text(
              subtitle,
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 14,
                fontFamily: 'Outfit',
              ),
            ),
            trailing: Checkbox(
              value: value,
              onChanged: (bool? newValue) => onChanged(newValue ?? false),
              fillColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? Colors.white
                    : Colors.white.withOpacity(0.2),
              ),
              checkColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
        ),
      ),
    );
  }
}