import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import 'common.dart';

/// Анимированная заглушка на время загрузки.
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, this.width, this.height = 14, this.radius = 8});

  final double? width;
  final double height;
  final double radius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final color = Color.lerp(AppColors.skeletonA, AppColors.skeletonB, _controller.value)!;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(widget.radius),
          ),
        );
      },
    );
  }
}

class ProductCardSkeleton extends StatelessWidget {
  const ProductCardSkeleton({super.key, this.width});

  final double? width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: SurfaceCard(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const <Widget>[
            AspectRatio(aspectRatio: 1.4, child: Skeleton(height: double.infinity, radius: 0)),
            Padding(
              padding: EdgeInsets.fromLTRB(10, 10, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Skeleton(width: 60, height: 10),
                  SizedBox(height: 8),
                  Skeleton(height: 12),
                  SizedBox(height: 6),
                  Skeleton(width: 90, height: 12),
                  SizedBox(height: 14),
                  Skeleton(width: 80, height: 18),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProductTileSkeleton extends StatelessWidget {
  const ProductTileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const SurfaceCard(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: EdgeInsets.all(10),
      child: Row(
        children: <Widget>[
          Skeleton(width: 92, height: 92, radius: 12),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Skeleton(width: 70, height: 10),
                SizedBox(height: 8),
                Skeleton(height: 12),
                SizedBox(height: 6),
                Skeleton(width: 120, height: 10),
                SizedBox(height: 16),
                Skeleton(width: 90, height: 18),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ProductListSkeleton extends StatelessWidget {
  const ProductListSkeleton({super.key, this.count = 6});

  final int count;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 8),
      itemCount: count,
      itemBuilder: (_, __) => const ProductTileSkeleton(),
    );
  }
}

class HorizontalProductsSkeleton extends StatelessWidget {
  const HorizontalProductsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 312,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        itemCount: 3,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, __) => const ProductCardSkeleton(width: 176),
      ),
    );
  }
}

/// Простая карточка-заглушка для блоков без своей формы.
class BlockSkeleton extends StatelessWidget {
  const BlockSkeleton({super.key, this.height = 120, this.margin = const EdgeInsets.symmetric(horizontal: 16)});

  final double height;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: Skeleton(height: height, radius: AppRadius.lg),
    );
  }
}
