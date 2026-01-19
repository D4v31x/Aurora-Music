import 'dart:async';
import 'package:aurora_music_v01/constants/font_constants.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/performance_mode_provider.dart';

/// A global toast notification manager that shows pill-shaped notifications
/// at the bottom of the screen, above the mini player.
class ToastNotification {
  static final ToastNotification _instance = ToastNotification._internal();
  factory ToastNotification() => _instance;
  ToastNotification._internal();

  static OverlayEntry? _currentOverlay;
  static Timer? _hideTimer;
  static final GlobalKey<_ToastWidgetState> _toastKey = GlobalKey();

  /// Show a toast notification
  static void show(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
    IconData? icon,
    bool isProgress = false,
  }) {
    // If there's an existing toast, update it instead of creating a new one
    if (_currentOverlay != null && _toastKey.currentState != null) {
      _toastKey.currentState!
          .updateMessage(message, icon: icon, isProgress: isProgress);
      _resetTimer(duration, isProgress);
      return;
    }

    // Remove any existing overlay
    hide();

    final overlay = Overlay.of(context);

    // Check if blur should be enabled based on performance mode
    final performanceProvider =
        Provider.of<PerformanceModeProvider>(context, listen: false);
    final shouldBlur = performanceProvider.shouldEnableBlur;

    _currentOverlay = OverlayEntry(
      builder: (context) => _ToastWidget(
        key: _toastKey,
        message: message,
        icon: icon,
        isProgress: isProgress,
        onDismiss: hide,
        shouldBlur: shouldBlur,
      ),
    );

    overlay.insert(_currentOverlay!);
    _resetTimer(duration, isProgress);
  }

  static void _resetTimer(Duration duration, bool isProgress) {
    _hideTimer?.cancel();
    if (!isProgress) {
      _hideTimer = Timer(duration, () {
        hide();
      });
    }
  }

  /// Hide the current toast
  static void hide() {
    _hideTimer?.cancel();
    _hideTimer = null;
    if (_currentOverlay != null) {
      _toastKey.currentState?.dismiss();
      Future.delayed(const Duration(milliseconds: 300), () {
        _currentOverlay?.remove();
        _currentOverlay = null;
      });
    }
  }

  /// Check if a toast is currently showing
  static bool get isShowing => _currentOverlay != null;
}

class _ToastWidget extends StatefulWidget {
  final String message;
  final IconData? icon;
  final bool isProgress;
  final VoidCallback onDismiss;
  final bool shouldBlur;

  const _ToastWidget({
    super.key,
    required this.message,
    this.icon,
    this.isProgress = false,
    required this.onDismiss,
    this.shouldBlur = true,
  });

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  String _message = '';
  IconData? _icon;
  bool _isProgress = false;

  @override
  void initState() {
    super.initState();
    _message = widget.message;
    _icon = widget.icon;
    _isProgress = widget.isProgress;

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void updateMessage(String message,
      {IconData? icon, bool isProgress = false}) {
    setState(() {
      _message = message;
      _icon = icon;
      _isProgress = isProgress;
    });
  }

  void dismiss() {
    _animationController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    // Position above mini player (approximately 100dp from bottom)
    final bottomPadding = MediaQuery.of(context).padding.bottom + 120;
    final colorScheme = Theme.of(context).colorScheme;

    // Use solid surface colors for lowend devices
    final BoxDecoration toastDecoration;
    if (widget.shouldBlur) {
      toastDecoration = BoxDecoration(
        color: Colors.grey[900]?.withOpacity(0.85),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: Colors.white.withOpacity(0.15),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 5),
          ),
        ],
      );
    } else {
      // Solid toast styling for lowend devices
      toastDecoration = BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: colorScheme.outlineVariant.withOpacity(0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      );
    }

    final toastContent = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 14,
      ),
      decoration: toastDecoration,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isProgress) ...[
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            const SizedBox(width: 12),
          ] else if (_icon != null) ...[
            Icon(
              _icon,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
          ],
          Flexible(
            child: Text(
              _message,
              style: const TextStyle(
                fontFamily: FontConstants.fontFamily,
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                decoration: TextDecoration.none,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );

    return Positioned(
      left: 24,
      right: 24,
      bottom: bottomPadding,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: GestureDetector(
            onTap: widget.onDismiss,
            onHorizontalDragEnd: (details) {
              if (details.primaryVelocity != null &&
                  details.primaryVelocity!.abs() > 100) {
                widget.onDismiss();
              }
            },
            child: Center(
              child: RepaintBoundary(
                child: widget.shouldBlur
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(30),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                          child: toastContent,
                        ),
                      )
                    : toastContent,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
