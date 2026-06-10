/// Insights settings sub-screen — recap schedule & period.
library;

import 'package:flutter/material.dart';
import 'package:iconoir_flutter/iconoir_flutter.dart' as iconoir;
import 'package:provider/provider.dart';
import '../../../core/constants/font_constants.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/services/audio_player_service.dart';
import '../../../shared/services/insights_promo_service.dart';
import '../../../shared/widgets/app_background.dart';
import '../../../shared/widgets/expanding_player.dart';
import '../../home/screens/listening_recap_screen.dart';
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
    final l10n   = AppLocalizations.of(context);

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
          l10n.settingsInsights,
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
            SettingsTiles.buildSectionHeader(context, l10n.settingsRecapSchedule),
            SettingsTiles.buildGlassmorphicCard(context, children: [
              SettingsTiles.buildSwitchTile(
                context,
                icon: Icon(Icons.calendar_view_week_rounded,
                    color: cs.primary, size: 20),
                title: l10n.settingsWeeklyRecap,
                subtitle: l10n.settingsWeeklyRecapDesc,
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
                title: l10n.settingsMonthlyRecap,
                subtitle: l10n.settingsMonthlyRecapDesc,
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
                l10n.settingsRecapBannerDesc,
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: FontConstants.fontFamily,
                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.45),
                  height: 1.5,
                ),
              ),
            ),

            // ── RECAP CONTENT ────────────────────────────────────────────
            SettingsTiles.buildSectionHeader(context, l10n.settingsRecapContent),
            SettingsTiles.buildGlassmorphicCard(context, children: [
              SettingsTiles.buildSegmentedChoiceTile(
                context,
                icon: Icon(Icons.bar_chart_rounded,
                    color: cs.primary, size: 20),
                title: l10n.settingsDataWindow,
                subtitle: l10n.settingsDataWindowDesc,
                options: [l10n.settingsLast7Days, l10n.settingsLast30Days],
                selectedIndex: _periodDays == 7 ? 0 : 1,
                onChanged: (i) async {
                  final days = i == 0 ? 7 : 30;
                  await InsightsPromoService.setRecapPeriodDays(days);
                  if (mounted) setState(() => _periodDays = days);
                },
                isFirst: true,
              ),
              SettingsTiles.buildActionTile(
                context,
                icon: Icon(Icons.play_circle_outline_rounded,
                    color: cs.primary, size: 20),
                title: l10n.settingsPreviewRecap,
                subtitle: l10n.settingsPreviewRecapDesc,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ListeningRecapScreen(),
                    ),
                  );
                },
              ),
            ]),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 10, 22, 0),
              child: Text(
                l10n.settingsRecapContentDesc,
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
