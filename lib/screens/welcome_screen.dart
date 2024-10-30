import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart' as handler;
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../localization/app_localizations.dart';
import '../localization/locale_provider.dart';
import 'home_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  _WelcomeScreenState createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> with SingleTickerProviderStateMixin {
  late PageController _pageController;
  int _currentPage = 0;
  final int _numPages = 7;
  String _selectedLanguage = 'en';
  late AnimationController _animationController;
  late Animation<double> _animation;
  bool _permissionsGranted = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _checkPermissions() async {
    try {
      var audioPermissionStatus = await handler.Permission.audio.status;
      if (!audioPermissionStatus.isGranted) {
        audioPermissionStatus = await handler.Permission.audio.request();
      }
      var storagePermissionStatus = await handler.Permission.storage.status;
      if (!storagePermissionStatus.isGranted) {
        storagePermissionStatus = await handler.Permission.storage.request();
      }
      var notificationPermissionStatus = await handler.Permission.notification.status;
      if (!notificationPermissionStatus.isGranted) {
        notificationPermissionStatus = await handler.Permission.notification.request();
      }
      if ((audioPermissionStatus.isGranted || storagePermissionStatus.isGranted) && notificationPermissionStatus.isGranted) {
        setState(() {
          _permissionsGranted = true;
        });
        _pageController.nextPage(
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      } else {
        _showPermissionDeniedDialog();
      }
    } catch (e) {
      print('Error requesting permissions: $e');
    }
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(AppLocalizations.of(context).translate('permission_required')),
          content: Text(AppLocalizations.of(context).translate('permission_explanation')),
          actions: <Widget>[
            TextButton(
              child: Text(AppLocalizations.of(context).translate('cancel')),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text(AppLocalizations.of(context).translate('open_settings')),
              onPressed: () {
                Navigator.of(context).pop();
                handler.openAppSettings();
              },
            ),
          ],
        );
      },
    );
  }

  void _navigateToHome() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isFirstRun', false);
    await prefs.setBool('isWelcomeCompleted', true);
    print('WelcomeScreen: Set isWelcomeCompleted to true');
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const HomeScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          var tween = Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.easeInOut));
          var fadeAnimation = animation.drive(tween);
          return FadeTransition(
            opacity: fadeAnimation,
            child: child,
          );
        },
        transitionDuration: const Duration(seconds: 2),
      ),
    );
  }
  Widget _buildBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF11B0CC),
            Color(0xFF272ACC),
            Color(0xFF3F008D),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 1000.ms);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return Stack(
            children: [
              _buildBackground(),
              SafeArea(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: PageView(
                        controller: _pageController,
                        onPageChanged: (int page) {
                          setState(() {
                            _currentPage = page;
                          });
                        },
                        children: [
                          _buildLanguagePage(),
                          _buildWelcomePage(),
                          _buildAlphaTestingPage(),
                          _buildPermissionsPage(),
                          _buildPrivacyPage(),
                          _buildCommunityPage(),
                          _buildFinishPage(),
                        ],
                      ),
                    ),
                    _buildPageIndicator(),
                    _buildButton(),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildWelcomePage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: AnimationLimiter(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: AnimationConfiguration.toStaggeredList(
            duration: const Duration(milliseconds: 375),
            childAnimationBuilder: (widget) => SlideAnimation(
              verticalOffset: 50.0,
              child: FadeInAnimation(
                child: widget,
              ),
            ),
            children: [
              Image.asset(
                'assets/images/logo/Music_logo.png',
                width: 90,
                height: 90,
              ),
              const SizedBox(height: 20),
              Text(
                AppLocalizations.of(context).translate('welcome_title'),
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Text(
                AppLocalizations.of(context).translate('welcome_description'),
                style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.8)),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAlphaTestingPage() {
    return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: AnimationLimiter(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: AnimationConfiguration.toStaggeredList(
                duration: const Duration(milliseconds: 375),
                childAnimationBuilder: (widget) => SlideAnimation(
                  verticalOffset: 50.0,
                  child: FadeInAnimation(
                    child: widget,
                  ),
                ),
                children: [
                  const Icon(Icons.star, size: 60, color: Colors.white),
                  const SizedBox(height: 20),
                  Text(
                    AppLocalizations.of(context).translate('alpha_title'),
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    AppLocalizations.of(context).translate('alpha_description'),
                    style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.8)),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )));
  }

  Widget _buildPermissionsPage() {
    return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: AnimationLimiter(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: AnimationConfiguration.toStaggeredList(
                duration: const Duration(milliseconds: 375),
                childAnimationBuilder: (widget) => SlideAnimation(
                  verticalOffset: 50.0,
                  child: FadeInAnimation(
                    child: widget,
                  ),
                ),
                children: [
                  const Icon(Icons.security, size: 60, color: Colors.white)
                      .animate()
                      .scale(duration: 600.ms, curve: Curves.elasticOut),
                  const SizedBox(height: 20),
                  Text(
                    AppLocalizations.of(context).translate('permissions_title'),
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    AppLocalizations.of(context).translate('permissions_description'),
                    style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.8)),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )));
  }

  Widget _buildPrivacyPage() {
    return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: AnimationLimiter(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: AnimationConfiguration.toStaggeredList(
                duration: const Duration(milliseconds: 375),
                childAnimationBuilder: (widget) => SlideAnimation(
                  verticalOffset: 50.0,
                  child: FadeInAnimation(
                    child: widget,
                  ),
                ),
                children: [
                  const Icon(Icons.privacy_tip, size: 60, color: Colors.white)
                      .animate()
                      .scale(duration: 600.ms, curve: Curves.elasticOut),
                  const SizedBox(height: 20),
                  Text(
                    AppLocalizations.of(context).translate('privacy_title'),
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    AppLocalizations.of(context).translate('privacy_description'),
                    style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.8)),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )));
  }

  Widget _buildLanguagePage() {
    return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: AnimationLimiter(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: AnimationConfiguration.toStaggeredList(
                duration: const Duration(milliseconds: 375),
                childAnimationBuilder: (widget) => SlideAnimation(
                  verticalOffset: 50.0,
                  child: FadeInAnimation(
                    child: widget,
                  ),
                ),
                children: [
                  const Icon(Icons.language, size: 60, color: Colors.white)
                      .animate()
                      .scale(duration: 600.ms, curve: Curves.elasticOut),
                  const SizedBox(height: 20),
                  Text(
                    AppLocalizations.of(context).translate('language_title'),
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 30),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildLanguageButton('English', 'en'),
                      const SizedBox(width: 20),
                      _buildLanguageButton('Čeština', 'cs'),
                    ],
                  ),
                ],
              ),
            )));
  }

  Widget _buildLanguageButton(String language, String code) {
    bool isSelected = _selectedLanguage == code;
    return ElevatedButton(
      onPressed: () {
        setState(() {
          _selectedLanguage = code;
        });
        LocaleProvider? localeProvider = LocaleProvider.of(context);
        if (localeProvider != null) {
          localeProvider.setLocale(Locale(_selectedLanguage));
        }
      },
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: isSelected ? Colors.blueAccent : Colors.grey[700],
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      child: Text(language),
    ).animate().scale(duration: 300.ms, curve: Curves.easeOutBack);
  }

  Widget _buildCommunityPage() {
    return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: AnimationLimiter(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: AnimationConfiguration.toStaggeredList(
                duration: const Duration(milliseconds: 375),
                childAnimationBuilder: (widget) => SlideAnimation(
                  verticalOffset: 50.0,
                  child: FadeInAnimation(
                    child: widget,
                  ),
                ),
                children: [
                  const Icon(Icons.people, size: 60, color: Colors.white)
                      .animate()
                      .scale(duration: 600.ms, curve: Curves.elasticOut),
                  const SizedBox(height: 20),
                  Text(
                    AppLocalizations.of(context).translate('community_title'),
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    AppLocalizations.of(context).translate('community_description'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.normal, color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () async {
                      const url = 'https://www.instagram.com/aurora.software?utm_source=ig_web_button_share_sheet&igsh=ZDNlZDc0MzIxNw==';
                      print('Attempting to launch URL: $url');
                      try {
                        final uri = Uri.parse(url);
                        if (await canLaunchUrl(uri)) {
                          print('Launching URL...');
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        } else {
                          print('Cannot launch URL');
                          throw 'Could not launch $url';
                        }
                      } catch (e) {
                        print('Error: $e');
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to open the link: $e')),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.pinkAccent,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: Text(AppLocalizations.of(context).translate('follow_instagram')),
                  )

                ],
              ),
            )));
  }

  Widget _buildFinishPage() {
    return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: AnimationLimiter(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: AnimationConfiguration.toStaggeredList(
                duration: const Duration(milliseconds: 375),
                childAnimationBuilder: (widget) => SlideAnimation(
                  verticalOffset: 50.0,
                  child: FadeInAnimation(
                    child: widget,
                  ),
                ),
                children: [
                  const Icon(Icons.celebration, size: 60, color: Colors.white)
                      .animate()
                      .scale(duration: 600.ms, curve: Curves.elasticOut),
                  const SizedBox(height: 20),
                  Text(
                    AppLocalizations.of(context).translate('finish_title'),
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    AppLocalizations.of(context).translate('finish_description'),
                    style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.8)),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )));
  }

  Widget _buildPageIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_numPages, (index) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4.0),
          height: 8.0,
          width: _currentPage == index ? 24.0 : 16.0,
          decoration: BoxDecoration(
            color: _currentPage == index ? Colors.white : Colors.white.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
          ),
        ).animate().scale(duration: 300.ms, curve: Curves.easeInOut);
      }),
    );
  }

  Widget _buildButton() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ElevatedButton(
        onPressed: _currentPage == _numPages - 1
            ? _navigateToHome
            : () {
          if (_currentPage == 2 && !_permissionsGranted) {
            _checkPermissions();
          } else {
            _pageController.nextPage(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          }
        },
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: Colors.blueAccent,
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          elevation: 5,
          shadowColor: Colors.blueAccent.withOpacity(0.5),
        ),
        child: Text(
          AppLocalizations.of(context).translate(_currentPage == _numPages - 1 ? 'get_started' : 'next'),
          style: const TextStyle(fontSize: 18),
        ),
      ),
    ).animate()
        .fade(duration: 300.ms)
        .scale(duration: 300.ms, curve: Curves.easeOutBack)
        .moveY(begin: 20, end: 0, duration: 300.ms, curve: Curves.easeOut);
  }
}
