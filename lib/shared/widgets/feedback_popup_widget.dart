import 'dart:ui';

import 'package:aurora_music_v01/core/constants/font_constants.dart';
import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../services/feedback_email_service.dart';
import '../services/feedback_reminder_service.dart';

enum _Sentiment { love, missing, broken }

extension on _Sentiment {
  /// English label used for Sentry descriptions (internal, not shown in UI).
  String get label => switch (this) {
        _Sentiment.love => 'Love it',
        _Sentiment.missing => 'Something\'s missing',
        _Sentiment.broken => 'Something\'s broken',
      };

  String localizedLabel(AppLocalizations l10n) => switch (this) {
        _Sentiment.love => l10n.feedbackLove,
        _Sentiment.missing => l10n.feedbackMissing,
        _Sentiment.broken => l10n.feedbackBroken,
      };

  IconData get icon => switch (this) {
        _Sentiment.love => Icons.favorite_rounded,
        _Sentiment.missing => Icons.search_rounded,
        _Sentiment.broken => Icons.bug_report_rounded,
      };

  /// Type tag sent to Sentry
  String get tag => switch (this) {
        _Sentiment.love => 'Positive',
        _Sentiment.missing => 'Feature Request',
        _Sentiment.broken => 'Bug Report',
      };
}

/// Full-screen feedback popup shown once after 7+ days of use.
///
/// Call [FeedbackPopupWidget.showIfNeeded] from your post-launch hook;
/// it delegates to [FeedbackReminderService] for all persistence logic.
class FeedbackPopupWidget extends StatefulWidget {
  const FeedbackPopupWidget({super.key});

  /// Shows the popup unconditionally — use from Settings where the user
  /// explicitly tapped the button.
  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => const FeedbackPopupWidget(),
    );
  }

  /// Shows the popup only when [FeedbackReminderService] decides the time
  /// is right (7+ days active, not permanently dismissed, etc.).
  static Future<void> showIfNeeded(BuildContext context) async {
    final shouldShow = await FeedbackReminderService.shouldShowFeedbackPrompt();
    if (!shouldShow || !context.mounted) return;
    await FeedbackReminderService.recordPromptShown();
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => const FeedbackPopupWidget(),
    );
  }

  @override
  State<FeedbackPopupWidget> createState() => _FeedbackPopupWidgetState();
}

class _FeedbackPopupWidgetState extends State<FeedbackPopupWidget>
    with SingleTickerProviderStateMixin {
  _Sentiment? _selected;
  final _textController = TextEditingController();
  bool _submitting = false;
  late final AnimationController _fadeIn;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _fadeIn = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    )..forward();
    _opacity = CurvedAnimation(parent: _fadeIn, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _fadeIn.dispose();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selected == null || _submitting) return;
    setState(() => _submitting = true);

    final extra = _textController.text.trim();
    final message =
        extra.isEmpty ? _selected!.label : '${_selected!.label} — $extra';

    try {
      await FeedbackEmailService.sendText(
        type: _selected!.tag,
        description: message,
      );
    } catch (_) {
      // Swallow — user has already provided their response; don't block close.
    }

    await FeedbackReminderService.dismissPermanently();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _dismissPermanently() async {
    await FeedbackReminderService.dismissPermanently();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
              child: Material(
                type: MaterialType.transparency,
                child: _PopupCard(
                  selected: _selected,
                  textController: _textController,
                  submitting: _submitting,
                  onSentimentTapped: (s) => setState(() => _selected = s),
                  onSubmit: _submit,
                  onDismiss: _dismissPermanently,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Card body ────────────────────────────────────────────────────────────────

class _PopupCard extends StatelessWidget {
  final _Sentiment? selected;
  final TextEditingController textController;
  final bool submitting;
  final ValueChanged<_Sentiment> onSentimentTapped;
  final VoidCallback onSubmit;
  final VoidCallback onDismiss;

  static const _accent = Color(0xFF6C63FF);

  const _PopupCard({
    required this.selected,
    required this.textController,
    required this.submitting,
    required this.onSentimentTapped,
    required this.onSubmit,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF1C1B1F).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────
            Text(
              AppLocalizations.of(context).feedbackHeaderTitle,
              style: const TextStyle(
                fontFamily: FontConstants.fontFamily,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context).feedbackHeaderSubtitle,
              style: TextStyle(
                fontFamily: FontConstants.fontFamily,
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.6),
                height: 1.5,
              ),
            ),

            const SizedBox(height: 24),

            // ── Sentiment options ────────────────────────────────────────
            for (final s in _Sentiment.values) ...[
              _SentimentTile(
                sentiment: s,
                isSelected: selected == s,
                onTap: () => onSentimentTapped(s),
              ),
              if (s != _Sentiment.broken) const SizedBox(height: 10),
            ],

            // ── Optional text field ──────────────────────────────────────
            AnimatedSize(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeInOut,
              child: selected == null
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: TextField(
                        controller: textController,
                        minLines: 2,
                        maxLines: 4,
                        style: const TextStyle(
                          fontFamily: FontConstants.fontFamily,
                          color: Colors.white,
                          fontSize: 14,
                        ),
                        decoration: InputDecoration(
                          hintText: AppLocalizations.of(context).feedbackHint,
                          hintStyle: TextStyle(
                            fontFamily: FontConstants.fontFamily,
                            color: Colors.white.withValues(alpha: 0.3),
                            fontSize: 14,
                          ),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.06),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: _accent.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                      ),
                    ),
            ),

            const SizedBox(height: 22),

            // ── Submit button ────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: (selected != null && !submitting) ? onSubmit : null,
                style: FilledButton.styleFrom(
                  backgroundColor: _accent,
                  disabledBackgroundColor: Colors.white.withValues(alpha: 0.08),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: submitting
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      )
                    : Text(
                        AppLocalizations.of(context).feedbackSend,
                        style: const TextStyle(
                          fontFamily: FontConstants.fontFamily,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),

            // ── Don't show again ─────────────────────────────────────────
            Align(
              child: TextButton(
                onPressed: submitting ? null : onDismiss,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white.withValues(alpha: 0.35),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  AppLocalizations.of(context).dontShowAgain,
                  style: const TextStyle(
                    fontFamily: FontConstants.fontFamily,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sentiment tile ───────────────────────────────────────────────────────────

class _SentimentTile extends StatelessWidget {
  final _Sentiment sentiment;
  final bool isSelected;
  final VoidCallback onTap;

  static const _accent = Color(0xFF6C63FF);

  const _SentimentTile({
    required this.sentiment,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: isSelected
            ? _accent.withValues(alpha: 0.16)
            : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected
              ? _accent.withValues(alpha: 0.7)
              : Colors.white.withValues(alpha: 0.10),
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        splashColor: _accent.withValues(alpha: 0.12),
        highlightColor: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(
                sentiment.icon,
                color: isSelected ? _accent : Colors.white.withValues(alpha: 0.5),
                size: 20,
              ),
              const SizedBox(width: 14),
              Text(
                sentiment.localizedLabel(AppLocalizations.of(context)),
                style: TextStyle(
                  fontFamily: FontConstants.fontFamily,
                  fontSize: 15,
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.75),
                ),
              ),
              const Spacer(),
              AnimatedOpacity(
                opacity: isSelected ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 180),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: _accent,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
