import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/category_icons.dart';

/// Картинка товара: кэшируется на диске, а если URL нет или он недоступен —
/// показывается аккуратная заглушка с иконкой категории (работает офлайн).
class ProductImage extends StatelessWidget {
  const ProductImage({
    super.key,
    required this.categoryId,
    this.url,
    this.fit = BoxFit.cover,
    this.borderRadius = 0,
  });

  final String categoryId;
  final String? url;
  final BoxFit fit;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final placeholder = _ImagePlaceholder(categoryId: categoryId);
    final source = url;
    final Widget image = (source == null || source.isEmpty)
        ? placeholder
        : source.startsWith('assets/')
            // Картинка, встроенная в приложение (работает без интернета).
            ? Image.asset(
                source,
                fit: fit,
                cacheWidth: 700,
                gaplessPlayback: true,
                errorBuilder: (context, _, __) => placeholder,
              )
            : CachedNetworkImage(
                imageUrl: source,
                fit: fit,
                fadeInDuration: const Duration(milliseconds: 150),
                placeholder: (context, _) => placeholder,
                errorWidget: (context, _, __) => placeholder,
              );
    if (borderRadius == 0) return image;
    return ClipRRect(borderRadius: BorderRadius.circular(borderRadius), child: image);
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder({required this.categoryId});

  final String categoryId;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = constraints.biggest.shortestSide;
        final base = side.isFinite ? side * 0.38 : 40.0;
        final iconSize = math.max(20.0, math.min(72.0, base));
        return Container(
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[AppColors.surfaceAlt, Color(0xFFE2E8F1)],
            ),
          ),
          child: Icon(CategoryIcons.of(categoryId), size: iconSize, color: AppColors.textHint),
        );
      },
    );
  }
}
