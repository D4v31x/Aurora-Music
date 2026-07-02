import 'package:aurora_music_v01/core/constants/font_constants.dart';
import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../services/feedback_email_service.dart';
import '../services/feedback_reminder_service.dart';
import 'glassmorphic_dialog.dart';

enum _Sentiment { love, missing, broken }

extension on _Sentiment {
  /// English label used for Sentry descriptions (internal, not shown in UI).
  String get label => switch (this) {
        _Sentiment.love => 'Love it',
        _Sentiment.missing => "Something's missing",
        _Sentiment.broken => "Something's broken",
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

/// Feedback dialog shown once after 7+ days of use.
///
/// Call [FeedbackPopupWidget.showIfNeeded] from your post-launch hook;
/// it delegates to [FeedbackReminderService] for all persistence logic.
class FeedbackPopupWidget extends StatefulWidget {
  const FeedbackPopupWidget({super.key});

  /// Shows the dialog unconditionally — use from Settings where the user
  /// explicitly tapped the button.
  static Future<void> show(BuildContext context) {
    return showGlassmorphicDialog<void>(
      context: context,
      builder: (_) => const FeedbackPopupWidget(),
    );
  }

  /// Shows the dialog only when [FeedbackReminderService] decides the time
  /// is right (7+ days active, not permanently dismissed, etc.).
  static Future<void> showIfNeeded(BuildContext context) async {
    final shouldShow = await FeedbackReminderService.shouldShowFeedbackPrompt();
    if (!shouldShow || !context.mounted) return;
    await FeedbackReminderService.recordPromptShown();
    if (!context.mounted) return;
    await show(context);
  }

  @override
  State<FeedbackPopupWidget> createState() => _FeedbackPopupWidgetState();
}

class _FeedbackPopupWidgetState extends State<FeedbackPopupWidget>
    with SingleTickerProviderStateMixin {
  _Sentiment? _selected;
  final _textController = TextEditingController();
  bool _submitting = false;
  late final AnimationController _enterAnim;
  late final Animation<double> _opacity;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _enterAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..forward();
    _opacity = CurvedAnimation(parent: _enterAnim, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _enterAnim, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _enterAnim.dispose();
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
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    return FadeTransition(
      opacity: _opacity,
      child: ScaleTransition(
        scale: _scale,
        child: GlassmorphicDialog(
          title: _FeedbackHeader(colorScheme: colorScheme, l10n: l10n),
          contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final s in _Sentiment.values) ...[
                _SentimentTile(
                  sentiment: s,
                  isSelected: _selected == s,
                  onTap: () => setState(() => _selected = s),
                  l10n: l10n,
                  colorScheme: colorScheme,
                ),
                if (s != _Sentiment.broken) const SizedBox(height: 8),
              ],
              // Optional detail field — slides in after a sentiment is picked
              AnimatedSize(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                child: _selected == null
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: TextField(
                          controller: _textController,
                          minLines: 2,
                          maxLines: 4,
                          style: const TextStyle(
                            fontFamily: FontConstants.fontFamily,
                            color: Colors.white,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            hintText: l10n.feedbackHint,
                            hintStyle: TextStyle(
                              fontFamily: FontConstants.fontFamily,
                              color: Colors.white.withValues(alpha: 0.35),
                              fontSize: 14,
                            ),
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.07),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: colorScheme.primary
                                    .withValues(alpha: 0.65),
                              ),
                            ),
                          ),
                        ),
                      ),
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          actions: [
            GlassmorphicTextButton(
              onPressed: _submitting ? null : _dismissPermanently,
              child: Text(l10n.dontShowAgain),
            ),
            GlassmorphicTextButton(
              isPrimary: true,
              onPressed: (_selected != null && !_submitting) ? _submit : null,
              child: _submitting
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation(colorScheme.primary),
                      ),
                    )
                  : Text(l10n.feedbackSend),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _FeedbackHeader extends StatelessWidget {
  final ColorScheme colorScheme;
  final AppLocalizations l10n;

  const _FeedbackHeader({required this.colorScheme, required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.music_note_rounded,
            color: colorScheme.primary,
            size: 22,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.feedbackHeaderTitle,
                style: const TextStyle(
                  fontFamily: FontConstants.fontFamily,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                l10n.feedbackHeaderSubtitle,
                style: TextStyle(
                  fontFamily: FontConstants.fontFamily,
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: Colors.white.withValues(alpha: 0.55),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Sentiment tile ────────────────────────────────────────────────────────────

class _SentimentTile extends StatelessWidget {
  final _Sentiment sentiment;
  final bool isSelected;
  final VoidCallback onTap;
  final AppLocalizations l10n;
  final ColorScheme colorScheme;

  const _SentimentTile({
    required this.sentiment,
    required this.isSelected,
    required this.onTap,
    required this.l10n,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: isSelected
            ? colorScheme.primaryContainer.withValues(alpha: 0.22)
            : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected
              ? colorScheme.primary.withValues(alpha: 0.55)
              : Colors.white.withValues(alpha: 0.08),
          width: isSelected ? 1.5 : 1.0,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          splashColor: colorScheme.primary.withValues(alpha: 0.10),
          highlightColor: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                // Icon in a small rounded container
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? colorScheme.primary.withValues(alpha: 0.18)
                        : Colors.white.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    sentiment.icon,
                    color: isSelected
                        ? colorScheme.primary
                        : Colors.white.withValues(alpha: 0.45),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    sentiment.localizedLabel(l10n),
                    style: TextStyle(
                      fontFamily: FontConstants.fontFamily,
                      fontSize: 14,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.72),
                    ),
                  ),
                ),
                AnimatedOpacity(
                  opacity: isSelected ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.check_circle_rounded,
                    color: colorScheme.primary,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

