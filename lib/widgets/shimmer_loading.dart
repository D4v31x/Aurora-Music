import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

/// Shimmer effect for loading states - creates smooth, animated placeholders
class ShimmerLoading extends HookWidget {
  final double width;
  final double height;
  final double borderRadius;
  final bool isCircle;

  const ShimmerLoading({
    super.key,
    this.width = double.infinity,
    this.height = 50,
    this.borderRadius = 8,
    this.isCircle = false,
  });

  @override
  Widget build(BuildContext context) {
    final controller = useAnimationController(
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    final animation = useAnimation(
      Tween<double>(begin: -2, end: 2).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeInOutSine),
      ),
    );

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: isCircle ? null : BorderRadius.circular(borderRadius),
        shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
        gradient: LinearGradient(
          begin: Alignment(animation, 0),
          end: Alignment(animation + 1, 0),
          colors: [
            Colors.white.withOpacity(0.05),
            Colors.white.withOpacity(0.15),
            Colors.white.withOpacity(0.05),
          ],
        ),
      ),
    );
  }
}

/// Song tile skeleton for loading states
class SongTileSkeleton extends StatelessWidget {
  const SongTileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        children: [
          const ShimmerLoading(width: 50, height: 50, borderRadius: 8),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                ShimmerLoading(width: 150, height: 14, borderRadius: 4),
                SizedBox(height: 6),
                ShimmerLoading(width: 100, height: 12, borderRadius: 4),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Album/Artist card skeleton for loading states
class CardSkeleton extends StatelessWidget {
  final double size;
  final bool isCircle;

  const CardSkeleton({
    super.key,
    this.size = 120,
    this.isCircle = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ShimmerLoading(
          width: size,
          height: size,
          borderRadius: isCircle ? size / 2 : 12,
          isCircle: isCircle,
        ),
        const SizedBox(height: 8),
        ShimmerLoading(width: size * 0.8, height: 12, borderRadius: 4),
        const SizedBox(height: 4),
        ShimmerLoading(width: size * 0.6, height: 10, borderRadius: 4),
      ],
    );
  }
}

/// Grid skeleton for loading grids of items
class GridSkeleton extends StatelessWidget {
  final int itemCount;
  final int crossAxisCount;
  final double itemSize;
  final bool isCircle;

  const GridSkeleton({
    super.key,
    this.itemCount = 6,
    this.crossAxisCount = 3,
    this.itemSize = 100,
    this.isCircle = false,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: 0.8,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) => CardSkeleton(
        size: itemSize,
        isCircle: isCircle,
      ),
    );
  }
}

/// List skeleton for loading lists of items
class ListSkeleton extends StatelessWidget {
  final int itemCount;

  const ListSkeleton({super.key, this.itemCount = 5});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        itemCount,
        (index) => const SongTileSkeleton(),
      ),
    );
  }
}

/// Header skeleton for artist/album detail screens
class DetailHeaderSkeleton extends StatelessWidget {
  final bool isArtist;

  const DetailHeaderSkeleton({super.key, this.isArtist = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ShimmerLoading(
          width: 200,
          height: 200,
          borderRadius: isArtist ? 100 : 16,
          isCircle: isArtist,
        ),
        const SizedBox(height: 16),
        const ShimmerLoading(width: 180, height: 24, borderRadius: 6),
        const SizedBox(height: 8),
        const ShimmerLoading(width: 120, height: 16, borderRadius: 4),
      ],
    );
  }
}
