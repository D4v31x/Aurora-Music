/// Backup and restore settings screen.
///
/// Allows users to export and import their playlists,
/// settings, and other data.
library;

import 'dart:ui';
import 'package:aurora_music_v01/core/constants/font_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/services/backup_restore_service.dart';

/// Settings screen for backup and restore operations.
class BackupRestoreScreen extends StatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  State<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends State<BackupRestoreScreen> {
  final BackupRestoreService _backupService = BackupRestoreService();
  List<FileSystemEntity> _backupFiles = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadBackupFiles();
  }

  Future<void> _loadBackupFiles() async {
    final files = await _backupService.getBackupFiles();
    if (mounted) {
      setState(() => _backupFiles = files);
    }
  }

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
          l10n.translate('backup'),
          style: TextStyle(
            fontFamily: FontConstants.fontFamily,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Info card
                _buildInfoCard(context, isDark, l10n),

                const SizedBox(height: 24),

                // Create backup section
                _buildSectionHeader(l10n.translate('backupData'), isDark),
                const SizedBox(height: 8),
                _buildSettingsCard(isDark, [
                  ListTile(
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.backup_rounded,
                        color: Colors.blue,
                      ),
                    ),
                    title: Text(
                      'Create full backup',
                      style: _titleStyle(isDark),
                    ),
                    subtitle: Text(
                      'Export all playlists, settings, and history',
                      style: _subtitleStyle(isDark),
                    ),
                    trailing: Icon(
                      Icons.chevron_right_rounded,
                      color:
                          (isDark ? Colors.white : Colors.black).withOpacity(0.3),
                    ),
                    onTap: () => _createFullBackup(context, isDark, l10n),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.purple.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.playlist_add_check_rounded,
                        color: Colors.purple,
                      ),
                    ),
                    title: Text(
                      'Export playlists only',
                      style: _titleStyle(isDark),
                    ),
                    subtitle: Text(
                      'Backup just your playlists',
                      style: _subtitleStyle(isDark),
                    ),
                    trailing: Icon(
                      Icons.chevron_right_rounded,
                      color:
                          (isDark ? Colors.white : Colors.black).withOpacity(0.3),
                    ),
                    onTap: () => _createSelectiveBackup(
                        context, isDark, l10n, [BackupDataType.playlists]),
                  ),
                ]),

                const SizedBox(height: 24),

                // Restore section
                _buildSectionHeader(l10n.translate('restoreData'), isDark),
                const SizedBox(height: 8),
                _buildSettingsCard(isDark, [
                  ListTile(
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.restore_rounded,
                        color: Colors.green,
                      ),
                    ),
                    title: Text(
                      'Restore from backup',
                      style: _titleStyle(isDark),
                    ),
                    subtitle: Text(
                      'Import data from a backup file',
                      style: _subtitleStyle(isDark),
                    ),
                    trailing: Icon(
                      Icons.chevron_right_rounded,
                      color:
                          (isDark ? Colors.white : Colors.black).withOpacity(0.3),
                    ),
                    onTap: () => _showBackupFilesSheet(context, isDark, l10n),
                  ),
                ]),

                // Previous backups
                if (_backupFiles.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _buildSectionHeader('Previous backups', isDark),
                  const SizedBox(height: 8),
                  _buildSettingsCard(
                    isDark,
                    _backupFiles.take(5).map((file) {
                      final name = file.path.split('/').last;
                      final stat = file.statSync();
                      final date = stat.modified;
                      final dateStr =
                          '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';

                      return Column(
                        children: [
                          ListTile(
                            leading: Icon(
                              Icons.description_rounded,
                              color: (isDark ? Colors.white : Colors.black)
                                  .withOpacity(0.5),
                            ),
                            title: Text(
                              name.replaceAll('aurora_backup_', '').replaceAll('.json', ''),
                              style: _titleStyle(isDark),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              dateStr,
                              style: _subtitleStyle(isDark),
                            ),
                            trailing: PopupMenuButton<String>(
                              icon: Icon(
                                Icons.more_vert,
                                color: (isDark ? Colors.white : Colors.black)
                                    .withOpacity(0.5),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              onSelected: (value) =>
                                  _handleBackupFileAction(context, isDark, l10n, file, value),
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'restore',
                                  child: Row(
                                    children: [
                                      Icon(Icons.restore_rounded),
                                      SizedBox(width: 12),
                                      Text('Restore'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'share',
                                  child: Row(
                                    children: [
                                      Icon(Icons.share_rounded),
                                      SizedBox(width: 12),
                                      Text('Share'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete_rounded, color: Colors.red),
                                      SizedBox(width: 12),
                                      Text(l10n.translate('delete'), style: TextStyle(color: Colors.red)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_backupFiles.indexOf(file) != _backupFiles.length - 1)
                            const Divider(height: 1),
                        ],
                      );
                    }).toList(),
                  ),
                ],

                const SizedBox(height: 100),
              ],
            ),
    );
  }

  Widget _buildInfoCard(
    BuildContext context,
    bool isDark,
    AppLocalizations l10n,
  ) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.translate('backupInfoMessage'),
                  style: TextStyle(
                    fontFamily: FontConstants.fontFamily,
                    fontSize: 13,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontFamily: FontConstants.fontFamily,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: (isDark ? Colors.white : Colors.black).withOpacity(0.5),
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSettingsCard(bool isDark, List<Widget> children) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: (isDark ? Colors.white : Colors.black).withOpacity(0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: (isDark ? Colors.white : Colors.black).withOpacity(0.1),
            ),
          ),
          child: Column(children: children),
        ),
      ),
    );
  }

  TextStyle _titleStyle(bool isDark) => TextStyle(
        fontFamily: FontConstants.fontFamily,
        fontSize: 15,
        color: isDark ? Colors.white : Colors.black,
      );

  TextStyle _subtitleStyle(bool isDark) => TextStyle(
        fontFamily: FontConstants.fontFamily,
        fontSize: 13,
        color: (isDark ? Colors.white : Colors.black).withOpacity(0.5),
      );

  Future<void> _createFullBackup(
    BuildContext context,
    bool isDark,
    AppLocalizations l10n,
  ) async {
    setState(() => _isLoading = true);

    final result = await _backupService.createFullBackup();

    setState(() => _isLoading = false);

    if (result.success && result.filePath != null) {
      await _loadBackupFiles();
      if (mounted) {
        _showBackupSuccessDialog(context, isDark, l10n, result);
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Backup failed: ${result.error}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _createSelectiveBackup(
    BuildContext context,
    bool isDark,
    AppLocalizations l10n,
    List<BackupDataType> types,
  ) async {
    setState(() => _isLoading = true);

    final result = await _backupService.createSelectiveBackup(types);

    setState(() => _isLoading = false);

    if (result.success && result.filePath != null) {
      await _loadBackupFiles();
      if (mounted) {
        _showBackupSuccessDialog(context, isDark, l10n, result);
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Backup failed: ${result.error}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showBackupSuccessDialog(
    BuildContext context,
    bool isDark,
    AppLocalizations l10n,
    BackupResult result,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1A1A2E) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.green),
            const SizedBox(width: 12),
            Text(
              l10n.translate('backupCreated'),
              style: TextStyle(
                fontFamily: FontConstants.fontFamily,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ],
        ),
        content: Text(
          'Backup created with ${result.itemsProcessed} items.',
          style: TextStyle(
            color: (isDark ? Colors.white : Colors.black).withOpacity(0.7),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.translate('close')),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(context);
              Share.shareXFiles([XFile(result.filePath!)]);
            },
            icon: const Icon(Icons.share_rounded),
            label: Text(l10n.translate('share')),
          ),
        ],
      ),
    );
  }

  void _showBackupFilesSheet(
    BuildContext context,
    bool isDark,
    AppLocalizations l10n,
  ) {
    if (_backupFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No backup files found'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
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
                  'Select backup to restore',
                  style: TextStyle(
                    fontFamily: FontConstants.fontFamily,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _backupFiles.length,
                  itemBuilder: (context, index) {
                    final file = _backupFiles[index];
                    final name = file.path.split('/').last;
                    final stat = file.statSync();
                    final date = stat.modified;
                    final dateStr =
                        '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';

                    return ListTile(
                      leading: const Icon(Icons.description_rounded),
                      title: Text(
                        name.replaceAll('aurora_backup_', '').replaceAll('.json', ''),
                        style: _titleStyle(isDark),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(dateStr, style: _subtitleStyle(isDark)),
                      onTap: () async {
                        Navigator.pop(context);
                        await _restoreFromBackup(context, isDark, l10n, file.path);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _restoreFromBackup(
    BuildContext context,
    bool isDark,
    AppLocalizations l10n,
    String filePath,
  ) async {
    // Validate first
    final validation = await _backupService.validateBackup(filePath);
    if (validation == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid backup file'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    // Confirm restore
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1A1A2E) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          'Restore from backup?',
          style: TextStyle(
            fontFamily: FontConstants.fontFamily,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        content: Text(
          'This will replace your current data with the backup. This action cannot be undone.',
          style: TextStyle(
            color: (isDark ? Colors.white : Colors.black).withOpacity(0.7),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.translate('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.translate('restore')),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    final result = await _backupService.restoreFromBackup(filePath);

    setState(() => _isLoading = false);

    if (result.success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${l10n.translate('backupRestored')} (${result.itemsProcessed} items)'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Restore failed: ${result.error}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _handleBackupFileAction(
    BuildContext context,
    bool isDark,
    AppLocalizations l10n,
    FileSystemEntity file,
    String action,
  ) {
    switch (action) {
      case 'restore':
        _restoreFromBackup(context, isDark, l10n, file.path);
        break;
      case 'share':
        Share.shareXFiles([XFile(file.path)]);
        break;
      case 'delete':
        _confirmDeleteBackup(context, isDark, l10n, file);
        break;
    }
  }

  void _confirmDeleteBackup(
    BuildContext context,
    bool isDark,
    AppLocalizations l10n,
    FileSystemEntity file,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1A1A2E) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          'Delete backup?',
          style: TextStyle(
            fontFamily: FontConstants.fontFamily,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        content: Text(
          'This backup will be permanently deleted.',
          style: TextStyle(
            color: (isDark ? Colors.white : Colors.black).withOpacity(0.7),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.translate('cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              final success = await _backupService.deleteBackup(file.path);
              if (success) {
                await _loadBackupFiles();
              }
            },
            child: Text(l10n.translate('delete')),
          ),
        ],
      ),
    );
  }
}
