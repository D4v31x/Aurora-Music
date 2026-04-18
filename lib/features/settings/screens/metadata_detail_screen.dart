import 'dart:io';
import 'package:aurora_music_v01/core/constants/font_constants.dart';
import 'package:flutter/material.dart';
import 'package:iconoir_flutter/iconoir_flutter.dart' as iconoir;
import 'package:flutter/services.dart';
import 'package:audiotags/audiotags.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../../../shared/services/audio_player_service.dart';
import '../../../shared/services/notification_manager.dart';
import '../../../shared/services/metadata_service.dart';
import '../../../shared/services/artwork_cache_service.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/widgets/app_background.dart';
import '../../../shared/widgets/expanding_player.dart';

class MetadataDetailScreen extends StatefulWidget {
  final SongModel song;

  const MetadataDetailScreen({
    super.key,
    required this.song,
  });

  @override
  State<MetadataDetailScreen> createState() => _MetadataDetailScreenState();
}

class _MetadataDetailScreenState extends State<MetadataDetailScreen> {
  late TextEditingController _titleController;
  late TextEditingController _artistController;
  late TextEditingController _albumController;
  late TextEditingController _genreController;
  late TextEditingController _trackController;
  late TextEditingController _yearController;
  late TextEditingController _composerController;

  bool _isEditing = false;
  bool _hasChanges = false;
  bool _isSaving = false;

  // AudioTags instance for reading/writing metadata
  Tag? _currentTag;
  Uint8List? _pendingCoverArt;

  // Cached artwork to prevent reloading
  Uint8List? _cachedArtwork;
  final ArtworkCacheService _artworkService = ArtworkCacheService();

  // OnAudioQuery instance for MediaStore operations
  final OnAudioQuery _audioQuery = OnAudioQuery();

  // Inline auto-tag search state
  final TextEditingController _autoTagSearchController = TextEditingController();
  List<Map<String, dynamic>>? _autoTagResults;
  bool _autoTagIsLoading = false;

  @override
  void initState() {
    super.initState();
    ExpandingPlayer.hiddenNotifier.value = true;
    _initControllers();
    _loadTags();
    _loadCachedArtwork();
  }

  Future<void> _loadCachedArtwork() async {
    try {
      final artwork = await _artworkService.getArtwork(widget.song.id);
      if (mounted) {
        setState(() {
          _cachedArtwork = artwork;
        });
      }
    } catch (e) {
      // Artwork loading failed, fallback to placeholder
    }
  }

  Future<void> _loadTags() async {
    try {
      _currentTag = await AudioTags.read(widget.song.data);
      if (_currentTag != null) {
        // Update controllers with loaded tag data if available
        if (_currentTag?.title != null && _currentTag!.title!.isNotEmpty) {
          _titleController.text = _currentTag!.title!;
        }
        if (_currentTag?.trackArtist != null &&
            _currentTag!.trackArtist!.isNotEmpty) {
          _artistController.text = _currentTag!.trackArtist!;
        }
        if (_currentTag?.album != null && _currentTag!.album!.isNotEmpty) {
          _albumController.text = _currentTag!.album!;
        }
        if (_currentTag?.genre != null && _currentTag!.genre!.isNotEmpty) {
          _genreController.text = _currentTag!.genre!;
        }
        if (_currentTag?.year != null) {
          _yearController.text = _currentTag!.year.toString();
        }
        if (_currentTag?.trackNumber != null) {
          _trackController.text = _currentTag!.trackNumber.toString();
        }
        setState(() {});
      }
    } catch (e) {
      debugPrint('Error loading tags: $e');
    }
  }

  void _initControllers() {
    _titleController = TextEditingController(text: widget.song.title);
    _artistController = TextEditingController(text: widget.song.artist ?? '');
    _albumController = TextEditingController(text: widget.song.album ?? '');
    _genreController = TextEditingController(text: widget.song.genre ?? '');
    _trackController =
        TextEditingController(text: widget.song.track?.toString() ?? '');
    _yearController = TextEditingController(text: '');
    _composerController =
        TextEditingController(text: widget.song.composer ?? '');

    // Add listeners for change detection
    _titleController.addListener(_onFieldChanged);
    _artistController.addListener(_onFieldChanged);
    _albumController.addListener(_onFieldChanged);
    _genreController.addListener(_onFieldChanged);
    _trackController.addListener(_onFieldChanged);
    _yearController.addListener(_onFieldChanged);
    _composerController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    if (_isEditing && !_hasChanges) {
      setState(() => _hasChanges = true);
    }
  }

