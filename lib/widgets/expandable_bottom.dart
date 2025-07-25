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
      duration: const Duration(milliseconds: 400),
    );
    _heightFactor = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
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
        if (expandablePlayerController.isExpanded && !isExpanded) {
          expand();
        } else if (!expandablePlayerController.isExpanded && isExpanded) {
          collapse();
        }

        return AnimatedBuilder(
          animation: _controller,
          builder: (BuildContext context, Widget? child) {
            return Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: widget.minHeight + 
                     (MediaQuery.of(context).size.height - widget.minHeight) * 
                     _heightFactor.value,
              child: RepaintBoundary(
                child: GestureDetector(
                  onVerticalDragUpdate: (details) {
                    if (!mounted) return;
                    _controller.value -= details.primaryDelta! / 
                                       (MediaQuery.of(context).size.height - widget.minHeight);
                  },
                  onVerticalDragEnd: (details) {
                    if (!mounted || _controller.isAnimating) return;

                    final double velocity = details.velocity.pixelsPerSecond.dy / 
                                         (MediaQuery.of(context).size.height - widget.minHeight);
                    
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
              child: RepaintBoundary(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.8),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20.0)
                    ),
                  ),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: FadeTransition(
                          opacity: ReverseAnimation(_controller),
                          child: widget.minChild,
                        ),
                      ),
                      Positioned.fill(
                        child: FadeTransition(
                          opacity: _controller,
                          child: widget.maxChild,
                        ),
                      ),
                    ],
                  ),
                ),
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
