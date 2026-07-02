/// Dialog preview screen — tap any tile to open the corresponding popup.
library;

import 'package:flutter/material.dart';
import 'package:iconoir_flutter/iconoir_flutter.dart' as iconoir;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/font_constants.dart';
import '../../../shared/services/audio_player_service.dart';
import '../../../shared/services/donation_service.dart';
import '../../../shared/widgets/about_dialog.dart';
import '../../../shared/widgets/app_background.dart';
import '../../../shared/widgets/changelog_dialog.dart';
import '../../../shared/widgets/expanding_player.dart';
import '../../../shared/widgets/feedback_popup_widget.dart';
import '../../../shared/widgets/glassmorphic_dialog.dart';
import '../../../shared/widgets/packages_dialog.dart' hide PackageInfo;
import '../../../shared/widgets/song_context_menu.dart';
import '../../../shared/widgets/translation_reminder_dialog.dart';
import '../../player/widgets/player_dialogs.dart';
import '../../player/widgets/sleep_timer_widgets.dart';
import '../widgets/settings_tile_builders.dart';

class DialogPreviewScreen extends StatelessWidget {
  const DialogPreviewScreen({super.key});

  // ── App-level dialogs ────────────────────────────────────────────────────

  Future<void> _previewAbout(BuildContext context) async {
    final info = await PackageInfo.fromPlatform();
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => AuroraAboutDialog(
        version: info.version,
        codename: 'Preview',
      ),
    );
  }

  Future<void> _previewChangelog(BuildContext context) async {
    final info = await PackageInfo.fromPlatform();
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => ChangelogDialog(currentVersion: info.version),
    );
  }

  void _previewPackages(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => const PackagesDialog(),
    );
  }

  void _previewDonationDialog(BuildContext context) {
    DonationService.showDonationDialog(context);
  }

  void _previewDonationReminder(BuildContext context) {
    DonationService.showDonationReminderDialog(context);
  }

  void _previewFeedback(BuildContext context) {
    FeedbackPopupWidget.show(context);
  }

  void _previewUpdateDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (ctx) => GlassmorphicDialog(
        title: const Row(
          children: [
            Icon(Icons.system_update_alt_rounded, color: Colors.white, size: 20),
            SizedBox(width: 10),
            Text('Update Available'),
          ],
        ),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Version 2.0.0 is now available.'),
            const SizedBox(height: 16),
            const Text(
              "What's new",
              style: TextStyle(
                fontFamily: FontConstants.fontFamily,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 144),
              child: SingleChildScrollView(
                child: Text(
                  '• Example new feature\n'
                  '• Another improvement\n'
                  '• Performance & stability fixes',
                  style: TextStyle(
                    fontFamily: FontConstants.fontFamily,
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.65),
                    height: 1.65,
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          GlassmorphicTextButton(
            isPrimary: true,
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Update Now'),
          ),
        ],
      ),
    );
  }

  void _previewTranslationReminder(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => const TranslationReminderDialog(),
    );
  }

  void _previewExitDialog(BuildContext context) {
    showGlassmorphicDialog<void>(
      context: context,
      builder: (ctx) => GlassmorphicDialog(
        title: const Text('Exit Aurora Music?'),
        content: const Text(
            'This will stop playback and close the app.'),
        actions: [
          GlassmorphicTextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('No'),
          ),
          GlassmorphicTextButton(
            isPrimary: true,
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Yes'),
          ),
        ],
      ),
    );
  }

  void _previewSongContextMenu(BuildContext context) {
    final audio = context.read<AudioPlayerService>();
    final song = audio.currentSong;
    if (song == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No song playing — play a song first')),
      );
      return;
    }
    showSongContextMenu(context, song);
  }

  // ── Player sheets ────────────────────────────────────────────────────────

  void _previewSleepTimer(BuildContext context) {
    showSleepTimerOptions(context);
  }

  void _previewQueue(BuildContext context) {
    final audio = context.read<AudioPlayerService>();
    showQueueDialog(context, audio);
  }

  void _previewSongInfo(BuildContext context) {
    final audio = context.read<AudioPlayerService>();
    showSongInfoDialog(context, audio);
  }

  void _previewAddToPlaylist(BuildContext context) {
    final audio = context.read<AudioPlayerService>();
    showAddToPlaylistDialog(context, audio);
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;

    return AppBackground(
      child: Scaffold(
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
            'Popup Previews',
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
              // ── App-level ─────────────────────────────────────────────
              SettingsTiles.buildSectionHeader(context, 'App Dialogs'),
              SettingsTiles.buildGlassmorphicCard(context, children: [
                SettingsTiles.buildActionTile(
                  context,
                  icon: iconoir.InfoCircle(
                      color: cs.primary, width: 20, height: 20),
                  title: 'About Aurora',
                  subtitle: 'App info, links & codename',
                  onTap: () => _previewAbout(context),
                  isFirst: true,
                ),
                SettingsTiles.buildActionTile(
                  context,
                  icon: const iconoir.Bell(
                      color: Colors.blue, width: 20, height: 20),
                  title: "What's New",
                  subtitle: 'Scrollable changelog',
                  iconColor: Colors.blue,
                  onTap: () => _previewChangelog(context),
                ),
                SettingsTiles.buildActionTile(
                  context,
                  icon: const iconoir.BookmarkBook(
                      color: Colors.teal, width: 20, height: 20),
                  title: 'Open Source Licenses',
                  subtitle: 'Third-party packages list',
                  iconColor: Colors.teal,
                  onTap: () => _previewPackages(context),
                ),
                SettingsTiles.buildActionTile(
                  context,
                  icon: const iconoir.HeartSolid(
                      color: Colors.pink, width: 20, height: 20),
                  title: 'Support Aurora',
                  subtitle: 'Donation tier picker & links',
                  iconColor: Colors.pink,
                  onTap: () => _previewDonationDialog(context),
                ),
                SettingsTiles.buildActionTile(
                  context,
                  icon: const iconoir.Heart(
                      color: Colors.pink, width: 20, height: 20),
                  title: 'Donation Reminder',
                  subtitle: 'Nudge with dismiss options',
                  iconColor: Colors.pink,
                  onTap: () => _previewDonationReminder(context),
                ),
                SettingsTiles.buildActionTile(
                  context,
                  icon: const iconoir.ChatBubble(
                      color: Colors.green, width: 20, height: 20),
                  title: 'Feedback',
                  subtitle: 'Sentiment + free-text form',
                  iconColor: Colors.green,
                  onTap: () => _previewFeedback(context),
                ),
                SettingsTiles.buildActionTile(
                  context,
                  icon: Icon(Icons.system_update_alt_rounded,
                      color: cs.primary, size: 20),
                  title: 'Update Available',
                  subtitle: 'Play Store update prompt',
                  onTap: () => _previewUpdateDialog(context),
                ),
                SettingsTiles.buildActionTile(
                  context,
                  icon: const iconoir.Language(
                      color: Colors.tealAccent, width: 20, height: 20),
                  title: 'Translation Reminder',
                  subtitle: 'Crowdin contribution nudge',
                  iconColor: Colors.tealAccent,
                  onTap: () => _previewTranslationReminder(context),
                ),
                SettingsTiles.buildActionTile(
                  context,
                  icon: Icon(Icons.exit_to_app_rounded,
                      color: cs.error, size: 20),
                  title: 'Exit Confirmation',
                  subtitle: 'App close prompt on back press',
                  iconColor: cs.error,
                  onTap: () => _previewExitDialog(context),
                ),
              ]),

              // ── Player sheets ──────────────────────────────────────────
              SettingsTiles.buildSectionHeader(context, 'Player Sheets'),
              SettingsTiles.buildGlassmorphicCard(context, children: [
                SettingsTiles.buildActionTile(
                  context,
                  icon: Icon(Icons.more_horiz_rounded,
                      color: cs.primary, size: 20),
                  title: 'Song Context Menu',
                  subtitle: 'Long-press sheet — needs a song',
                  onTap: () => _previewSongContextMenu(context),
                  isFirst: true,
                ),
                SettingsTiles.buildActionTile(
                  context,
                  icon: Icon(Icons.bedtime_outlined,
                      color: cs.primary, size: 20),
                  title: 'Sleep Timer',
                  subtitle: 'Timer options bottom sheet',
                  onTap: () => _previewSleepTimer(context),
                ),
                SettingsTiles.buildActionTile(
                  context,
                  icon: Icon(Icons.queue_music_rounded,
                      color: cs.primary, size: 20),
                  title: 'Queue',
                  subtitle: 'Current playback queue — needs a song',
                  onTap: () => _previewQueue(context),
                ),
                SettingsTiles.buildActionTile(
                  context,
                  icon: Icon(Icons.info_outline_rounded,
                      color: cs.primary, size: 20),
                  title: 'Song Info',
                  subtitle: 'Technical metadata — needs a song',
                  onTap: () => _previewSongInfo(context),
                ),
                SettingsTiles.buildActionTile(
                  context,
                  icon: Icon(Icons.playlist_add_rounded,
                      color: cs.primary, size: 20),
                  title: 'Add to Playlist',
                  subtitle: 'Playlist picker — needs a song',
                  onTap: () => _previewAddToPlaylist(context),
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
