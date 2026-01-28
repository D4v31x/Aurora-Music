import 'dart:io';
import 'package:flutter/material.dart';
import '../constants/font_constants.dart';
import '../services/local_caching_service.dart';
import '../services/performance/performance_manager.dart';
import '../services/artist_separator_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ArtistCard extends StatefulWidget {
  final String artistName;
  final VoidCallback onTap;

  const ArtistCard({
    super.key,
    required this.artistName,
    required this.onTap,
  });

  // Static cache to prevent duplicate API calls for artist info
  static final Map<String, String> _artistInfoCache = {};
  static final Set<String> _pendingRequests = {};

  static List<String> splitArtistNames(String artistNames) {
    return ArtistSeparatorService().splitArtists(artistNames);
  }

  @override
  State<ArtistCard> createState() => _ArtistCardState();
}

class _ArtistCardState extends State<ArtistCard>
    with AutomaticKeepAliveClientMixin {
  final LocalCachingArtistService _artistService = LocalCachingArtistService();
  String? _artistImagePath;
  bool _isInitialized = false;
  String _artistInfo = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initializeService();
    _fetchArtistInfo();
  }

  @override
  void didUpdateWidget(ArtistCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.artistName != widget.artistName) {
      _artistImagePath = null;
      _artistInfo = '';
      _loadArtistImage();
      _fetchArtistInfo();
    }
  }

  Future<void> _fetchArtistInfo() async {
    final String primaryArtist = ArtistCard.splitArtistNames(widget.artistName).first;

    // Check cache first
    if (ArtistCard._artistInfoCache.containsKey(primaryArtist)) {
      if (mounted) {
        setState(() {
          _artistInfo = ArtistCard._artistInfoCache[primaryArtist]!;
        });
      }
      return;
    }

    // Check if request is already pending
    if (ArtistCard._pendingRequests.contains(primaryArtist)) {
      // Wait for existing request and check cache again
      await Future.delayed(const Duration(milliseconds: 100));
      if (ArtistCard._artistInfoCache.containsKey(primaryArtist) && mounted) {
        setState(() {
          _artistInfo = ArtistCard._artistInfoCache[primaryArtist]!;
        });
      }
      return;
    }

    try {
      ArtistCard._pendingRequests.add(primaryArtist);

      final url =
          'https://en.wikipedia.org/api/rest_v1/page/summary/${Uri.encodeComponent(primaryArtist)}';
      final response = await http.get(Uri.parse(url));

      if (!mounted) return;

      String artistInfo = 'Musical artist'; // Default value

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final String description = data['extract'] ?? '';

        final RegExp regExp = RegExp(
            r'(?:is|was) (?:an?|the) ([A-Za-z\s-]+?(singer|musician|rapper|band|group|artist|producer|composer|songwriter|DJ)[A-Za-z\s-]*?)(?:\.|\,|who|from)');
        final match = regExp.firstMatch(description);

        if (match != null) {
          artistInfo = match.group(1)?.trim() ?? 'Musical artist';
        }
      }

      // Cache the result
      ArtistCard._artistInfoCache[primaryArtist] = artistInfo;

      // Clean up cache if it gets too large
      if (PerformanceManager.shouldCleanup(ArtistCard._artistInfoCache)) {
        PerformanceManager.cleanupCache(ArtistCard._artistInfoCache);
      }

      if (mounted) {
        setState(() {
          _artistInfo = artistInfo;
        });
      }
    } catch (e) {
      // Cache default value to prevent repeated failed requests
      ArtistCard._artistInfoCache[primaryArtist] = 'Musical artist';

      // Clean up cache if needed
      if (PerformanceManager.shouldCleanup(ArtistCard._artistInfoCache)) {
        PerformanceManager.cleanupCache(ArtistCard._artistInfoCache);
      }

      if (mounted) {
        setState(() {
          _artistInfo = 'Musical artist';
        });
      }
    } finally {
      ArtistCard._pendingRequests.remove(primaryArtist);
    }
  }

  Future<void> _initializeService() async {
    try {
      await _artistService.initialize();
      if (!mounted) return;
      setState(() {
        _isInitialized = true;
      });
      await _loadArtistImage();
    } catch (e) {}
  }

  Future<void> _loadArtistImage() async {
    if (!_isInitialized) return;

    try {
      // The singleton service handles all caching and pending request management
      final imagePath =
          await _artistService.fetchArtistImage(widget.artistName);

      if (!mounted) return;
      setState(() {
        _artistImagePath = imagePath;
      });
    } catch (e) {
      // Silently handle errors
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    return RepaintBoundary(
      child: InkWell(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.1),
                Colors.white.withOpacity(0.2),
              ],
            ),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Row(
            children: [
              Hero(
                tag: 'artist_image_${widget.artistName}',
                child: RepaintBoundary(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: _artistImagePath != null
                          ? Image.file(
                              File(_artistImagePath!),
                              fit: BoxFit.cover,
                              width: 80,
                              height: 80,
                            )
                          : Image.asset(
                              'assets/images/UI/unknown.png',
                              fit: BoxFit.cover,
                              width: 80,
                              height: 80,
                            ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.artistName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        fontFamily: FontConstants.fontFamily,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _artistInfo,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 14,
                        fontFamily: FontConstants.fontFamily,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Colors.white.withOpacity(0.7),
                size: 30,
              ),
            ],
          ),
        ),
      ), // Added closing parenthesis for RepaintBoundary
    );
  }

  @override
  void dispose() {
    _isInitialized = false;
    super.dispose();
  }
}
