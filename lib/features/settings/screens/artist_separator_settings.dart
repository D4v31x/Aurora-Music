import 'package:aurora_music_v01/core/constants/font_constants.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../shared/services/artist_separator_service.dart';
import '../../../shared/services/audio_player_service.dart';
import '../../../shared/widgets/app_background.dart';
import '../../../shared/widgets/expanding_player.dart';
import '../../../l10n/app_localizations.dart';

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

    return AppBackground(
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            l10n.translate('artist_separation'),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          backgroundColor: Colors.black.withValues(alpha: 0.45),
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            IconButton(
              icon: Icon(Icons.restore_rounded,
                  color: Colors.white.withValues(alpha: 0.7)),
              onPressed: _showResetDialog,
              tooltip: l10n.translate('reset'),
            ),
          ],
        ),
        body: Selector<AudioPlayerService, bool>(
          selector: (_, svc) => svc.currentSong != null,
          builder: (context, hasCurrentSong, _) => ListView(
            padding: EdgeInsets.fromLTRB(
              16,
              0,
              16,
              hasCurrentSong
                  ? ExpandingPlayer.getMiniPlayerPaddingHeight(context)
                  : MediaQuery.of(context).padding.bottom + 24,
            ),
            children: [
          const SizedBox(height: kToolbarHeight + 32),

          // ── Enable toggle ─────────────────────────────────────
          _sectionLabel('SETTINGS'),
          const SizedBox(height: 10),
          _glassCard(
            child: SwitchListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              title: Text(
                l10n.translate('enable_artist_separation'),
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                l10n.translate('enable_artist_separation_desc'),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 12,
                ),
              ),
              value: _isEnabled,
              activeThumbColor: Colors.blue,
              onChanged: (value) async {
                await _service.setEnabled(value);
                setState(() => _isEnabled = value);
                _updateTestResult();
              },
            ),
          ),

          const SizedBox(height: 28),

          // ── Test section ──────────────────────────────────────
          _sectionLabel('TEST'),
          const SizedBox(height: 10),
          _glassCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Input field
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.15)),
                    ),
                    child: TextField(
                      controller: _testController,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      onChanged: (_) => _updateTestResult(),
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        border: InputBorder.none,
                        hintText:
                            'e.g. Artist One/Artist Two feat. Three',
                        hintStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.28),
                            fontSize: 13),
                        suffixIcon: IconButton(
                          icon: Icon(Icons.refresh_rounded,
                              color: Colors.white.withValues(alpha: 0.4),
                              size: 18),
                          onPressed: _updateTestResult,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'RESULT',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_testResult.isEmpty)
                    Text(
                      '—',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.3),
                          fontSize: 14),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children:
                          _testResult.asMap().entries.map((e) {
                        const colors = [
                          Colors.blue,
                          Colors.purple,
                          Colors.teal,
                          Colors.orange,
                          Colors.pink,
                        ];
                        final c = colors[e.key % colors.length];
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: c.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: c.withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            e.value,
                            style: TextStyle(
                                color: c.withValues(alpha: 0.9),
                                fontSize: 13,
                                fontWeight: FontWeight.w500),
                          ),
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 28),

          // ── Separators ────────────────────────────────────────
          Row(
            children: [
              Expanded(
                  child: _sectionLabel(
                      l10n.translate('separators').toUpperCase())),
              TextButton.icon(
                onPressed: _showAddSeparatorDialog,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.blue.shade300,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _glassCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _separators.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          l10n.translate('no_separators'),
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.3),
                              fontSize: 13),
                        ),
                      ),
                    )
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

          // ── Exclusions ────────────────────────────────────────
          Row(
            children: [
              Expanded(
                  child: _sectionLabel(
                      l10n.translate('exclusions').toUpperCase())),
              TextButton.icon(
                onPressed: _showAddExclusionDialog,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.blue.shade300,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            l10n.translate('exclusions_desc'),
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.35), fontSize: 12),
          ),
          const SizedBox(height: 12),
          _glassCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _exclusions.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          l10n.translate('no_exclusions'),
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.3),
                              fontSize: 13),
                        ),
                      ),
                    )
                  : Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _exclusions.map((ex) {
                        return _chipTag(
                          label: ex,
                          accent: Colors.purple,
                          onDelete: () => _removeExclusion(ex),
                        );
                      }).toList(),
                    ),
            ),
          ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.4,
        color: Colors.white.withValues(alpha: 0.45),
      ),
    );
  }

  Widget _glassCard({required Widget child}) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: child,
    );
  }

  Widget _chipTag({
    required String label,
    Color accent = Colors.blue,
    bool mono = false,
    required VoidCallback onDelete,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 13,
              fontFamily:
                  mono ? FontConstants.monospaceFontFamily : null,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onDelete,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(Icons.close,
                  size: 11,
                  color: Colors.white.withValues(alpha: 0.55)),
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
          backgroundColor: Colors.grey[900]?.withValues(alpha: 0.9),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
          title: Text(
            l10n.translate('add_separator'),
            style: const TextStyle(
              fontFamily: FontConstants.fontFamily,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: const TextStyle(
              fontFamily: FontConstants.fontFamily,
              color: Colors.white,
            ),
            decoration: InputDecoration(
              labelText: l10n.translate('separator'),
              hintText: l10n.translate('separator_hint'),
              labelStyle: const TextStyle(color: Colors.white70),
              hintStyle: const TextStyle(color: Colors.white38),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.white),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                l10n.translate('cancel'),
                style: const TextStyle(
                  fontFamily: FontConstants.fontFamily,
                  color: Colors.white70,
                ),
              ),
            ),
            TextButton(
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
                l10n.translate('add'),
                style: const TextStyle(
                  fontFamily: FontConstants.fontFamily,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
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
          backgroundColor: Colors.grey[900]?.withValues(alpha: 0.9),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
          title: Text(
            l10n.translate('add_exclusion'),
            style: const TextStyle(
              fontFamily: FontConstants.fontFamily,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: const TextStyle(
              fontFamily: FontConstants.fontFamily,
              color: Colors.white,
            ),
            decoration: InputDecoration(
              labelText: l10n.translate('artist_name'),
              hintText: l10n.translate('exclusion_hint'),
              labelStyle: const TextStyle(color: Colors.white70),
              hintStyle: const TextStyle(color: Colors.white38),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.white),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                l10n.translate('cancel'),
                style: const TextStyle(
                  fontFamily: FontConstants.fontFamily,
                  color: Colors.white70,
                ),
              ),
            ),
            TextButton(
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
                l10n.translate('add'),
                style: const TextStyle(
                  fontFamily: FontConstants.fontFamily,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
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
          backgroundColor: Colors.grey[900]?.withValues(alpha: 0.9),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
          title: Text(
            l10n.translate('reset_to_defaults'),
            style: const TextStyle(
              fontFamily: FontConstants.fontFamily,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            l10n.translate('reset_artist_separation_desc'),
            style: const TextStyle(
              fontFamily: FontConstants.fontFamily,
              color: Colors.white70,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                l10n.translate('cancel'),
                style: const TextStyle(
                  fontFamily: FontConstants.fontFamily,
                  color: Colors.white70,
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                await _service.resetToDefaults();
                await _loadSettings();
                if (context.mounted) Navigator.pop(context);
              },
              child: Text(
                l10n.translate('reset'),
                style: const TextStyle(
                  fontFamily: FontConstants.fontFamily,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
    );
  }
}
