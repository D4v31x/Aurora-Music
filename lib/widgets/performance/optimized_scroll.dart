import 'package:flutter/material.dart';
import '../utils/debouncer.dart';

/// Optimized scroll controller that includes debouncing and performance optimizations
class OptimizedScrollController extends ScrollController {
  final Debouncer _scrollDebouncer;
  final Throttler _scrollThrottler;
  
  OptimizedScrollController({
    Duration debounceDuration = const Duration(milliseconds: 100),
    Duration throttleDuration = const Duration(milliseconds: 16), // ~60fps
  }) : _scrollDebouncer = Debouncer(delay: debounceDuration),
       _scrollThrottler = Throttler(delay: throttleDuration);

  /// Adds a debounced listener that only fires after scroll has stopped
  void addDebouncedListener(VoidCallback listener) {
    super.addListener(() {
      _scrollDebouncer.call(listener);
    });
  }

  /// Adds a throttled listener that fires at regular intervals during scroll
  void addThrottledListener(VoidCallback listener) {
    super.addListener(() {
      _scrollThrottler.call(listener);
    });
  }

  @override
  void dispose() {
    _scrollDebouncer.dispose();
    _scrollThrottler.dispose();
    super.dispose();
  }
}

/// Performance-optimized ListView.builder with automatic optimizations
class OptimizedListView extends StatelessWidget {
  final int itemCount;
  final Widget Function(BuildContext context, int index) itemBuilder;
  final ScrollController? controller;
  final EdgeInsets? padding;
  final bool shrinkWrap;
  final ScrollPhysics? physics;

  const OptimizedListView({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.controller,
    this.padding,
    this.shrinkWrap = false,
    this.physics,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: controller,
      itemCount: itemCount,
      padding: padding,
      shrinkWrap: shrinkWrap,
      physics: physics,
      // Optimize for memory usage
      cacheExtent: 200.0,
      // Add keys for better performance
      itemBuilder: (context, index) {
        return RepaintBoundary(
          key: ValueKey(index),
          child: itemBuilder(context, index),
        );
      },
    );
  }
}

/// Widget that automatically adds RepaintBoundary and Key for list items
class OptimizedListItem extends StatelessWidget {
  final Widget child;
  final Object itemKey;

  const OptimizedListItem({
    super.key,
    required this.child,
    required this.itemKey,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: ValueKey(itemKey),
      child: child,
    );
  }
}