  @override
  void dispose() {
    ExpandingPlayer.hiddenNotifier.value = false;
    _titleController.dispose();
    _artistController.dispose();
    _albumController.dispose();
    _genreController.dispose();
    _trackController.dispose();
    _yearController.dispose();
    _composerController.dispose();
    _autoTagSearchController.dispose();
    super.dispose();
  }

  /// Returns the file extension (with leading dot) of the current song,
  /// used when naming the temporary file for metadata editing.
  String _extension() {
    final path = widget.song.data.toLowerCase();
    for (final ext in [
      '.mp3',
      '.m4a',
      '.flac',
      '.wav',
      '.ogg',
      '.opus',
      '.aac',
      '.wma',
      '.alac'
    ]) {
      if (path.endsWith(ext)) return ext;
    }
    return '.audio';
  }

  String _getFileFormat() {
    final path = widget.song.data.toLowerCase();
    if (path.endsWith('.mp3')) return 'MP3';
    if (path.endsWith('.m4a')) return 'M4A';
    if (path.endsWith('.flac')) return 'FLAC';
    if (path.endsWith('.wav')) return 'WAV';
    if (path.endsWith('.ogg')) return 'OGG';
    if (path.endsWith('.opus')) return 'OPUS';
    if (path.endsWith('.aac')) return 'AAC';
    if (path.endsWith('.wma')) return 'WMA';
    if (path.endsWith('.alac')) return 'ALAC';
    return 'AUDIO';
  }

