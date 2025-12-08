import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/user_preferences.dart';
import '../../providers/theme_provider.dart';
import '../../localization/app_localizations.dart';
import '../home_screen.dart';
import 'pages/welcome_page.dart';
import 'pages/app_info_page.dart';
import 'pages/language_selection_page.dart';
import 'pages/theme_selection_page.dart';
import 'pages/internet_usage_page.dart';
import 'pages/asset_download_page.dart';
import 'pages/download_choice_page.dart';
import 'pages/download_progress_page.dart';
import 'pages/permissions_page.dart';
import 'pages/completion_page.dart';
import '../../widgets/grainy_gradient_background.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  int _currentPage = 0;
  final int _totalPages = 10; // Updated from 8 to 10
  late AnimationController _transitionController;
  late Animation<double> _fadeAnimation;

  // Track download choices
  bool _downloadLyrics = false;
  bool _downloadArtwork = false;

  @override
  void initState() {
    super.initState();
    _transitionController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _transitionController,
        curve: Curves.easeInOut,
      ),
    );

    _transitionController.value = 1.0;
  }

  void _nextPage() async {
    if (_currentPage < _totalPages - 1) {
      await _transitionController.reverse();
      setState(() {
        _currentPage++;
      });
      await _transitionController.forward();
    } else {
      _completeOnboarding();
    }
  }

  void _previousPage() async {
    if (_currentPage > 0) {
      await _transitionController.reverse();
      setState(() {
        _currentPage--;
      });
      await _transitionController.forward();
    }
  }

  void _skipToEnd() async {
    await _transitionController.reverse();
    setState(() {
      _currentPage = _totalPages - 1;
    });
    await _transitionController.forward();
  }

  Future<void> _completeOnboarding() async {
    await UserPreferences.setFirstTimeUser(false);
    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const HomeScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(0.0, 1.0);
            const end = Offset.zero;
            const curve = Curves.easeInOutCubic;

            var tween =
                Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
            var offsetAnimation = animation.drive(tween);

            return SlideTransition(
              position: offsetAnimation,
              child: FadeTransition(
                opacity: animation,
                child: child,
              ),
            );
          },
          transitionDuration: const Duration(milliseconds: 800),
        ),
      );
    }
  }

  @override
  void dispose() {
    _transitionController.dispose();
    super.dispose();
  }

  Widget _getCurrentPage() {
    switch (_currentPage) {
      case 0:
        return WelcomePage(onContinue: _nextPage);
      case 1:
        // Language selection moved to be first after welcome
        return LanguageSelectionPage(
          onContinue: _nextPage,
          onBack: _previousPage,
        );
      case 2:
        return AppInfoPage(
          onContinue: _nextPage,
          onBack: _previousPage,
        );
      case 3:
        return ThemeSelectionPage(
          onContinue: _nextPage,
          onBack: _previousPage,
        );
      case 4:
        return InternetUsagePage(
          onContinue: _nextPage,
          onBack: _previousPage,
        );
      case 5:
        return AssetDownloadPage(
          onContinue: _nextPage,
          onBack: _previousPage,
        );
      case 6:
        // Permissions BEFORE downloads
        return PermissionsPage(
          onContinue: _nextPage,
          onBack: _previousPage,
        );
      case 7:
        return DownloadChoicePage(
          onContinue: _nextPage,
          onBack: _previousPage,
          onChoiceSelected: (downloadLyrics, downloadArtwork) {
            _downloadLyrics = downloadLyrics;
            _downloadArtwork = downloadArtwork;
          },
        );
      case 8:
        // Only show download progress if user chose to download something
        if (_downloadLyrics || _downloadArtwork) {
          return DownloadProgressPage(
            onComplete: _nextPage,
            downloadLyrics: _downloadLyrics,
            downloadArtwork: _downloadArtwork,
          );
        } else {
          // Skip download progress if nothing to download
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _nextPage();
          });
          return Container(); // Placeholder
        }
      case 9:
        return CompletionPage(onComplete: _completeOnboarding);
      default:
        return WelcomePage(onContinue: _nextPage);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return GrainyGradientBackground(
      colors: themeProvider.currentGradientColors,
      noiseOpacity: 0.08,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            // Main content with crossfade
            FadeTransition(
              opacity: _fadeAnimation,
              child: _getCurrentPage(),
            ),

            // Top bar with skip button (except on first and last page)
            if (_currentPage > 0 && _currentPage < _totalPages - 1)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24.0, vertical: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: _skipToEnd,
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white.withOpacity(0.7),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                          ),
                          child: Text(
                            AppLocalizations.of(context)
                                .translate('onboarding_skip'),
                            style: const TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Page indicator (not shown on pages with bottom buttons that need space)
            if (_currentPage > 0 &&
                _currentPage < _totalPages - 1 &&
                _currentPage != 8)
              Positioned(
                bottom: 20,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _totalPages - 2, // Exclude welcome and completion pages
                      (index) {
                        final pageIndex =
                            index + 1; // Offset by 1 to skip welcome page
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          height: 8,
                          width: _currentPage == pageIndex ? 24 : 8,
                          decoration: BoxDecoration(
                            color: _currentPage == pageIndex
                                ? const Color(0xFF3B82F6)
                                : Colors.white.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
