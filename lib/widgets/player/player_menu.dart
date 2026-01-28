/// Popup menu items for the Now Playing screen.
///
/// Provides reusable menu item builders and the more options menu.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../localization/app_localizations.dart';
import '../../services/sleep_timer_controller.dart';

// MARK: - Constants

const _kIconSpacing = 12.0;
const _kMenuBorderRadius = 20.0;
const _kMenuBorderOpacity = 0.15;

// MARK: - Menu Item Builder

/// A reusable builder for popup menu items.
class PlayerMenuItem extends StatelessWidget {
  /// The icon to display.
  final IconData icon;

  /// The label text.
  final String label;

  /// The value for this menu item.
  final String value;

  const PlayerMenuItem({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(width: _kIconSpacing),
          Text(
            label,
            style: const TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }
}

// MARK: - Menu Item with Dynamic Icon (for Sleep Timer)

/// A menu item that shows the sleep timer status.
class SleepTimerMenuItem extends StatelessWidget {
  const SleepTimerMenuItem({super.key});

  @override
  Widget build(BuildContext context) {
    return PopupMenuItem<String>(
      value: 'sleep_timer',
      child: Consumer<SleepTimerController>(
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
      ),
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
        // Sleep Timer
        const PopupMenuItem<String>(
          value: 'sleep_timer',
          child: _SleepTimerRow(),
        ),
        // View Artist
        PopupMenuItem<String>(
          value: 'view_artist',
          child: Row(
            children: [
              const Icon(Icons.person_outline, color: Colors.white),
              const SizedBox(width: _kIconSpacing),
              Text(
                l10n.translate('view_artist'),
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
        // Lyrics
        PopupMenuItem<String>(
          value: 'lyrics',
          child: Row(
            children: [
              const Icon(Icons.lyrics_outlined, color: Colors.white),
              const SizedBox(width: _kIconSpacing),
              Text(
                l10n.translate('lyrics'),
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
        // Add to Playlist
        PopupMenuItem<String>(
          value: 'add_playlist',
          child: Row(
            children: [
              const Icon(Icons.playlist_add, color: Colors.white),
              const SizedBox(width: _kIconSpacing),
              Text(
                l10n.translate('add_to_playlist'),
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
        // Share
        PopupMenuItem<String>(
          value: 'share',
          child: Row(
            children: [
              const Icon(Icons.share_outlined, color: Colors.white),
              const SizedBox(width: _kIconSpacing),
              Text(
                l10n.translate('share'),
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
        // Queue
        PopupMenuItem<String>(
          value: 'queue',
          child: Row(
            children: [
              const Icon(Icons.queue_music_outlined, color: Colors.white),
              const SizedBox(width: _kIconSpacing),
              Text(
                l10n.translate('queue'),
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
        // Song Info
        PopupMenuItem<String>(
          value: 'info',
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.white),
              const SizedBox(width: _kIconSpacing),
              Text(
                l10n.translate('song_info'),
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
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
