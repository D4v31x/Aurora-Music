import 'dart:typed_data';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Sends in-app user feedback to the existing Sentry project — no new service
/// or account required.
///
/// The annotated screenshot from the `feedback` package is attached to the
/// Sentry event so it appears alongside the feedback message in the dashboard.
///
/// [type]        – "Bug Report" or "Feature Suggestion" (used as the event tag)
/// [description] – user's typed message
/// [screenshot]  – raw PNG bytes from [UserFeedback.screenshot]
class FeedbackEmailService {
  static Future<void> send({
    required String type,
    required String description,
    required List<int> screenshot,
  }) async {
    final message = description.isEmpty ? '(no description)' : description;

    // Capture a message event so the screenshot has an event to attach to.
    final hint = Hint.withAttachment(
      SentryAttachment.fromUint8List(
        Uint8List.fromList(screenshot),
        'screenshot.png',
        contentType: 'image/png',
      ),
    );

    final eventId = await Sentry.captureMessage(
      '[$type] $message',
      withScope: (scope) => scope.setTag('feedback_type', type),
      hint: hint,
    );

    // Attach the structured user-feedback so it shows in the
    // "User Feedback" section of the Sentry dashboard.
    await Sentry.captureFeedback(
      SentryFeedback(
        message: message,
        associatedEventId: eventId,
      ),
    );
  }
}
