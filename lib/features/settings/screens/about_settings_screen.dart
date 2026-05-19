/// About settings sub-screen — version, changelog, support, updates & reset.
library;

import 'package:aurora_music_v01/shared/widgets/about_dialog.dart';
import 'package:flutter/material.dart';
import 'package:iconoir_flutter/iconoir_flutter.dart' as iconoir;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/font_constants.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/services/audio_player_service.dart';
import '../../../shared/services/donation_service.dart';
import '../../../shared/services/notification_manager.dart';
import '../../../shared/services/version_service.dart';
import '../../../shared/widgets/changelog_dialog.dart';
import '../../../shared/widgets/app_background.dart';
import '../../../shared/widgets/expanding_player.dart';
import '../../../shared/widgets/feedback_popup_widget.dart';
import '../widgets/settings_tile_builders.dart';

class AboutSettingsScreen extends StatelessWidget {
  final String currentVersion;
  final NotificationManager notificationManager;
  final VoidCallback? onUpdateCheck;
  final VoidCallback? onResetSetup;

  const AboutSettingsScreen({
    super.key,
    required this.currentVersion,
    required this.notificationManager,
    this.onUpdateCheck,
    this.onResetSetup,
  });

  // ── Dialogs ────────────────────────────────────────────────────────────────

  void _showAboutDialog(BuildContext context) async {
    final packageInfo = await PackageInfo.fromPlatform();
    const codename =
        String.fromEnvironment('CODE_NAME', defaultValue: 'Unknown');
    if (!context.mounted) return;
    await showDialog(
      context: context,
      builder: (_) => AuroraAboutDialog(
        version: packageInfo.version,
        codename: codename,
      ),
    );
  }

  void _showChangelogDialog(BuildContext context) async {
    if (!context.mounted) return;
    await showDialog(
      context: context,
      builder: (_) => ChangelogDialog(currentVersion: currentVersion),
    );
  }

  Future<void> _checkUpdates(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    notificationManager.showNotification(
      l10n.settingsCheckingUpdates,
      duration: const Duration(seconds: 2),
    );
    final result = await VersionService.checkForNewVersion();
    if (!context.mounted) return;
    if (result.isUpdateAvailable && result.latestVersion != null) {
      notificationManager.showNotification(
        l10n.settingsUpdateAvailable,
        duration: const Duration(seconds: 2),
        onComplete: () {
          _showUpdateDialog(context, result.latestVersion!);
          notificationManager.showDefaultTitle();
        },
      );
    } else {
      notificationManager.showNotification(
        l10n.settingsUpToDate,
        duration: const Duration(seconds: 2),
        onComplete: notificationManager.showDefaultTitle,
      );
    }
  }

  void _showUpdateDialog(BuildContext context, dynamic latestVersion) {
    final l10n = AppLocalizations.of(context);
    final perfProvider =
        Provider.of<PerformanceModeProvider>(context, listen: false);
    final cs = Theme.of(context).colorScheme;
    final shouldBlur = perfProvider.shouldEnableBlur;
    final bg = shouldBlur
        ? Colors.grey[900]!.withValues(alpha: 0.9)
        : cs.surfaceContainerHigh;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: shouldBlur
                ? Colors.white.withValues(alpha: 0.1)
                : cs.outlineVariant,
          ),
        ),
        title: Text(l10n.updateAvailable,
            style: const TextStyle(
                fontFamily: FontConstants.fontFamily,
                color: Colors.white,
                fontWeight: FontWeight.bold)),
        content: Text('${l10n.updateMessage}: $latestVersion',
            style: const TextStyle(
                fontFamily: FontConstants.fontFamily, color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.later,
                style: const TextStyle(
                    fontFamily: FontConstants.fontFamily,
                    color: Colors.white70)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onUpdateCheck?.call();
            },
            child: Text(l10n.updateNow,
                style: const TextStyle(
                    fontFamily: FontConstants.fontFamily,
                    color: Colors.white,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);
    final primary = Theme.of(context).colorScheme.primary;

    return AppBackground(child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: iconoir.NavArrowLeft(
            color: isDark ? Colors.white : Colors.black,
            width: 28,
            height: 28,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          l10n.settingsAbout,
          style: TextStyle(
            fontFamily: FontConstants.fontFamily,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
      ),
      body: Selector<AudioPlayerService, bool>(
        selector: (_, s) => s.currentSong != null,
        builder: (context, hasCurrentSong, _) => ListView(
          padding: EdgeInsets.only(
            top: 10,
            bottom: hasCurrentSong
                ? ExpandingPlayer.getMiniPlayerPaddingHeight(context)
                : MediaQuery.of(context).padding.bottom + 24,
          ),
          children: [
            SettingsTiles.buildSectionHeader(context, l10n.settingsAbout),
            SettingsTiles.buildGlassmorphicCard(context, children: [
              SettingsTiles.buildActionTile(
                context,
                icon: iconoir.InfoCircle(
                    color: primary, width: 20, height: 20),
                title: l10n.settingsAboutApp,
                subtitle: '${l10n.settingsVersion} $currentVersion',
                onTap: () => _showAboutDialog(context),
                isFirst: true,
              ),
              SettingsTiles.buildActionTile(
                context,
                icon: const iconoir.Bell(
                    color: Colors.blue, width: 20, height: 20),
                title: l10n.whatsNew,
                subtitle: l10n.view_changelog,
                iconColor: Colors.blue,
                onTap: () => _showChangelogDialog(context),
              ),
              SettingsTiles.buildActionTile(
                context,
                icon: const iconoir.HeartSolid(
                    color: Colors.pink, width: 20, height: 20),
                title: l10n.supportAurora,
                subtitle: l10n.supportAuroraDescShort,
                iconColor: Colors.pink,
                onTap: () => DonationService.showDonationDialog(context),
              ),
              SettingsTiles.buildActionTile(
                context,
                icon: const iconoir.ChatBubble(
                    color: Colors.green, width: 20, height: 20),
                title: l10n.send_feedback,
                subtitle: l10n.send_feedback_desc,
                iconColor: Colors.green,
                onTap: () => FeedbackPopupWidget.show(context),
              ),
              SettingsTiles.buildActionTile(
                context,
                icon: const iconoir.Language(
                    color: Colors.purple, width: 20, height: 20),
                title: l10n.contributeTranslations,
                subtitle: l10n.contributeTranslationsDesc,
                iconColor: Colors.purple,
                onTap: () => launchUrl(
                  Uri.parse('https://crowdin.com/project/aurora-music'),
                  mode: LaunchMode.externalApplication,
                ),
              ),
              SettingsTiles.buildActionTile(
                context,
                icon: iconoir.Refresh(
                    color: primary, width: 20, height: 20),
                title: l10n.settingsCheckUpdates,
                subtitle: l10n.settingsCheckUpdatesDesc,
                onTap: () => _checkUpdates(context),
              ),
              if (onResetSetup != null)
                SettingsTiles.buildActionTile(
                  context,
                  icon: iconoir.WarningTriangle(
                      color: Colors.orange, width: 20, height: 20),
                  title: 'Reset Setup',
                  subtitle: 'Restart the onboarding flow',
                  iconColor: Colors.orange,
                  onTap: onResetSetup!,
                ),
            ]),
            const SizedBox(height: 32),
          ],
        ),
      ),
    ),
    );
  }
}
