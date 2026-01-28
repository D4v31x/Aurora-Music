/// Popup menu items for the Now Playing screen.
///
/// Provides reusable menu item builders and the more options menu.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../../mixins/services/sleep_timer_controller.dart';

// MARK: - Constants

const _kIconSpacing = 12.0;
const _kMenuBorderRadius = 20.0;
const _kMenuBorderOpacity = 0.15;

// MARK: - Menu Item Row Builder

/// A reusable row for popup menu items.
///
/// Used internally to build consistent menu item rows with icon and label.
class _MenuItemRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MenuItemRow({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.white),
        const SizedBox(width: _kIconSpacing),
        Text(
          label,
          style: const TextStyle(color: Colors.white),
        ),
      ],
    );
  }
}

// MARK: - Sleep Timer Row (Dynamic Icon)

/// Internal widget for the sleep timer row with dynamic icon.
class _SleepTimerRow extends StatelessWidget {
  const _SleepTimerRow();

  @override
  Widget build(BuildContext context) {
    return Consumer<SleepTimerController>(
      builder: (context, sleepTimer, child) {
        return Row(
          children: [
            Icon(
              sleepTimer.isActive ? Icons.timer : Icons.timer_outlined,
              color: Colors.white,
            ),
            const SizedBox(width: _kIconSpacing),
            Text(
              AppLocalizations.of(context).translate('sleep_timer'),
              style: const TextStyle(color: Colors.white),
            ),
          ],
        );
      },
    );
  }
}

// MARK: - Player More Options Menu

/// The complete more options menu for the Now Playing screen.
///
/// Usage:
/// ```dart
/// PlayerMoreOptionsMenu(
///   onSelected: (value) => handleMenuSelection(value),
/// )
/// ```
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
      icon: const Icon(Icons.more_vert, color: Colors.white),
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
            icon: Icons.person_outline,
            label: l10n.translate('view_artist'),
          ),
        ),
        // Lyrics
        PopupMenuItem<String>(
          value: 'lyrics',
          child: _MenuItemRow(
            icon: Icons.lyrics_outlined,
            label: l10n.translate('lyrics'),
          ),
        ),
        // Add to Playlist
        PopupMenuItem<String>(
          value: 'add_playlist',
          child: _MenuItemRow(
            icon: Icons.playlist_add,
            label: l10n.translate('add_to_playlist'),
          ),
        ),
        // Share
        PopupMenuItem<String>(
          value: 'share',
          child: _MenuItemRow(
            icon: Icons.share_outlined,
            label: l10n.translate('share'),
          ),
        ),
        // Queue
        PopupMenuItem<String>(
          value: 'queue',
          child: _MenuItemRow(
            icon: Icons.queue_music_outlined,
            label: l10n.translate('queue'),
          ),
        ),
        // Song Info
        PopupMenuItem<String>(
          value: 'info',
          child: _MenuItemRow(
            icon: Icons.info_outline,
            label: l10n.translate('song_info'),
          ),
        ),
      ],
    );
  }
}
