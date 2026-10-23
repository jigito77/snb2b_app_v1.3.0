import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_text.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../features/cart/presentation/providers/cart_provider.dart';
import '../../features/product/domain/entities/product.dart';
import '../state/product_collections.dart';
import 'common.dart';
import 'product_image.dart';

/// Кнопка «в избранное» (сердечко) — работает для гостей локально.
class FavoriteButton extends ConsumerWidget {
  const FavoriteButton({super.key, required this.product, this.size = 20});

  final Product product;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFavorite = ref.watch(favoritesProvider.select((l) => l.any((p) => p.id == product.id)));
    return InkResponse(
      radius: 22,
      onTap: () => ref.read(favoritesProvider.notifier).toggle(product),
      child: Container(
        width: 34,
        height: 34,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: AppShadows.card,
        ),
        child: Icon(
          isFavorite ? Icons.favorite : Icons.favorite_border,
          size: size,
          color: isFavorite ? AppColors.danger : AppColors.textSecondary,
        ),
      ),
    );
  }
}

/// Индикатор наличия: «В наличии» / «Нет в наличии».
class StockBadge extends StatelessWidget {
  const StockBadge({super.key, required this.product, this.showQty = false});

  final Product product;
  final bool showQty;

  @override
  Widget build(BuildContext context) {
    final inStock = product.inStock;
    final onRequest = !inStock && product.offers.isNotEmpty;
    final color = inStock ? AppColors.success : (onRequest ? AppColors.warning : AppColors.danger);
    // Остатки клиенту не раскрываются (backend отдаёт только признак), поэтому количество показываем лишь для старого формата.
    final text = inStock
        ? (showQty && product.offers.isEmpty ? 'В наличии: ${Fmt.pieces(product.stock.available)}' : 'В наличии')
        : (onRequest ? 'Под заказ' : 'Нет в наличии');
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
      ],
    );
  }
}

/// Цена за единицу с учётом количества: персональная / оптовая / розничная.
class PriceView extends StatelessWidget {
  const PriceView({
    super.key,
    required this.product,
    this.qty = 1,
    this.large = false,
    this.showKind = false,
  });

  final Product product;
  final int qty;
  final bool large;
  final bool showKind;

  @override
  Widget build(BuildContext context) {
    final unit = product.unitPrice(qty);
    final old = product.oldPrice;
    final kind = product.priceKind(qty);
    final kindLabel = kind == 'personal'
        ? 'Ваша цена'
        : (kind == 'wholesale' ? 'Оптовая цена' : null);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (showKind && kindLabel != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              kindLabel,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.success),
            ),
          ),
        Text(
          (product.offers.length > 1 && !showKind ? 'от ' : '') + Fmt.price(unit),
          style: AppText.price.copyWith(fontSize: large ? 26 : 16),
        ),
        if (product.weightKg != null && !large)
          Text('Вес ${Fmt.kg(product.weightKg)} кг', style: AppText.caption),
        if (old != null && old > unit)
          Text(
            Fmt.price(old),
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textHint,
              decoration: TextDecoration.lineThrough,
            ),
          ),
      ],
    );
  }
}

/// Быстрое добавление в корзину прямо из карточки.
class AddToCartButton extends ConsumerWidget {
  const AddToCartButton({super.key, required this.product});

  final Product product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inCart = ref.watch(cartProvider.select((l) => l.any((e) => e.product.id == product.id)));
    final enabled = product.canOrder;
    return Material(
      color: !enabled
          ? AppColors.surfaceAlt
          : (inCart ? AppColors.successSoft : AppColors.accent),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: !enabled
            ? () => showSnack(context, 'Товар временно отсутствует.', error: true)
            : () {
                final error = ref.read(cartProvider.notifier).add(product);
                showSnack(
                  context,
                  error ?? 'Добавлено в корзину',
                  error: error != null,
                  action: error == null
                      ? SnackBarAction(
                          label: tr('Корзина'),
                          textColor: AppColors.accent,
                          onPressed: () => context.go('/cart'),
                        )
                      : null,
                );
              },
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(
            inCart ? Icons.check : Icons.add_shopping_cart,
            size: 20,
            color: !enabled
                ? AppColors.textHint
                : (inCart ? AppColors.success : AppColors.onAccent),
          ),
        ),
      ),
    );
  }
}

class _ProductBadges extends StatelessWidget {
  const _ProductBadges({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (product.isSpecial)
          const InfoPill(text: 'Акция', background: AppColors.accentSoft, foreground: AppColors.accentDark),
        if (product.isSpecial && product.isNew) const SizedBox(height: 4),
        if (product.isNew) const InfoPill(text: 'Новинка'),
      ],
    );
  }
}

/// Вертикальная карточка для горизонтальных подборок и сетки.
class ProductCard extends StatelessWidget {
  const ProductCard({super.key, required this.product, this.width});

  final Product product;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final p = product;
    return SizedBox(
      width: width,
      child: SurfaceCard(
        padding: EdgeInsets.zero,
        onTap: () => context.push('/product/${p.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Stack(
              children: <Widget>[
                AspectRatio(
                  aspectRatio: 1.4,
                  child: ProductImage(
                    categoryId: p.categoryId,
                    url: p.images.isEmpty ? null : p.images.first,
                  ),
                ),
                Positioned(left: 8, top: 8, child: _ProductBadges(product: p)),
                Positioned(right: 8, top: 8, child: FavoriteButton(product: p)),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(p.brandName, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.caption),
                  const SizedBox(height: 2),
                  SizedBox(
                    height: 36,
                    child: Text(
                      p.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text('Арт. ${p.article}', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.caption),
                  const SizedBox(height: 6),
                  StockBadge(product: p),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      Expanded(child: PriceView(product: p, qty: p.effectiveMinQty)),
                      AddToCartButton(product: p),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Горизонтальная карточка для списков каталога и поиска.
class ProductTile extends StatelessWidget {
  const ProductTile({super.key, required this.product, this.onOpen});

  final Product product;

  /// Вызывается перед переходом в карточку (например, чтобы сохранить запрос в историю поиска).
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final p = product;
    return SurfaceCard(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(10),
      onTap: () {
        onOpen?.call();
        context.push('/product/${p.id}');
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 96,
            height: 96,
            child: Stack(
              children: <Widget>[
                Positioned.fill(
                  child: ProductImage(
                    categoryId: p.categoryId,
                    url: p.images.isEmpty ? null : p.images.first,
                    borderRadius: 12,
                  ),
                ),
                if (p.isSpecial || p.isNew)
                  Positioned(left: 4, top: 4, child: _ProductBadges(product: p)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(p.brandName, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.caption),
                    ),
                    FavoriteButton(product: p, size: 18),
                  ],
                ),
                Text(
                  p.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Арт. ${p.article}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption,
                ),
                const SizedBox(height: 6),
                Row(
                  children: <Widget>[
                    StockBadge(product: p),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        p.inStock ? p.deliveryLabel : 'под заказ ${p.deliveryLabel}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.caption,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Expanded(child: PriceView(product: p, qty: p.effectiveMinQty)),
                    AddToCartButton(product: p),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
