import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/app_text.dart';
import '../../../../app/di.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/common.dart';
import '../../../../shared/widgets/manager_sheet.dart';
import '../../../../shared/widgets/skeleton.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../cart/presentation/providers/cart_provider.dart';
import '../../../product/domain/entities/product.dart';
import '../../domain/entities/order.dart';
import '../providers/orders_providers.dart';
import '../widgets/order_widgets.dart';

class OrderDetailPage extends ConsumerWidget {
  const OrderDetailPage({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(orderProvider(orderId));
    return Scaffold(
      appBar: AppBar(title: const Text('Заказ')),
      body: async.when(
        loading: () => ListView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.only(top: 12),
          children: const <Widget>[
            BlockSkeleton(height: 120, margin: EdgeInsets.fromLTRB(16, 0, 16, 12)),
            BlockSkeleton(height: 200, margin: EdgeInsets.fromLTRB(16, 0, 16, 12)),
            BlockSkeleton(height: 140, margin: EdgeInsets.fromLTRB(16, 0, 16, 12)),
          ],
        ),
        error: (e, _) => ErrorState(error: e, onRetry: () => ref.invalidate(orderProvider(orderId))),
        data: (order) => _OrderView(order: order),
      ),
    );
  }
}

class _OrderView extends ConsumerStatefulWidget {
  const _OrderView({required this.order});

  final Order order;

  @override
  ConsumerState<_OrderView> createState() => _OrderViewState();
}

class _OrderViewState extends ConsumerState<_OrderView> {
  bool _repeating = false;
  bool _invoiceLoading = false;
  bool _invoiceSent = false;

  Future<void> _repeat() async {
    final order = widget.order;
    setState(() => _repeating = true);
    try {
      final products = await ref
          .read(catalogRepositoryProvider)
          .productsByIds(order.items.map((e) => e.productId).toList());
      final byId = <String, Product>{for (final p in products) p.id: p};
      final cart = ref.read(cartProvider.notifier);
      var added = 0;
      var skipped = 0;
      for (final item in order.items) {
        final product = byId[item.productId];
        if (product == null || !product.canOrder) {
          skipped++;
          continue;
        }
        final error = cart.add(product, qty: item.qty, offer: item.offer.isEmpty ? null : item.offer);
        if (error == null) {
          added++;
        } else {
          skipped++;
        }
      }
      if (!mounted) return;
      setState(() => _repeating = false);
      if (added == 0) {
        showSnack(context, 'Товары из этого заказа сейчас недоступны.', error: true);
        return;
      }
      showSnack(
        context,
        skipped == 0
            ? 'Позиции добавлены в корзину'
            : 'Добавлено позиций: $added. Недоступно: $skipped',
      );
      context.go('/cart');
    } catch (e) {
      if (!mounted) return;
      setState(() => _repeating = false);
      showSnack(context, errorMessage(e), error: true);
    }
  }

