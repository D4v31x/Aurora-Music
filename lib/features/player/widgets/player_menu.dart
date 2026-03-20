/// Popup menu items for the Now Playing screen.
library;

import 'package:flutter/material.dart';
import 'package:iconoir_flutter/iconoir_flutter.dart' as Iconoir;
import 'package:provider/provider.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/services/sleep_timer_controller.dart';


const _kIconSpacing = 12.0;
const _kMenuBorderRadius = 20.0;
const _kMenuBorderOpacity = 0.15;


/// A reusable row for popup menu items.
class _MenuItemRow extends StatelessWidget {
  final Widget icon;
  final String label;

  const _MenuItemRow({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        icon,
        const SizedBox(width: _kIconSpacing),
        Text(
          label,
          style: const TextStyle(color: Colors.white),
        ),
      ],
    );
  }
}


/// Internal widget for the sleep timer row with dynamic icon.
class _SleepTimerRow extends StatelessWidget {
  const _SleepTimerRow();

  @override
  Widget build(BuildContext context) {
    return Consumer<SleepTimerController>(
      builder: (context, sleepTimer, child) {
        return Row(
          children: [
            sleepTimer.isActive
                ? const Iconoir.Alarm(color: Colors.white)
                : const Iconoir.Timer(color: Colors.white),
            const SizedBox(width: _kIconSpacing),
            Text(
              AppLocalizations.of(context).sleepTimer,
              style: const TextStyle(color: Colors.white),
            ),
          ],
        );
      },
    );
  }
}


/// The complete more options menu for the Now Playing screen.
class PlayerMoreOptionsMenu extends StatelessWidget {
  /// Callback when a menu item is selected.
  final void Function(String value) onSelected;

  const PlayerMoreOptionsMenu({
    super.key,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return PopupMenuButton<String>(
      icon: const Iconoir.MoreVert(color: Colors.white),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_kMenuBorderRadius),
        side: BorderSide(
          color: Colors.white.withValues(alpha: _kMenuBorderOpacity),
        ),
      ),
      onSelected: onSelected,
      itemBuilder: (BuildContext context) => [
        // Sleep Timer (with dynamic icon)
        const PopupMenuItem<String>(
          value: 'sleep_timer',
          child: _SleepTimerRow(),
        ),
        // View Artist
        PopupMenuItem<String>(
          value: 'view_artist',
          child: _MenuItemRow(
            icon: const Iconoir.User(color: Colors.white),
            label: l10n.viewArtist,
          ),
        ),
        // Lyrics
        PopupMenuItem<String>(
          value: 'lyrics',
          child: _MenuItemRow(
            icon: const Iconoir.MusicNote(color: Colors.white),
            label: l10n.lyrics,
          ),
        ),
        // Add to Playlist
        PopupMenuItem<String>(
          value: 'add_playlist',
          child: _MenuItemRow(
            icon: const Iconoir.PlaylistPlus(color: Colors.white),
            label: l10n.addToPlaylist,
          ),
        ),
        // Share
        PopupMenuItem<String>(
          value: 'share',
          child: _MenuItemRow(
            icon: const Iconoir.ShareAndroid(color: Colors.white),
            label: l10n.share,
          ),
        ),
        // Queue
        PopupMenuItem<String>(
          value: 'queue',
          child: _MenuItemRow(
            icon: const Iconoir.Playlist(color: Colors.white),
            label: l10n.queue,
          ),
        ),
        // Song Info
        PopupMenuItem<String>(
          value: 'info',
          child: _MenuItemRow(
            icon: const Iconoir.InfoCircle(color: Colors.white),
            label: l10n.songInfo,
          ),
        ),
      ],
    );
  }
}
