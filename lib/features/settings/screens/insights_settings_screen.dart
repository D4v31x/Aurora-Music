/// Insights settings sub-screen — configure the listening recap period.
library;

import 'package:flutter/material.dart';
import 'package:iconoir_flutter/iconoir_flutter.dart' as iconoir;
import 'package:provider/provider.dart';
import '../../../core/constants/font_constants.dart';
import '../../../shared/services/audio_player_service.dart';
import '../../../shared/services/insights_promo_service.dart';
import '../../../shared/widgets/expanding_player.dart';
import '../widgets/settings_tile_builders.dart';

class InsightsSettingsScreen extends StatefulWidget {
  const InsightsSettingsScreen({super.key});

  @override
  State<InsightsSettingsScreen> createState() => _InsightsSettingsScreenState();
}

class _InsightsSettingsScreenState extends State<InsightsSettingsScreen> {
  int _periodDays = InsightsPromoService.defaultPeriodDays;

  @override
  void initState() {
    super.initState();
    InsightsPromoService.getRecapPeriodDays().then((days) {
      if (mounted) setState(() => _periodDays = days);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0A0A0F) : const Color(0xFFF5F5F7),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: iconoir.NavArrowLeft(
            color: isDark ? Colors.white : Colors.black,
            width: 28,
            height: 28,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Insights',
          style: TextStyle(
            fontFamily: FontConstants.fontFamily,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
      ),
      body: Selector<AudioPlayerService, bool>(
        selector: (_, s) => s.currentSong != null,
        builder: (context, hasCurrentSong, _) => ListView(
          padding: EdgeInsets.only(
            top: 10,
            bottom: hasCurrentSong
                ? ExpandingPlayer.getMiniPlayerPaddingHeight(context)
                : MediaQuery.of(context).padding.bottom + 24,
          ),
          children: [
            SettingsTiles.buildSectionHeader(context, 'Listening Recap'),
            SettingsTiles.buildGlassmorphicCard(context, children: [
              SettingsTiles.buildSegmentedChoiceTile(
                context,
                icon: Icon(
                  Icons.calendar_month_rounded,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
                title: 'Recap Period',
                subtitle: 'How far back your recap looks',
                options: const ['Last 7 Days', 'Last 30 Days'],
                selectedIndex: _periodDays == 7 ? 0 : 1,
                onChanged: (i) async {
                  final days = i == 0 ? 7 : 30;
                  await InsightsPromoService.setRecapPeriodDays(days);
                  if (mounted) setState(() => _periodDays = days);
                },
                isFirst: true,
              ),
            ]),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
              child: Text(
                'Your recap is a period-based overview of your most-played tracks, '
                'artists and listening habits. Switch between 7-day and 30-day views '
                'to get a weekly or monthly picture.',
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: FontConstants.fontFamily,
                  color: isDark
                      ? Colors.white.withOpacity(0.45)
                      : Colors.black.withOpacity(0.45),
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
