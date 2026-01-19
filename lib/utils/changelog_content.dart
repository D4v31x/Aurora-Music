class ChangelogContent {
  static const Map<String, List<Map<String, List<String>>>> versions = {
    // Latest version at the top
    '0.1.20': [
      {
        'Screens': [
          'Added all used packages',
          'Added donation options in settings',
        ],
      },
      {
        'Performance Fixes': [
          'Improved shaders warmup on app start',
          'Various performance optimizations',
        ],
      },
      {
        'Under the Hood': [
          'Upgrade to AGP 9.0.0',
          'Upgrade to ndk 29',
          'Recompiled native libraries to work with 16KB page size devices'
        ],
      },
      {
        'Others': [
          'Various fixes and optimizations',
        ],
      },
    ],
    '0.1.5': [
      {
        'New Features': [
          'Complete onboarding flow with theme selection, permissions, and feature introduction',
          'Asset download configuration (Album Art, Lyrics, Auto-download)',
          'Donation options integration (Buy Me a Coffee, Ko-fi, PayPal)',
          'Internet usage explanation screen',
          'Metadata Editor',
          'Timed Lyrics support in Now Playing screen',
        ],
      },
      {
        'UI/UX Improvements': [
          'Major UI redesign across all screens',
          'Consistent navigation buttons with smooth animations',
          'Standardized page transitions throughout the app',
          'Enhanced onboarding experience with animated pages',
          'Refined permissions request flow',
        ],
      },
      {
        'Core Functionality': [
          'Enhanced audio playback engine',
          'Improved metadata fetching and display',
          'Better album and artist information',
          'Optimized song recommendations algorithm',
          'Enhanced library management',
          'Improved search functionality',
        ],
      },
      {
        'Localization': [
          'Full app translation support',
          'Czech language support added',
          'Localized UI elements and buttons',
          'Multilingual settings and preferences',
        ],
      },
      {
        'Technical Improvements': [
          'Code optimization and refactoring',
          'Better state management',
          'Performance enhancements',
          'Bug fixes and stability improvements',
        ],
      },
    ],

    // Older versions below
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
  };

  static List<Map<String, List<String>>> getChangelogForVersion(
      String version) {
    return versions[version] ?? [];
  }

  static String getLatestVersion() {
    return versions.keys.first;
  }

  static bool hasVersion(String version) {
    return versions.containsKey(version);
  }
}
