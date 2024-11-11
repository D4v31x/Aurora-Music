import 'dart:io';
import 'package:flutter/material.dart';
import '../services/local_caching_service.dart';
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

  static List<String> splitArtistNames(String artistNames) {
    return artistNames
        .split(RegExp(r'[,/]|\s+&\s+|\s+feat\.?\s+|\s+ft\.?\s+|\s+featuring\s+|\s+with\s+|\s+x\s+|\s+X\s+'))
        .map((name) => name.trim())
        .where((name) => name.isNotEmpty)
        .toList();
  }

  @override
  State<ArtistCard> createState() => _ArtistCardState();
}

class _ArtistCardState extends State<ArtistCard> {
  final LocalCachingArtistService _artistService = LocalCachingArtistService();
  String? _artistImagePath;
  bool _isInitialized = false;
  String _artistInfo = '';

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
    try {
      String primaryArtist = ArtistCard.splitArtistNames(widget.artistName).first;

      final url = 'https://en.wikipedia.org/api/rest_v1/page/summary/${Uri.encodeComponent(primaryArtist)}';
      final response = await http.get(Uri.parse(url));
      
      if (!mounted) return;
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        String description = data['extract'] ?? '';
        
        RegExp regExp = RegExp(r'(?:is|was) (?:an?|the) ([A-Za-z\s-]+?(singer|musician|rapper|band|group|artist|producer|composer|songwriter|DJ)[A-Za-z\s-]*?)(?:\.|\,|who|from)');
        var match = regExp.firstMatch(description);
        
        if (!mounted) return;
        
        setState(() {
          if (match != null) {
            _artistInfo = match.group(1)?.trim() ?? '';
          } else {
            _artistInfo = 'Musical artist';
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _artistInfo = 'Musical artist';
      });
    }
  }

  Future<void> _initializeService() async {
    try {
      await _artistService.initializeService();
      if (!mounted) return;
      setState(() {
        _isInitialized = true;
      });
      await _loadArtistImage();
    } catch (e) {
    }
  }

  Future<void> _loadArtistImage() async {
    if (!_isInitialized) return;

    try {
      final imagePath = await _artistService.fetchArtistImage(widget.artistName);
      if (!mounted) return;
      setState(() {
        _artistImagePath = imagePath;
      });
    } catch (e) {
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: widget.onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Colors.white.withOpacity(0.1),
              Colors.white.withOpacity(0.2),
            ],
          ),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
            width: 1,
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
                    'assets/images/logo/default_art.png',
                    fit: BoxFit.cover,
                    width: 80,
                    height: 80,
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
    );
  }

  @override
  void dispose() {
    _isInitialized = false;
    super.dispose();
  }
}