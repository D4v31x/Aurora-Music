class ChangelogContent {
  static const Map<String, List<Map<String, List<String>>>> versions = {
    // Latest version at the top
    '1.4.0': [
      {
        '_': ['Aurora Music 1.4 — Orbit'],
      },
      {
        'New Features': [
          'Playlist song reordering — tap ⋮ on any playlist and choose "Reorder Songs" to drag tracks into your preferred order',
          'M3U / M3U8 playlist import and export — share playlists with other apps or import from files; optional two-way folder sync (Poweramp-style)',
          'Sort order is now remembered — your chosen sort option and direction for Tracks, Albums, Artists, and Folders is restored after restarting the app',
        ],
      },
      {
        'Splash Screen': [
          'Redesigned splash screen ("Orbit")',
          'Home screen data (suggestions, artwork) is pre-warmed during the splash so the first frame of the home screen is ready immediately',
        ],
      },
      {
        'Listening Stats & Recap': [
          'Time-listened figures now reflect the actual time you spent on each song, not its full length — minutes in Recap and Insights are now accurate',
        ],
      },
      {
        'Performance': [
          'Smart Suggestions no longer re-queries device storage on each refresh — reuses the already-loaded library for a significant speed-up',
          'Library initialisation is guarded against double-init races; a future cache prevents redundant scans',
          'BlurDialog respects low-end device mode and skips backdrop blur where it would hurt performance',
        ],
      },
      {
        'Under the Hood': [
          'ReplayGain now reads MP4/M4A/AAC/ALAC files (iTunes freeform atoms), APEv2 tags on MP3, and Opus R128_TRACK_GAIN; tag matching is case-insensitive and whitespace-tolerant; album gain is used as a fallback when track gain is absent',
          'Metadata changes propagate instantly to playlists and the playback queue without requiring a library rescan',
          'Liked Songs playlist is always shown first in the Quick Access section',
          'Page transitions use a faster fade animation for snappier navigation',
        ],
      },
    ],
    '1.3.2': [
      {
        '_': ['Aurora Music 1.3 — Insights, Equalizer & Folder Filtering'],
      },
      {
        'New Features': [
          'Aurora Wrapped — a personalised year-in-review of your listening habits',
          'Listening Insights — detailed stats about your most played artists, albums, and tracks',
          'Equalizer — built-in 5-band EQ with presets and custom profiles',
          'Folder Filtering — exclude specific folders from your library in Settings',
          'Color themes - Pick your favorite color instead of using Material You colors and background artwork-based theming',
        ],
      },
      {
        'Now Playing': [
          'Improved artwork transitions and track info animations',
          'Sleep timer UI improvements',
        ],
      },
      {
        'Library': [
          'Refreshed Albums, Artists, and Tracks screens',
          'Smart suggestions algorithm improvements',
        ],
      },
      {
        'Settings': [
          'Appearance settings redesigned and expanded',
          'New Playback settings screen',
          'Insights settings for controlling listening data',
          'Folder filter management screen',
        ],
      },
      {
        'Performance': [
          'Fixed unnecessary full-screen rebuilds in Now Playing, Fullscreen Lyrics, and Lyrics Editor during active playback',
          'Eliminated redundant widget rebuilds in Library tab sections',
          'Optimised animated background — color blend listenable is now cached instead of recreated each frame',
          'Reduced list sort overhead in Recently Added section',
          'Various state management and rendering optimisations',
        ],
      },
      {
        'Under the Hood': [
          'Bluetooth playback service improvements',
          'Lyrics translation service refactored',
          'Play count tracking accuracy improved',
          'Minor code cleanup and dependency updates',
        ],
      },
    ],
    '1.0.5': [
      {
        '_': ['Aurora Music 1.0 — the first production release'],
      },
      {
        'Preface for beta testers': [
          'After over a year of development and testing, Aurora Music has reached its first stable release! This version includes all the core features I envisioned, along with numerous optimizations and bug fixes. I am incredibly grateful to our early adopters and beta testers for their invaluable feedback and support throughout this journey.',
          'This release marks a major milestone for me, but it’s just the beginning. I am committed to continuously enhancing Aurora Music based on user feedback and evolving needs. Thank you for being part of this journey, and I can’t wait to share what’s next!',
        ],
        'New Features': [
          'Music Visualizer — real-time audio visualization with multiple modes (accessible from Now Playing)',
          'Android Auto support — control playback from your car display',
          'Lyrics Editor — create and edit custom timed lyrics for any song',
          'In-app feedback form — send feedback or bug reports directly from the app',
        ],
      },
      {
        'Lyrics': [ 
          'Lyrics Editor for writing and fine-tuning timed (.lrc) lyrics',
          'Smoother lyric line animations and improved scroll behavior',
        ],
      },
      {
        'Bug Fixes': [
          'Fixed artwork not updating when skipping between tracks',
          'Fixed play count tracking not incrementing correctly',
        ],
      },
      {
        'UI': [
          'Various visual refinements across screens',
        ],
      },
      {
        'Under the Hood': [
          'Improved error tracking and logging',
          'Background service stability improvements',
        ],
      },
    ],
    '0.1.84': [
      {
        'UI': [
          'Added option to contribute to translate app via Crowdin in settings',
          'Replaced most Material icons with iconoir icon library throughout the app',
          'Added more customization options in settings',
          'Playback speed slider now has step arrow buttons (±0.05) and max speed capped at 2.0×',
          'Various UI improvements',
        ],
      },
      {
        'Lyrics':[
          'Lyrics translation — translate button lets you translate lyrics to your app language using online service'
        ],
      },
      {
        'Performance Fixes': [
          'Improved performance on high-end devices',
          'Fixed performance issues on all devices - users now have option to reduce the performance demand by reducing effects in settings',
          'Various performance and state management optimizations',
        ],
      },
      {
        'Under the Hood': [
          'Refactored audio_player_service',
          'Introduced error and performance tracking via Sentry service',
          'Removed redundant packages and files',
          'Added support for community translated strings via Crowdin',
          'Adjusted Spotify API usage for ToS compilance',
          'Minor code optimizations and refactoring',
        ],
      },
      {
        'Others': [
          'In-app update support via Google Play version checking'
        ],
      },
    ],
    '0.1.21': [
      {
        'Screens': [
          'Added all used packages',
          'Added full screen artwork view from Now Playing screen',
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
          'Recompiled native libraries to work with 16KB page size devices',
          'Fixed issues with state management for updating UI',
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
