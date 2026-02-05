/// Smart playlist builder screen.
///
/// Allows users to create and edit smart playlists with rule-based filtering.
library;

import 'dart:ui';
import 'package:aurora_music_v01/core/constants/font_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/services/smart_playlist_service.dart';
import '../../../shared/widgets/glassmorphic_container.dart';

/// Screen for creating and editing smart playlists.
class SmartPlaylistBuilderScreen extends StatefulWidget {
  final SmartPlaylist? existingPlaylist;

  const SmartPlaylistBuilderScreen({
    super.key,
    this.existingPlaylist,
  });

  @override
  State<SmartPlaylistBuilderScreen> createState() =>
      _SmartPlaylistBuilderScreenState();
}

class _SmartPlaylistBuilderScreenState
    extends State<SmartPlaylistBuilderScreen> {
  final SmartPlaylistService _service = SmartPlaylistService();
  final _nameController = TextEditingController();
  final List<SmartPlaylistRule> _rules = [];
  RuleMatch _matchType = RuleMatch.all;
  int? _limit;
  bool _sortByPlayCount = false;
  bool _sortDescending = true;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initializeService();
  }

  Future<void> _initializeService() async {
    await _service.initialize();

    if (widget.existingPlaylist != null) {
      _nameController.text = widget.existingPlaylist!.name;
      _rules.addAll(widget.existingPlaylist!.rules);
      _matchType = widget.existingPlaylist!.matchType;
      _limit = widget.existingPlaylist!.limit;
      _sortByPlayCount = widget.existingPlaylist!.sortByPlayCount;
      _sortDescending = widget.existingPlaylist!.sortDescending;
    }

    if (mounted) {
      setState(() => _initialized = true);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);
    final isEditing = widget.existingPlaylist != null;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0A0A0F) : const Color(0xFFF5F5F7),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.close_rounded,
            color: isDark ? Colors.white : Colors.black,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isEditing
              ? l10n.translate('editRules')
              : l10n.translate('createSmartPlaylist'),
          style: TextStyle(
            fontFamily: FontConstants.fontFamily,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _canSave() ? _savePlaylist : null,
            child: Text(
              l10n.translate('save'),
              style: TextStyle(
                fontFamily: FontConstants.fontFamily,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: !_initialized
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Playlist name
                _buildNameField(isDark, l10n),

                const SizedBox(height: 24),

                // Match type
                _buildMatchTypeSelector(isDark, l10n),

                const SizedBox(height: 24),

                // Rules section
                _buildRulesSection(isDark, l10n),

                const SizedBox(height: 24),

                // Options section
                _buildOptionsSection(isDark, l10n),

                const SizedBox(height: 100),
              ],
            ),
    );
  }

  Widget _buildNameField(bool isDark, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'PLAYLIST NAME',
            style: TextStyle(
              fontFamily: FontConstants.fontFamily,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: (isDark ? Colors.white : Colors.black).withOpacity(0.5),
              letterSpacing: 1.2,
            ),
          ),
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                color: (isDark ? Colors.white : Colors.black).withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color:
                      (isDark ? Colors.white : Colors.black).withOpacity(0.1),
                ),
              ),
              child: TextField(
                controller: _nameController,
                style: TextStyle(
                  fontFamily: FontConstants.fontFamily,
                  color: isDark ? Colors.white : Colors.black,
                ),
                decoration: InputDecoration(
                  hintText: 'Enter playlist name',
                  hintStyle: TextStyle(
                    color:
                        (isDark ? Colors.white : Colors.black).withOpacity(0.4),
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMatchTypeSelector(bool isDark, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'RULE MATCHING',
            style: TextStyle(
              fontFamily: FontConstants.fontFamily,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: (isDark ? Colors.white : Colors.black).withOpacity(0.5),
              letterSpacing: 1.2,
            ),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: _MatchTypeChip(
                label: l10n.translate('matchAll'),
                isSelected: _matchType == RuleMatch.all,
                isDark: isDark,
                onTap: () => setState(() => _matchType = RuleMatch.all),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MatchTypeChip(
                label: l10n.translate('matchAny'),
                isSelected: _matchType == RuleMatch.any,
                isDark: isDark,
                onTap: () => setState(() => _matchType = RuleMatch.any),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRulesSection(bool isDark, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'RULES',
                style: TextStyle(
                  fontFamily: FontConstants.fontFamily,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color:
                      (isDark ? Colors.white : Colors.black).withOpacity(0.5),
                  letterSpacing: 1.2,
                ),
              ),
              TextButton.icon(
                onPressed: () => _showAddRuleSheet(context, isDark, l10n),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(l10n.translate('addRule')),
              ),
            ],
          ),
        ),
        if (_rules.isEmpty)
          _buildEmptyRulesCard(isDark, l10n)
        else
          ..._rules.asMap().entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _RuleCard(
                rule: entry.value,
                isDark: isDark,
                onRemove: () {
                  setState(() => _rules.removeAt(entry.key));
                },
                onEdit: () =>
                    _showEditRuleSheet(context, isDark, l10n, entry.key),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildEmptyRulesCard(bool isDark, AppLocalizations l10n) {
    return GlassmorphicContainer(
      child: InkWell(
        onTap: () => _showAddRuleSheet(context, isDark, l10n),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(
                Icons.rule_rounded,
                size: 48,
                color: (isDark ? Colors.white : Colors.black).withOpacity(0.2),
              ),
              const SizedBox(height: 12),
              Text(
                'No rules added yet',
                style: TextStyle(
                  fontFamily: FontConstants.fontFamily,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color:
                      (isDark ? Colors.white : Colors.black).withOpacity(0.5),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Tap to add your first rule',
                style: TextStyle(
                  fontFamily: FontConstants.fontFamily,
                  fontSize: 14,
                  color:
                      (isDark ? Colors.white : Colors.black).withOpacity(0.3),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionsSection(bool isDark, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'OPTIONS',
            style: TextStyle(
              fontFamily: FontConstants.fontFamily,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: (isDark ? Colors.white : Colors.black).withOpacity(0.5),
              letterSpacing: 1.2,
            ),
          ),
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                color: (isDark ? Colors.white : Colors.black).withOpacity(0.06),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color:
                      (isDark ? Colors.white : Colors.black).withOpacity(0.1),
                ),
              ),
              child: Column(
                children: [
                  // Limit
                  ListTile(
                    title: Text(
                      'Limit to',
                      style: TextStyle(
                        fontFamily: FontConstants.fontFamily,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _limit != null ? '$_limit tracks' : 'No limit',
                          style: TextStyle(
                            fontFamily: FontConstants.fontFamily,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: (isDark ? Colors.white : Colors.black)
                              .withOpacity(0.3),
                        ),
                      ],
                    ),
                    onTap: () => _showLimitDialog(context, isDark, l10n),
                  ),
                  const Divider(height: 1),
                  // Sort by play count
                  SwitchListTile(
                    title: Text(
                      'Sort by play count',
                      style: TextStyle(
                        fontFamily: FontConstants.fontFamily,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    value: _sortByPlayCount,
                    onChanged: (value) {
                      setState(() => _sortByPlayCount = value);
                    },
                  ),
                  if (_sortByPlayCount) ...[
                    const Divider(height: 1),
                    SwitchListTile(
                      title: Text(
                        'Most played first',
                        style: TextStyle(
                          fontFamily: FontConstants.fontFamily,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      value: _sortDescending,
                      onChanged: (value) {
                        setState(() => _sortDescending = value);
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  bool _canSave() {
    return _nameController.text.trim().isNotEmpty && _rules.isNotEmpty;
  }

  Future<void> _savePlaylist() async {
    if (!_canSave()) return;

    HapticFeedback.mediumImpact();

    if (widget.existingPlaylist != null) {
      // Update existing playlist
      final updated = widget.existingPlaylist!.copyWith(
        name: _nameController.text.trim(),
        rules: _rules,
        matchType: _matchType,
        limit: _limit,
        clearLimit: _limit == null,
        sortByPlayCount: _sortByPlayCount,
        sortDescending: _sortDescending,
      );
      await _service.updatePlaylist(updated);
    } else {
      // Create new playlist
      await _service.createPlaylist(
        name: _nameController.text.trim(),
        rules: _rules,
        matchType: _matchType,
        limit: _limit,
        sortByPlayCount: _sortByPlayCount,
        sortDescending: _sortDescending,
      );
    }

    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  void _showAddRuleSheet(
    BuildContext context,
    bool isDark,
    AppLocalizations l10n,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _RuleEditorSheet(
        isDark: isDark,
        l10n: l10n,
        onSave: (rule) {
          setState(() => _rules.add(rule));
        },
      ),
    );
  }

  void _showEditRuleSheet(
    BuildContext context,
    bool isDark,
    AppLocalizations l10n,
    int index,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _RuleEditorSheet(
        isDark: isDark,
        l10n: l10n,
        existingRule: _rules[index],
        onSave: (rule) {
          setState(() => _rules[index] = rule);
        },
      ),
    );
  }

  void _showLimitDialog(
    BuildContext context,
    bool isDark,
    AppLocalizations l10n,
  ) {
    final limits = [null, 10, 25, 50, 100, 200];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Limit tracks',
                  style: TextStyle(
                    fontFamily: FontConstants.fontFamily,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              ),
              ...limits.map((limit) => ListTile(
                    title: Text(
                      limit != null ? '$limit tracks' : 'No limit',
                      style: TextStyle(
                        fontFamily: FontConstants.fontFamily,
                        color: isDark ? Colors.white : Colors.black,
                        fontWeight:
                            _limit == limit ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    trailing: _limit == limit
                        ? Icon(
                            Icons.check_rounded,
                            color: Theme.of(context).colorScheme.primary,
                          )
                        : null,
                    onTap: () {
                      setState(() => _limit = limit);
                      Navigator.pop(context);
                    },
                  )),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

/// Match type selection chip
class _MatchTypeChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _MatchTypeChip({
    required this.label,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary.withOpacity(0.2)
                  : (isDark ? Colors.white : Colors.black).withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : (isDark ? Colors.white : Colors.black).withOpacity(0.1),
              ),
            ),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: FontConstants.fontFamily,
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : (isDark ? Colors.white : Colors.black).withOpacity(0.7),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Rule card displaying a single rule
class _RuleCard extends StatelessWidget {
  final SmartPlaylistRule rule;
  final bool isDark;
  final VoidCallback onRemove;
  final VoidCallback onEdit;

  const _RuleCard({
    required this.rule,
    required this.isDark,
    required this.onRemove,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: (isDark ? Colors.white : Colors.black).withOpacity(0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: (isDark ? Colors.white : Colors.black).withOpacity(0.1),
            ),
          ),
          child: ListTile(
            leading: Icon(
              _getIconForRuleType(rule.type),
              color: Theme.of(context).colorScheme.primary,
            ),
            title: Text(
              rule.getDescription(),
              style: TextStyle(
                fontFamily: FontConstants.fontFamily,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                    Icons.edit_rounded,
                    size: 20,
                    color:
                        (isDark ? Colors.white : Colors.black).withOpacity(0.5),
                  ),
                  onPressed: onEdit,
                ),
                IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    size: 20,
                    color:
                        (isDark ? Colors.white : Colors.black).withOpacity(0.5),
                  ),
                  onPressed: onRemove,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getIconForRuleType(SmartPlaylistRuleType type) {
    switch (type) {
      case SmartPlaylistRuleType.playCount:
        return Icons.play_arrow_rounded;
      case SmartPlaylistRuleType.lastPlayed:
        return Icons.history_rounded;
      case SmartPlaylistRuleType.genre:
        return Icons.category_rounded;
      case SmartPlaylistRuleType.artist:
        return Icons.person_rounded;
      case SmartPlaylistRuleType.album:
        return Icons.album_rounded;
      case SmartPlaylistRuleType.year:
        return Icons.calendar_today_rounded;
      case SmartPlaylistRuleType.duration:
        return Icons.timer_rounded;
      case SmartPlaylistRuleType.dateAdded:
        return Icons.add_circle_outline_rounded;
      case SmartPlaylistRuleType.title:
        return Icons.music_note_rounded;
    }
  }
}

/// Rule editor bottom sheet
class _RuleEditorSheet extends StatefulWidget {
  final bool isDark;
  final AppLocalizations l10n;
  final SmartPlaylistRule? existingRule;
  final Function(SmartPlaylistRule) onSave;

  const _RuleEditorSheet({
    required this.isDark,
    required this.l10n,
    this.existingRule,
    required this.onSave,
  });

  @override
  State<_RuleEditorSheet> createState() => _RuleEditorSheetState();
}

class _RuleEditorSheetState extends State<_RuleEditorSheet> {
  late SmartPlaylistRuleType _type;
  late RuleOperator _operator;
  dynamic _value;
  final _valueController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.existingRule != null) {
      _type = widget.existingRule!.type;
      _operator = widget.existingRule!.operator;
      _value = widget.existingRule!.value;
      _valueController.text = _value.toString();
    } else {
      _type = SmartPlaylistRuleType.playCount;
      _operator = RuleOperator.greaterThan;
      _value = 5;
      _valueController.text = '5';
    }
  }

  @override
  void dispose() {
    _valueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF1A1A2E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.existingRule != null ? 'Edit Rule' : 'Add Rule',
                    style: TextStyle(
                      fontFamily: FontConstants.fontFamily,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: widget.isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  TextButton(
                    onPressed: _saveRule,
                    child: Text(widget.l10n.translate('save')),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  // Rule type
                  _buildSectionTitle('Rule type'),
                  _buildRuleTypeSelector(),
                  const SizedBox(height: 16),

                  // Operator
                  _buildSectionTitle('Condition'),
                  _buildOperatorSelector(),
                  const SizedBox(height: 16),

                  // Value
                  _buildSectionTitle('Value'),
                  _buildValueInput(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontFamily: FontConstants.fontFamily,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: (widget.isDark ? Colors.white : Colors.black).withOpacity(0.5),
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildRuleTypeSelector() {
    final types = [
      (SmartPlaylistRuleType.playCount, 'Play count', Icons.play_arrow_rounded),
      (SmartPlaylistRuleType.lastPlayed, 'Last played', Icons.history_rounded),
      (SmartPlaylistRuleType.artist, 'Artist', Icons.person_rounded),
      (SmartPlaylistRuleType.album, 'Album', Icons.album_rounded),
      (SmartPlaylistRuleType.genre, 'Genre', Icons.category_rounded),
      (SmartPlaylistRuleType.duration, 'Duration', Icons.timer_rounded),
      (SmartPlaylistRuleType.title, 'Title', Icons.music_note_rounded),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: types.map((t) {
        final isSelected = _type == t.$1;
        return ChoiceChip(
          label: Text(t.$2),
          selected: isSelected,
          onSelected: (selected) {
            if (selected) {
              setState(() {
                _type = t.$1;
                _updateDefaultOperator();
              });
            }
          },
        );
      }).toList(),
    );
  }

  Widget _buildOperatorSelector() {
    final operators = _getOperatorsForType(_type);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: operators.map((op) {
        final isSelected = _operator == op.$1;
        return ChoiceChip(
          label: Text(op.$2),
          selected: isSelected,
          onSelected: (selected) {
            if (selected) {
              setState(() => _operator = op.$1);
            }
          },
        );
      }).toList(),
    );
  }

  Widget _buildValueInput() {
    final isNumeric = _isNumericType(_type);

    return TextField(
      controller: _valueController,
      keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
      style: TextStyle(
        fontFamily: FontConstants.fontFamily,
        color: widget.isDark ? Colors.white : Colors.black,
      ),
      decoration: InputDecoration(
        hintText: _getHintForType(_type),
        hintStyle: TextStyle(
          color: (widget.isDark ? Colors.white : Colors.black).withOpacity(0.4),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        suffixText: _getSuffixForType(_type),
      ),
      onChanged: (text) {
        if (isNumeric) {
          _value = int.tryParse(text) ?? 0;
        } else {
          _value = text;
        }
      },
    );
  }

  void _updateDefaultOperator() {
    if (_isNumericType(_type)) {
      _operator = RuleOperator.greaterThan;
    } else {
      _operator = RuleOperator.contains;
    }
  }

  bool _isNumericType(SmartPlaylistRuleType type) {
    return type == SmartPlaylistRuleType.playCount ||
        type == SmartPlaylistRuleType.lastPlayed ||
        type == SmartPlaylistRuleType.duration ||
        type == SmartPlaylistRuleType.dateAdded ||
        type == SmartPlaylistRuleType.year;
  }

  List<(RuleOperator, String)> _getOperatorsForType(SmartPlaylistRuleType type) {
    if (_isNumericType(type)) {
      return [
        (RuleOperator.greaterThan, '>'),
        (RuleOperator.lessThan, '<'),
        (RuleOperator.greaterOrEqual, '≥'),
        (RuleOperator.lessOrEqual, '≤'),
        (RuleOperator.equals, '='),
        (RuleOperator.notEquals, '≠'),
      ];
    } else {
      return [
        (RuleOperator.contains, 'contains'),
        (RuleOperator.notContains, 'not contains'),
        (RuleOperator.equals, 'is'),
        (RuleOperator.notEquals, 'is not'),
        (RuleOperator.startsWith, 'starts with'),
        (RuleOperator.endsWith, 'ends with'),
      ];
    }
  }

  String _getHintForType(SmartPlaylistRuleType type) {
    switch (type) {
      case SmartPlaylistRuleType.playCount:
        return 'e.g., 5';
      case SmartPlaylistRuleType.lastPlayed:
      case SmartPlaylistRuleType.dateAdded:
        return 'Number of days';
      case SmartPlaylistRuleType.duration:
        return 'Duration in seconds';
      case SmartPlaylistRuleType.year:
        return 'e.g., 2020';
      default:
        return 'Enter value';
    }
  }

  String? _getSuffixForType(SmartPlaylistRuleType type) {
    switch (type) {
      case SmartPlaylistRuleType.lastPlayed:
      case SmartPlaylistRuleType.dateAdded:
        return 'days';
      case SmartPlaylistRuleType.duration:
        return 'seconds';
      default:
        return null;
    }
  }

  void _saveRule() {
    if (_isNumericType(_type)) {
      _value = int.tryParse(_valueController.text) ?? 0;
    } else {
      _value = _valueController.text;
    }

    final rule = SmartPlaylistRule(
      type: _type,
      operator: _operator,
      value: _value,
    );

    widget.onSave(rule);
    Navigator.pop(context);
  }
}
