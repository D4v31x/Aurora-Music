import 'package:sentry_flutter/sentry_flutter.dart';

/// Sends in-app user feedback to the existing Sentry project.
class FeedbackEmailService {
  /// Sends a plain-text feedback entry to Sentry.
  static Future<void> sendText({
    required String type,
    required String description,
  }) async {
    final message = description.isEmpty ? '(no description)' : description;
    final eventId = await Sentry.captureMessage(
      '[$type] $message',
      withScope: (scope) => scope.setTag('feedback_type', type),
    );
    await Sentry.captureFeedback(
      SentryFeedback(
        message: message,
        associatedEventId: eventId,
      ),
    );
  }
}
