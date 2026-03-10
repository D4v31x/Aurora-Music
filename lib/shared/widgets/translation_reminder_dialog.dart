import 'dart:async';
import 'dart:ui';

import 'package:aurora_music_v01/core/constants/font_constants.dart';
import 'package:flutter/material.dart';
import 'package:iconoir_flutter/iconoir_flutter.dart' as Iconoir;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/generated/app_localizations.dart';
import '../providers/performance_mode_provider.dart';
import '../services/translation_reminder_service.dart';

/// A glassmorphic dialog encouraging non-English users to help translate
/// Aurora Music on Crowdin.
class TranslationReminderDialog extends StatelessWidget {
  const TranslationReminderDialog({super.key});

  static Future<void> showIfNeeded(BuildContext context) async {
    final shouldShow = await TranslationReminderService.shouldShowPrompt();

    if (shouldShow && context.mounted) {
      await TranslationReminderService.markShown();

      if (context.mounted) {
        unawaited(showDialog(
          context: context,
          builder: (context) => const TranslationReminderDialog(),
        ));
      }
    }
  }

  void _openCrowdin() async {
    final url = Uri.parse('https://crowdin.com/project/aurora-music');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final performanceProvider =
        Provider.of<PerformanceModeProvider>(context, listen: false);
    final shouldBlur = performanceProvider.shouldEnableBlur;
    final colorScheme = Theme.of(context).colorScheme;

    final BoxDecoration dialogDecoration;
    if (shouldBlur) {
      dialogDecoration = BoxDecoration(
        color: Colors.grey[900]?.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      );
    } else {
      dialogDecoration = BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.outlineVariant),
      );
    }

    final innerContent = Container(
      constraints: const BoxConstraints(maxWidth: 400),
      decoration: dialogDecoration,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Iconoir.Language(
                  color: colorScheme.primary,
                  width: 44,
                  height: 44,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Title
            Text(
              l10n.contributeTranslationsTitle,
              style: const TextStyle(
                fontFamily: FontConstants.fontFamily,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            // Description
            Text(
              l10n.contributeTranslationsSubtitle,
              style: TextStyle(
                fontFamily: FontConstants.fontFamily,
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.7),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Primary action
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _openCrowdin();
                },
                icon: const Iconoir.Language(
                  color: Colors.white,
                  width: 20,
                  height: 20,
                ),
                label: Text(
                  l10n.contributeTranslationsOpenCrowdin,
                  style: const TextStyle(
                    fontFamily: FontConstants.fontFamily,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Dismiss
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                l10n.maybeLater,
                style: TextStyle(
                  fontFamily: FontConstants.fontFamily,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return Dialog(
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: shouldBlur
            ? BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: innerContent,
              )
            : innerContent,
      ),
    );
  }
}
