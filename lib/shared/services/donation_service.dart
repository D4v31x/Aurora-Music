import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:aurora_music_v01/core/constants/font_constants.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/glassmorphic_container.dart';
import '../../l10n/app_localizations.dart';

/// Service for handling donations via external platforms
/// Uses free services like Ko-fi, Buy Me a Coffee, and PayPal
class DonationService {
  // Configure your donation links here
  static const String kofiUsername =
      'aurorasoftwarecz'; // Replace with your Ko-fi username
  static const String buyMeCoffeeUsername = 
      'aurorasoftwareCZ'; // Replace with your BMC username

  static const String kofiUrl = 'https://ko-fi.com/$kofiUsername';
  static const String buyMeCoffeeUrl =
      'https://buymeacoffee.com/$buyMeCoffeeUsername';

  // Reminder settings
  static const String _lastReminderKey = 'donation_last_reminder';
  static const String _reminderCountKey = 'donation_reminder_count';
  static const String _neverShowKey = 'donation_never_show';
  static const int _reminderIntervalDays = 7; // Show reminder every 7 days

  /// Check if we should show donation reminder
  static Future<bool> shouldShowReminder() async {
    final prefs = await SharedPreferences.getInstance();

    // Check if user opted out
    if (prefs.getBool(_neverShowKey) ?? false) {
      return false;
    }

    final lastReminder = prefs.getInt(_lastReminderKey) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    final daysSinceLastReminder = (now - lastReminder) / (1000 * 60 * 60 * 24);

    return daysSinceLastReminder >= _reminderIntervalDays;
  }

  /// Mark reminder as shown
  static Future<void> markReminderShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastReminderKey, DateTime.now().millisecondsSinceEpoch);
    final count = prefs.getInt(_reminderCountKey) ?? 0;
    await prefs.setInt(_reminderCountKey, count + 1);
  }

  /// User opted to never show reminders again
  static Future<void> neverShowAgain() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_neverShowKey, true);
  }

  /// Reset reminder preferences (for testing)
  static Future<void> resetReminders() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastReminderKey);
    await prefs.remove(_reminderCountKey);
    await prefs.remove(_neverShowKey);
  }

  /// Open Ko-fi donation page
  static Future<bool> openKofi() async {
    return _launchUrl(kofiUrl);
  }

  /// Open Buy Me a Coffee donation page
  static Future<bool> openBuyMeACoffee() async {
    return _launchUrl(buyMeCoffeeUrl);
  }


  static Future<bool> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      return launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return false;
  }

  /// Show donation reminder popup (with "Don't show again" option)
  static Future<void> showReminderIfNeeded(BuildContext context) async {
    if (await shouldShowReminder()) {
      await markReminderShown();
      if (context.mounted) {
        showDonationReminderDialog(context);
      }
    }
  }

  /// Show donation reminder dialog with dismiss options
  static void showDonationReminderDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: GlassmorphicContainer(
              borderRadius: BorderRadius.circular(24),
              blur: 20,
              padding: const EdgeInsets.all(24),
              child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 20),
              // Title
              Text(
                loc.translate('enjoying_aurora'),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  fontFamily: FontConstants.fontFamily,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              // Description
              Text(
                loc.translate('enjoying_aurora_desc'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontFamily: FontConstants.fontFamily,
                  color: isDark ? Colors.white60 : Colors.black54,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              // Support button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    showDonationDialog(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.pink,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    loc.translate('support_aurora_btn'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      fontFamily: FontConstants.fontFamily,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Maybe later button
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  loc.translate('maybe_later'),
                  style: TextStyle(
                    fontSize: 14,
                    fontFamily: FontConstants.fontFamily,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                ),
              ),
              // Don't show again
              TextButton(
                onPressed: () {
                  neverShowAgain();
                  Navigator.pop(context);
                },
                child: Text(
                  loc.translate('dont_show_again'),
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: FontConstants.fontFamily,
                    color: isDark ? Colors.white30 : Colors.black26,
                  ),
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

  /// Show donation options dialog
  static void showDonationDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 400,
                maxHeight: MediaQuery.of(context).size.height * 0.8,
              ),
              child: GlassmorphicContainer(
                borderRadius: BorderRadius.circular(28),
                blur: 25,
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title
                  Text(
                    loc.translate('support_aurora_title'),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      fontFamily: FontConstants.fontFamily,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Description
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      loc.translate('support_aurora_message'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontFamily: FontConstants.fontFamily,
                        color: isDark ? Colors.white60 : Colors.black54,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  // Donation options
                  _DonationOption(
                    title: loc.translate('buy_me_coffee'),
                    subtitle: loc.translate('one_time_support'),
                    color: const Color(0xFFFFDD00),
                    onTap: () {
                      Navigator.pop(context);
                      openBuyMeACoffee();
                    },
                    isDark: isDark,
                  ),
                  const SizedBox(height: 12),
                  _DonationOption(
                    title: loc.translate('kofi'),
                    subtitle: loc.translate('coffee_support'),
                    color: const Color(0xFFFF5E5B),
                    onTap: () {
                      Navigator.pop(context);
                      openKofi();
                    },
                    isDark: isDark,
                  ),
                  const SizedBox(height: 16),
                  // Thank you note
                  Text(
                    loc.translate('thank_you_support'),
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: FontConstants.fontFamily,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  ),
                ],
              ),
            ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DonationOption extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  final bool isDark;

  const _DonationOption({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.05),
            ),
          ),
          child: Row(
            children: [
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        fontFamily: FontConstants.fontFamily,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: FontConstants.fontFamily,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: isDark ? Colors.white24 : Colors.black26,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
