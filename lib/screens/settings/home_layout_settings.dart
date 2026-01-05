import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../services/home_layout_service.dart';
import '../../localization/app_localizations.dart';

/// Settings screen for customizing home tab layout and section order
class HomeLayoutSettingsScreen extends StatefulWidget {
  const HomeLayoutSettingsScreen({super.key});

  @override
  State<HomeLayoutSettingsScreen> createState() =>
      _HomeLayoutSettingsScreenState();
}

class _HomeLayoutSettingsScreenState extends State<HomeLayoutSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0A0A0F) : const Color(0xFFF5F5F7),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: isDark ? Colors.white : Colors.black,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          l10n.translate('customizeHomeTab'),
          style: TextStyle(
            fontFamily: 'ProductSans',
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        actions: [
          Consumer<HomeLayoutService>(
            builder: (context, layoutService, _) {
              if (layoutService.isCustomLayout) {
                return IconButton(
                  icon: Icon(
                    Icons.restore_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  tooltip: l10n.translate('resetToDefault'),
                  onPressed: () => _showResetDialog(context, layoutService),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: Consumer<HomeLayoutService>(
        builder: (context, layoutService, _) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Instructions
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: (isDark ? Colors.white : Colors.black)
                            .withOpacity(0.06),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: (isDark ? Colors.white : Colors.black)
                              .withOpacity(0.1),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.drag_indicator_rounded,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              l10n.translate('dragToReorder'),
                              style: TextStyle(
                                fontFamily: 'ProductSans',
                                fontSize: 14,
                                color: isDark ? Colors.white70 : Colors.black54,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Section list
              Expanded(
                child: ReorderableListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: layoutService.sectionOrder.length,
                  onReorder: (oldIndex, newIndex) {
                    HapticFeedback.mediumImpact();
                    layoutService.reorderSections(oldIndex, newIndex);
                  },
                  proxyDecorator: (child, index, animation) {
                    return AnimatedBuilder(
                      animation: animation,
                      builder: (context, child) {
                        final double elevation =
                            Curves.easeInOut.transform(animation.value) * 8;
                        return Material(
                          elevation: elevation,
                          borderRadius: BorderRadius.circular(16),
                          shadowColor: Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(0.3),
                          child: child,
                        );
                      },
                      child: child,
                    );
                  },
                  itemBuilder: (context, index) {
                    final section = layoutService.sectionOrder[index];
                    final isVisible = layoutService.isSectionVisible(section);

                    return _SectionTile(
                      key: ValueKey(section),
                      section: section,
                      isVisible: isVisible,
                      isDark: isDark,
                      onVisibilityChanged: (visible) {
                        HapticFeedback.lightImpact();
                        layoutService.setSectionVisibility(section, visible);
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showResetDialog(BuildContext context, HomeLayoutService layoutService) {
    final l10n = AppLocalizations.of(context);

    showDialog(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AlertDialog(
          backgroundColor: Colors.grey[900]?.withOpacity(0.9),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.white.withOpacity(0.1)),
          ),
          title: Text(
            l10n.translate('resetLayoutConfirm'),
            style: const TextStyle(
              fontFamily: 'ProductSans',
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            l10n.translate('resetLayoutMessage'),
            style: const TextStyle(
              fontFamily: 'ProductSans',
              color: Colors.white70,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                l10n.translate('cancel'),
                style: const TextStyle(
                  fontFamily: 'ProductSans',
                  color: Colors.white70,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                layoutService.resetToDefault();
                Navigator.pop(context);
                HapticFeedback.mediumImpact();
              },
              child: Text(
                l10n.translate('resetToDefault'),
                style: const TextStyle(
                  fontFamily: 'ProductSans',
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTile extends StatelessWidget {
  final HomeSection section;
  final bool isVisible;
  final bool isDark;
  final ValueChanged<bool> onVisibilityChanged;

  const _SectionTile({
    super.key,
    required this.section,
    required this.isVisible,
    required this.isDark,
    required this.onVisibilityChanged,
  });

  IconData _getSectionIcon() {
    switch (section) {
      case HomeSection.forYou:
        return Icons.auto_awesome_rounded;
      case HomeSection.suggestedArtists:
        return Icons.person_rounded;
      case HomeSection.recentlyPlayed:
        return Icons.history_rounded;
      case HomeSection.mostPlayed:
        return Icons.trending_up_rounded;
      case HomeSection.listeningHistory:
        return Icons.bar_chart_rounded;
      case HomeSection.recentlyAdded:
        return Icons.add_circle_outline_rounded;
      case HomeSection.libraryStats:
        return Icons.library_music_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: (isDark ? Colors.white : Colors.black)
                  .withOpacity(isVisible ? 0.08 : 0.03),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: (isDark ? Colors.white : Colors.black)
                    .withOpacity(isVisible ? 0.15 : 0.05),
              ),
            ),
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withOpacity(isVisible ? 0.15 : 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getSectionIcon(),
                  size: 22,
                  color: isVisible
                      ? Theme.of(context).colorScheme.primary
                      : (isDark ? Colors.white38 : Colors.black26),
                ),
              ),
              title: Text(
                l10n.translate(section.translationKey),
                style: TextStyle(
                  fontFamily: 'ProductSans',
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: isVisible
                      ? (isDark ? Colors.white : Colors.black)
                      : (isDark ? Colors.white38 : Colors.black38),
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Visibility toggle
                  Switch.adaptive(
                    value: isVisible,
                    onChanged: onVisibilityChanged,
                    activeColor: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  // Drag handle
                  ReorderableDragStartListener(
                    index: HomeLayoutService().sectionOrder.indexOf(section),
                    child: Icon(
                      Icons.drag_handle_rounded,
                      color: isDark ? Colors.white38 : Colors.black26,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
