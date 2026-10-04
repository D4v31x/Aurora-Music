import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/font_constants.dart';
import '../../l10n/generated/app_localizations.dart';
import '../providers/performance_mode_provider.dart';
import '../services/donation_service.dart';
import '../utils/changelog_content.dart';

/// Popup shown after an app update: logo, version, key highlights and a donation reminder.
class UpdatePopupDialog extends StatelessWidget {
  final String version;
  final VoidCallback onSupport;

  const UpdatePopupDialog({
    super.key,
    required this.version,
    required this.onSupport,
  });

  static Future<void> show(BuildContext context, {required String version}) {
    return showDialog(
      context: context,
      builder: (dialogContext) => UpdatePopupDialog(
        version: version,
        onSupport: () {
          Navigator.of(dialogContext).pop();
          DonationService.showDonationDialog(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final shouldBlur =
        Provider.of<PerformanceModeProvider>(context, listen: false)
            .shouldEnableBlur;
    const codename =
        String.fromEnvironment('CODE_NAME', defaultValue: 'Unknown');
    final highlights =
        ChangelogContent.getHighlightsForVersion(version).take(3);

    final content = DecoratedBox(
      decoration: BoxDecoration(
        gradient: shouldBlur
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.18),
                  Colors.white.withValues(alpha: 0.06),
                ],
              )
            : null,
        color: shouldBlur
            ? null
            : Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 360,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Image.asset(
                  'assets/images/logo/Music_full_logo.png',
                  width: 96,
                  height: 36,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                loc.updatedTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  fontFamily: FontConstants.fontFamily,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'v$version · $codename',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 13,
                  fontFamily: FontConstants.fontFamily,
                ),
              ),
              const SizedBox(height: 20),
              for (final item in highlights)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Text(
                    '•  ${item.text}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      height: 1.4,
                      fontFamily: FontConstants.fontFamily,
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              Text(
                loc.enjoyingAuroraDesc,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.4,
                  fontFamily: FontConstants.fontFamily,
                ),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: onSupport,
                icon: const Icon(Icons.favorite_rounded, size: 18),
                label: Text(
                  loc.supportAuroraBtn,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    fontFamily: FontConstants.fontFamily,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.pink,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  loc.gotIt,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontFamily: FontConstants.fontFamily,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: RepaintBoundary(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: shouldBlur
              ? BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: content,
                )
              : content,
        ),
      ),
    );
  }
}
