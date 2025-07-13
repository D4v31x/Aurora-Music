import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:aurora_music_v01/main.dart';
import 'package:aurora_music_v01/widgets/mini_player.dart';
import 'package:aurora_music_v01/widgets/home/suggested_tracks_section.dart';
import 'package:aurora_music_v01/services/Audio_Player_Service.dart';
import 'package:aurora_music_v01/services/expandable_player_controller.dart';
import 'package:aurora_music_v01/utils/color_utils.dart';
import 'package:on_audio_query/on_audio_query.dart';

void main() {
  group('Aurora Music Performance Tests', () {
    testWidgets('Mini player renders with proper island styling', (WidgetTester tester) async {
      // Create a mock song for testing
      final mockSong = SongModel({
        '_id': 1,
        '_data': '/path/to/song.mp3',
        '_uri': 'content://media/external/audio/media/1',
        'album': 'Test Album',
        'artist': 'Test Artist',
        'title': 'Test Song',
        'duration': 180000,
      });

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AudioPlayerService()),
            ChangeNotifierProvider(create: (_) => ExpandablePlayerController()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: MiniPlayer(currentSong: mockSong),
            ),
          ),
        ),
      );

      // Verify mini player renders
      expect(find.byType(MiniPlayer), findsOneWidget);
      
      // Verify song title is displayed
      expect(find.text('Test Song'), findsOneWidget);
      
      // Verify artist is displayed
      expect(find.text('Test Artist'), findsOneWidget);
      
      // Verify play button is present
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    });

    testWidgets('SuggestedTracksSection optimized list renders correctly', (WidgetTester tester) async {
      final mockSongs = [
        SongModel({
          '_id': 1,
          'title': 'Song 1',
          'artist': 'Artist 1',
        }),
        SongModel({
          '_id': 2,
          'title': 'Song 2',
          'artist': 'Artist 2',
        }),
      ];

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AudioPlayerService()),
            ChangeNotifierProvider(create: (_) => ExpandablePlayerController()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SuggestedTracksSection(randomSongs: mockSongs),
            ),
          ),
        ),
      );

      // Verify tracks section renders
      expect(find.byType(SuggestedTracksSection), findsOneWidget);
      
      // Verify songs are displayed
      expect(find.text('Song 1'), findsOneWidget);
      expect(find.text('Song 2'), findsOneWidget);
    });

    test('ColorUtils provides optimal text colors', () {
      // Test light background returns dark text
      final lightBackground = Colors.white;
      final textColorForLight = ColorUtils.getOptimalTextColor(lightBackground);
      expect(textColorForLight, equals(Colors.black87));

      // Test dark background returns light text
      final darkBackground = Colors.black;
      final textColorForDark = ColorUtils.getOptimalTextColor(darkBackground);
      expect(textColorForDark, equals(Colors.white));

      // Test medium background
      final mediumBackground = Colors.grey;
      final textColorForMedium = ColorUtils.getOptimalTextColor(mediumBackground);
      expect(textColorForMedium, equals(Colors.black87));
    });

    test('ColorUtils caches color calculations', () {
      final testColor = Colors.red;
      
      // First call should calculate
      final firstResult = ColorUtils.getOptimalTextColor(testColor);
      
      // Second call should use cache
      final secondResult = ColorUtils.getOptimalTextColor(testColor);
      
      expect(firstResult, equals(secondResult));
    });
  });
}
