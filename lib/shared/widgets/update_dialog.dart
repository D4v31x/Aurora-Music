import 'package:aurora_music_v01/core/constants/font_constants.dart';
import 'package:flutter/material.dart';
import 'package:upgrader/upgrader.dart';
import 'glassmorphic_dialog.dart';

/// Aurora Music's update prompt.
///
/// Subclasses [UpgradeAlert] so all version-comparison and store-URL logic
/// stays inside the upgrader package. Only [showTheDialog] is overridden to
/// render the same [GlassmorphicDialog] used throughout the app instead of
/// the default Material alert.
class AuroraUpgradeAlert extends UpgradeAlert {
  AuroraUpgradeAlert({
    super.key,
    required Upgrader super.upgrader,
    super.navigatorKey,
    super.child,
  }) : super(
          showLater: false,
          showIgnore: false,
          barrierDismissible: false,
        );

  @override
  UpgradeAlertState createState() => _AuroraUpgradeAlertState();
}

class _AuroraUpgradeAlertState extends UpgradeAlertState {
  @override
  void showTheDialog({
    Key? key,
    required BuildContext context,
    required String? title,
    required String message,
    required String? releaseNotes,
    required bool barrierDismissible,
    required UpgraderMessages messages,
  }) {
    if (!context.mounted) return;

    widget.upgrader.saveLastAlerted();

    final storeVersion =
        widget.upgrader.versionInfo?.appStoreVersion?.toString();
    final rawNotes = widget.upgrader.releaseNotes ?? releaseNotes;
    final notes = rawNotes != null && rawNotes.trim().isNotEmpty
        ? _decode(rawNotes)
        : null;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (ctx) => GlassmorphicDialog(
        title: const Row(
          children: [
            Icon(
              Icons.system_update_alt_rounded,
              color: Colors.white,
              size: 20,
            ),
            SizedBox(width: 10),
            Text('Update Available'),
          ],
        ),
        content: _Content(storeVersion: storeVersion, notes: notes),
        actions: [
          GlassmorphicTextButton(
            isPrimary: true,
            onPressed: () {
              Navigator.of(ctx).pop();
              // Delegates to upgrader which opens the Play Store app directly
              // via LaunchMode.externalNonBrowserApplication on Android.
              onUserUpdated(ctx, false);
            },
            child: const Text('Update Now'),
          ),
        ],
      ),
    );
  }

  static String _decode(String s) => s
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&apos;', "'");
}

// ---------------------------------------------------------------------------
// Content widget — plain Column, no nested cards
// ---------------------------------------------------------------------------

class _Content extends StatelessWidget {
  final String? storeVersion;
  final String? notes;

  const _Content({this.storeVersion, this.notes});

  @override
  Widget build(BuildContext context) {
    // GlassmorphicDialog wraps content in DefaultTextStyle:
    //   fontFamily, 15px, w400, white.withValues(alpha: 0.8)
    // Plain Text() nodes below inherit that style automatically.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          storeVersion != null
              ? 'Version $storeVersion is now available.'
              : 'A new version is now available.',
        ),
        if (notes != null) ...[
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
                notes!,
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
      ],
    );
  }
}
