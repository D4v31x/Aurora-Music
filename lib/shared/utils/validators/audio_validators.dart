/// Path and URL validation utilities.
///
/// Provides security-focused validation for file paths and audio URLs
/// to prevent directory traversal, injection attacks, and invalid inputs.
library;

import '../../mixins/services/audio_constants.dart';

// MARK: - Path Validation

/// Validates a file path for security issues.
///
/// Checks for:
/// - Null or empty paths
/// - Directory traversal attempts (.., ~)
/// - Excessive path length
/// - Null bytes (injection attempt)
///
/// Returns `true` if the path is valid and safe to use.
bool isValidFilePath(String? path) {
  if (path == null || path.isEmpty) {
    return false;
  }

  // Check for excessive length
  if (path.length > kMaxPathLength) {
    return false;
  }

  // Check for null bytes (injection attempt)
  if (path.contains('\x00')) {
    return false;
  }

  // Check for forbidden path patterns
  for (final forbidden in kForbiddenPathPatterns) {
    if (path.contains(forbidden)) {
      return false;
    }
  }

  return true;
}

/// Sanitizes a file path by removing potentially dangerous characters.
///
/// This should be used in addition to [isValidFilePath], not instead of it.
String sanitizeFilePath(String path) {
  var sanitized = path;

  // Remove null bytes
  sanitized = sanitized.replaceAll('\x00', '');

  // Remove potentially dangerous patterns
  for (final forbidden in kForbiddenPathPatterns) {
    sanitized = sanitized.replaceAll(forbidden, '');
  }

  // Trim whitespace
  sanitized = sanitized.trim();

  return sanitized;
}

// MARK: - URL Validation

/// Validates an audio URL or URI for safety.
///
/// Checks for:
/// - Null or empty URIs
/// - Allowed URI schemes (file, content, http, https, asset)
/// - Null bytes (injection attempt)
///
/// Returns `true` if the URI is valid and safe to use.
bool isValidAudioUri(String? uri) {
  if (uri == null || uri.isEmpty) {
    return false;
  }

  // Check for null bytes
  if (uri.contains('\x00')) {
    return false;
  }

  // Try to parse as URI
  Uri? parsedUri;
  try {
    parsedUri = Uri.parse(uri);
  } catch (e) {
    return false;
  }

  // For file paths without scheme, validate as file path
  if (parsedUri.scheme.isEmpty) {
    return isValidFilePath(uri);
  }

  // Check allowed schemes
  if (!kAllowedUriSchemes.contains(parsedUri.scheme.toLowerCase())) {
    return false;
  }

  // For file:// URIs, also validate the path
  if (parsedUri.scheme == 'file') {
    return isValidFilePath(parsedUri.path);
  }

  // For http/https, check for basic URL validity
  if (parsedUri.scheme == 'http' || parsedUri.scheme == 'https') {
    if (parsedUri.host.isEmpty) {
      return false;
    }
  }

  return true;
}

/// Checks if a URI has an allowed audio file extension.
///
/// Useful for validating that a file is actually an audio file
/// before attempting to load it.
bool hasAllowedAudioExtension(String uri) {
  final lowerUri = uri.toLowerCase();
  return kAllowedAudioExtensions.any((ext) => lowerUri.endsWith(ext));
}

// MARK: - Input Sanitization

/// Sanitizes user input for search operations.
///
/// Removes characters that could be used for injection attacks.
String sanitizeSearchInput(String input) {
  // Remove control characters
  var sanitized = input.replaceAll(RegExp(r'[\x00-\x1f]'), '');

  // Limit length to prevent DoS
  if (sanitized.length > 256) {
    sanitized = sanitized.substring(0, 256);
  }

  return sanitized.trim();
}

/// Sanitizes metadata strings (track names, artist names, etc.).
///
/// Removes control characters, normalizes newlines to spaces, and trims 
/// whitespace while preserving valid Unicode characters for international names.
/// 
/// Note: Newlines are normalized to spaces to prevent log injection
/// and display issues in single-line contexts.
String sanitizeMetadata(String? metadata) {
  if (metadata == null) return '';

  // Remove all control characters including newlines/tabs
  // to prevent log injection and display issues
  var sanitized = metadata.replaceAll(RegExp(r'[\x00-\x1f]'), ' ');

  // Normalize multiple spaces to single space
  sanitized = sanitized.replaceAll(RegExp(r'\s+'), ' ');

  // Limit length
  if (sanitized.length > 512) {
    sanitized = sanitized.substring(0, 512);
  }

  return sanitized.trim();
}

// MARK: - Playlist Validation

/// Validates a playlist ID for safety.
///
/// Playlist IDs should be alphanumeric with underscores/hyphens only.
bool isValidPlaylistId(String? id) {
  if (id == null || id.isEmpty) {
    return false;
  }

  // Only allow alphanumeric, underscore, and hyphen
  return RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(id);
}

/// Validates a playlist name for display.
///
/// Checks for reasonable length and removes dangerous characters.
bool isValidPlaylistName(String? name) {
  if (name == null || name.trim().isEmpty) {
    return false;
  }

  if (name.length > 100) {
    return false;
  }

  // Check for null bytes
  if (name.contains('\x00')) {
    return false;
  }

  return true;
}

/// Sanitizes a playlist name for storage and display.
String sanitizePlaylistName(String name) {
  var sanitized = sanitizeMetadata(name);

  // Limit to reasonable playlist name length
  if (sanitized.length > 100) {
    sanitized = sanitized.substring(0, 100);
  }

  return sanitized;
}
