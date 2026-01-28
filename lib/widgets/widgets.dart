/// Aurora Music Widgets
///
/// This library exports all reusable UI components in the application,
/// organized by category:
/// - Core: Common UI components used throughout the app
/// - Player: Player-specific reusable widgets
/// - Common: Shared utility widgets
/// - Home: Widgets specific to home screen tabs
/// - Dialogs: Dialog and sheet components
/// - Backgrounds: Background and visual effect widgets
library;

// Core widgets
export 'common_screen_scaffold.dart';
export 'glassmorphic_container.dart';
export 'glassmorphic_card.dart';
export 'pill_button.dart';
export 'optimized_tiles.dart';
export 'shimmer_loading.dart';
export 'outline_indicator.dart';
export 'auto_scroll_text.dart';
export 'artist_card.dart';
export 'music_metadata_widget.dart';
export 'responsive_scaffold.dart';
export 'expanding_player.dart';
export 'toast_notification.dart';
export 'song_picker_sheet.dart';

// Player widgets
export 'player/player.dart';

// Common widgets
export 'common/common.dart';

// Dialogs and sheets
export 'about_dialog.dart';
export 'changelog_dialog.dart';
export 'glassmorphic_dialog.dart';
export 'feedback_reminder_dialog.dart';

// Backgrounds and visual effects
export 'app_background.dart';
export 'animated_artwork_background.dart';
export 'grainy_gradient_background.dart';

// Debug and performance
export 'performance_debug_overlay.dart';
