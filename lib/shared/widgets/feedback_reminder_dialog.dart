import 'dart:async';
import 'dart:io';
import 'package:aurora_music_v01/core/constants/font_constants.dart';
import 'package:feedback/feedback.dart';
import 'package:flutter/material.dart';
import 'package:iconoir_flutter/iconoir_flutter.dart' as Iconoir;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../l10n/generated/app_localizations.dart';
import '../services/feedback_reminder_service.dart';
import '../services/feedback_email_service.dart';

/// Minimal bottom-sheet prompt for feedback and bug reporting.
/// Uses the `feedback` package to capture annotated screenshots before
/// opening the corresponding GitHub page.
class FeedbackReminderDialog extends StatelessWidget {
  const FeedbackReminderDialog({super.key});

  /// Shows the sheet only when the reminder service decides it's time.
  static Future<void> showIfNeeded(BuildContext context) async {
    final shouldShow = await FeedbackReminderService.shouldShowFeedbackPrompt();
    if (shouldShow && context.mounted) {
      await FeedbackReminderService.recordPromptShown();
      if (context.mounted) unawaited(show(context));
    }
  }

  /// Shows the sheet unconditionally (e.g. tapped from Settings).
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const FeedbackReminderDialog(),
    );
  }

  void _reportBug(BuildContext context) {
    final feedbackController = BetterFeedback.of(context);
    Navigator.pop(context);
    feedbackController.show((UserFeedback feedback) async {
      await _submit(
        context: context,
        type: 'Bug Report',
        feedback: feedback,
      );
    });
  }

  void _suggestFeature(BuildContext context) {
    final feedbackController = BetterFeedback.of(context);
    Navigator.pop(context);
    feedbackController.show((UserFeedback feedback) async {
      await _submit(
        context: context,
        type: 'Feature Suggestion',
        feedback: feedback,
      );
    });
  }

  /// Sends feedback to Sentry (with annotated screenshot attached).
  /// Falls back to the native share sheet if Sentry throws.
  static Future<void> _submit({
    required BuildContext context,
    required String type,
    required UserFeedback feedback,
  }) async {
    try {
      await FeedbackEmailService.send(
        type: type,
        description: feedback.text,
        screenshot: feedback.screenshot,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Thanks! Your $type was received.',
              style: const TextStyle(fontFamily: FontConstants.fontFamily),
            ),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (_) {
      // Fallback: share sheet with annotated screenshot
      final tmpDir = await getTemporaryDirectory();
      final file = File(
        '${tmpDir.path}/aurora_feedback_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(feedback.screenshot);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png', name: 'screenshot.png')],
        text: feedback.text.isEmpty
            ? '$type — no description provided.'
            : feedback.text,
        subject: 'Aurora Music – $type',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Title
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  l10n.send_feedback,
                  style: TextStyle(
                    fontFamily: FontConstants.fontFamily,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
              ),
            ),

            // Report Bug
            ListTile(
              leading: Iconoir.Bug(
                color: cs.error,
                width: 22,
                height: 22,
              ),
              title: Text(
                l10n.report_bug,
                style: TextStyle(
                  fontFamily: FontConstants.fontFamily,
                  color: cs.onSurface,
                ),
              ),
              onTap: () => _reportBug(context),
            ),

            // Suggest Feature
            ListTile(
              leading: Iconoir.LightBulb(
                color: cs.primary,
                width: 22,
                height: 22,
              ),
              title: Text(
                l10n.suggest_feature,
                style: TextStyle(
                  fontFamily: FontConstants.fontFamily,
                  color: cs.onSurface,
                ),
              ),
              onTap: () => _suggestFeature(context),
            ),

            const Divider(height: 1, indent: 16, endIndent: 16),

            // Dismiss row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    l10n.maybeLater,
                    style: TextStyle(
                      fontFamily: FontConstants.fontFamily,
                      color: cs.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    await FeedbackReminderService.dismissPermanently();
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: Text(
                    l10n.dont_ask_again,
                    style: TextStyle(
                      fontFamily: FontConstants.fontFamily,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}
