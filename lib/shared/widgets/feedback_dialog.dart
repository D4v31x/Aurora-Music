import 'package:flutter/material.dart';
import '../../core/constants/font_constants.dart';
import '../../l10n/generated/app_localizations.dart';
import '../services/feedback_email_service.dart';
import 'glassmorphic_dialog.dart';

/// Dialog for submitting a bug report / suggestion, sent to Sentry.
class FeedbackDialog extends StatefulWidget {
  const FeedbackDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(context: context, builder: (_) => const FeedbackDialog());
  }

  @override
  State<FeedbackDialog> createState() => _FeedbackDialogState();
}

class _FeedbackDialogState extends State<FeedbackDialog> {
  final _controller = TextEditingController();
  String _type = 'bug';
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    final messenger = ScaffoldMessenger.of(context);
    final loc = AppLocalizations.of(context);
    try {
      await FeedbackEmailService.sendText(type: _type, description: text);
      if (!mounted) return;
      Navigator.pop(context);
      messenger.showSnackBar(SnackBar(content: Text(loc.feedbackSentThanks)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _sending = false);
      messenger.showSnackBar(SnackBar(content: Text(loc.feedbackSentError)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return GlassmorphicDialog(
      title: Text(loc.send_feedback),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(loc.send_feedback_desc),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: Text(loc.feedbackTypeBug),
                selected: _type == 'bug',
                onSelected: (_) => setState(() => _type = 'bug'),
              ),
              ChoiceChip(
                label: Text(loc.feedbackTypeSuggestion),
                selected: _type == 'suggestion',
                onSelected: (_) => setState(() => _type = 'suggestion'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            minLines: 3,
            maxLines: 6,
            maxLength: 1000,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: FontConstants.fontFamily,
            ),
            decoration: InputDecoration(
              hintText: loc.feedbackHint,
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.08),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              counterStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _sending ? null : () => Navigator.pop(context),
          child: Text(loc.cancel),
        ),
        TextButton(
          onPressed: _sending ? null : _send,
          child: _sending
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(loc.feedbackSend),
        ),
      ],
    );
  }
}
