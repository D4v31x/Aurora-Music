/// Utility class for common validation operations
/// Provides standardized validation methods throughout the app
class ValidationUtils {
  /// Validates if a string is not null and not empty
  static bool isNotEmpty(String? value) {
    return value != null && value.trim().isNotEmpty;
  }

  /// Validates if a string is a valid file path
  static bool isValidFilePath(String? path) {
    if (path == null || path.isEmpty) return false;
    
    // Basic validation for common invalid characters
    final invalidChars = ['<', '>', ':', '"', '|', '?', '*'];
    return !invalidChars.any((char) => path.contains(char));
  }

  /// Validates if a string is a valid URL
  static bool isValidUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }

  /// Validates audio file extension
  static bool isValidAudioFile(String? fileName) {
    if (fileName == null || fileName.isEmpty) return false;
    
    const validExtensions = ['.mp3', '.wav', '.flac', '.aac', '.ogg', '.m4a', '.wma'];
    final lowerFileName = fileName.toLowerCase();
    
    return validExtensions.any((ext) => lowerFileName.endsWith(ext));
  }

  /// Validates image file extension
  static bool isValidImageFile(String? fileName) {
    if (fileName == null || fileName.isEmpty) return false;
    
    const validExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp'];
    final lowerFileName = fileName.toLowerCase();
    
    return validExtensions.any((ext) => lowerFileName.endsWith(ext));
  }

  /// Sanitizes string for safe file naming
  static String sanitizeFileName(String fileName) {
    if (fileName.isEmpty) return 'untitled';
    
    // Replace invalid characters with underscores
    final invalidChars = RegExp(r'[<>:"/\\|?*]');
    return fileName.replaceAll(invalidChars, '_').trim();
  }

  /// Validates duration format (for lyrics, etc.)
  static bool isValidDuration(String? duration) {
    if (duration == null || duration.isEmpty) return false;
    
    // Accept formats like: mm:ss or hh:mm:ss
    final timeRegex = RegExp(r'^(\d{1,2}:)?\d{1,2}:\d{2}$');
    return timeRegex.hasMatch(duration);
  }

  /// Validates if a number is within a specific range
  static bool isInRange(num? value, num min, num max) {
    if (value == null) return false;
    return value >= min && value <= max;
  }

  /// Validates playlist name
  static bool isValidPlaylistName(String? name) {
    if (!isNotEmpty(name)) return false;
    
    // Check for reasonable length
    return name!.length <= 100 && name.length >= 1;
  }

  /// Cleans text for search queries
  static String cleanSearchQuery(String query) {
    return query.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }
}