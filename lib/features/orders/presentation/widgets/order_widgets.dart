import 'package:flutter/material.dart' hide Text;

import '../../../../core/l10n/app_text.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/order.dart';

class OrderStatusPill extends StatelessWidget {
  const OrderStatusPill({super.key, required this.status});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    switch (status) {
      case OrderStatus.accepted:
        bg = AppColors.infoSoft;
        fg = AppColors.info;
        break;
      case OrderStatus.confirmed:
        bg = AppColors.accentSoft;
        fg = AppColors.accentDark;
        break;
      case OrderStatus.processing:
      case OrderStatus.ready:
        bg = AppColors.accentSoft;
        fg = AppColors.accentDark;
        break;
      case OrderStatus.shipped:
      case OrderStatus.inTransit:
        bg = AppColors.warningSoft;
        fg = AppColors.warning;
        break;
      case OrderStatus.delivered:
        bg = AppColors.successSoft;
        fg = AppColors.success;
        break;
      case OrderStatus.cancelled:
        bg = AppColors.dangerSoft;
        fg = AppColors.danger;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Text(
        status.label,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}

/// Шкала статусов: создан → подтверждён → в обработке → отправлен → в пути → доставлен.
class OrderTimeline extends StatelessWidget {
  const OrderTimeline({super.key, required this.status});

  final OrderStatus status;

  static const List<OrderStatus> _steps = <OrderStatus>[
    OrderStatus.accepted,
    OrderStatus.confirmed,
    OrderStatus.processing,
    OrderStatus.shipped,
    OrderStatus.inTransit,
    OrderStatus.delivered,
  ];

  @override
  Widget build(BuildContext context) {
    if (status == OrderStatus.cancelled) {
      return Row(
        children: const <Widget>[
          Icon(Icons.cancel_outlined, color: AppColors.danger),
          SizedBox(width: 8),
          Text('Заказ отменён', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700)),
        ],
      );
    }
    final current = _steps.indexOf(status == OrderStatus.ready ? OrderStatus.processing : status);
    return Row(
      children: <Widget>[
        for (var i = 0; i < _steps.length; i++) ...<Widget>[
          Expanded(
            child: Column(
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Container(
                        height: 3,
                        color: i == 0
                            ? Colors.transparent
                            : (i <= current ? AppColors.success : AppColors.border),
                      ),
                    ),
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i <= current ? AppColors.success : AppColors.surfaceAlt,
                      ),
                      child: Icon(
                        Icons.check,
                        size: 14,
                        color: i <= current ? Colors.white : AppColors.textHint,
                      ),
                    ),
                    Expanded(
                      child: Container(
                        height: 3,
                        color: i == _steps.length - 1
                            ? Colors.transparent
                            : (i < current ? AppColors.success : AppColors.border),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _steps[i].label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: i == current ? FontWeight.w700 : FontWeight.w500,
                    color: i <= current ? AppColors.textPrimary : AppColors.textHint,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
