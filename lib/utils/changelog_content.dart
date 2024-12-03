class ChangelogContent {
  static const Map<String, List<Map<String, List<String>>>> versions = {
    // Latest version at the top
    '0.0.9-alpha': [
      {
        'Now Playing': [
          'New Now Playing interface',
          'Timed Lyrics',
          'Search Tab',
          'Info about artist in Now Playing screen',
          'Sleep Timer',
        ],
      },
      {
        'Screens': [
          'Optimized songs recommendation',
          'Added Library Screen',
          'Added Album Screen',
          'Some items on Library Tab are now clickable',
          'Refined Welcome Screen',
        ],
      },
      {
        'Others': [
          'Audio Notification controls',
          'Background Playback',
          'Added Favourite Songs playlist',
          'Various fixes and optimizations',
        ],
      },
    ],
    
    // Older versions below
    '0.9.0': [
      {
        'Features': [
          'Initial beta release',
          'Basic music playback',
          'Library organization',
        ],
      },
      {
        'Improvements': [
          'Performance optimizations',
          'UI refinements',
        ],
      },
    ],
  };

  static List<Map<String, List<String>>> getChangelogForVersion(String version) {
    return versions[version] ?? [];
  }

  static String getLatestVersion() {
    return versions.keys.first;
  }

  static bool hasVersion(String version) {
    return versions.containsKey(version);
  }
} 