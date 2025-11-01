import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:provider/provider.dart';

import '../services/expandable_player_controller.dart';
import '../constants/animation_constants.dart';

class ExpandableBottomSheet extends StatefulWidget {
  final Widget minChild;
  final Widget maxChild;
  final double minHeight;

  const ExpandableBottomSheet({
    super.key,
    required this.minChild,
    required this.maxChild,
    this.minHeight = 60.0,
  });

  @override
  State<ExpandableBottomSheet> createState() => ExpandableBottomSheetState();
}

class ExpandableBottomSheetState extends State<ExpandableBottomSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _heightFactor;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AnimationConstants.playerExpand,
    );
    _heightFactor = CurvedAnimation(
      parent: _controller,
      curve: AnimationConstants.playerExpandCurve,
      reverseCurve: AnimationConstants.playerCollapseCurve,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get isExpanded => _controller.value == 1.0;

  Future<void> collapse() async {
    if (!mounted) return;
    await _controller.animateTo(
      0.0,
      duration: AnimationConstants.playerCollapse,
      curve: AnimationConstants.playerCollapseCurve,
    );
  }

  Future<void> expand() async {
    if (!mounted) return;
    await _controller.animateTo(
      1.0,
      duration: AnimationConstants.playerExpand,
      curve: AnimationConstants.playerExpandCurve,
    );
  }

  void _handleDragEnd(
      DragEndDetails details, double screenHeight, double minHeightWithMargin) {
    if (!mounted || _controller.isAnimating) return;

    final velocity = details.velocity.pixelsPerSecond.dy /
        (screenHeight - minHeightWithMargin);
    final spring = SpringDescription(
      mass: 1.0,
      stiffness: 500.0,
      damping: 30.0,
    );

    // Use velocity-based spring simulation for natural feel
    if (velocity.abs() > 0.5) {
      final simulation = SpringSimulation(
        spring,
        _controller.value,
        velocity > 0 ? 0.0 : 1.0,
        -velocity,
      );
      _controller.animateWith(simulation);

      if (velocity > 0) {
        Provider.of<ExpandablePlayerController>(context, listen: false)
            .collapse();
      } else {
        Provider.of<ExpandablePlayerController>(context, listen: false)
            .expand();
      }
    } else {
      // Position-based decision with spring animation
      final targetValue = _controller.value < 0.5 ? 0.0 : 1.0;
      final simulation = SpringSimulation(
        spring,
        _controller.value,
        targetValue,
        0.0,
      );
      _controller.animateWith(simulation);

      if (targetValue == 0.0) {
        Provider.of<ExpandablePlayerController>(context, listen: false)
            .collapse();
      } else {
        Provider.of<ExpandablePlayerController>(context, listen: false)
            .expand();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ExpandablePlayerController>(
      builder: (context, expandablePlayerController, child) {
        // Sync controller state
        if (expandablePlayerController.isExpanded && !isExpanded) {
          expand();
        } else if (!expandablePlayerController.isExpanded && isExpanded) {
          collapse();
        }

        return AnimatedBuilder(
          animation: _controller,
          builder: (BuildContext context, Widget? child) {
            final bottomPadding = MediaQuery.of(context).padding.bottom;
            final minHeightWithMargin = widget.minHeight +
                32 +
                bottomPadding; // margin inside MiniPlayer
            final screenHeight = MediaQuery.of(context).size.height;
            final height = minHeightWithMargin +
                (screenHeight - minHeightWithMargin) * _heightFactor.value;

            return Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: height,
              child: RepaintBoundary(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onVerticalDragUpdate: (details) {
                    if (!mounted) return;
                    final delta = -details.primaryDelta! /
                        (screenHeight - minHeightWithMargin);
                    _controller.value =
                        (_controller.value + delta).clamp(0.0, 1.0);
                  },
                  onVerticalDragEnd: (details) {
                    _handleDragEnd(details, screenHeight, minHeightWithMargin);
                  },
                  onTap: () {
                    if (!mounted) return;
                    if (_controller.value == 0.0) {
                      expand();
                      expandablePlayerController.expand();
                    }
                  },
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final v = _controller.value;
                      // Use a smoother threshold for mode switching
                      final bool expandedMode = v > 0.01;

                      // Compute background opacity with faster fade-in
                      final bgOpacity = (v * 1.2).clamp(0.0, 0.95);

                      return Container(
                        margin: EdgeInsets.zero,
                        decoration: expandedMode
                            ? BoxDecoration(
                                color: Colors.black.withOpacity(bgOpacity),
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(28 * v),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.5 * v),
                                    blurRadius: 30 * v,
                                    spreadRadius: -5,
                                    offset: Offset(0, -8 * v),
                                  ),
                                ],
                              )
                            : const BoxDecoration(),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          children: [
                            // Mini player - keep at full opacity for Hero animations
                            Positioned.fill(
                              child: IgnorePointer(
                                ignoring: v > 0.05,
                                child: Opacity(
                                  // Keep fully visible until 60% to allow Heroes to complete
                                  opacity: v < 0.6
                                      ? 1.0
                                      : (1.0 - ((v - 0.6) / 0.4))
                                          .clamp(0.0, 1.0),
                                  child: widget.minChild,
                                ),
                              ),
                            ),
                            // Expanded content - fade in after Heroes start
                            Positioned.fill(
                              child: IgnorePointer(
                                ignoring: v < 0.5,
                                child: Opacity(
                                  // Start fading in at 50% to overlap with Heroes
                                  opacity: v < 0.5
                                      ? 0.0
                                      : ((v - 0.5) / 0.5).clamp(0.0, 1.0),
                                  child: widget.maxChild,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
