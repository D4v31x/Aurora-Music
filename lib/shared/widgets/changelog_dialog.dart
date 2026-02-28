import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:ui';
import '../../core/constants/font_constants.dart';
import '../../l10n/app_localizations.dart';
import '../providers/performance_mode_provider.dart';
import '../providers/theme_provider.dart';
import '../utils/changelog_content.dart';

/// Changelog dialog with glassmorphic styling.
/// Performance-aware: Respects device performance mode for blur effects.
class ChangelogDialog extends StatelessWidget {
  final String currentVersion;

  const ChangelogDialog({
    super.key,
    required this.currentVersion,
  });

  Future<void> _openPrivacyPolicy() async {
    const url = 'https://aurorasoftware.netlify.app/terms.html';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  Widget _buildChangelogSection(String title, List<String> items,
      {required bool isDarkMode}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            fontFamily: FontConstants.fontFamily,
          ),
        ),
        const SizedBox(height: 8),
        ...items.map((item) => Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.blue[300] : Colors.blue[700],
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (isDarkMode
                                  ? Colors.blue[300]
                                  : Colors.blue[700])!
                              .withOpacity(0.3),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item,
                      style: TextStyle(
                        color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                        height: 1.5,
                        fontFamily: FontConstants.fontFamily,
                      ),
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final codename = dotenv.env['CODE_NAME'] ?? 'Unknown';
    final changelogSections =
        ChangelogContent.getChangelogForVersion(currentVersion);

    // Check if blur should be enabled based on performance mode
    final performanceProvider =
        Provider.of<PerformanceModeProvider>(context, listen: false);
    final shouldBlur = performanceProvider.shouldEnableBlur;
    final colorScheme = Theme.of(context).colorScheme;

    // Use solid surface colors for low-end devices
    final BoxDecoration dialogDecoration;
    if (shouldBlur) {
      dialogDecoration = BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.15),
            Colors.white.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
        ),
      );
    } else {
      // Solid dialog styling for low-end devices
      dialogDecoration = BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: colorScheme.outlineVariant,
          width: 1,
        ),
      );
    }

    final dialogContent = DecoratedBox(
      decoration: dialogDecoration,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
          maxWidth: MediaQuery.of(context).size.width * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Fixed Title
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 500),
                offset: const Offset(0, 0),
                child: Text(
                  AppLocalizations.of(context).translate('whats_new'),
                  style: TextStyle(
                    color: isDarkMode ? Colors.white : Colors.black,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    fontFamily: FontConstants.fontFamily,
                  ),
                ),
              ),
            ),

            // Version Badge
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: shouldBlur
                      ? (isDarkMode
                          ? Colors.blue.withOpacity(0.2)
                          : Colors.blue.withOpacity(0.1))
                      : colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: shouldBlur
                        ? (isDarkMode
                            ? Colors.blue.withOpacity(0.3)
                            : Colors.blue.withOpacity(0.2))
                        : colorScheme.primary,
                    width: 1,
                  ),
                ),
                child: Text(
                  'Version $currentVersion ($codename)',
                  style: TextStyle(
                    color: isDarkMode ? Colors.blue[300] : Colors.blue[700],
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    fontFamily: FontConstants.fontFamily,
                  ),
                ),
              ),
            ),

            // Scrollable Content
            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 500),
                  opacity: 1.0,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Dynamic changelog sections
                      ...changelogSections.expand((section) => [
                            ...section.entries.map((entry) => Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildChangelogSection(
                                      entry.key,
                                      entry.value,
                                      isDarkMode: isDarkMode,
                                    ),
                                    const SizedBox(height: 16),
                                  ],
                                )),
                          ]),

                      // Privacy Notice Section
                      Divider(
                        color: shouldBlur
                            ? (isDarkMode
                                ? Colors.white.withOpacity(0.1)
                                : Colors.black.withOpacity(0.1))
                            : colorScheme.outlineVariant,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        AppLocalizations.of(context)
                            .translate('privacy_notice'),
                        style: TextStyle(
                          fontSize: 12,
                          fontFamily: FontConstants.fontFamily,
                          color:
                              isDarkMode ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: _openPrivacyPolicy,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Text(
                            AppLocalizations.of(context)
                                .translate('privacy_policy_link'),
                            style: TextStyle(
                              fontSize: 12,
                              fontFamily: FontConstants.fontFamily,
                              color: isDarkMode
                                  ? Colors.blue[300]
                                  : Colors.blue[700],
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),

            // Fixed Actions
            Padding(
              padding: const EdgeInsets.all(24),
              child: TextButton(
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  backgroundColor: shouldBlur
                      ? Colors.white.withValues(alpha: 0.1)
                      : colorScheme.primaryContainer,
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  AppLocalizations.of(context).translate('got_it'),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    fontFamily: FontConstants.fontFamily,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    // Apply blur filter to popup window when performance allows
    Widget blurredContent = ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: shouldBlur
          ? BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: dialogContent,
            )
          : dialogContent,
    );

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: RepaintBoundary(
        child: blurredContent,
      ),
    );
  }
}
