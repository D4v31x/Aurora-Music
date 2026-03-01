/// Frosted-glass dialog widget with BackdropFilter blur.
///
/// A reusable dialog styled with Colors.white.withOpacity(0.1),
/// a white border, and a soft box shadow — with real backdrop blur.
library;

import 'dart:ui';

import 'package:flutter/material.dart';

// MARK: - Constants

const double _kDefaultBlur = 10.0;
const double _kDefaultBorderRadius = 20.0;
const double _kDefaultBorderOpacity = 0.2;

// MARK: - Blur Dialog

/// A dialog with a frosted-glass appearance backed by a real BackdropFilter blur.
///
/// Features:
/// - Configurable content and actions
/// - Consistent styling across the app
///
/// Usage:
/// ```dart
/// showDialog(
///   context: context,
///   builder: (context) => BlurDialog(
///     title: 'Dialog Title',
///     content: Text('Dialog content'),
///     actions: [
///       TextButton(onPressed: () {}, child: Text('OK')),
///     ],
///   ),
/// );
/// ```
class BlurDialog extends StatelessWidget {
  /// Title widget for the dialog.
  final Widget? title;

  /// Content widget for the dialog.
  final Widget content;

  /// Action buttons for the dialog.
  final List<Widget>? actions;

  /// Sigma value for the backdrop blur filter.
  final double blur;

  /// Background color of the dialog.
  final Color? backgroundColor;

  /// Border radius of the dialog.
  final double borderRadius;

  /// Whether to show the close button.
  final bool showCloseButton;

  /// Optional maximum width constraint.
  final double? maxWidth;

  const BlurDialog({
    super.key,
    this.title,
    required this.content,
    this.actions,
    this.blur = _kDefaultBlur,
    this.backgroundColor,
    this.borderRadius = _kDefaultBorderRadius,
    this.showCloseButton = false,
    this.maxWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth ?? MediaQuery.of(context).size.width * 0.9,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
            child: Container(
              decoration: BoxDecoration(
                color: backgroundColor ?? Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(borderRadius),
                border: Border.all(
                  color: Colors.white.withOpacity(_kDefaultBorderOpacity),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (title != null) _buildTitleSection(context),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      child: content,
                    ),
                  ),
                  if (actions != null && actions!.isNotEmpty)
                    _buildActionsSection(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTitleSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (title != null) Expanded(child: title!),
          if (showCloseButton)
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white70),
              onPressed: () => Navigator.of(context).pop(),
            ),
        ],
      ),
    );
  }

  Widget _buildActionsSection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: actions!,
      ),
    );
  }
}

// MARK: - Show Blur Dialog Helper

/// Shows a solid-glass dialog with the given configuration.
Future<T?> showBlurDialog<T>({
  required BuildContext context,
  Widget? title,
  required Widget content,
  List<Widget>? actions,
  bool barrierDismissible = true,
  double blur = _kDefaultBlur,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (context) => BlurDialog(
      title: title,
      content: content,
      actions: actions,
      blur: blur,
    ),
  );
}
