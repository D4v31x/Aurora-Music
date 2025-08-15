import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/expandable_player_controller.dart';

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

class ExpandableBottomSheetState extends State<ExpandableBottomSheet> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _heightFactor;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500), // smoother
    );
    _heightFactor = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic, // smoother curve
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
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  Future<void> expand() async {
    if (!mounted) return;
    await _controller.animateTo(
      1.0,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
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
            final minHeightWithMargin = widget.minHeight + 32 + bottomPadding; // margin inside MiniPlayer
            final screenHeight = MediaQuery.of(context).size.height;
            final height = minHeightWithMargin + (screenHeight - minHeightWithMargin) * _heightFactor.value;

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
                    _controller.value -= details.primaryDelta! / (screenHeight - minHeightWithMargin);
                  },
                  onVerticalDragEnd: (details) {
                    if (!mounted || _controller.isAnimating) return;
                    final velocity = details.velocity.pixelsPerSecond.dy / (screenHeight - minHeightWithMargin);
                    if (velocity.abs() > 1.0) {
                      if (velocity > 0) {
                        collapse();
                        expandablePlayerController.collapse();
                      } else {
                        expand();
                        expandablePlayerController.expand();
                      }
                    } else {
                      if (_controller.value < 0.5) {
                        collapse();
                        expandablePlayerController.collapse();
                      } else {
                        expand();
                        expandablePlayerController.expand();
                      }
                    }
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
                      final bool expandedMode = v > 0.02; // threshold
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.easeInOutCubic,
                        margin: EdgeInsets.zero, // no outer pill duplication
                        padding: EdgeInsets.only(bottom: bottomPadding * (1 - v)),
                        decoration: expandedMode
                            ? BoxDecoration(
                                color: Colors.black.withOpacity(0.9 * v),
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.4 * v),
                                    blurRadius: 30 * v,
                                    offset: Offset(0, 12 * v),
                                  ),
                                ],
                              )
                            : const BoxDecoration(),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          children: [
                            // Mini (collapsed) only visible while not expanded
                            Positioned.fill(
                              child: IgnorePointer(
                                ignoring: expandedMode,
                                child: FadeTransition(
                                  opacity: ReverseAnimation(_controller),
                                  child: widget.minChild,
                                ),
                              ),
                            ),
                            // Expanded content
                            Positioned.fill(
                              child: IgnorePointer(
                                ignoring: !expandedMode,
                                child: FadeTransition(
                                  opacity: _controller,
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
