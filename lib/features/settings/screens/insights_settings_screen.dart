/// Insights settings sub-screen — recap schedule & period.
library;

import 'package:flutter/material.dart';
import 'package:iconoir_flutter/iconoir_flutter.dart' as iconoir;
import 'package:provider/provider.dart';
import '../../../core/constants/font_constants.dart';
import '../../../shared/services/audio_player_service.dart';
import '../../../shared/services/insights_promo_service.dart';
import '../../../shared/widgets/app_background.dart';
import '../../../shared/widgets/expanding_player.dart';
import '../widgets/settings_tile_builders.dart';

class InsightsSettingsScreen extends StatefulWidget {
  const InsightsSettingsScreen({super.key});

  @override
  State<InsightsSettingsScreen> createState() => _InsightsSettingsScreenState();
}

class _InsightsSettingsScreenState extends State<InsightsSettingsScreen> {
  int  _periodDays     = InsightsPromoService.defaultPeriodDays;
  bool _weeklyEnabled  = true;
  bool _monthlyEnabled = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final period  = await InsightsPromoService.getRecapPeriodDays();
    final weekly  = await InsightsPromoService.getWeeklyEnabled();
    final monthly = await InsightsPromoService.getMonthlyEnabled();
    if (mounted) {
      setState(() {
        _periodDays     = period;
        _weeklyEnabled  = weekly;
        _monthlyEnabled = monthly;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs     = Theme.of(context).colorScheme;

    return AppBackground(child: Scaffold(
      backgroundColor: Colors.transparent,
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
            // ── RECAP SCHEDULE ──────────────────────────────────────────
            SettingsTiles.buildSectionHeader(context, 'Recap Schedule'),
            SettingsTiles.buildGlassmorphicCard(context, children: [
              SettingsTiles.buildSwitchTile(
                context,
                icon: Icon(Icons.calendar_view_week_rounded,
                    color: cs.primary, size: 20),
                title: 'Weekly Recap',
                subtitle: 'Show a banner every week after your first play',
                value: _weeklyEnabled,
                onChanged: (v) async {
                  await InsightsPromoService.setWeeklyEnabled(v);
                  if (mounted) setState(() => _weeklyEnabled = v);
                },
                isFirst: true,
              ),
              SettingsTiles.buildSwitchTile(
                context,
                icon: Icon(Icons.calendar_month_rounded,
                    color: cs.primary, size: 20),
                title: 'Monthly Recap',
                subtitle: 'Show a banner every month (takes precedence over weekly)',
                value: _monthlyEnabled,
                onChanged: (v) async {
                  await InsightsPromoService.setMonthlyEnabled(v);
                  if (mounted) setState(() => _monthlyEnabled = v);
                },
              ),
            ]),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 10, 22, 0),
              child: Text(
                'The banner appears on the home screen at the start of each new '
                'week or month counted from your very first play. Tapping "Later" '
                'hides it for the session; tapping "Show" marks it as seen.',
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: FontConstants.fontFamily,
                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.45),
                  height: 1.5,
                ),
              ),
            ),

            // ── RECAP CONTENT ────────────────────────────────────────────
            SettingsTiles.buildSectionHeader(context, 'Recap Content'),
            SettingsTiles.buildGlassmorphicCard(context, children: [
              SettingsTiles.buildSegmentedChoiceTile(
                context,
                icon: Icon(Icons.bar_chart_rounded,
                    color: cs.primary, size: 20),
                title: 'Data Window',
                subtitle: 'How far back the recap screen looks',
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
              padding: const EdgeInsets.fromLTRB(22, 10, 22, 0),
              child: Text(
                'Controls how much history the recap screen displays when you open it '
                'manually or via the banner.',
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: FontConstants.fontFamily,
                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.45),
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    ),
    );
  }
}
