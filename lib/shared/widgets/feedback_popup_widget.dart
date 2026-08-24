import 'package:in_app_review/in_app_review.dart';

import '../services/feedback_reminder_service.dart';

/// Triggers a Google Play in-app review, or falls back to the store listing.
///
/// No dialog is shown — the review sheet is presented directly by the OS.
/// Call [showIfNeeded] from your post-launch hook; it delegates to
/// [FeedbackReminderService] for all persistence/gating logic.
class FeedbackPopupWidget {
  FeedbackPopupWidget._();

  static Future<void> _triggerReview() async {
    final inAppReview = InAppReview.instance;
    // Prefer the native in-app review sheet (stays in the app); only fall
    // back to jumping to the Play Store listing when it's unavailable.
    if (await inAppReview.isAvailable()) {
      await inAppReview.requestReview();
    } else {
      await inAppReview.openStoreListing(
          appStoreId: 'com.aurorasoftware.music');
    }
  }

  /// Triggers the in-app review unconditionally — use from Settings where
  /// the user explicitly tapped the button.
  // ignore: use_build_context_synchronously
  static Future<void> show(dynamic context) => _triggerReview();

  /// Triggers the in-app review only when [FeedbackReminderService] decides
  /// the time is right (7+ days active, not permanently dismissed, etc.).
  static Future<void> showIfNeeded(dynamic context) async {
    final shouldShow = await FeedbackReminderService.shouldShowFeedbackPrompt();
    if (!shouldShow) return;
    await FeedbackReminderService.recordPromptShown();
    await FeedbackReminderService.dismissPermanently();
    await _triggerReview();
  }
}
