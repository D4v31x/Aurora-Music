import 'package:aurora_music_v01/core/constants/font_constants.dart';
import 'package:flutter/material.dart';
import 'package:iconoir_flutter/iconoir_flutter.dart' as Iconoir;
import 'package:provider/provider.dart';
import '../../../shared/services/artist_separator_service.dart';
import '../../../shared/services/audio_player_service.dart';
import '../../../shared/providers/performance_mode_provider.dart';
import '../../../shared/widgets/app_background.dart';
import '../../../shared/widgets/expanding_player.dart';
import '../../../l10n/generated/app_localizations.dart';

/// Settings screen for configuring artist name separation
class ArtistSeparatorSettingsScreen extends StatefulWidget {
  const ArtistSeparatorSettingsScreen({super.key});

  @override
  State<ArtistSeparatorSettingsScreen> createState() =>
      _ArtistSeparatorSettingsScreenState();
}

class _ArtistSeparatorSettingsScreenState
    extends State<ArtistSeparatorSettingsScreen> {
  final ArtistSeparatorService _service = ArtistSeparatorService();
  bool _isEnabled = true;
  List<String> _separators = [];
  List<String> _exclusions = [];
  final TextEditingController _testController = TextEditingController();
  List<String> _testResult = [];

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _testController.text = 'Artist One/Artist Two feat. Artist Three';
    _updateTestResult();
  }

  @override
  void dispose() {
    _testController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    await _service.initialize();
    setState(() {
      _isEnabled = _service.isEnabled;
      _separators = List.from(_service.separators);
      _exclusions = List.from(_service.exclusions);
    });
    _updateTestResult();
  }

  void _updateTestResult() {
    setState(() {
      _testResult = _service.splitArtists(_testController.text);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.surface,
          elevation: 0,
          leading: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Iconoir.NavArrowLeft(
                color: colorScheme.onSurface,
                width: 28,
                height: 28,
              ),
            ),
          ),
          title: Text(
            l10n.artistSeparation,
            style: TextStyle(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.bold,
              fontSize: 18,
              fontFamily: FontConstants.fontFamily,
            ),
          ),
          actions: [
            GestureDetector(
              onTap: _showResetDialog,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Iconoir.Refresh(
                  color: colorScheme.onSurface.withValues(alpha: 0.7),
                  width: 22,
                  height: 22,
                ),
              ),
            ),
          ],
        ),
        body: Selector<AudioPlayerService, bool>(
          selector: (_, svc) => svc.currentSong != null,
          builder: (context, hasCurrentSong, _) => ListView(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              hasCurrentSong
                  ? ExpandingPlayer.getMiniPlayerPaddingHeight(context)
                  : MediaQuery.of(context).padding.bottom + 24,
            ),
            children: [
              // ── Enable toggle ──────────────────────────────────
              _glassCard(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.enableArtistSeparation,
                              style: TextStyle(
                                color: colorScheme.onSurface,
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                fontFamily: FontConstants.fontFamily,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              l10n.enableArtistSeparationDesc,
                              style: TextStyle(
                                color: colorScheme.onSurface.withValues(alpha: 0.5),
                                fontSize: 12,
                                fontFamily: FontConstants.fontFamily,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Switch(
                        value: _isEnabled,
                        onChanged: (value) async {
                          await _service.setEnabled(value);
                          setState(() => _isEnabled = value);
                          _updateTestResult();
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // ── Separators ─────────────────────────────────────
              _sectionLabelWithAction(
                label: l10n.separators.toUpperCase(),
                icon: Iconoir.Slash(
                    color: colorScheme.onSurface.withValues(alpha: 0.65),
                    width: 15,
                    height: 15),
                onAction: _showAddSeparatorDialog,
                actionLabel: l10n.add,
              ),
              const SizedBox(height: 10),
              _glassCard(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _separators.isEmpty
                      ? _emptyState(l10n.noSeparators)
                      : Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _separators.map((sep) {
                            return _chipTag(
                              label: _formatSeparatorForDisplay(sep),
                              mono: true,
                              onDelete: () => _removeSeparator(sep),
                            );
                          }).toList(),
                        ),
                ),
              ),

              const SizedBox(height: 28),

              // ── Exclusions ─────────────────────────────────────
              _sectionLabelWithAction(
                label: l10n.exclusions.toUpperCase(),
                icon: Iconoir.FilterAlt(
                    color: colorScheme.onSurface.withValues(alpha: 0.65),
                    width: 15,
                    height: 15),
                onAction: _showAddExclusionDialog,
                actionLabel: l10n.add,
              ),
              const SizedBox(height: 6),
              Text(
                l10n.exclusionsDesc,
                style: TextStyle(
                    color: colorScheme.onSurface.withValues(alpha: 0.45),
                    fontSize: 12),
              ),
              const SizedBox(height: 10),
              _glassCard(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _exclusions.isEmpty
                      ? _emptyState(l10n.noExclusions)
                      : Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _exclusions.map((ex) {
                            return _chipTag(
                              label: ex,
                              onDelete: () => _removeExclusion(ex),
                            );
                          }).toList(),
                        ),
                ),
              ),

              const SizedBox(height: 28),

              // ── Test ───────────────────────────────────────────
              _sectionLabel(
                'TEST',
                icon: Iconoir.Flask(
                    color: colorScheme.onSurface.withValues(alpha: 0.65),
                    width: 15,
                    height: 15),
              ),
              const SizedBox(height: 10),
              _glassCard(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Input field
                      Builder(builder: (ctx) {
                        final isLowEnd = Provider.of<PerformanceModeProvider>(ctx, listen: false).isLowEndDevice;
                        final cs = Theme.of(ctx).colorScheme;
                        return DecoratedBox(
                          decoration: BoxDecoration(
                            color: isLowEnd
                                ? cs.surfaceContainer
                                : Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isLowEnd
                                  ? cs.outlineVariant
                                  : Colors.white.withValues(alpha: 0.15),
                            ),
                          ),
                          child: TextField(
                            controller: _testController,
                            style: TextStyle(color: cs.onSurface, fontSize: 14),
                            onChanged: (_) => _updateTestResult(),
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              border: InputBorder.none,
                              hintText: 'e.g. Artist One / Artist Two feat. Three',
                              hintStyle: TextStyle(
                                  color: cs.onSurface.withValues(alpha: 0.35),
                                  fontSize: 13),
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 14),
                      if (_testResult.isEmpty)
                        Text(
                          '—',
                          style: TextStyle(
                              color: colorScheme.onSurface.withValues(alpha: 0.35),
                              fontSize: 14),
                        )
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _testResult.map((name) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: colorScheme.secondaryContainer,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: colorScheme.secondary
                                        .withValues(alpha: 0.35)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Iconoir.User(
                                    color: colorScheme.onSecondaryContainer,
                                    width: 13,
                                    height: 13,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    name,
                                    style: TextStyle(
                                      color: colorScheme.onSecondaryContainer,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      fontFamily: FontConstants.fontFamily,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text, {Widget? icon}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        if (icon != null) ...[
          icon,
          const SizedBox(width: 6),
        ],
        Text(
          text,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: colorScheme.onSurface.withValues(alpha: 0.75),
            fontFamily: FontConstants.fontFamily,
          ),
        ),
      ],
    );
  }

  Widget _sectionLabelWithAction({
    required String label,
    Widget? icon,
    required VoidCallback onAction,
    required String actionLabel,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        if (icon != null) ...[
          icon,
          const SizedBox(width: 6),
        ],
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: colorScheme.onSurface.withValues(alpha: 0.75),
              fontFamily: FontConstants.fontFamily,
            ),
          ),
        ),
        FilledButton.tonalIcon(
          onPressed: onAction,
          style: FilledButton.styleFrom(
            minimumSize: Size.zero,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
          icon: Iconoir.Plus(
            color: colorScheme.onSecondaryContainer,
            width: 14,
            height: 14,
          ),
          label: Text(
            actionLabel,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              fontFamily: FontConstants.fontFamily,
              color: colorScheme.onSecondaryContainer,
            ),
          ),
        ),
      ],
    );
  }

  Widget _emptyState(String message) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          message,
          style: TextStyle(
            color: colorScheme.onSurface.withValues(alpha: 0.38),
            fontSize: 13,
            fontFamily: FontConstants.fontFamily,
          ),
        ),
      ),
    );
  }

  Widget _glassCard({required Widget child}) {
    final isLowEnd = Provider.of<PerformanceModeProvider>(context, listen: false).isLowEndDevice;
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isLowEnd
            ? colorScheme.surfaceContainerHigh
            : Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isLowEnd
              ? colorScheme.outlineVariant
              : Colors.white.withValues(alpha: 0.10),
        ),
      ),
      child: child,
    );
  }

  Widget _chipTag({
    required String label,
    bool mono = false,
    required VoidCallback onDelete,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 13,
              fontFamily:
                  mono ? FontConstants.monospaceFontFamily : FontConstants.fontFamily,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onDelete,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Iconoir.Xmark(
                  width: 12,
                  height: 12,
                  color: colorScheme.onErrorContainer,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatSeparatorForDisplay(String separator) {
    if (separator == ' ') return '(space)';
    if (separator.trim().isEmpty) return '"$separator"';
    return separator;
  }

  void _showAddSeparatorDialog() {
    final controller = TextEditingController();
    final l10n = AppLocalizations.of(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          l10n.addSeparator,
          style: const TextStyle(
            fontFamily: FontConstants.fontFamily,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(fontFamily: FontConstants.fontFamily),
          decoration: InputDecoration(
            labelText: l10n.separator,
            hintText: l10n.separatorHint,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              l10n.cancel,
              style: const TextStyle(fontFamily: FontConstants.fontFamily),
            ),
          ),
          FilledButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                await _service.addSeparator(controller.text);
                setState(() {
                  _separators = List.from(_service.separators);
                });
                _updateTestResult();
              }
              if (context.mounted) Navigator.pop(context);
            },
            child: Text(
              l10n.add,
              style: const TextStyle(fontFamily: FontConstants.fontFamily),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddExclusionDialog() {
    final controller = TextEditingController();
    final l10n = AppLocalizations.of(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          l10n.addExclusion,
          style: const TextStyle(
            fontFamily: FontConstants.fontFamily,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(fontFamily: FontConstants.fontFamily),
          decoration: InputDecoration(
            labelText: l10n.artistName,
            hintText: l10n.exclusionHint,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              l10n.cancel,
              style: const TextStyle(fontFamily: FontConstants.fontFamily),
            ),
          ),
          FilledButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                await _service.addExclusion(controller.text);
                setState(() {
                  _exclusions = List.from(_service.exclusions);
                });
                _updateTestResult();
              }
              if (context.mounted) Navigator.pop(context);
            },
            child: Text(
              l10n.add,
              style: const TextStyle(fontFamily: FontConstants.fontFamily),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _removeSeparator(String separator) async {
    await _service.removeSeparator(separator);
    setState(() {
      _separators = List.from(_service.separators);
    });
    _updateTestResult();
  }

  Future<void> _removeExclusion(String exclusion) async {
    await _service.removeExclusion(exclusion);
    setState(() {
      _exclusions = List.from(_service.exclusions);
    });
    _updateTestResult();
  }

  void _showResetDialog() {
    final l10n = AppLocalizations.of(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          l10n.resetToDefaults,
          style: const TextStyle(
            fontFamily: FontConstants.fontFamily,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          l10n.resetArtistSeparationDesc,
          style: const TextStyle(fontFamily: FontConstants.fontFamily),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              l10n.cancel,
              style: const TextStyle(fontFamily: FontConstants.fontFamily),
            ),
          ),
          FilledButton(
            onPressed: () async {
              await _service.resetToDefaults();
              await _loadSettings();
              if (context.mounted) Navigator.pop(context);
            },
            child: Text(
              l10n.reset,
              style: const TextStyle(fontFamily: FontConstants.fontFamily),
            ),
          ),
        ],
      ),
    );
  }
}
