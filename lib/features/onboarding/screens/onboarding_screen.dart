import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:provider/provider.dart';
import '../../../shared/services/user_preferences.dart';
import '../../../shared/providers/theme_provider.dart';
import '../../home/screens/home_screen.dart';
import '../pages/welcome_page.dart';
import '../pages/beta_welcome_page.dart';
import '../pages/app_info_page.dart';
import '../pages/language_selection_page.dart';
import '../pages/theme_selection_page.dart';
import '../pages/internet_usage_page.dart';
import '../pages/permissions_page.dart';
import '../pages/completion_page.dart';
import '../pages/donation_page.dart';
import '../pages/translation_contribution_page.dart';
import '../../../shared/widgets/grainy_gradient_background.dart';
import '../../../shared/widgets/expanding_player.dart';

class OnboardingScreen extends HookWidget {
  const OnboardingScreen({super.key});

  static const int _totalPages = 10;

  @override
  Widget build(BuildContext context) {
    final currentPage = useState(0);

    final transitionController = useAnimationController(
      duration: const Duration(milliseconds: 400),
      initialValue: 1.0,
    );

    final fadeAnimation = useAnimation(
      CurvedAnimation(
        parent: transitionController,
        curve: Curves.easeInOut,
      ),
    );

    Future<void> nextPage() async {
      if (currentPage.value < _totalPages - 1) {
        await transitionController.reverse();
        currentPage.value++;
        await transitionController.forward();
      } else {
        await _completeOnboarding(context);
      }
    }

    Future<void> previousPage() async {
      if (currentPage.value > 0) {
        await transitionController.reverse();
        currentPage.value--;
        await transitionController.forward();
      }
    }

    Widget getCurrentPage() {
      switch (currentPage.value) {
        case 0:
          return WelcomePage(onContinue: nextPage);
        case 1:
          return LanguageSelectionPage(
            onContinue: nextPage,
            onBack: previousPage,
          );
        case 2:
          return TranslationContributionPage(
            onContinue: nextPage,
            onBack: previousPage,
          );
        case 3:
          return BetaWelcomePage(
            onContinue: nextPage,
            onBack: previousPage,
          );
        case 4:
          return AppInfoPage(
            onContinue: nextPage,
            onBack: previousPage,
          );
        case 5:
          return PermissionsPage(
            onContinue: nextPage,
            onBack: previousPage,
          );
        case 6:
          return ThemeSelectionPage(
            onContinue: nextPage,
            onBack: previousPage,
          );
        case 7:
          return InternetUsagePage(
            onContinue: nextPage,
            onBack: previousPage,
          );
        case 8:
          return DonationPage(
            onContinue: nextPage,
            onBack: previousPage,
          );
        case 9:
          return CompletionPage(onComplete: () => _completeOnboarding(context));
        default:
          return WelcomePage(onContinue: nextPage);
      }
    }

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
              opacity: AlwaysStoppedAnimation(fadeAnimation),
              child: getCurrentPage(),
            ),

            // Page indicator
            if (currentPage.value > 0 && currentPage.value < _totalPages - 1)
              Positioned(
                bottom: 20,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _totalPages - 2,
                      (index) {
                        final pageIndex = index + 1;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          height: 8,
                          width: currentPage.value == pageIndex ? 24 : 8,
                          decoration: BoxDecoration(
                            color: currentPage.value == pageIndex
                                ? Theme.of(context).colorScheme.primary
                                : Colors.white.withValues(alpha: 0.3),
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

  Future<void> _completeOnboarding(BuildContext context) async {
    await UserPreferences.setFirstTimeUser(false);
    if (context.mounted) {
      ExpandingPlayer.hiddenNotifier.value = false;
      await Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const HomeScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(0.0, 1.0);
            const end = Offset.zero;
            const curve = Curves.easeInOutCubic;

            final tween =
                Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
            final offsetAnimation = animation.drive(tween);

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
}
