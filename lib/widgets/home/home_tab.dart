import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:on_audio_query/on_audio_query.dart';
import '../../localization/app_localizations.dart';
import '../../services/local_caching_service.dart';
import 'quick_access_section.dart';
import 'suggested_tracks_section.dart';
import 'suggested_artists_section.dart';

class HomeTab extends StatefulWidget {
  final List<SongModel> randomSongs;
  final List<String> randomArtists;
  final LocalCachingArtistService artistService;
  final SongModel? currentSong;
  final Future<void> Function() onRefresh;

  const HomeTab({
    super.key,
    required this.randomSongs,
    required this.randomArtists,
    required this.artistService,
    required this.currentSong,
    required this.onRefresh,
  });

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  bool _isRefreshing = false;
  double _pullDistance = 0.0;
  final double _refreshTriggerDistance = 100.0;

  Future<void> _handleRefresh() async {
    setState(() => _isRefreshing = true);
    await widget.onRefresh();
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) {
      setState(() {
        _isRefreshing = false;
        _pullDistance = 0.0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollUpdateNotification) {
          if (notification.metrics.pixels < 0) {
            setState(() {
              _pullDistance = -notification.metrics.pixels;
            });
          }
        }
        if (notification is ScrollEndNotification) {
          if (_pullDistance >= _refreshTriggerDistance && !_isRefreshing) {
            _handleRefresh();
          } else if (!_isRefreshing) {
            setState(() => _pullDistance = 0.0);
          }
        }
        return false;
      },
      child: Stack(
        children: [
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: EdgeInsets.only(
              top: 24.0,
              bottom: widget.currentSong != null ? 100.0 : 40.0,
            ),
            child: AnimationLimiter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: AnimationConfiguration.toStaggeredList(
                  duration: const Duration(milliseconds: 375),
                  childAnimationBuilder: (w) => SlideAnimation(
                    verticalOffset: 50.0,
                    child: FadeInAnimation(child: w),
                  ),
                  children: [
                    _buildSectionTitle(
                      context,
                      AppLocalizations.of(context).translate('quick_access'),
                    ),
                    const SizedBox(height: 12.0),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.0),
                      child: RepaintBoundary(
                        child: QuickAccessSection(),
                      ),
                    ),
                    const SizedBox(height: 24.0),
                    _buildSectionTitle(
                      context,
                      AppLocalizations.of(context).translate('suggested_tracks'),
                    ),
                    const SizedBox(height: 12.0),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: RepaintBoundary(
                        child: SuggestedTracksSection(randomSongs: widget.randomSongs),
                      ),
                    ),
                    const SizedBox(height: 24.0),
                    _buildSectionTitle(
                      context,
                      AppLocalizations.of(context).translate('suggested_artists'),
                    ),
                    const SizedBox(height: 12.0),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: RepaintBoundary(
                        child: SuggestedArtistsSection(
                          randomArtists: widget.randomArtists,
                          artistService: widget.artistService,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Custom refresh indicator with text
          if (_pullDistance > 0 || _isRefreshing)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: _isRefreshing ? 60.0 : _pullDistance.clamp(0.0, 80.0),
                alignment: Alignment.center,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: (_pullDistance / _refreshTriggerDistance).clamp(0.0, 1.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_isRefreshing) ...[
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Text(
                        _isRefreshing
                            ? AppLocalizations.of(context).translate('refreshing')
                            : _pullDistance >= _refreshTriggerDistance
                                ? AppLocalizations.of(context).translate('release_to_refresh')
                                : AppLocalizations.of(context).translate('pull_to_refresh'),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              fontFamily: 'ProductSans',
            ),
      ),
    );
  }
}
