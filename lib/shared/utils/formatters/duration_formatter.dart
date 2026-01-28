/// Duration formatting utilities for the Aurora Music app.
///
/// Provides consistent duration formatting across the application,
/// supporting both short (MM:SS) and long (HH:MM:SS) formats.
library;

/// Format a [Duration] to a human-readable string.
///
/// Returns '--:--' for null durations.
/// For durations under one hour, returns 'MM:SS'.
/// For durations one hour or longer, returns 'HH:MM:SS'.
String formatDuration(Duration? duration) {
  if (duration == null) return '--:--';

  String twoDigits(int n) => n.toString().padLeft(2, '0');

  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);

  if (hours > 0) {
    return '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}';
  }
  return '${twoDigits(minutes)}:${twoDigits(seconds)}';
}

/// Format a [Duration] always including hours (HH:MM:SS).
///
/// Returns '00:00:00' for null durations (consistent width for UI layouts).
String formatDurationWithHours(Duration? duration) {
  if (duration == null) return '00:00:00';

  String twoDigits(int n) => n.toString().padLeft(2, '0');

  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);

  return '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}';
}

/// Format a [Duration] to a compact string (M:SS for < 10 min, MM:SS otherwise).
String formatDurationCompact(Duration? duration) {
  if (duration == null) return '-:--';

  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);

  if (duration.inHours > 0) {
    return '${duration.inHours}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}
