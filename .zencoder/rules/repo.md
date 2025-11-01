---
description: Repository Information Overview
alwaysApply: true
---

# Aurora Music - Information Overview

## Summary
Aurora Music is a modern, feature-rich music player application built with Flutter. It offers local music playback, Material You design, synced lyrics, intelligent playback features, playlist management, and artist exploration. The app supports multiple languages and is designed for Android 10 and higher, with additional support for iOS, Web, and Windows platforms.

## Structure
- **lib/** - Application source code including screens, widgets, services, models, providers, utilities, and localization
- **test/** - Widget tests and test configurations
- **android/** - Android-specific platform code and build configuration (Gradle-based)
- **ios/** - iOS-specific platform code and Xcode configuration
- **web/** - Web platform support with web-specific icons and assets
- **windows/** - Windows platform support with native runner and resources
- **assets/** - Static assets including images, fonts (ProductSans), and localization files

## Language & Runtime
**Language**: Dart  
**SDK Version**: >=3.3.3 <4.0.0  
**Framework**: Flutter  
**Application Version**: 0.1.0+1  
**Build System**: Flutter CLI with Gradle (Android) and Xcode (iOS)  
**Package Manager**: Pub (Dart)

## Dependencies
**Main Dependencies**:
- `just_audio: ^0.10.4` - Audio playback functionality
- `just_audio_background: ^0.0.1-beta.13` - Background audio service
- `permission_handler: ^12.0.0+1` - Runtime permissions handling
- `http: ^1.2.1` - HTTP networking
- `on_audio_query: ^2.9.0` - Query device audio library
- `package_info_plus: ^8.0.0` - App package information
- `shared_preferences: ^2.3.4` - Local data persistence
- `provider: ^6.1.2` - State management
- `palette_generator: ^0.3.3+4` - Color palette extraction from artwork
- `dynamic_color: ^1.7.0` - Material You dynamic colors
- `audio_service: ^0.18.15` - Background audio service integration
- `path_provider: ^2.1.3` - File system paths
- `url_launcher: ^6.2.6` - URL launching
- `flutter_local_notifications: ^19.2.1` - Push notifications
- `flutter_animate: ^4.5.0` - Animation utilities
- `lottie: ^3.2.0` - Lottie animations
- `logger: ^2.5.0` - Logging
- `mesh: ^0.5.0` - Mesh graphics
- `spotify: ^0.13.7` - Spotify API integration
- `device_info_plus: ^11.4.0` - Device information

**Development Dependencies**:
- `flutter_test` - Widget testing framework
- `flutter_lints: ^6.0.0` - Lint rules
- `flutter_native_splash: ^2.4.1` - Native splash screen generation

## Build & Installation
```bash
# Get dependencies
flutter pub get

# Generate code (l10n and other generated files)
flutter pub run build_runner build

# Build APK for Android
flutter build apk --release

# Build debug APK
flutter build apk --debug

# Build AAB for Play Store
flutter build appbundle --release

# Build iOS app
flutter build ios --release

# Run on connected device/emulator
flutter run

# Run tests
flutter test
```

## Main Application Structure
**Entry Point**: `lib/main.dart`
- Initializes error tracking (ErrorTrackingService)
- Loads environment variables from .env file
- Sets up Flutter bindings and audio background service
- Initializes user preferences and theme/locale configuration
- Loads shader warmup for performance optimization

**Core Application Module**: `MyApp` widget that provides:
- Multi-language support with Flutter localization
- Theme management with dynamic Material You colors
- State management with Provider
- Performance mode configuration
- Background audio service initialization

## Configuration Files
- **pubspec.yaml** - Project manifest with dependencies, version, and Flutter configuration
- **.env.example** - Environment variables template for API keys (Spotify, LastFM) and feature flags
- **analysis_options.yaml** - Dart analyzer configuration with Flutter lints
- **android/app/build.gradle** - Android build configuration with Gradle wrapper 8.10.2
- **devtools_options.yaml** - DevTools configuration
- **flutter_icons configuration** - App icon configuration for Android and iOS

## Testing
**Framework**: flutter_test  
**Test Location**: test/  
**Test File**: test/widget_test.dart  
**Naming Convention**: *_test.dart  
**Configuration File**: analysis_options.yaml (includes flutter_lints)

**Run Tests**:
```bash
flutter test
```

**Code Quality**:
```bash
flutter analyze
```

## Platforms Supported
- **Android** (Primary: Android 10+)
- **iOS** (Podfile-based dependency management)
- **Web** (Flutter web support)
- **Windows** (UWP platform support)

## Key Services
The application implements multiple specialized services in `lib/services/`:
- **AudioPlayerService** - Core audio playback management
- **AudioSessionService** - System audio session handling
- **PermissionService** - Runtime permissions
- **PlaylistService** - Playlist CRUD operations
- **PlayCountService** - Track play statistics
- **LyricsService** - Synced lyrics fetching
- **NotificationManager** - System notifications
- **PerformanceMonitoringService** - Performance tracking
- **CacheManager** - Data caching strategies
