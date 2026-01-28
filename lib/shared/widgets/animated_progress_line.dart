import 'package:flutter/material.dart';

/// An animated underline that shows below content when progress is active.
/// The line animates with a "roaming" white segment effect for indeterminate progress,
/// or shows a deterministic fill progress bar when [determinateProgress] is provided.
class AnimatedProgressLine extends StatefulWidget {
  final Widget child;
  final bool isAnimating;
  final Color lineColor;
  final double lineHeight;
  final double lineWidth;
  final Duration animationDuration;

  /// If provided (0.0 to 1.0), shows a deterministic progress bar instead of indeterminate animation.
  /// When >= 1.0, the line turns green to indicate ready state.
  final double? determinateProgress;

  const AnimatedProgressLine({
    super.key,
    required this.child,
    this.isAnimating = false,
    this.lineColor = Colors.white,
    this.lineHeight = 2.0,
    this.lineWidth = 120.0,
    this.animationDuration = const Duration(milliseconds: 1800),
    this.determinateProgress,
  });

  @override
  State<AnimatedProgressLine> createState() => _AnimatedProgressLineState();
}

class _AnimatedProgressLineState extends State<AnimatedProgressLine>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    );

    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );

    if (widget.isAnimating && widget.determinateProgress == null) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(AnimatedProgressLine oldWidget) {
    super.didUpdateWidget(oldWidget);
    final shouldAnimate =
        widget.isAnimating && widget.determinateProgress == null;
    final wasAnimating =
        oldWidget.isAnimating && oldWidget.determinateProgress == null;

    if (shouldAnimate != wasAnimating) {
      if (shouldAnimate) {
        _controller.repeat();
      } else {
        _controller.stop();
        _controller.reset();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _shouldShowLine =>
      widget.isAnimating ||
      (widget.determinateProgress != null && widget.determinateProgress! > 0);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        widget.child,
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: _shouldShowLine
              ? Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: widget.determinateProgress != null
                      ? _buildDeterminateProgress()
                      : AnimatedBuilder(
                          animation: _animation,
                          builder: (context, child) {
                            return CustomPaint(
                              size: Size(widget.lineWidth, widget.lineHeight),
                              painter: _ProgressLinePainter(
                                progress: _animation.value,
                                lineColor: widget.lineColor,
                                lineHeight: widget.lineHeight,
                              ),
                            );
                          },
                        ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildDeterminateProgress() {
    final progress = widget.determinateProgress!.clamp(0.0, 1.0);
    final isReady = progress >= 1.0;

    return CustomPaint(
      size: Size(widget.lineWidth, widget.lineHeight),
      painter: _DeterminateProgressPainter(
        progress: progress,
        lineColor: isReady ? Colors.greenAccent : widget.lineColor,
        lineHeight: widget.lineHeight,
      ),
    );
  }
}

class _ProgressLinePainter extends CustomPainter {
  final double progress;
  final Color lineColor;
  final double lineHeight;

  _ProgressLinePainter({
    required this.progress,
    required this.lineColor,
    required this.lineHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;

    // Draw the background line (faded)
    final bgPaint = Paint()
      ..color = lineColor.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = lineHeight
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(0, y),
      Offset(size.width, y),
      bgPaint,
    );

    // Animation cycle:
    // 0.0 - 0.25: Fill from left to right
    // 0.25 - 0.5: Empty from left to right
    // 0.5 - 0.75: Fill from right to left
    // 0.75 - 1.0: Empty from right to left

    final phase = (progress * 4) % 4;
    double startX, endX;

    if (phase < 1.0) {
      // Phase 1: Fill from left to right
      startX = 0;
      endX = size.width * phase;
    } else if (phase < 2.0) {
      // Phase 2: Empty from left to right
      startX = size.width * (phase - 1.0);
      endX = size.width;
    } else if (phase < 3.0) {
      // Phase 3: Fill from right to left
      startX = size.width * (1.0 - (phase - 2.0));
      endX = size.width;
    } else {
      // Phase 4: Empty from right to left
      startX = 0;
      endX = size.width * (1.0 - (phase - 3.0));
    }

    // Draw the filled portion
    if (endX > startX) {
      final fillPaint = Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = lineHeight
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(
        Offset(startX, y),
        Offset(endX, y),
        fillPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_ProgressLinePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.lineColor != lineColor;
  }
}

/// Painter for deterministic progress (0.0 to 1.0 fill from left to right)
class _DeterminateProgressPainter extends CustomPainter {
  final double progress;
  final Color lineColor;
  final double lineHeight;

  _DeterminateProgressPainter({
    required this.progress,
    required this.lineColor,
    required this.lineHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;

    // Draw the background line (faded)
    final bgPaint = Paint()
      ..color = lineColor.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = lineHeight
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(0, y),
      Offset(size.width, y),
      bgPaint,
    );

    // Draw the filled portion from left to right
    if (progress > 0) {
      final fillPaint = Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = lineHeight
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(
        Offset(0, y),
        Offset(size.width * progress, y),
        fillPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_DeterminateProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.lineColor != lineColor;
  }
}
