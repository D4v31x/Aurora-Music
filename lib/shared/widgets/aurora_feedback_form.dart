import 'package:aurora_music_v01/core/constants/font_constants.dart';
import 'package:feedback/feedback.dart';
import 'package:flutter/material.dart';

/// Custom feedback form panel shown at the bottom of the BetterFeedback
/// screenshot overlay. The package's built-in left-column controls handle
/// draw / navigate mode switching and colour selection automatically.
Widget auroraFeedbackForm(
  BuildContext context,
  OnSubmit onSubmit,
  ScrollController? scrollController,
) =>
    _AuroraFeedbackForm(
        onSubmit: onSubmit, scrollController: scrollController);

class _AuroraFeedbackForm extends StatefulWidget {
  final OnSubmit onSubmit;
  final ScrollController? scrollController;

  const _AuroraFeedbackForm({required this.onSubmit, this.scrollController});

  @override
  State<_AuroraFeedbackForm> createState() => _AuroraFeedbackFormState();
}

class _AuroraFeedbackFormState extends State<_AuroraFeedbackForm> {
  final _textController = TextEditingController();

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    widget.onSubmit(text);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1C1B1F),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            14,
            16,
            MediaQuery.of(context).viewInsets.bottom + 14,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Hint label ────────────────────────────────────────────
              Text(
                'Annotate the screenshot above, then describe the issue or idea.',
                style: TextStyle(
                  fontFamily: FontConstants.fontFamily,
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.45),
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 10),

              // ── Text field ────────────────────────────────────────────
              TextField(
                controller: _textController,
                scrollController: widget.scrollController,
                minLines: 3,
                maxLines: 5,
                autofocus: false,
                style: const TextStyle(
                  fontFamily: FontConstants.fontFamily,
                  color: Colors.white,
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  hintText: 'Describe the issue or idea…',
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
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.18),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ── Actions row ───────────────────────────────────────────
              Row(
                children: [
                  TextButton(
                    onPressed: () => BetterFeedback.of(context).hide(),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white.withValues(alpha: 0.45),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(fontFamily: FontConstants.fontFamily),
                    ),
                  ),
                  const Spacer(),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _textController,
                    builder: (_, value, __) => FilledButton(
                      onPressed: value.text.trim().isEmpty ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF7C3AED),
                        disabledBackgroundColor:
                            Colors.white.withValues(alpha: 0.1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 12,
                        ),
                      ),
                      child: const Text(
                        'Submit',
                        style: TextStyle(
                          fontFamily: FontConstants.fontFamily,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
