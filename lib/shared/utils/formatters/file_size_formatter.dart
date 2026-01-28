/// File size formatting utilities for the Aurora Music app.
///
/// Provides consistent file size formatting across the application.
library;

/// Format bytes to a human-readable string.
///
/// Returns sizes in B, KB, MB, or GB as appropriate.
String formatBytes(int bytes, {int decimals = 1}) {
  if (bytes < 1024) {
    return '$bytes B';
  }
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(decimals)} KB';
  }
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(decimals)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(decimals)} GB';
}

/// Format bytes to a compact human-readable string (no decimals for small values).
String formatBytesCompact(int bytes) {
  if (bytes < 1024) {
    return '$bytes B';
  }
  if (bytes < 10 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).round()} KB';
  }
  if (bytes < 10 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).round()} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}
