import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/artist_separator_service.dart';
import '../localization/app_localizations.dart';

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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(l10n.translate('artist_separation')),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.restore),
            onPressed: _showResetDialog,
            tooltip: l10n.translate('reset'),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [Colors.black, Colors.grey.shade900]
                : [Colors.grey.shade100, Colors.white],
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Enable/Disable toggle
              _buildGlassmorphicCard(
                isDark: isDark,
                child: SwitchListTile(
                  title: Text(
                    l10n.translate('enable_artist_separation'),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    l10n.translate('enable_artist_separation_desc'),
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                    ),
                  ),
                  value: _isEnabled,
                  onChanged: (value) async {
                    await _service.setEnabled(value);
                    setState(() => _isEnabled = value);
                    _updateTestResult();
                  },
                ),
              ),

              const SizedBox(height: 24),

              // Test section
              _buildSectionHeader(l10n.translate('test_separation')),
              _buildGlassmorphicCard(
                isDark: isDark,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _testController,
                        decoration: InputDecoration(
                          labelText: l10n.translate('test_artist_string'),
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.refresh),
                            onPressed: _updateTestResult,
                          ),
                        ),
                        onChanged: (_) => _updateTestResult(),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l10n.translate('result'),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _testResult
                            .map((artist) => Chip(
                                  label: Text(artist),
                                  backgroundColor: theme.colorScheme.primary
                                      .withOpacity(0.15),
                                ))
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Separators section
              _buildSectionHeader(l10n.translate('separators')),
              _buildGlassmorphicCard(
                isDark: isDark,
                child: Column(
                  children: [
                    ListTile(
                      title: Text(l10n.translate('separators_desc')),
                      trailing: IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: () => _showAddSeparatorDialog(),
                      ),
                    ),
                    const Divider(height: 1),
                    if (_separators.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          l10n.translate('no_separators'),
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _separators.length,
                        itemBuilder: (context, index) {
                          final separator = _separators[index];
                          return ListTile(
                            title: Text(
                              _formatSeparatorForDisplay(separator),
                              style: const TextStyle(fontFamily: 'monospace'),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: Colors.red),
                              onPressed: () => _removeSeparator(separator),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Exclusions section
              _buildSectionHeader(l10n.translate('exclusions')),
              _buildGlassmorphicCard(
                isDark: isDark,
                child: Column(
                  children: [
                    ListTile(
                      title: Text(l10n.translate('exclusions_desc')),
                      trailing: IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: () => _showAddExclusionDialog(),
                      ),
                    ),
                    const Divider(height: 1),
                    if (_exclusions.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          l10n.translate('no_exclusions'),
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _exclusions.length,
                        itemBuilder: (context, index) {
                          final exclusion = _exclusions[index];
                          return ListTile(
                            title: Text(exclusion),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: Colors.red),
                              onPressed: () => _removeExclusion(exclusion),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildGlassmorphicCard({
    required bool isDark,
    required Widget child,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.08)
                : Colors.black.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.12)
                  : Colors.black.withOpacity(0.08),
            ),
          ),
          child: child,
        ),
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
        title: Text(l10n.translate('add_separator')),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: l10n.translate('separator'),
            hintText: l10n.translate('separator_hint'),
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.translate('cancel')),
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
            child: Text(l10n.translate('add')),
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
        title: Text(l10n.translate('add_exclusion')),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: l10n.translate('artist_name'),
            hintText: l10n.translate('exclusion_hint'),
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.translate('cancel')),
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
            child: Text(l10n.translate('add')),
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
        title: Text(l10n.translate('reset_to_defaults')),
        content: Text(l10n.translate('reset_artist_separation_desc')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.translate('cancel')),
          ),
          FilledButton(
            onPressed: () async {
              await _service.resetToDefaults();
              await _loadSettings();
              if (context.mounted) Navigator.pop(context);
            },
            child: Text(l10n.translate('reset')),
          ),
        ],
      ),
    );
  }
}
