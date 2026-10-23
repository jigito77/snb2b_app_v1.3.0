import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/currency_button.dart';
import '../../../../core/l10n/app_text.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/common.dart';
import '../../../../shared/widgets/product_image.dart';
import '../../../../shared/widgets/quantity_selector.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/cart_item.dart';
import '../providers/cart_provider.dart';
import '../../../../shared/widgets/state_views.dart';

class CartPage extends ConsumerStatefulWidget {
  const CartPage({super.key});

  @override
  ConsumerState<CartPage> createState() => _CartPageState();
}

class _CartPageState extends ConsumerState<CartPage> {
  @override
  void initState() {
    super.initState();
    // Актуализируем цены и остатки при открытии корзины.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(cartProvider.notifier).refresh();
    });
  }

  Future<void> _confirmClear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        title: const Text('Очистить корзину?', style: AppText.h2),
        content: const Text('Все товары будут удалены из корзины.'),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Отмена')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Очистить')),
        ],
      ),
    );
    if (ok == true) ref.read(cartProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(cartProvider);
    final auth = ref.watch(authControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Корзина'),
        actions: <Widget>[
          const CurrencyButton(),
          if (items.isNotEmpty)
            IconButton(
              tooltip: tr('Очистить корзину'),
              onPressed: _confirmClear,
              icon: const Icon(Icons.delete_sweep_outlined),
            ),
        ],
      ),
      body: items.isEmpty
          ? EmptyState(
              icon: Icons.shopping_cart_outlined,
              title: 'Корзина пуста',
              message: 'Добавьте товары из каталога или найдите запчасть по артикулу.',
              actionLabel: 'Перейти в каталог',
              onAction: () => context.go('/catalog'),
            )
          : Column(
              children: <Widget>[
                Expanded(
                  child: RefreshIndicator(
                    color: AppColors.accent,
                    onRefresh: () => ref.read(cartProvider.notifier).refresh(),
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(top: 8, bottom: 16),
                      children: <Widget>[
                        _PriceHint(isAuthenticated: auth.isAuthenticated, isB2b: auth.isB2b),
                        for (final item in items) _CartItemCard(key: ValueKey<String>(item.product.id), item: item),
                      ],
                    ),
                  ),
                ),
                _SummaryBar(items: items),
              ],
            ),
    );
  }
}

class _PriceHint extends StatelessWidget {
  const _PriceHint({required this.isAuthenticated, required this.isB2b});

  final bool isAuthenticated;
  final bool isB2b;

  @override
  Widget build(BuildContext context) {
    if (isB2b) {
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.successSoft, borderRadius: BorderRadius.circular(AppRadius.md)),
        child: const Row(
          children: <Widget>[
            Icon(Icons.verified_outlined, color: AppColors.success, size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Применены ваши персональные и оптовые цены.',
                style: TextStyle(fontSize: 13, color: AppColors.success, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    }
    if (!isAuthenticated) {
      return InkWell(
        onTap: () => context.push('/login?from=${Uri.encodeComponent('/cart')}'),
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 4, 16, 6),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppColors.infoSoft, borderRadius: BorderRadius.circular(AppRadius.md)),
          child: const Row(
            children: <Widget>[
              Icon(Icons.lock_outline, color: AppColors.info, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Войдите, чтобы увидеть персональные цены и оформить заказ.',
                  style: TextStyle(fontSize: 13, color: AppColors.info, fontWeight: FontWeight.w600),
                ),
              ),
              Icon(Icons.chevron_right, color: AppColors.info),
            ],
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

class _CartItemCard extends ConsumerWidget {
  const _CartItemCard({super.key, required this.item});

  final CartItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = item.product;
    final notifier = ref.read(cartProvider.notifier);
    final level = item.priceLevel;
    final wt = item.weightKg;
    return Dismissible(
      key: ValueKey<String>('dismiss-${item.key}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => notifier.remove(p.id, offer: item.offer),
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(color: AppColors.danger, borderRadius: BorderRadius.circular(AppRadius.lg)),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      child: SurfaceCard(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            InkWell(
              onTap: () => context.push('/product/${p.id}'),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SizedBox(
                    width: 72,
                    height: 72,
                    child: ProductImage(
                      categoryId: p.categoryId,
                      url: p.images.isEmpty ? null : p.images.first,
                      borderRadius: 12,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          p.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 1.25),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Арт. ${item.offerData?.partNumber.isNotEmpty == true ? item.offerData!.partNumber : p.article}'
                          '${item.offer.isEmpty ? '' : ' · ${item.offer}'}',
                          style: AppText.caption,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: <Widget>[
                            Text(Fmt.price(item.unitPrice), style: AppText.body.copyWith(fontWeight: FontWeight.w700)),
                            Text(' за шт.', style: AppText.caption),
                            if (level.isNotEmpty) ...<Widget>[
                              const SizedBox(width: 6),
                              Flexible(
                                child: InfoPill(
                                  text: level,
                                  background: AppColors.successSoft,
                                  foreground: AppColors.success,
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (wt != null)
                          Text(
                            'Вес: ${Fmt.kg(item.unitWeightKg)} кг/шт. · всего ${Fmt.kg(wt)} кг',
                            style: AppText.caption,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (!p.canOrder) ...<Widget>[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AppColors.dangerSoft, borderRadius: BorderRadius.circular(AppRadius.md)),
                child: const Row(
                  children: <Widget>[
                    Icon(Icons.info_outline, color: AppColors.danger, size: 18),
                    SizedBox(width: 8),
                    Expanded(child: Text('Товар временно отсутствует.', style: TextStyle(fontSize: 13))),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                if (p.canOrder)
                  QuantitySelector(
                    compact: true,
                    value: item.qty,
                    min: item.minQty,
                    max: p.maxQty,
                    onChanged: (v) => notifier.setQty(p.id, v, offer: item.offer),
                    onRemove: () => notifier.remove(p.id, offer: item.offer),
                  )
                else
                  TextButton.icon(
                    onPressed: () => notifier.remove(p.id, offer: item.offer),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Удалить'),
                  ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Text(Fmt.price(item.total), style: AppText.price),
                    if (item.minQty > 1) Text('Мин. заказ: ${Fmt.pieces(item.minQty)}', style: AppText.caption),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryBar extends StatelessWidget {
  const _SummaryBar({required this.items});

  final List<CartItem> items;

  @override
  Widget build(BuildContext context) {
    final hasUnavailable = items.hasUnavailable;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider)),
        boxShadow: AppShadows.card,
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                Text(
                  '${Fmt.products(items.length)} · ${Fmt.pieces(items.units)}',
                  style: AppText.bodySecondary,
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => context.push('/quote'),
                  child: const Text('Запросить КП'),
                ),
              ],
            ),
            if (items.weightKg != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: <Widget>[
                    const Text('Общий вес', style: AppText.bodySecondary),
                    const Spacer(),
                    Text('${Fmt.kg(items.weightKg)} кг', style: AppText.body),
                  ],
                ),
              ),
            Row(
              children: <Widget>[
                const Text('Итого', style: AppText.h3),
                const Spacer(),
                Text(Fmt.price(items.total), style: AppText.h1),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: hasUnavailable
                  ? () => showSnack(context, 'Удалите из корзины товары, которых нет в наличии.', error: true)
                  : () => context.push('/checkout'),
              child: const Text('Оформить заказ'),
            ),
          ],
        ),
      ),
    );
  }
}
