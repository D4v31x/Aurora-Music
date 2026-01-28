import 'dart:ui';
import 'package:aurora_music_v01/core/constants/font_constants.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../l10n/app_localizations.dart';
import '../providers/performance_mode_provider.dart';
import '../services/feedback_reminder_service.dart';

/// A glassmorphic dialog to remind users to provide feedback.
/// Performance-aware: Respects device performance mode for blur effects.
class FeedbackReminderDialog extends StatelessWidget {
  const FeedbackReminderDialog({super.key});

  static Future<void> showIfNeeded(BuildContext context) async {
    final shouldShow = await FeedbackReminderService.shouldShowFeedbackPrompt();

    if (shouldShow && context.mounted) {
      await FeedbackReminderService.recordPromptShown();

      showDialog(
        context: context,
        builder: (context) => const FeedbackReminderDialog(),
      );
    }
  }

  void _openGitHubIssues() async {
    final url = Uri.parse('https://github.com/D4v31x/Aurora-Music/issues');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  void _openGitHubDiscussions() async {
    final url = Uri.parse('https://github.com/D4v31x/Aurora-Music/discussions');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // Check if blur should be enabled based on performance mode
    final performanceProvider =
        Provider.of<PerformanceModeProvider>(context, listen: false);
    final shouldBlur = performanceProvider.shouldEnableBlur;
    final colorScheme = Theme.of(context).colorScheme;

    // Use solid surface colors for low-end devices
    final BoxDecoration dialogDecoration;
    if (shouldBlur) {
      dialogDecoration = BoxDecoration(
        color: Colors.grey[900]?.withOpacity(0.9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      );
    } else {
      // Solid dialog styling for low-end devices
      dialogDecoration = BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colorScheme.outlineVariant,
          width: 1,
        ),
      );
    }

    final dialogContent = Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
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
                  color:
                      Theme.of(context).colorScheme.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.favorite_rounded,
                  size: 32,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 20),

              // Title
              Text(
                l10n.translate('feedback_title'),
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
                l10n.translate('feedback_description'),
                style: TextStyle(
                  fontFamily: FontConstants.fontFamily,
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.7),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: _FeedbackButton(
                      icon: Icons.bug_report_rounded,
                      label: l10n.translate('report_bug'),
                      color: Colors.orange,
                      onTap: () {
                        Navigator.pop(context);
                        _openGitHubIssues();
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _FeedbackButton(
                      icon: Icons.lightbulb_rounded,
                      label: l10n.translate('suggest_feature'),
                      color: Colors.blue,
                      onTap: () {
                        Navigator.pop(context);
                        _openGitHubDiscussions();
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Dismiss options
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      l10n.translate('maybe_later'),
                      style: TextStyle(
                        fontFamily: FontConstants.fontFamily,
                        color: Colors.white.withOpacity(0.6),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  TextButton(
                    onPressed: () async {
                      await FeedbackReminderService.dismissPermanently();
                      if (context.mounted) {
                        Navigator.pop(context);
                      }
                    },
                    child: Text(
                      l10n.translate('dont_ask_again'),
                      style: TextStyle(
                        fontFamily: FontConstants.fontFamily,
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    // Wrap with BackdropFilter only when blur is enabled
    if (shouldBlur) {
      return BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: dialogContent,
      );
    }

    return dialogContent;
  }
}

class _FeedbackButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _FeedbackButton({
    required this.icon,
    required this.label,
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
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: color.withOpacity(0.3),
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: color,
                size: 28,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontFamily: FontConstants.fontFamily,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