  Future<void> _requestInvoice() async {
    setState(() => _invoiceLoading = true);
    try {
      await ref.read(ordersRepositoryProvider).requestInvoice(widget.order.id);
      if (!mounted) return;
      setState(() {
        _invoiceLoading = false;
        _invoiceSent = true;
      });
      showSnack(context, 'Запрос счёта отправлен менеджеру.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _invoiceLoading = false);
      showSnack(context, errorMessage(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: () async {
        ref.invalidate(orderProvider(o.id));
        try {
          await ref.read(orderProvider(o.id).future);
        } catch (_) {
          // ошибка отобразится на экране
        }
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: <Widget>[
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text('Заказ №${o.number}', style: AppText.h2),
                          const SizedBox(height: 2),
                          Text(Fmt.dateTime(o.createdAt), style: AppText.caption),
                        ],
                      ),
                    ),
                    OrderStatusPill(status: o.status),
                  ],
                ),
                const SizedBox(height: 18),
                OrderTimeline(status: o.status),
                if (o.managerComment.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.infoSoft,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Icon(Icons.chat_bubble_outline, size: 18, color: AppColors.info),
                        const SizedBox(width: 8),
                        Expanded(child: Text(o.managerComment, style: AppText.body)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SectionHeader(title: 'Состав заказа'),
          SurfaceCard(
            child: Column(
              children: <Widget>[
                for (var i = 0; i < o.items.length; i++) ...<Widget>[
                  if (i > 0) const Divider(height: 20),
                  InkWell(
                    onTap: () => context.push('/product/${o.items[i].productId}'),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(o.items[i].name, style: AppText.body),
                              const SizedBox(height: 2),
                              Text(
                                'Арт. ${o.items[i].article}${o.items[i].offer.isEmpty ? '' : ' · ${o.items[i].offer}'} · ${Fmt.pieces(o.items[i].qty)} × ${Fmt.price(o.items[i].unit, currency: o.currency.isEmpty ? null : o.currency)}',
                                style: AppText.caption,
                              ),
                              if (o.items[i].weightKg != null)
                                Text(
                                  'Вес: ${Fmt.kg(o.items[i].unitWeightKg)} кг/шт. · всего ${Fmt.kg(o.items[i].weightKg)} кг',
                                  style: AppText.caption,
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          Fmt.price(o.items[i].total, currency: o.currency.isEmpty ? null : o.currency),
                          style: AppText.body.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ],
                const Divider(height: 24),
                if (o.displayItemsTotal != null)
                  KeyValueRow(
                    label: 'Товары',
                    value: Fmt.price(o.displayItemsTotal!, currency: o.currency.isEmpty ? null : o.currency),
                  ),
                if (o.totalWeightKg != null) KeyValueRow(label: 'Вес товаров', value: '${Fmt.kg(o.totalWeightKg)} кг'),
                if (o.delivery?.distanceKm != null)
                  KeyValueRow(label: 'Расстояние', value: '${Fmt.kg(o.delivery!.distanceKm)} км'),
                if (o.displayDeliveryTotal != null && o.deliveryMethod == 'delivery')
                  KeyValueRow(
                    label: 'Доставка',
                    value: Fmt.price(o.displayDeliveryTotal!, currency: o.currency.isEmpty ? null : o.currency),
                  ),
                Row(
                  children: <Widget>[
                    const Text('Итого', style: AppText.h3),
                    const Spacer(),
                    Text(
                      Fmt.price(o.shownTotal, currency: o.currency.isEmpty ? null : o.currency),
                      style: AppText.h1,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SectionHeader(title: 'Доставка и оплата'),
          SurfaceCard(
            child: Column(
              children: <Widget>[
                KeyValueRow(label: 'Доставка', value: CheckoutOptions.deliveryTitle(o.deliveryMethod)),
                KeyValueRow(label: 'Адрес', value: o.address.isEmpty ? '—' : o.address),
                const Divider(height: 1),
                KeyValueRow(label: 'Оплата', value: CheckoutOptions.paymentTitle(o.paymentMethod)),
                const Divider(height: 1),
                KeyValueRow(label: 'Контакт', value: o.contactName),
                KeyValueRow(label: 'Телефон', value: o.phone),
                if (o.company.isNotEmpty) KeyValueRow(label: 'Компания', value: o.company),
                if (o.comment.isNotEmpty) KeyValueRow(label: 'Комментарий', value: o.comment),
              ],
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _repeating ? null : _repeat,
            icon: _repeating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.2, color: AppColors.accent),
                  )
                : const Icon(Icons.replay),
            label: const Text('Повторить заказ'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: (_invoiceLoading || _invoiceSent) ? null : _requestInvoice,
            icon: _invoiceLoading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(_invoiceSent ? Icons.check : Icons.description_outlined),
            label: Text(_invoiceSent ? 'Счёт запрошен' : 'Запросить счёт'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => showManagerSheet(context),
            icon: const Icon(Icons.support_agent),
            label: const Text('Связаться с менеджером'),
          ),
        ],
      ),
    );
  }
}
