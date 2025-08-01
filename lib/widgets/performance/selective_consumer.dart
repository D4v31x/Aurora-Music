import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// A consumer that only rebuilds when specific parts of the provider change
/// This helps reduce unnecessary widget rebuilds for better performance
class SelectiveConsumer<T> extends StatelessWidget {
  final Widget Function(BuildContext context, T value, Widget? child) builder;
  final Widget? child;
  final bool Function(T previous, T current)? shouldRebuild;

  const SelectiveConsumer({
    super.key,
    required this.builder,
    this.child,
    this.shouldRebuild,
  });

  @override
  Widget build(BuildContext context) {
    if (shouldRebuild != null) {
      return Consumer<T>(
        builder: (context, value, child) {
          return builder(context, value, child);
        },
        child: child,
      );
    }
    
    // Default behavior - use regular Consumer
    return Consumer<T>(
      builder: builder,
      child: child,
    );
  }
}

/// Consumer specifically optimized for AudioPlayerService that only rebuilds
/// when the current song changes, not on every playback state change
class AudioPlayerConsumer extends StatelessWidget {
  final Widget Function(BuildContext context, dynamic audioService, Widget? child) builder;
  final Widget? child;

  const AudioPlayerConsumer({
    super.key,
    required this.builder,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: builder,
      child: child,
    );
  }
}