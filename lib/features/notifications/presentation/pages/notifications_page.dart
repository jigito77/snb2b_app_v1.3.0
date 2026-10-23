import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/app_text.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/skeleton.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../domain/entities/app_notification.dart';
import '../providers/notifications_providers.dart';

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  static IconData _icon(String type) {
    switch (type) {
      case NotificationType.orderAccepted:
        return Icons.assignment_turned_in_outlined;
      case NotificationType.orderConfirmed:
        return Icons.check_circle_outline;
      case NotificationType.orderShipped:
        return Icons.local_shipping_outlined;
      case NotificationType.orderDelivered:
        return Icons.inventory_2_outlined;
      case NotificationType.priceChanged:
        return Icons.price_change_outlined;
      case NotificationType.backInStock:
        return Icons.notifications_active_outlined;
      default:
        return Icons.local_offer_outlined;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(notificationsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Уведомления'),
        actions: <Widget>[
          IconButton(
            tooltip: tr('Настройки'),
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.tune),
          ),
        ],
      ),
      body: async.when(
        loading: () => const ProductListSkeleton(),
        error: (e, _) => ErrorState(error: e, onRetry: () => ref.invalidate(notificationsProvider)),
        data: (list) {
          if (list.isEmpty) {
            return const EmptyState(
              icon: Icons.notifications_none,
              title: 'Уведомлений нет',
              message: 'Здесь появятся статусы заказов, изменения цен и новости.',
            );
          }
          return RefreshIndicator(
            color: AppColors.accent,
            onRefresh: () async {
              ref.invalidate(notificationsProvider);
              try {
                await ref.read(notificationsProvider.future);
              } catch (_) {
                // ошибка отобразится на экране
              }
            },
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: list.length,
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
              itemBuilder: (context, i) {
                final n = list[i];
                return ListTile(
                  tileColor: n.isRead ? AppColors.surface : AppColors.accentSoft,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  leading: CircleAvatar(
                    backgroundColor: AppColors.surfaceAlt,
                    child: Icon(_icon(n.type), color: AppColors.primary),
                  ),
                  title: Text(
                    n.title,
                    style: AppText.body.copyWith(fontWeight: n.isRead ? FontWeight.w500 : FontWeight.w700),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(n.body, style: AppText.bodySecondary),
                        const SizedBox(height: 4),
                        Text(Fmt.dateTime(n.createdAt), style: AppText.caption),
                      ],
                    ),
                  ),
                  onTap: n.orderId == null ? null : () => context.push('/orders/${n.orderId}'),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
