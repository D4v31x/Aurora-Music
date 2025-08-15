import 'package:flutter/material.dart';
import 'package:mesh/mesh.dart';
import 'package:palette_generator/palette_generator.dart';

/// A mesh gradient background that adapts to artwork colors
class ArtworkMeshBackground extends StatefulWidget {
  final Widget child;
  final bool isDarkMode;
  final ImageProvider? artwork;

  const ArtworkMeshBackground({
    super.key,
    required this.child,
    required this.isDarkMode,
    this.artwork,
  });

  @override
  State<ArtworkMeshBackground> createState() => _ArtworkMeshBackgroundState();
}

class _ArtworkMeshBackgroundState extends State<ArtworkMeshBackground> {
  List<Color> _artworkColors = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _extractColorsFromArtwork();
  }

  @override
  void didUpdateWidget(ArtworkMeshBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.artwork != widget.artwork) {
      _extractColorsFromArtwork();
    }
  }

  Future<void> _extractColorsFromArtwork() async {
    if (widget.artwork == null) {
      _setDefaultColors();
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final PaletteGenerator palette = await PaletteGenerator.fromImageProvider(
        widget.artwork!,
        maximumColorCount: 6,
      );

      final colors = <Color>[];
      
      // Extract colors from palette
      if (palette.dominantColor != null) {
        colors.add(palette.dominantColor!.color);
      }
      if (palette.vibrantColor != null) {
        colors.add(palette.vibrantColor!.color);
      }
      if (palette.mutedColor != null) {
        colors.add(palette.mutedColor!.color);
      }
      if (palette.darkVibrantColor != null) {
        colors.add(palette.darkVibrantColor!.color);
      }

      // Ensure we have at least 4 colors for the mesh
      while (colors.length < 4) {
        colors.add(_getDefaultColor(colors.length));
      }

      setState(() {
        _artworkColors = colors.take(4).toList();
        _isLoading = false;
      });
    } catch (e) {
      _setDefaultColors();
    }
  }

  void _setDefaultColors() {
    setState(() {
      _artworkColors = widget.isDarkMode
          ? [
              const Color(0xFF1A237E),
              const Color(0xFF311B92),
              const Color(0xFF512DA8),
              const Color(0xFF7B1FA2),
            ]
          : [
              const Color(0xFFE3F2FD),
              const Color(0xFFBBDEFB),
              const Color(0xFF90CAF9),
              const Color(0xFF64B5F6),
            ];
      _isLoading = false;
    });
  }

  Color _getDefaultColor(int index) {
    if (widget.isDarkMode) {
      switch (index) {
        case 0: return const Color(0xFF1A237E);
        case 1: return const Color(0xFF311B92);
        case 2: return const Color(0xFF512DA8);
        default: return const Color(0xFF7B1FA2);
      }
    } else {
      switch (index) {
        case 0: return const Color(0xFFE3F2FD);
        case 1: return const Color(0xFFBBDEFB);
        case 2: return const Color(0xFF90CAF9);
        default: return const Color(0xFF64B5F6);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _artworkColors.isEmpty) {
      _setDefaultColors();
    }

    return Stack(
      children: [
        Positioned.fill(
          child: OMeshGradient(
            mesh: OMeshRect(
              width: 2,
              height: 2,
              fallbackColor: _artworkColors.isNotEmpty 
                  ? _artworkColors.first 
                  : (widget.isDarkMode ? const Color(0xFF1A237E) : const Color(0xFFE3F2FD)),
              vertices: [
                // Top-left corner
                (0.0, 0.0).v.to(_artworkColors.isNotEmpty ? _artworkColors[0] : _getDefaultColor(0)),
                // Top-right corner  
                (1.0, 0.0).v.to(_artworkColors.length > 1 ? _artworkColors[1] : _getDefaultColor(1)),
                // Bottom-left corner
                (0.0, 1.0).v.to(_artworkColors.length > 2 ? _artworkColors[2] : _getDefaultColor(2)),
                // Bottom-right corner
                (1.0, 1.0).v.to(_artworkColors.length > 3 ? _artworkColors[3] : _getDefaultColor(3)),
              ],
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}