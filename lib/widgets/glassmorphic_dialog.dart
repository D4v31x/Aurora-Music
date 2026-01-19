import 'dart:ui';
import 'package:aurora_music_v01/constants/font_constants.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/performance_mode_provider.dart';

/// A glassmorphic dialog with blur effect and rounded corners.
/// Performance-aware: Respects device performance mode for blur effects.
class GlassmorphicDialog extends StatelessWidget {
  final Widget? title;
  final Widget? content;
  final List<Widget>? actions;
  final EdgeInsetsGeometry? contentPadding;
  final EdgeInsetsGeometry? actionsPadding;
  final double borderRadius;
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
    // Check if blur should be enabled based on performance mode
    final performanceProvider =
        Provider.of<PerformanceModeProvider>(context, listen: false);
    final shouldBlur = performanceProvider.shouldEnableBlur;
    final colorScheme = Theme.of(context).colorScheme;

    // Use solid surface colors for lowend devices
    final BoxDecoration containerDecoration;
    if (shouldBlur) {
      containerDecoration = BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.15),
            Colors.white.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
        ),
      );
    } else {
      // Solid dialog styling for lowend devices
      containerDecoration = BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: colorScheme.outlineVariant,
          width: 1,
        ),
      );
    }

    final dialogContent = DecoratedBox(
      decoration: containerDecoration,
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
                  color: shouldBlur
                      ? Colors.white.withValues(alpha: 0.8)
                      : colorScheme.onSurface,
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
      child: RepaintBoundary(
        child: shouldBlur
            ? ClipRRect(
                borderRadius: BorderRadius.circular(borderRadius),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                  child: dialogContent,
                ),
              )
            : ClipRRect(
                borderRadius: BorderRadius.circular(borderRadius),
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

/// Custom popup menu that wraps content in glassmorphic container
/// Performance-aware: Respects device performance mode for blur effects.
class GlassmorphicPopupMenuButton<T> extends StatelessWidget {
  final List<PopupMenuEntry<T>> Function(BuildContext) itemBuilder;
  final void Function(T)? onSelected;
  final Widget? child;
  final Widget? icon;
  final double borderRadius;
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
    // Check if blur should be enabled based on performance mode
    final performanceProvider =
        Provider.of<PerformanceModeProvider>(context, listen: false);
    final shouldBlur = performanceProvider.shouldEnableBlur;
    final colorScheme = Theme.of(context).colorScheme;

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

        // Use solid surface colors for lowend devices
        final BoxDecoration menuDecoration;
        if (shouldBlur) {
          menuDecoration = BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.15),
                Colors.white.withValues(alpha: 0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
            ),
          );
        } else {
          // Solid menu styling for lowend devices
          menuDecoration = BoxDecoration(
            color: colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: colorScheme.outlineVariant.withOpacity(0.3),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          );
        }

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
            child: RepaintBoundary(
              child: shouldBlur
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(borderRadius),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                        child: menuContent,
                      ),
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(borderRadius),
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

/// Show a glassmorphic modal bottom sheet
/// Performance-aware: Respects device performance mode for blur effects.
Future<T?> showGlassmorphicBottomSheet<T>({
  required BuildContext context,
  required Widget Function(BuildContext) builder,
  bool isDismissible = true,
  bool enableDrag = true,
  double borderRadius = 28,
  double blur = 25,
}) {
  // Check if blur should be enabled based on performance mode
  final performanceProvider =
      Provider.of<PerformanceModeProvider>(context, listen: false);
  final shouldBlur = performanceProvider.shouldEnableBlur;
  final colorScheme = Theme.of(context).colorScheme;

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
      // Use solid surface colors for lowend devices
      final BoxDecoration sheetDecoration;
      if (shouldBlur) {
        sheetDecoration = BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.15),
              Colors.white.withValues(alpha: 0.05),
            ],
          ),
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(borderRadius)),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
          ),
        );
      } else {
        // Solid bottom sheet styling for lowend devices
        sheetDecoration = BoxDecoration(
          color: colorScheme.surfaceContainerHigh,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(borderRadius)),
          border: Border.all(
            color: colorScheme.outlineVariant.withOpacity(0.3),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        );
      }

      final sheetContent = DecoratedBox(
        decoration: sheetDecoration,
        child: builder(context),
      );

      return RepaintBoundary(
        child: shouldBlur
            ? ClipRRect(
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(borderRadius)),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                  child: sheetContent,
                ),
              )
            : ClipRRect(
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(borderRadius)),
                child: sheetContent,
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
