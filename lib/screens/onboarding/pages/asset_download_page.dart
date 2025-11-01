import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../widgets/pill_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AssetDownloadPage extends StatefulWidget {
  final VoidCallback onContinue;
  final VoidCallback onBack;

  const AssetDownloadPage({
    super.key,
    required this.onContinue,
    required this.onBack,
  });

  @override
  State<AssetDownloadPage> createState() => _AssetDownloadPageState();
}

class _AssetDownloadPageState extends State<AssetDownloadPage>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _exitController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _exitFadeAnimation;
  late Animation<Offset> _exitSlideAnimation;

  bool _downloadAlbumArt = true;
  bool _downloadLyrics = true;
  bool _downloadOnWifiOnly = true;
  bool _autoDownloadNewSongs = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ),
    );

    _exitController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _exitFadeAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(
      CurvedAnimation(
        parent: _exitController,
        curve: Curves.easeIn,
      ),
    );

    _exitSlideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, -0.08),
    ).animate(
      CurvedAnimation(
        parent: _exitController,
        curve: Curves.easeInCubic,
      ),
    );

    _controller.forward();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _downloadAlbumArt = prefs.getBool('download_album_art') ?? true;
      _downloadLyrics = prefs.getBool('download_lyrics') ?? true;
      _downloadOnWifiOnly = prefs.getBool('download_wifi_only') ?? true;
      _autoDownloadNewSongs = prefs.getBool('auto_download_new') ?? false;
    });
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('download_album_art', _downloadAlbumArt);
    await prefs.setBool('download_lyrics', _downloadLyrics);
    await prefs.setBool('download_wifi_only', _downloadOnWifiOnly);
    await prefs.setBool('auto_download_new', _autoDownloadNewSongs);
  }

  @override
  void dispose() {
    _controller.dispose();
    _exitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final textColor = isDark ? Colors.white : Colors.black;
    final subtitleColor =
        isDark ? Colors.white.withOpacity(0.6) : Colors.black.withOpacity(0.6);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: AnimatedBuilder(
            animation: Listenable.merge([_controller, _exitController]),
            builder: (context, child) {
              final slidePos =
                  _exitController.isAnimating || _exitController.isCompleted
                      ? _exitSlideAnimation
                      : _slideAnimation;
              final fadeOp =
                  _exitController.isAnimating || _exitController.isCompleted
                      ? _exitFadeAnimation
                      : _fadeAnimation;

              return Column(
                children: [
                  const SizedBox(height: 80),

                  // Title
                  SlideTransition(
                    position: slidePos,
                    child: FadeTransition(
                      opacity: fadeOp,
                      child: Text(
                        'Download Preferences',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 32,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                          letterSpacing: -0.8,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Subtitle
                  FadeTransition(
                    opacity: fadeOp,
                    child: Text(
                      'Choose what to download for your music',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: subtitleColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  const SizedBox(height: 48),

                  // Options list
                  Expanded(
                    child: SlideTransition(
                      position: slidePos,
                      child: FadeTransition(
                        opacity: fadeOp,
                        child: ListView(
                          children: [
                            _buildOptionItem(
                              icon: Icons.image_rounded,
                              title: 'Download Album Art',
                              description:
                                  'Automatically fetch album covers for all songs',
                              value: _downloadAlbumArt,
                              onChanged: (value) {
                                setState(() {
                                  _downloadAlbumArt = value;
                                });
                                _savePreferences();
                              },
                              isDark: isDark,
                            ),
                            const SizedBox(height: 12),
                            _buildOptionItem(
                              icon: Icons.lyrics_rounded,
                              title: 'Download Lyrics',
                              description:
                                  'Fetch synchronized lyrics when available',
                              value: _downloadLyrics,
                              onChanged: (value) {
                                setState(() {
                                  _downloadLyrics = value;
                                });
                                _savePreferences();
                              },
                              isDark: isDark,
                            ),
                            const SizedBox(height: 12),
                            _buildOptionItem(
                              icon: Icons.wifi_rounded,
                              title: 'Wi-Fi Only',
                              description:
                                  'Download assets only when connected to Wi-Fi',
                              value: _downloadOnWifiOnly,
                              onChanged: (value) {
                                setState(() {
                                  _downloadOnWifiOnly = value;
                                });
                                _savePreferences();
                              },
                              isDark: isDark,
                            ),
                            const SizedBox(height: 12),
                            _buildOptionItem(
                              icon: Icons.auto_awesome_rounded,
                              title: 'Auto-Download for New Songs',
                              description:
                                  'Automatically download assets when adding new songs',
                              value: _autoDownloadNewSongs,
                              onChanged: (value) {
                                setState(() {
                                  _autoDownloadNewSongs = value;
                                });
                                _savePreferences();
                              },
                              isDark: isDark,
                            ),
                            const SizedBox(height: 24),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: (isDark ? Colors.white : Colors.black)
                                    .withOpacity(0.05),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: (isDark ? Colors.white : Colors.black)
                                      .withOpacity(0.1),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline_rounded,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'You can change these settings later in the app preferences.',
                                      style: TextStyle(
                                        fontFamily: 'Outfit',
                                        fontSize: 13,
                                        color: subtitleColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Navigation buttons
                  Padding(
                    padding: const EdgeInsets.only(bottom: 40.0, top: 16.0),
                    child: PillNavigationButtons(
                      onBack: widget.onBack,
                      onContinue: () async {
                        await _exitController.forward();
                        widget.onContinue();
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildOptionItem({
    required IconData icon,
    required String title,
    required String description,
    required bool value,
    required ValueChanged<bool> onChanged,
    required bool isDark,
  }) {
    final titleColor = isDark ? Colors.white : Colors.black;
    final descriptionColor =
        isDark ? Colors.white.withOpacity(0.6) : Colors.black.withOpacity(0.6);

    return Container(
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: value
              ? Theme.of(context).colorScheme.primary.withOpacity(0.3)
              : (isDark ? Colors.white : Colors.black).withOpacity(0.1),
          width: 1.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onChanged(!value),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: value
                        ? Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.15)
                        : (isDark ? Colors.white : Colors.black)
                            .withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: value
                        ? Theme.of(context).colorScheme.primary
                        : (isDark ? Colors.white : Colors.black)
                            .withOpacity(0.4),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: titleColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 13,
                          color: descriptionColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Switch(
                  value: value,
                  onChanged: onChanged,
                  activeThumbColor: Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
