# Aurora Music - Project Structure

This document describes the folder structure and organization of the Aurora Music Flutter application.

## Directory Structure

```
lib/
├── main.dart                    # Application entry point
├── core/                        # Core application infrastructure
│   └── constants/               # Application constants
│       ├── animation_constants.dart
│       ├── app_config.dart
│       └── font_constants.dart
├── features/                    # Feature modules (organized by domain)
│   ├── home/                    # Home feature
│   │   ├── screens/            # Home screens
│   │   └── widgets/            # Home-specific widgets
│   ├── library/                # Music library feature
│   │   ├── screens/            # Library screens (albums, artists, tracks)
│   │   └── library.dart        # Library barrel file
│   ├── player/                 # Audio player feature
│   │   ├── screens/            # Player screens (now playing, fullscreen)
│   │   └── widgets/            # Player-specific widgets
│   ├── playlists/              # Playlists feature
│   │   └── screens/            # Playlist screens
│   ├── search/                 # Search feature
│   │   └── widgets/            # Search widgets
│   ├── settings/               # Settings feature
│   │   ├── screens/            # Settings screens
│   │   └── widgets/            # Settings widgets
│   ├── onboarding/             # Onboarding feature
│   │   ├── screens/            # Onboarding screens
│   │   └── pages/              # Onboarding pages
│   └── splash/                 # Splash screen feature
├── shared/                      # Shared code across features
│   ├── models/                 # Data models
│   │   ├── playlist_model.dart
│   │   ├── separated_artist.dart
│   │   ├── timed_lyrics.dart
│   │   └── utils.dart
│   ├── services/               # Business logic services
│   │   ├── audio_player_service.dart
│   │   ├── artwork_cache_service.dart
│   │   ├── lyrics_service.dart
│   │   └── ...
│   ├── widgets/                # Reusable UI widgets
│   │   ├── common/            # Common widget utilities
│   │   ├── album_card.dart
│   │   ├── artist_card.dart
│   │   └── ...
│   ├── mixins/                 # Reusable mixins
│   │   ├── artwork_mixin.dart
│   │   ├── playback_mixin.dart
│   │   └── ...
│   ├── providers/              # State providers
│   │   ├── theme_provider.dart
│   │   └── performance_mode_provider.dart
│   └── utils/                  # Utility functions
│       ├── formatters/         # Value formatters
│       ├── validators/         # Input validators
│       └── ...
└── l10n/                        # Localization
    ├── app_localizations.dart
    ├── locale_provider.dart
    └── generated/              # Generated localization files
```

## Organization Principles

### 1. Feature-First Architecture
Each feature is self-contained with its own screens, widgets, and controllers:
- **Screens**: Full-page UI components
- **Widgets**: Feature-specific reusable widgets
- **Controllers**: Feature-specific state management (if needed)

### 2. Shared Layer
Code that is used across multiple features goes in `shared/`:
- **Models**: Data classes and domain entities
- **Services**: Business logic and API integrations
- **Widgets**: UI components used by multiple features
- **Mixins**: Reusable behavior that can be mixed into widgets
- **Utils**: Helper functions and utilities
- **Providers**: Global state management

### 3. Core Layer
Application-wide infrastructure:
- **Constants**: Configuration values, asset paths, strings
- **Theme**: Colors, text styles, app theme data
- **Router**: Navigation configuration (if used)

### 4. Barrel Files
Each folder has an index/barrel file that exports all public APIs:
- `models/models.dart`
- `services/services.dart`
- `widgets/widgets.dart`
- etc.

## Import Conventions

### Package Imports
```dart
import 'package:aurora_music_v01/core/constants/app_config.dart';
import 'package:aurora_music_v01/shared/services/audio_player_service.dart';
import 'package:aurora_music_v01/features/player/screens/now_playing.dart';
```

### Relative Imports
Use relative imports within the same feature:
```dart
import '../widgets/player_controls.dart';
```

### Import Order
1. Dart SDK imports
2. Flutter imports
3. Package imports
4. Relative imports

## Adding New Features

1. Create a new folder under `features/`
2. Add `screens/`, `widgets/`, `controllers/` subfolders as needed
3. Create a feature barrel file (e.g., `feature_name_feature.dart`)
4. Add exports to `features/features.dart`

## Adding Shared Components

1. Determine the appropriate subfolder under `shared/`
2. Create the component
3. Add export to the relevant barrel file
4. Update documentation if the component has special usage patterns
