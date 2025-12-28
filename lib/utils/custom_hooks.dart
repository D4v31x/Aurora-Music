import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

/// Custom hook for debounced text input
/// Returns a debounced value that only updates after the delay
T useDebouncedValue<T>(T value, Duration delay) {
  final debouncedValue = useState<T>(value);

  useEffect(() {
    final timer = Timer(delay, () {
      debouncedValue.value = value;
    });

    return timer.cancel;
  }, [value, delay]);

  return debouncedValue.value;
}

/// Custom hook for scroll controller with scroll position tracking
/// Returns both the controller and a ValueNotifier for scroll position
({ScrollController controller, ValueNotifier<double> position})
    useScrollControllerWithPosition() {
  final controller = useScrollController();
  final position = useState<double>(0.0);

  useEffect(() {
    void listener() {
      if (controller.hasClients) {
        position.value = controller.offset;
      }
    }

    controller.addListener(listener);
    return () => controller.removeListener(listener);
  }, [controller]);

  return (controller: controller, position: ValueNotifier(position.value));
}

/// Custom hook that returns true if scroll offset exceeds threshold
bool useIsScrolled(ScrollController controller, {double threshold = 0}) {
  final isScrolled = useState(false);

  useEffect(() {
    void listener() {
      if (controller.hasClients) {
        final newValue = controller.offset > threshold;
        if (isScrolled.value != newValue) {
          isScrolled.value = newValue;
        }
      }
    }

    controller.addListener(listener);
    return () => controller.removeListener(listener);
  }, [controller, threshold]);

  return isScrolled.value;
}

/// Custom hook for pagination/lazy loading
/// Returns pagination state and methods
class PaginationState<T> {
  final List<T> items;
  final bool isLoading;
  final bool hasMore;
  final VoidCallback loadMore;
  final VoidCallback reset;

  PaginationState({
    required this.items,
    required this.isLoading,
    required this.hasMore,
    required this.loadMore,
    required this.reset,
  });
}

PaginationState<T> usePagination<T>({
  required List<T> allItems,
  int pageSize = 20,
}) {
  final displayedItems = useState<List<T>>([]);
  final currentPage = useState(0);
  final isLoading = useState(false);

  final hasMore = displayedItems.value.length < allItems.length;

  void loadMore() {
    if (isLoading.value || !hasMore) return;

    isLoading.value = true;

    final startIndex = currentPage.value * pageSize;
    final endIndex = (startIndex + pageSize).clamp(0, allItems.length);

    if (startIndex < allItems.length) {
      final newItems = allItems.sublist(startIndex, endIndex);
      displayedItems.value = [...displayedItems.value, ...newItems];
      currentPage.value++;
    }

    isLoading.value = false;
  }

  void reset() {
    displayedItems.value = [];
    currentPage.value = 0;
    isLoading.value = false;
  }

  // Auto-load first page
  useEffect(() {
    if (displayedItems.value.isEmpty && allItems.isNotEmpty) {
      loadMore();
    }
    return null;
  }, [allItems]);

  return PaginationState<T>(
    items: displayedItems.value,
    isLoading: isLoading.value,
    hasMore: hasMore,
    loadMore: loadMore,
    reset: reset,
  );
}

/// Custom hook for stream subscription that auto-cancels
void useStreamSubscription<T>(
  Stream<T>? stream,
  void Function(T) onData, {
  void Function(Object)? onError,
  void Function()? onDone,
  List<Object?> keys = const [],
}) {
  useEffect(() {
    if (stream == null) return null;

    final subscription = stream.listen(
      onData,
      onError: onError,
      onDone: onDone,
    );

    return subscription.cancel;
  }, [stream, ...keys]);
}

/// Custom hook for async initialization with loading state
class AsyncState<T> {
  final T? data;
  final bool isLoading;
  final Object? error;

  AsyncState({
    this.data,
    this.isLoading = false,
    this.error,
  });

  bool get hasData => data != null;
  bool get hasError => error != null;
}

AsyncState<T> useAsync<T>(
  Future<T> Function() asyncFunction, {
  List<Object?> keys = const [],
}) {
  final data = useState<T?>(null);
  final isLoading = useState(true);
  final error = useState<Object?>(null);

  useEffect(() {
    isLoading.value = true;
    error.value = null;

    asyncFunction().then((result) {
      data.value = result;
      isLoading.value = false;
    }).catchError((e) {
      error.value = e;
      isLoading.value = false;
    });

    return null;
  }, keys);

  return AsyncState<T>(
    data: data.value,
    isLoading: isLoading.value,
    error: error.value,
  );
}

/// Custom hook for interval-based updates
void useInterval(VoidCallback callback, Duration duration,
    {bool enabled = true}) {
  useEffect(() {
    if (!enabled) return null;

    final timer = Timer.periodic(duration, (_) => callback());
    return timer.cancel;
  }, [duration, enabled]);
}

/// Custom hook for delayed execution
void useTimeout(VoidCallback callback, Duration delay, {bool enabled = true}) {
  useEffect(() {
    if (!enabled) return null;

    final timer = Timer(delay, callback);
    return timer.cancel;
  }, [delay, enabled]);
}

/// Custom hook for ValueNotifier that auto-disposes
ValueNotifier<T> useValueNotifierWithDispose<T>(T initialValue) {
  return useMemoized(() => ValueNotifier<T>(initialValue));
}
