import 'package:flutter/material.dart';
import '../../../services/donation_service.dart';
import '../../../widgets/pill_button.dart';
import '../../../widgets/glassmorphic_container.dart';

class DonationPage extends StatefulWidget {
  final VoidCallback onContinue;
  final VoidCallback onBack;

  const DonationPage({
    super.key,
    required this.onContinue,
    required this.onBack,
  });

  @override
  State<DonationPage> createState() => _DonationPageState();
}

class _DonationPageState extends State<DonationPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _heartScale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
      ),
    );

    _heartScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 0.7, curve: Curves.elasticOut),
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: GlassmorphicContainer(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Heart animation
                  AnimatedBuilder(
                    animation: _heartScale,
                    builder: (context, _) {
                      return Transform.scale(
                        scale: _heartScale.value,
                        child: Container(
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            color: Colors.pink.withOpacity(0.15),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.pink.withOpacity(0.2),
                                blurRadius: 30,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.favorite_rounded,
                            color: Colors.pink,
                            size: 64,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 32),
                  // Title
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: const Text(
                        'Support Aurora',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontFamily: 'Outfit',
                          letterSpacing: -0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Description
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Text(
                        'Aurora Music is free and always will be. If you enjoy the app, consider supporting its development!',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white.withOpacity(0.7),
                          fontFamily: 'Outfit',
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Donation options
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      children: [
                        _DonationOptionTile(
                          icon: '☕',
                          title: 'Buy Me a Coffee',
                          color: const Color(0xFFFFDD00),
                          onTap: () => DonationService.openBuyMeACoffee(),
                        ),
                        const SizedBox(height: 12),
                        _DonationOptionTile(
                          icon: '❤️',
                          title: 'Ko-fi',
                          color: const Color(0xFFFF5E5B),
                          onTap: () => DonationService.openKofi(),
                        ),
                        const SizedBox(height: 12),
                        _DonationOptionTile(
                          icon: '💳',
                          title: 'PayPal',
                          color: const Color(0xFF0070BA),
                          onTap: () => DonationService.openPayPal(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Navigation buttons
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Row(
                      children: [
                        // Back button
                        Expanded(
                          child: PillButton(
                            text: 'Back',
                            onPressed: widget.onBack,
                            backgroundColor: Colors.white.withOpacity(0.1),
                            foregroundColor: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Continue button
                        Expanded(
                          flex: 2,
                          child: PillButton(
                            text: 'Continue',
                            onPressed: widget.onContinue,
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Skip text
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Text(
                      'No pressure - you can always donate later in Settings',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.4),
                        fontFamily: 'Outfit',
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DonationOptionTile extends StatelessWidget {
  final String icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  const _DonationOptionTile({
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    icon,
                    style: const TextStyle(fontSize: 22),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    fontFamily: 'Outfit',
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: Colors.white.withOpacity(0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
