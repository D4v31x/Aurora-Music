import 'dart:async';

/// Debouncer utility to prevent excessive function calls during rapid events
/// Useful for search input, scroll events, and other high-frequency operations
class Debouncer {
  final Duration delay;
  Timer? _timer;

  Debouncer({required this.delay});

  /// Executes the callback after the delay, canceling any previous pending execution
  void call(void Function() callback) {
    _timer?.cancel();
    _timer = Timer(delay, callback);
  }

  /// Cancels any pending execution
  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  /// Disposes the debouncer and cancels any pending execution
  void dispose() {
    cancel();
  }
}

/// Throttler utility to limit function calls to a maximum frequency
/// Useful for scroll events and other high-frequency operations where some calls should be preserved
class Throttler {
  final Duration delay;
  Timer? _timer;
  bool _isReady = true;

  Throttler({required this.delay});

  /// Executes the callback immediately if ready, otherwise ignores the call
  void call(void Function() callback) {
    if (_isReady) {
      _isReady = false;
      callback();
      _timer = Timer(delay, () {
        _isReady = true;
      });
    }
  }

  /// Disposes the throttler and cancels any pending timer
  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}

/// Batch processor for state updates to reduce rebuild frequency
class BatchProcessor<T> {
  final Duration delay;
  final void Function(List<T>) onBatch;
  Timer? _timer;
  final List<T> _queue = [];

  BatchProcessor({
    required this.delay,
    required this.onBatch,
  });

  /// Adds an item to the batch queue
  void add(T item) {
    _queue.add(item);
    _timer?.cancel();
    _timer = Timer(delay, _processBatch);
  }

  void _processBatch() {
    if (_queue.isNotEmpty) {
      final batch = List<T>.from(_queue);
      _queue.clear();
      onBatch(batch);
    }
  }

  /// Forces immediate processing of the current batch
  void flush() {
    _timer?.cancel();
    _processBatch();
  }

  /// Disposes the batch processor
  void dispose() {
    _timer?.cancel();
    _queue.clear();
  }
}