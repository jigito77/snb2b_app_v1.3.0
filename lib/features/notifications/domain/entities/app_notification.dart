import '../../../../core/utils/json_utils.dart';

/// Типы уведомлений, которые backend отправляет через FCM и показывает в ленте.
class NotificationType {
  NotificationType._();

  static const String orderAccepted = 'order_accepted';
  static const String orderConfirmed = 'order_confirmed';
  static const String orderShipped = 'order_shipped';
  static const String orderDelivered = 'order_delivered';
  static const String priceChanged = 'price_changed';
  static const String backInStock = 'back_in_stock';
  static const String promo = 'promo';
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.createdAt,
    this.isRead = false,
    this.orderId,
  });

  final String id;
  final String title;
  final String body;
  final String type;
  final DateTime createdAt;
  final bool isRead;
  final String? orderId;

  factory AppNotification.fromJson(Json j) => AppNotification(
        id: j.str('id'),
        title: j.str('title'),
        body: j.str('body'),
        type: j.str('type', NotificationType.promo),
        createdAt: DateTime.tryParse(j.str('createdAt'))?.toLocal() ?? DateTime.now(),
        isRead: j.flag('isRead'),
        orderId: j.strOrNull('orderId'),
      );
}
