
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class WelcomePage extends StatelessWidget {
  final String title;
  final String description;
  final bool isLastPage;
  final VoidCallback onGetStarted;

  const WelcomePage({
    super.key,
    required this.title,
    required this.description,
    this.isLastPage = false,
    required this.onGetStarted,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 24.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16.0),
              Text(
                description,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16.0,
                ),
              ),
              const SizedBox(height: 32.0),
              if (isLastPage)
                ElevatedButton(
                  onPressed: onGetStarted,
                  child: const Text('Get Started'),
                ),
              const SizedBox(height: 16.0),
              if (isLastPage)
                const Text(
                  'Version: 0.1.0',
                  style: TextStyle(
                    fontSize: 14.0,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              const SizedBox(height: 16.0),
              if (isLastPage)
                TextButton(
                  onPressed: () {
                    launch('https://instagram.com/aurora.software');
                  },
                  child: const Text('Follow us on Instagram'),
                ),
              const SizedBox(height: 16.0),
              if (isLastPage)
                const Text(
                  'By using this app, you accept our Privacy Policy.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14.0,
                    fontStyle: FontStyle.italic,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
