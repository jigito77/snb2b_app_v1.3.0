import '../../../../core/utils/json_utils.dart';

enum OrderStatus {
  accepted('accepted', 'Создан'),
  confirmed('confirmed', 'Подтверждён'),
  processing('processing', 'В обработке'),
  ready('ready', 'Готов к отправке'),
  shipped('shipped', 'Отправлен'),
  inTransit('in_transit', 'В пути'),
  delivered('delivered', 'Доставлен'),
  cancelled('cancelled', 'Отменён');

  const OrderStatus(this.id, this.label);

  /// Идентификатор статуса в backend (поле `status` заказа).
  final String id;
  final String label;

  static OrderStatus parse(String? value) {
    for (final s in OrderStatus.values) {
      if (s.id == value || s.name == value) return s;
    }
    return OrderStatus.accepted;
  }
}

class ChoiceOption {
  const ChoiceOption(this.id, this.title, this.subtitle);

  final String id;
  final String title;
  final String subtitle;
}

class CheckoutOptions {
  CheckoutOptions._();

  static const List<ChoiceOption> delivery = <ChoiceOption>[
    ChoiceOption('pickup', 'Самовывоз со склада', 'Адрес и время согласует менеджер'),
    ChoiceOption('delivery', 'Доставка по адресу', 'Точка на карте; стоимость считает сервер: расстояние × вес × тариф'),
  ];

  /// Прежние способы доставки — только для показа старых заказов.
  static const List<ChoiceOption> _legacyDelivery = <ChoiceOption>[
    ChoiceOption('courier', 'Курьерская доставка', ''),
    ChoiceOption('transport', 'Транспортная компания', ''),
  ];

  static const List<ChoiceOption> payment = <ChoiceOption>[
    ChoiceOption('invoice', 'Безналичный расчёт по счёту', 'Счёт на оплату выставит менеджер'),
    ChoiceOption('card', 'Банковская карта', 'Ссылка на оплату придёт после подтверждения'),
    ChoiceOption('cash', 'Наличными при получении', 'Оплата курьеру или на складе'),
  ];

  static String deliveryTitle(String id) => <ChoiceOption>[...delivery, ..._legacyDelivery]
      .firstWhere((o) => o.id == id, orElse: () => ChoiceOption(id, id, ''))
      .title;

  static String paymentTitle(String id) => payment
      .firstWhere((o) => o.id == id, orElse: () => ChoiceOption(id, id, ''))
      .title;
}

class OrderItem {
  const OrderItem({
    required this.productId,
    required this.name,
    required this.article,
    required this.qty,
    required this.price,
    this.offer = '',
    this.displayPrice,
    this.displaySubtotal,
    this.unitWeightKg,
    this.weightKg,
    this.priceLevel = '',
  });

  final String productId;
  final String name;
  final String article;
  final int qty;

  /// Цена в базовой валюте магазина (для отчётов). Клиенту показывается [displayPrice].
  final double price;
  final String offer;
  final double? displayPrice;
  final double? displaySubtotal;
  final double? unitWeightKg;
  final double? weightKg;
  final String priceLevel;

  double get total => displaySubtotal ?? price * qty;
  double get unit => displayPrice ?? price;

  factory OrderItem.fromJson(Json j) => OrderItem(
        productId: j.str('productId'),
        name: j.str('name'),
        article: j.str('article'),
        qty: j.integer('qty', 1),
        price: j.dbl('price'),
        offer: j.str('offer'),
        displayPrice: j.dblOrNull('displayPrice'),
        displaySubtotal: j.dblOrNull('displaySubtotal'),
        unitWeightKg: j.dblOrNull('unitWeightKg'),
        weightKg: j.dblOrNull('weightKg'),
        priceLevel: j.str('priceLevel'),
      );
}

/// Доставка заказа, зафиксированная сервером в момент оформления.
class OrderDelivery {
  const OrderDelivery({
    this.address = '',
    this.lat,
    this.lng,
    this.distanceKm,
    this.weightKg,
    this.ratePer1000KmPerKg,
    this.price,
  });