  String _getFileSizeFormatted() {
    final sizeBytes = widget.song.size;
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  int _estimateBitrateValue() {
    if (widget.song.duration == null || widget.song.duration! <= 0) return 0;
    final durationSeconds = widget.song.duration! / 1000;
    final sizeKB = widget.song.size / 1024;
    return ((sizeKB * 8) / durationSeconds).round();
  }

  String _getQualityLabel(AppLocalizations loc) {
    final format = _getFileFormat();
    final bitrate = _estimateBitrateValue();

    if (format == 'FLAC' || format == 'WAV' || format == 'ALAC') {
      return loc.lossless;
    }
    if (bitrate >= 256) return loc.highQuality;
    if (bitrate >= 192) return loc.goodQuality;
    if (bitrate >= 128) return loc.standardQuality;
    return loc.lowQuality;
  }

  String _formatDuration() {
    if (widget.song.duration == null) return '—';
    final duration = Duration(milliseconds: widget.song.duration!);
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  String _getFileName() {
    return widget.song.data.split('/').last;
  }

  String _formatDate(int? timestamp) {
    if (timestamp == null || timestamp == 0) return '—';
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    return '${date.day}.${date.month}.${date.year}';
  }

  String _getEstimatedSampleRate() {
    final format = _getFileFormat();
    final bitrate = _estimateBitrateValue();

    if (format == 'FLAC' || format == 'WAV' || format == 'ALAC') {
      if (bitrate > 1400) return '96 kHz';
      if (bitrate > 1000) return '48 kHz';
      return '44.1 kHz';
    }
    if (bitrate >= 256) return '44.1 kHz';
    if (bitrate >= 128) return '44.1 kHz';
    return '22 kHz';
  }

  IconData _getQualityIcon(AppLocalizations loc) {
    final label = _getQualityLabel(loc);
    if (label == loc.lossless) return Icons.diamond_outlined;
    if (label == loc.highQuality) return Icons.stars_outlined;
    if (label == loc.goodQuality) return Icons.thumb_up_outlined;
    if (label == loc.standardQuality) {
      return Icons.check_circle_outline;
    }
    return Icons.warning_amber_outlined;
  }

  Color _getQualityColor(AppLocalizations loc) {
    final label = _getQualityLabel(loc);
    if (label == loc.lossless) return const Color(0xFF8B5CF6);
    if (label == loc.highQuality) return const Color(0xFF10B981);
    if (label == loc.goodQuality) return const Color(0xFF3B82F6);
    if (label == loc.standardQuality) {
      return const Color(0xFFF59E0B);
    }
    return const Color(0xFFEF4444);
  }

  Future<void> _runAutoTagSearch() async {
    if (_autoTagSearchController.text.trim().isEmpty) return;
    setState(() {
      _autoTagIsLoading = true;
      _autoTagResults = null;
    });
    final res =
        await MetadataService().searchMetadata(_autoTagSearchController.text);
    if (mounted) {
      setState(() {
        _autoTagResults = res;
        _autoTagIsLoading = false;
      });
    }
  }

  Future<void> _applyMetadata(Map<String, dynamic> data) async {
    final service = MetadataService();

    // Fetch enriched data (year, genre, track#) and cover art in parallel.
    final results = await Future.wait([
      service.fetchFullTrackDetails(data),
      service.fetchCoverArt('${data['title']} ${(data['artist'] as Map?)?['name'] ?? ''}'),
    ]);

    final enriched = results[0] as Map<String, dynamic>;
    final coverUrl = results[1] as String?;

    // Parse year from release_date string ("YYYY-MM-DD" or "YYYY").
    String year = '';
    final releaseDate = enriched['_release_date'] as String? ?? '';
    if (releaseDate.length >= 4) year = releaseDate.substring(0, 4);

    // Track position and genre.
    final trackPos = enriched['_track_position'];
    final genre = enriched['_genre'] as String? ?? '';

    setState(() {
      _titleController.text = enriched['title'] as String? ?? '';
      _artistController.text = (enriched['artist'] as Map?)?['name'] as String? ?? '';
      _albumController.text = (enriched['album'] as Map?)?['title'] as String? ?? '';
      if (genre.isNotEmpty) _genreController.text = genre;
      if (year.isNotEmpty) _yearController.text = year;
      if (trackPos != null) _trackController.text = trackPos.toString();
      _isEditing = true;
      _hasChanges = true;
    });

    if (coverUrl != null && mounted) {
      final bytes = await service.downloadImage(coverUrl);
      if (bytes != null && mounted) {
        setState(() {
          _pendingCoverArt = Uint8List.fromList(bytes);
          _hasChanges = true;
        });
        NotificationManager.showMessage(
          context,
          AppLocalizations.of(context).coverArtUpdated,
        );
      }
    }
  }

  void _toggleEditMode() {
    if (!_isEditing) {
      // Entering edit mode — pre-fill the inline auto-tag search field.
      _autoTagSearchController.text =
          '${_titleController.text} ${_artistController.text}'.trim();
      _autoTagResults = null;
      _autoTagIsLoading = false;
    }
    setState(() {
      if (_isEditing && _hasChanges) {
        _showSaveDialog();
      } else {
        _isEditing = !_isEditing;
        _hasChanges = false;
      }
    });
  }

  void _showSaveDialog() {
    final loc = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
          backgroundColor: Colors.grey[900]?.withValues(alpha: 0.9),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
          title: Text(
            loc.saveChanges,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: FontConstants.fontFamily,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            loc.saveChangesDesc,
            style: const TextStyle(
              color: Colors.white70,
              fontFamily: FontConstants.fontFamily,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _discardChanges();
              },
              child: Text(
                loc.discard,
                style: const TextStyle(
                  fontFamily: FontConstants.fontFamily,
                  color: Colors.white70,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _saveChanges();
              },
              child: Text(
                loc.save,
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

  void _discardChanges() {
    setState(() {
      _initControllers();
      _isEditing = false;
      _hasChanges = false;
      _autoTagResults = null;
      _autoTagIsLoading = false;
    });
  }

  /// Platform channel to the native SAF write helper in MainActivity.
  static const _safChannel = MethodChannel('aurora/saf_write');

  Future<void> _saveChanges() async {
    final loc = AppLocalizations.of(context);

    setState(() => _isSaving = true);

    try {
      // Parse year and track number
      int? year;
      int? trackNumber;
      if (_yearController.text.isNotEmpty) {
        year = int.tryParse(_yearController.text);
      }
      if (_trackController.text.isNotEmpty) {
        trackNumber = int.tryParse(_trackController.text);
      }

      // 1. Copy the original file to a temp location inside the app's cache.
      //    AudioTags can write to any path we own without special permissions.
      final originalFile = File(widget.song.data);
      debugPrint('[META] Step 1 – source: ${widget.song.data}');
      debugPrint('[META] Step 1 – file exists: ${originalFile.existsSync()}');
      final tempDir = await getTemporaryDirectory();
      final tempFile = File(
          '${tempDir.path}/aurora_meta_${widget.song.id}_${DateTime.now().millisecondsSinceEpoch}${_extension()}');
      debugPrint('[META] Step 1 – temp target: ${tempFile.path}');
      await originalFile.copy(tempFile.path);
      debugPrint(
          '[META] Step 1 – copy OK, temp size: ${tempFile.lengthSync()} bytes');

      // 2. Build the updated tag and write it to the temp copy.
      debugPrint('[META] Step 2 – writing tags to temp file');
      final updatedTag = Tag(
        title: _titleController.text.isEmpty ? null : _titleController.text,
        trackArtist:
            _artistController.text.isEmpty ? null : _artistController.text,
        album: _albumController.text.isEmpty ? null : _albumController.text,
        genre: _genreController.text.isEmpty ? null : _genreController.text,
        year: year,
        trackNumber: trackNumber,
        pictures: _pendingCoverArt != null
            ? [
                Picture(
                  bytes: _pendingCoverArt!,
                  mimeType: MimeType.jpeg,
                  pictureType: PictureType.coverFront,
                )
              ]
            : _currentTag?.pictures ?? [],
      );
      await AudioTags.write(tempFile.path, updatedTag);
      debugPrint(
          '[META] Step 2 – AudioTags.write OK, temp size now: ${tempFile.lengthSync()} bytes');

      // 3. Push the modified temp file back to the original location via the
      //    MediaStore ContentResolver. On Android 11+ this shows a one-time
      //    system dialog asking the user to allow the edit.
      debugPrint('[META] Step 3 – invoking writeFileViaMediaStore');
      try {
        await _safChannel.invokeMethod<void>('writeFileViaMediaStore', {
          'tempPath': tempFile.path,
          'originalPath': widget.song.data,
        });
      } on PlatformException catch (pe) {
        if (pe.code == 'PERMISSION_DENIED') {
          // User tapped "Deny" on the system write-request dialog.
          setState(() => _isSaving = false);
          try {
            await tempFile.delete();
          } catch (_) {}
          if (mounted) {
            NotificationManager.showMessage(context, loc.storagePermissionNeeded);
          }
          return;
        }
        rethrow;
      }
      debugPrint('[META] Step 3 – writeFileViaMediaStore OK');

      // 4. Clean up the temp file.
      try {
        await tempFile.delete();
      } catch (_) {}

      // 5. Trigger MediaStore rescan and wait for it to propagate.
      debugPrint('[META] Step 5 – scanning media');
      await _audioQuery.scanMedia(widget.song.data);
      // Give MediaStore a moment to commit the updated index entry.
      await Future.delayed(const Duration(milliseconds: 500));
      debugPrint('[META] Step 5 – scan OK');

      // 6. Re-read the updated tag from the file (source of truth).
      _currentTag = await AudioTags.read(widget.song.data);

      // 7. Update the controllers so the screen shows the saved values.
      if (_currentTag != null) {
        _titleController.text = _currentTag!.title ?? _titleController.text;
        _artistController.text =
            _currentTag!.trackArtist ?? _artistController.text;
        _albumController.text = _currentTag!.album ?? _albumController.text;
        _genreController.text = _currentTag!.genre ?? _genreController.text;
        if (_currentTag!.year != null) {
          _yearController.text = _currentTag!.year.toString();
        }
        if (_currentTag!.trackNumber != null) {
          _trackController.text = _currentTag!.trackNumber.toString();
        }
      }

      // 8. Re-query MediaStore for the updated SongModel and push it into
      //    the audio player service so every screen sees the new metadata.
      if (mounted) {
        final audioPlayerService =
            Provider.of<AudioPlayerService>(context, listen: false);
        try {
          final freshSongs = await _audioQuery.querySongs(
            orderType: OrderType.ASC_OR_SMALLER,
            uriType: UriType.EXTERNAL,
            ignoreCase: true,
          );
          final freshSong = freshSongs.firstWhere(
            (s) => s.id == widget.song.id,
            orElse: () => widget.song,
          );
          audioPlayerService.refreshSongInPlaylist(freshSong);
        } catch (e) {
          debugPrint('[META] Re-query failed, falling back to full reload: $e');
          await audioPlayerService.initializeMusicLibrary();
        }
      }

      setState(() {
        _isEditing = false;
        _hasChanges = false;
        _isSaving = false;
      });

      if (mounted) {
        NotificationManager.showMessage(context, loc.metadataSaved);
      }
    } catch (e) {
      setState(() => _isSaving = false);
      debugPrint('[META] FAILED: $e');

      if (mounted) {
        _showSaveErrorDialog(loc, e.toString());
      }
    }
  }

  void _showSaveErrorDialog(AppLocalizations loc, String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
          backgroundColor: Colors.grey[900]?.withValues(alpha: 0.9),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
          title: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red[400]),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  loc.saveFailed,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontFamily: FontConstants.fontFamily,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                loc.saveFailedDesc,
                style: const TextStyle(
                  color: Colors.white70,
                  fontFamily: FontConstants.fontFamily,
                ),
              ),
              const SizedBox(height: 12),
              // Show the raw error so we can diagnose it without logcat
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black38,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  error,
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loc.possibleReasons,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        fontFamily: FontConstants.fontFamily,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildReasonItem(loc.reasonPermissions),
                    _buildReasonItem(loc.reasonReadonly),
                    _buildReasonItem(loc.reasonFormat),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                loc.gotIt,
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

  Widget _buildReasonItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.circle, color: Colors.red.withValues(alpha: 0.7), size: 8),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    final loc = AppLocalizations.of(context);
    NotificationManager.showMessage(context, '${loc.copied}: $label');
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final isLowEnd = Provider.of<PerformanceModeProvider>(context, listen: false).isLowEndDevice;
    final colorScheme = Theme.of(context).colorScheme;

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const iconoir.NavArrowLeft(color: Colors.white, width: 28, height: 28),
            onPressed: () {
              if (_hasChanges) {
                _showSaveDialog();
              } else {
                Navigator.pop(context);
              }
            },
          ),
          title: Text(
            loc.metadata,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: FontConstants.fontFamily,
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [
            if (_isSaving)
              const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              )
            else
              IconButton(
                icon: Icon(
                  _isEditing ? Icons.check : Icons.edit_outlined,
                  color: _isEditing ? Colors.green : Colors.white,
                ),
                onPressed: _toggleEditMode,
              ),
          ],
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, 20 + MediaQuery.of(context).padding.bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Artwork
              Center(
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: _pendingCoverArt != null
                        ? Image.memory(
                            _pendingCoverArt!,
                            fit: BoxFit.cover,
                            gaplessPlayback: true,
                          )
                        : _cachedArtwork != null
                            ? Image.memory(
                                _cachedArtwork!,
                                fit: BoxFit.cover,
                                width: 200,
                                height: 200,
                                gaplessPlayback: true,
                              )
                            : Container(
                                color: Colors.grey[800],
                                child: const Icon(Icons.music_note,
                                    size: 80, color: Colors.white54),
                              ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Inline auto-tag search — visible in edit mode
              if (_isEditing) ...[
                _buildAutoTagPanel(loc, isLowEnd, colorScheme),
                const SizedBox(height: 16),
              ],

              // Quality card
              _buildQualityCard(loc, isLowEnd, colorScheme),
              const SizedBox(height: 24),

              // Audio info section
              _buildSectionCard(
                loc.audioQuality,
                Icons.graphic_eq,
                [
                  _buildInfoRow(loc.format, _getFileFormat()),
                  _buildInfoRow(loc.bitrate,
                      '${_estimateBitrateValue()} kbps'),
                  _buildInfoRow(
                      loc.sampleRate, _getEstimatedSampleRate()),
                  _buildInfoRow(loc.duration, _formatDuration()),
                ],
                description: loc.audioQualityDesc,
                isLowEnd: isLowEnd,
                colorScheme: colorScheme,
              ),
              const SizedBox(height: 16),

              // Track info section (editable)
              _buildSectionCard(
                loc.trackInfo,
                Icons.music_note_outlined,
                [
                  _buildEditableRow(loc.title, _titleController),
                  _buildEditableRow(loc.artist, _artistController),
                  _buildEditableRow(loc.album, _albumController),
                  _buildEditableRow(loc.genre, _genreController),
                  _buildEditableRow(loc.year, _yearController,
                      isNumber: true),
                  _buildEditableRow(loc.track, _trackController,
                      isNumber: true),
                  _buildEditableRow(
                      loc.composer, _composerController),
                ],
                description: _isEditing
                    ? loc.trackInfoEditDesc
                    : loc.trackInfoDesc,
                isLowEnd: isLowEnd,
                colorScheme: colorScheme,
              ),
              const SizedBox(height: 16),

              // File info section
              _buildSectionCard(
                loc.fileInfo,
                Icons.folder_outlined,
                [
                  _buildInfoRow(loc.fileName, _getFileName(),
                      canCopy: true),
                  _buildInfoRow(loc.size, _getFileSizeFormatted()),
                  if (widget.song.dateAdded != null)
                    _buildInfoRow(loc.dateAdded,
                        _formatDate(widget.song.dateAdded)),
                  if (widget.song.dateModified != null)
                    _buildInfoRow(loc.dateModified,
                        _formatDate(widget.song.dateModified)),
                ],
                description: loc.fileInfoDesc,
                isLowEnd: isLowEnd,
                colorScheme: colorScheme,
              ),
              const SizedBox(height: 16),

              // File path section
              _buildPathCard(loc, isLowEnd, colorScheme),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQualityCard(AppLocalizations loc, bool isLowEnd, ColorScheme colorScheme) {
    final qualityColor = _getQualityColor(loc);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: isLowEnd ? null : LinearGradient(
          colors: [
            qualityColor.withValues(alpha: 0.3),
            qualityColor.withValues(alpha: 0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        color: isLowEnd ? colorScheme.surfaceContainerHigh : null,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isLowEnd ? colorScheme.outlineVariant : qualityColor.withValues(alpha: 0.3),
        ),
      ),
      // replace two uses of _getQualityColor(loc) below with local variable
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: qualityColor.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _getQualityIcon(loc),
              color: qualityColor,
              size: 32,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getQualityLabel(loc),
                  style: TextStyle(
                    color: qualityColor,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    fontFamily: FontConstants.fontFamily,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_getFileFormat()} • ${_estimateBitrateValue()} kbps',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  loc.qualityDesc,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(String title, IconData icon, List<Widget> children,
      {String? description, bool isLowEnd = false, ColorScheme? colorScheme}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isLowEnd
            ? colorScheme!.surfaceContainerHigh
            : Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isLowEnd
              ? colorScheme!.outlineVariant
              : Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white.withValues(alpha: 0.7), size: 20),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  fontFamily: FontConstants.fontFamily,
                ),
              ),
            ],
          ),
          if (description != null) ...[
            const SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool canCopy = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: GestureDetector(
              onLongPress:
                  canCopy ? () => _copyToClipboard(value, label) : null,
              child: Text(
                value,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.end,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableRow(String label, TextEditingController controller,
      {bool isNumber = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: _isEditing
                ? TextField(
                    controller: controller,
                    keyboardType:
                        isNumber ? TextInputType.number : TextInputType.text,
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.1),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  )
                : GestureDetector(
                    onLongPress: () => _copyToClipboard(controller.text, label),
                    child: Text(
                      controller.text.isEmpty ? '—' : controller.text,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.end,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPathCard(AppLocalizations loc, bool isLowEnd, ColorScheme colorScheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isLowEnd
            ? colorScheme.surfaceContainerHigh
            : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isLowEnd
              ? colorScheme.outlineVariant
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.link,
                  color: Colors.white.withValues(alpha: 0.5), size: 18),
              const SizedBox(width: 10),
              Text(
                loc.filePath,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(
                  Icons.copy,
                  color: Colors.white.withValues(alpha: 0.5),
                  size: 18,
                ),
                onPressed: () => _copyToClipboard(
                    widget.song.data, loc.filePath),
                tooltip: loc.copy,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: SelectableText(
              widget.song.data,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 12,
                fontFamily: FontConstants.monospaceFontFamily,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Open in file manager button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _openInFileManager(),
              icon: const Icon(Icons.folder_open, size: 18),
              label: Text(loc.openFolder),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white.withValues(alpha: 0.8),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAutoTagPanel(
      AppLocalizations loc, bool isLowEnd, ColorScheme colorScheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isLowEnd
            ? colorScheme.surfaceContainerHigh
            : Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isLowEnd
              ? colorScheme.outlineVariant
              : Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.auto_fix_high,
                  color: Colors.white.withValues(alpha: 0.7), size: 20),
              const SizedBox(width: 10),
              Text(
                loc.autoTag,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  fontFamily: FontConstants.fontFamily,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Search field
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _autoTagSearchController,
                  style: const TextStyle(
                      color: Colors.white,
                      fontFamily: FontConstants.fontFamily),
                  decoration: InputDecoration(
                    hintText: loc.searchMetadata,
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontFamily: FontConstants.fontFamily,
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.1),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          BorderSide(color: colorScheme.primary),
                    ),
                  ),
                  onSubmitted: (_) => _runAutoTagSearch(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _runAutoTagSearch,
                icon: const Icon(Icons.search, color: Colors.white),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          // Results
          if (_autoTagIsLoading) ...[
            const SizedBox(height: 20),
            const Center(child: CircularProgressIndicator()),
            const SizedBox(height: 20),
          ] else if (_autoTagResults != null) ...[
            const SizedBox(height: 16),
            if (_autoTagResults!.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  loc.noResults,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontFamily: FontConstants.fontFamily),
                ),
              )
            else
              SizedBox(
                height: 148,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _autoTagResults!.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final item = _autoTagResults![index];
                    final title = item['title'] as String? ?? '';
                    final artist =
                        (item['artist'] as Map?)?['name'] as String? ?? '';
                    final album =
                        (item['album'] as Map?)?['title'] as String? ?? '';
                    final coverUrl =
                        (item['album'] as Map?)?['cover_medium'] as String?;
                    return GestureDetector(
                      onTap: () => _applyMetadata(item),
                      child: Container(
                        width: 104,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.12)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Artwork
                            ClipRRect(
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(12),
                                topRight: Radius.circular(12),
                              ),
                              child: coverUrl != null && coverUrl.isNotEmpty
                                  ? Image.network(
                                      coverUrl,
                                      width: 104,
                                      height: 104,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        width: 104,
                                        height: 104,
                                        color: Colors.grey[800],
                                        child: const Icon(Icons.music_note,
                                            color: Colors.white54),
                                      ),
                                    )
                                  : Container(
                                      width: 104,
                                      height: 104,
                                      color: Colors.grey[800],
                                      child: const Icon(Icons.music_note,
                                          color: Colors.white54),
                                    ),
                            ),
                            // Text
                            Expanded(
                              child: Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(6, 5, 6, 4),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        fontFamily: FontConstants.fontFamily,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      artist,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.white
                                            .withValues(alpha: 0.55),
                                        fontSize: 9,
                                        fontFamily: FontConstants.fontFamily,
                                      ),
                                    ),
                                    Text(
                                      album,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.white
                                            .withValues(alpha: 0.4),
                                        fontSize: 9,
                                        fontFamily: FontConstants.fontFamily,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ],
      ),
    );
  }

  void _openInFileManager() async {
    final loc = AppLocalizations.of(context);
    // This would require platform-specific implementation
    NotificationManager.showMessage(
      context,
      loc.openFolderInfo,
      duration: const Duration(seconds: 2),
    );
  }
}
