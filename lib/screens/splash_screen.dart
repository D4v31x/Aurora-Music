import 'package:flutter/material.dart';
import 'package:rive/rive.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mesh_gradient/mesh_gradient.dart';
import 'dart:ui';  // Import this for ImageFilter
import '../services/user_preferences.dart';
import 'welcome_screen.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late RiveAnimationController _riveController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  String _versionNumber = '';
  String _codeName = '';

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadVersionInfo();
    _scheduleTransition();
  }

  void _initializeAnimations() {
    _riveController = SimpleAnimation('Timeline 1');
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(_fadeController);
  }

  Future<void> _loadVersionInfo() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    String codeName = dotenv.env['CODE_NAME'] ?? 'Unknown';

    setState(() {
      _versionNumber = packageInfo.version;
      _codeName = codeName;
    });
  }

  void _scheduleTransition() {
    Future.delayed(const Duration(seconds: 3), () {
      _transitionToNextScreen();
    });
  }

  Future<void> _transitionToNextScreen() async {
    await _fadeController.forward();
    bool isFirstTime = await UserPreferences.isFirstTimeUser();
    if (isFirstTime) {
      await UserPreferences.setFirstTimeUser(false);
      _navigateToScreen(const WelcomeScreen());
    } else {
      _navigateToScreen(const HomeScreen());
    }
  }

  void _navigateToScreen(Widget screen) {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => screen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOutCubic;
          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          var offsetAnimation = animation.drive(tween);
          return SlideTransition(position: offsetAnimation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 800),
      ),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Stack(
          children: [
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                child: AnimatedMeshGradient(
                  colors: [
                    Colors.purple[100]!,
                    Colors.purple[300]!,
                    Colors.pink[300]!,
                    Colors.pink[100]!,
                  ],
                  options: AnimatedMeshGradientOptions(
                    speed: 1.5,
                    frequency: 2.0,
                    amplitude: 0.5,
                  ),
                ),
              ),
            ),
            Center(
              child: RiveAnimation.asset(
                "assets/animations/untitled.riv",
                controllers: [_riveController],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 20,
              child: Text(
                'Version $_versionNumber ($_codeName)',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}