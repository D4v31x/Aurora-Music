import 'dart:ui';

import 'package:aurora_music_v01/core/constants/font_constants.dart';
import 'package:flutter/material.dart';

/// Glassmorphic dialog with BackdropFilter blur.
class GlassmorphicDialog extends StatelessWidget {
  final Widget? title;
  final Widget? content;
  final List<Widget>? actions;
  final EdgeInsetsGeometry? contentPadding;
  final EdgeInsetsGeometry? actionsPadding;
  final double borderRadius;

  /// Sigma value for the backdrop blur filter.
  final double blur;

  const GlassmorphicDialog({
    super.key,
    this.title,
    this.content,
    this.actions,
    this.contentPadding,
    this.actionsPadding,
    this.borderRadius = 28,
    this.blur = 25,
  });

  @override
  Widget build(BuildContext context) {
    final dialogContent = DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: DefaultTextStyle(
                style: const TextStyle(
                  fontFamily: FontConstants.fontFamily,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
                child: title!,
              ),
            ),
          if (content != null)
            Padding(
              padding:
                  contentPadding ?? const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: DefaultTextStyle(
                style: TextStyle(
                  fontFamily: FontConstants.fontFamily,
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: Colors.white.withOpacity(0.8),
                ),
                child: content!,
              ),
            ),
          if (actions != null && actions!.isNotEmpty)
            Padding(
              padding:
                  actionsPadding ?? const EdgeInsets.fromLTRB(16, 24, 16, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: actions!,
              ),
            ),
        ],
      ),
    );

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: dialogContent,
        ),
      ),
    );
  }
}

/// A glassmorphic popup menu theme data
PopupMenuThemeData glassmorphicPopupMenuTheme() {
  return PopupMenuThemeData(
    color: Colors.transparent,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
    ),
  );
}

/// A glassmorphic popup menu item builder
Widget buildGlassmorphicPopupMenu<T>({
  required List<PopupMenuEntry<T>> items,
  required void Function(T) onSelected,
  required Widget child,
  double blur = 25,
  double borderRadius = 20,
}) {
  return PopupMenuButton<T>(
    onSelected: onSelected,
    color: Colors.transparent,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(borderRadius),
    ),
    itemBuilder: (context) => items,
    child: child,
  );
}

/// Glassmorphic popup menu button with BackdropFilter blur.
class GlassmorphicPopupMenuButton<T> extends StatelessWidget {
  final List<PopupMenuEntry<T>> Function(BuildContext) itemBuilder;
  final void Function(T)? onSelected;
  final Widget? child;
  final Widget? icon;
  final double borderRadius;

  /// Sigma value for the backdrop blur filter.
  final double blur;

  final Offset offset;
  final Color? iconColor;
  final double? iconSize;

  const GlassmorphicPopupMenuButton({
    super.key,
    required this.itemBuilder,
    this.onSelected,
    this.child,
    this.icon,
    this.borderRadius = 20,
    this.blur = 25,
    this.offset = Offset.zero,
    this.iconColor,
    this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    final menuDecoration = BoxDecoration(
      color: Colors.white.withOpacity(0.1),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: Colors.white.withOpacity(0.2),
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.25),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ],
    );

    return PopupMenuButton<T>(
      onSelected: onSelected,
      offset: offset,
      color: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      popUpAnimationStyle: const AnimationStyle(
        duration: Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
      ),
      itemBuilder: (context) {
        final items = itemBuilder(context);

        final menuContent = DecoratedBox(
          decoration: menuDecoration,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: items.map((item) {
              if (item is PopupMenuItem<T>) {
                return InkWell(
                  onTap: () {
                    Navigator.of(context).pop(item.value);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: item.child,
                );
              }
              return const SizedBox.shrink();
            }).toList(),
          ),
        );

        return [
          PopupMenuItem<T>(
            enabled: false,
            padding: EdgeInsets.zero,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(borderRadius),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                child: menuContent,
              ),
            ),
          ),
        ];
      },
      icon: icon,
      iconColor: iconColor,
      iconSize: iconSize,
      child: child,
    );
  }
}

/// Show a glassmorphic dialog
Future<T?> showGlassmorphicDialog<T>({
  required BuildContext context,
  required Widget Function(BuildContext) builder,
  bool barrierDismissible = true,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: Colors.black54,
    builder: builder,
  );
}

/// Glassmorphic modal bottom sheet with BackdropFilter blur.
Future<T?> showGlassmorphicBottomSheet<T>({
  required BuildContext context,
  required Widget Function(BuildContext) builder,
  bool isDismissible = true,
  bool enableDrag = true,
  double borderRadius = 28,

  /// Sigma value for the backdrop blur filter.
  double blur = 25,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black54,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(borderRadius)),
    ),
    builder: (context) {
      return ClipRRect(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(borderRadius)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(borderRadius)),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 24,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: builder(context),
          ),
        ),
      );
    },
  );
}

/// A glassmorphic text button for use in dialogs
class GlassmorphicTextButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final bool isPrimary;

  const GlassmorphicTextButton({
    super.key,
    this.onPressed,
    required this.child,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor:
            isPrimary ? Theme.of(context).colorScheme.primary : Colors.white70,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: DefaultTextStyle(
        style: TextStyle(
          fontFamily: FontConstants.fontFamily,
          fontSize: 15,
          fontWeight: isPrimary ? FontWeight.w600 : FontWeight.w500,
        ),
        child: child,
      ),
    );
  }
}

