import 'package:flutter/material.dart';
import 'dart:async';

/// Collection of widget optimization utilities
class WidgetOptimizations {
  WidgetOptimizations._();

  /// Wraps a widget in RepaintBoundary if optimization is enabled
  static Widget maybeRepaintBoundary({
    required Widget child,
    bool enable = true,
    Key? key,
  }) {
    if (!enable) return child;
    return RepaintBoundary(key: key, child: child);
  }

  /// Creates an optimized ListView.builder with performance settings
  static Widget optimizedListView({
    required IndexedWidgetBuilder itemBuilder,
    required int itemCount,
    ScrollController? controller,
    ScrollPhysics? physics,
    EdgeInsetsGeometry? padding,
    Axis scrollDirection = Axis.vertical,
    double? itemExtent,
    double cacheExtent = 500,
    bool addRepaintBoundaries = true,
    bool addAutomaticKeepAlives = false,
  }) {
    return ListView.builder(
      controller: controller,
      physics: physics ?? const BouncingScrollPhysics(),
      padding: padding,
      scrollDirection: scrollDirection,
      itemCount: itemCount,
      itemExtent: itemExtent,
      cacheExtent: cacheExtent,
      addRepaintBoundaries: addRepaintBoundaries,
      addAutomaticKeepAlives: addAutomaticKeepAlives,
      itemBuilder: itemBuilder,
    );
  }

  /// Creates an optimized GridView.builder
  static Widget optimizedGridView({
    required IndexedWidgetBuilder itemBuilder,
    required int itemCount,
    required SliverGridDelegate gridDelegate,
    ScrollController? controller,
    ScrollPhysics? physics,
    EdgeInsetsGeometry? padding,
    double cacheExtent = 500,
    bool addRepaintBoundaries = true,
    bool addAutomaticKeepAlives = false,
  }) {
    return GridView.builder(
      controller: controller,
      physics: physics ?? const BouncingScrollPhysics(),
      padding: padding,
      gridDelegate: gridDelegate,
      itemCount: itemCount,
      cacheExtent: cacheExtent,
      addRepaintBoundaries: addRepaintBoundaries,
      addAutomaticKeepAlives: addAutomaticKeepAlives,
      itemBuilder: itemBuilder,
    );
  }

  /// Optimized image widget with caching
  static Widget optimizedImage({
    required ImageProvider image,
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    Widget? placeholder,
    Widget? errorWidget,
  }) {
    return Image(
      image: image,
      width: width,
      height: height,
      fit: fit,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded) return child;
        return AnimatedOpacity(
          opacity: frame == null ? 0 : 1,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          child: child,
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return errorWidget ?? const Icon(Icons.error);
      },
      gaplessPlayback: true,
      isAntiAlias: false, // Disable anti-aliasing for better performance
    );
  }

  /// Debounces a function call
  static Timer? _debounceTimer;
  static void debounce(Duration duration, VoidCallback action) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(duration, action);
  }

  /// Throttles a function call
  static DateTime? _lastThrottleTime;
  static void throttle(Duration duration, VoidCallback action) {
    final now = DateTime.now();
    if (_lastThrottleTime == null ||
        now.difference(_lastThrottleTime!) >= duration) {
      _lastThrottleTime = now;
      action();
    }
  }

  /// Creates a builder that only rebuilds when specific selector changes
  static Widget selectiveBuilder<T>({
    required T Function() selector,
    required Widget Function(BuildContext, T) builder,
    T? initialValue,
  }) {
    return ValueListenableBuilder<T>(
      valueListenable: _SelectorValueNotifier(selector, initialValue),
      builder: (context, value, _) => builder(context, value),
    );
  }
}

class _SelectorValueNotifier<T> extends ValueNotifier<T> {
  final T Function() selector;

  _SelectorValueNotifier(this.selector, T? initialValue)
      : super(initialValue ?? selector()) {
    _updateValue();
  }

  void _updateValue() {
    final newValue = selector();
    if (value != newValue) {
      value = newValue;
    }
  }
}

/// Mixin for widgets that need performance monitoring
mixin PerformanceMonitoringMixin on State {
  Stopwatch? _buildStopwatch;

  @override
  void initState() {
    super.initState();
    _buildStopwatch = Stopwatch();
  }

  @override
  Widget build(BuildContext context) {
    _buildStopwatch?.start();
    final widget = buildWidget(context);
    _buildStopwatch?.stop();

    // Log slow builds in debug mode
    if (_buildStopwatch!.elapsedMilliseconds > 16) {
      debugPrint('⚠️ Slow build detected in ${runtimeType}: '
          '${_buildStopwatch!.elapsedMilliseconds}ms');
    }
    _buildStopwatch?.reset();

    return widget;
  }

  Widget buildWidget(BuildContext context);
}