  final String address;
  final double? lat;
  final double? lng;
  final double? distanceKm;
  final double? weightKg;
  final double? ratePer1000KmPerKg;

  /// Стоимость доставки в валюте заказа.
  final double? price;

  factory OrderDelivery.fromJson(Json j) => OrderDelivery(
        address: j.str('address'),
        lat: j.dblOrNull('lat'),
        lng: j.dblOrNull('lng'),
        distanceKm: j.dblOrNull('distanceKm'),
        weightKg: j.dblOrNull('weightKg'),
        ratePer1000KmPerKg: j.dblOrNull('ratePer1000KmPerKg'),
        price: j.dblOrNull('price'),
      );
}

class Order {
  const Order({
    required this.id,
    required this.number,
    required this.createdAt,
    required this.status,
    required this.items,
    required this.total,
    required this.deliveryMethod,
    required this.paymentMethod,
    required this.address,
    required this.contactName,
    required this.phone,
    required this.email,
    this.company = '',
    this.comment = '',
    this.managerComment = '',
    this.currency = '',
    this.displayTotal,
    this.displayItemsTotal,
    this.displayDeliveryTotal,
    this.totalWeightKg,
    this.delivery,
  });

  /// Валюта заказа (суммы displayX — в ней, без пересчёта на устройстве).
  final String currency;
  final double? displayTotal;
  final double? displayItemsTotal;
  final double? displayDeliveryTotal;
  final double? totalWeightKg;
  final OrderDelivery? delivery;

  /// Итого для показа клиенту: в валюте заказа, если backend её вернул.
  double get shownTotal => displayTotal ?? total;

  final String id;
  final String number;
  final DateTime createdAt;
  final OrderStatus status;
  final List<OrderItem> items;
  final double total;
  final String deliveryMethod;
  final String paymentMethod;
  final String address;
  final String contactName;
  final String phone;
  final String email;
  final String company;
  final String comment;
  final String managerComment;

  int get units => items.fold<int>(0, (sum, e) => sum + e.qty);

  factory Order.fromJson(Json j) => Order(
        id: j.str('id'),
        number: j.str('number'),
        createdAt: DateTime.tryParse(j.str('createdAt'))?.toLocal() ?? DateTime.now(),
        status: OrderStatus.parse(j.strOrNull('status')),
        items: j.list('items').map(OrderItem.fromJson).toList(),
        total: j.dbl('total'),
        deliveryMethod: j.str('deliveryMethod'),
        paymentMethod: j.str('paymentMethod'),
        address: j.str('address'),
        contactName: j.str('contactName'),
        phone: j.str('phone'),
        email: j.str('email'),
        company: j.str('company'),
        comment: j.str('comment'),
        managerComment: j.str('managerComment'),
        currency: j.str('currency'),
        displayTotal: j.dblOrNull('displayTotal'),
        displayItemsTotal: j.dblOrNull('displayItemsTotal'),
        displayDeliveryTotal: j.dblOrNull('displayDeliveryTotal'),
        totalWeightKg: j.dblOrNull('totalWeightKg'),
        delivery: j.obj('delivery') == null ? null : OrderDelivery.fromJson(j.obj('delivery')!),
      );
}

/// Данные формы оформления заказа.
class CheckoutData {
  const CheckoutData({
    required this.contactName,
    required this.company,
    required this.phone,
    required this.email,
    required this.address,
    required this.deliveryMethod,
    required this.paymentMethod,
    this.comment = '',
    this.lat,
    this.lng,
  });

  /// Точка доставки, выбранная на карте (сервер сам считает по ней расстояние и стоимость).
  final double? lat;
  final double? lng;
  final String contactName;
  final String company;
  final String phone;
  final String email;
  final String address;
  final String deliveryMethod;
  final String paymentMethod;
  final String comment;
}
