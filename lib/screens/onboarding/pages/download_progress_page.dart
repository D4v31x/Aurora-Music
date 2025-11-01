import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../widgets/pill_button.dart';
import '../../../services/batch_download_service.dart';

class DownloadProgressPage extends StatefulWidget {
  final VoidCallback onComplete;
  final bool downloadLyrics;
  final bool downloadArtwork;

  const DownloadProgressPage({
    super.key,
    required this.onComplete,
    required this.downloadLyrics,
    required this.downloadArtwork,
  });

  @override
  State<DownloadProgressPage> createState() => _DownloadProgressPageState();
}

class _DownloadProgressPageState extends State<DownloadProgressPage>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _pulseController;
  late AnimationController _progressBarController;
  late AnimationController _statsController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _progressBarAnimation;
  late Animation<double> _statsAnimation;

  final BatchDownloadService _downloadService = BatchDownloadService();
  StreamSubscription<DownloadProgress>? _progressSubscription;

  DownloadProgress? _currentProgress;
  bool _isDownloadComplete = false;
  bool _hasStarted = false;

  @override
  void initState() {
    super.initState();

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

    // Pulse animation for download icon
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(
      begin: 0.9,
      end: 1.1,
    ).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );

    // Progress bar shimmer animation
    _progressBarController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();

    _progressBarAnimation = Tween<double>(
      begin: -1.0,
      end: 2.0,
    ).animate(
      CurvedAnimation(
        parent: _progressBarController,
        curve: Curves.easeInOut,
      ),
    );

    // Stats fade-in animation
    _statsController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _statsAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _statsController,
        curve: Curves.easeOut,
      ),
    );

    _controller.forward();
    _statsController.forward();

    // Start download after a short delay
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _startDownload();
      }
    });
  }

  Future<void> _startDownload() async {
    if (_hasStarted) return;
    _hasStarted = true;

    // Listen to progress updates from the stream
    _progressSubscription = _downloadService.progressStream.listen((progress) {
      if (mounted) {
        setState(() {
          _currentProgress = progress;
          if (progress.isComplete && !_isDownloadComplete) {
            _isDownloadComplete = true;
            // Use a short delay to allow the user to see the completion status
            Future.delayed(const Duration(seconds: 2), () {
              if (mounted) {
                widget.onComplete();
              }
            });
          }
        });
      }
    });

    // Start the download but don't await it here,
    // as we are listening to the stream for progress.
    _downloadService.startBatchDownload(
      downloadLyrics: widget.downloadLyrics,
      downloadArtwork: widget.downloadArtwork,
    );
  }

  @override
  void dispose() {
    _progressSubscription?.cancel();
    _controller.dispose();
    _pulseController.dispose();
    _progressBarController.dispose();
    _statsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final textColor = isDark ? Colors.white : Colors.black;
    final subtitleColor =
        isDark ? Colors.white.withOpacity(0.6) : Colors.black.withOpacity(0.6);
    final progressBgColor =
        isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: SlideTransition(
            position: _slideAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                children: [
                  const SizedBox(height: 80),

                  // Title with animation
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 600),
                    transitionBuilder: (child, animation) {
                      return SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.15),
                          end: Offset.zero,
                        ).animate(
                          CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeOutCubic,
                          ),
                        ),
                        child: FadeTransition(
                          opacity: animation,
                          child: child,
                        ),
                      );
                    },
                    child: Text(
                      key: ValueKey(_isDownloadComplete),
                      _isDownloadComplete
                          ? 'Download Complete!'
                          : 'Downloading Content',
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
                  const SizedBox(height: 12),

                  // Status text
                  AnimatedOpacity(
                    opacity: _isDownloadComplete ? 0.0 : 1.0,
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      _currentProgress?.currentStatus ?? 'Preparing...',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: subtitleColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 48),

                  // Progress bar with shimmer effect
                  AnimatedOpacity(
                    opacity: _isDownloadComplete ? 0.0 : 1.0,
                    duration: const Duration(milliseconds: 400),
                    child: _currentProgress != null
                        ? Column(
                            children: [
                              Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      height: 10,
                                      decoration: BoxDecoration(
                                        color: progressBgColor,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: SizedBox(
                                      height: 10,
                                      child: AnimatedBuilder(
                                        animation: _progressBarAnimation,
                                        builder: (context, child) {
                                          return LinearProgressIndicator(
                                            value: _currentProgress!.percentage,
                                            backgroundColor: Colors.transparent,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                              Theme.of(context)
                                                  .colorScheme
                                                  .primary,
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${_currentProgress!.completed + _currentProgress!.failed} / ${_currentProgress!.total}',
                                    style: TextStyle(
                                      fontFamily: 'Outfit',
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: textColor,
                                    ),
                                  ),
                                  Text(
                                    '${(_currentProgress!.percentage * 100).toStringAsFixed(0)}%',
                                    style: TextStyle(
                                      fontFamily: 'Outfit',
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          )
                        : const SizedBox.shrink(),
                  ),

                  const SizedBox(height: 32),

                  // Stats cards with staggered fade-in - hide when complete
                  AnimatedOpacity(
                    opacity: _isDownloadComplete ? 0.0 : 1.0,
                    duration: const Duration(milliseconds: 400),
                    child: Row(
                      children: [
                        Expanded(
                          child: TweenAnimationBuilder<double>(
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.elasticOut,
                            tween: Tween<double>(begin: 0.8, end: 1.0),
                            builder: (context, scale, child) {
                              return Transform.scale(
                                scale: scale,
                                child: _buildStatCard(
                                  icon: Icons.check_circle_outline_rounded,
                                  label: 'Completed',
                                  value: '${_currentProgress?.completed ?? 0}',
                                  color: const Color(0xFF10B981),
                                  isDark: isDark,
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TweenAnimationBuilder<double>(
                            duration: const Duration(milliseconds: 600),
                            curve: Curves.elasticOut,
                            tween: Tween<double>(begin: 0.8, end: 1.0),
                            builder: (context, scale, child) {
                              return Transform.scale(
                                scale: scale,
                                child: _buildStatCard(
                                  icon: Icons.error_outline_rounded,
                                  label: 'Failed',
                                  value: '${_currentProgress?.failed ?? 0}',
                                  color: const Color(0xFFF59E0B),
                                  isDark: isDark,
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (_isDownloadComplete)
                    FadeTransition(
                      opacity: _statsAnimation,
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFF10B981).withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_rounded,
                                color: Color(0xFF10B981), size: 24),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'All done! Ready to explore Aurora Music.',
                                style: TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: textColor.withOpacity(0.9),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 24),

                  // Current item with slide animation
                  if (_currentProgress?.currentItem != null &&
                      !_isDownloadComplete) ...[
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      transitionBuilder: (child, animation) {
                        return SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.2),
                            end: Offset.zero,
                          ).animate(CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeOutCubic,
                          )),
                          child: FadeTransition(
                            opacity: animation,
                            child: child,
                          ),
                        );
                      },
                      child: Container(
                        key: ValueKey(_currentProgress?.currentItem),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.1),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _currentProgress!.currentItem!.title,
                                style: TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w400,
                                  color: textColor.withOpacity(0.8),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  const Spacer(),

                  // Skip/Continue button
                  if (!_isDownloadComplete)
                    Padding(
                      padding: const EdgeInsets.only(
                          bottom: 40.0, left: 24.0, right: 24.0),
                      child: PillButton(
                        text: 'Skip & Continue',
                        onPressed: widget.onComplete,
                        isPrimary: false,
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),

                  // Complete button
                  if (_isDownloadComplete)
                    Padding(
                      padding: const EdgeInsets.only(
                          bottom: 40.0, left: 24.0, right: 24.0),
                      child: PillButton(
                        text: 'Continue',
                        onPressed: widget.onComplete,
                        isPrimary: true,
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
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

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    final textColor = isDark ? Colors.white : Colors.black;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: textColor.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }
}
