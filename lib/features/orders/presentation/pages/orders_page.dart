import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/app_text.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/common.dart';
import '../../../../shared/widgets/skeleton.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../domain/entities/order.dart';
import '../providers/orders_providers.dart';
import '../widgets/order_widgets.dart';

class OrdersPage extends ConsumerWidget {
  const OrdersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(ordersProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Мои заказы')),
      body: orders.when(
        loading: () => ListView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.only(top: 12),
          children: const <Widget>[
            BlockSkeleton(height: 120, margin: EdgeInsets.fromLTRB(16, 0, 16, 12)),
            BlockSkeleton(height: 120, margin: EdgeInsets.fromLTRB(16, 0, 16, 12)),
            BlockSkeleton(height: 120, margin: EdgeInsets.fromLTRB(16, 0, 16, 12)),
          ],
        ),
        error: (e, _) => ErrorState(error: e, onRetry: () => ref.invalidate(ordersProvider)),
        data: (list) {
          if (list.isEmpty) {
            return EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'Заказов пока нет',
              message: 'Оформленные заказы и их статусы появятся здесь.',
              actionLabel: 'Перейти в каталог',
              onAction: () => context.go('/catalog'),
            );
          }
          final current = list
              .where((o) => o.status != OrderStatus.delivered && o.status != OrderStatus.cancelled)
              .toList();
          final history = list
              .where((o) => o.status == OrderStatus.delivered || o.status == OrderStatus.cancelled)
              .toList();
          return RefreshIndicator(
            color: AppColors.accent,
            onRefresh: () async {
              ref.invalidate(ordersProvider);
              try {
                await ref.read(ordersProvider.future);
              } catch (_) {
                // ошибка будет показана экраном
              }
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 24),
              children: <Widget>[
                if (current.isNotEmpty) ...<Widget>[
                  const SectionHeader(title: 'Текущие заказы'),
                  for (final o in current) OrderCard(order: o),
                ],
                if (history.isNotEmpty) ...<Widget>[
                  const SectionHeader(title: 'История заказов'),
                  for (final o in history) OrderCard(order: o),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class OrderCard extends StatelessWidget {
  const OrderCard({super.key, required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final first = order.items.isEmpty ? null : order.items.first;
    final more = order.items.length - 1;
    return SurfaceCard(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      onTap: () => context.push('/orders/${order.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Заказ №${order.number}', style: AppText.h3),
                    const SizedBox(height: 2),
                    Text(Fmt.dateTime(order.createdAt), style: AppText.caption),
                  ],
                ),
              ),
              OrderStatusPill(status: order.status),
            ],
          ),
          if (first != null) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              more > 0 ? '${first.name} и ещё $more' : first.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppText.body,
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Text('${Fmt.products(order.items.length)} · ${Fmt.pieces(order.units)}', style: AppText.caption),
              const Spacer(),
              Text(Fmt.price(order.shownTotal, currency: order.currency.isEmpty ? null : order.currency), style: AppText.price),
            ],
          ),
        ],
      ),
    );
  }
}
