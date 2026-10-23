import 'package:flutter_test/flutter_test.dart';
import 'package:snb2b_app/core/utils/formatters.dart';
import 'package:snb2b_app/features/cart/domain/entities/cart_item.dart';
import 'package:snb2b_app/features/orders/domain/entities/order.dart';
import 'package:snb2b_app/features/product/domain/entities/product.dart';

Map<String, dynamic> _productJson() => <String, dynamic>{
      'id': 'p1',
      'name': 'Фильтр',
      'article': 'A-1',
      'price': 10000, // базовая валюта магазина — приложение её не использует, если есть offers
      'stock': <String, dynamic>{'available': 0},
      'weightKg': 0.9,
      'currency': 'USD',
      'priceFrom': 60,
      'offers': <Map<String, dynamic>>[
        <String, dynamic>{'type': 'ORG', 'price': 100, 'weightKg': 0.9, 'minQty': 1},
        <String, dynamic>{'type': 'SNP', 'price': 60, 'weightKg': 0.9, 'minQty': 1},
      ],
    };

void main() {
  test('Product: предложения ORG/OEM/SNP и вес приходят с backend', () {
    final p = Product.fromJson(_productJson());
    expect(p.offers.map((o) => o.type), <String>['ORG', 'SNP']);
    expect(p.price, 60);
    expect(p.weightKg, 0.9);
    expect(p.offerOf('SNP')!.price, 60);
    expect(p.canOrder, isTrue, reason: 'под заказ можно, как на сайте');
    expect(p.maxQty, greaterThan(1000));
  });

  test('CartItem: цена и вес берутся из расчёта сервера, устаревшая строка игнорируется', () {
    final p = Product.fromJson(_productJson());
    const line = CartLine(qty: 10, unitPrice: 54, subtotal: 540, unitWeightKg: 0.9, weightKg: 9, priceLevel: 'MALI OPT');
    final fresh = CartItem(product: p, qty: 10, offer: 'SNP', line: line);
    expect(fresh.unitPrice, 54);
    expect(fresh.total, 540);
    expect(fresh.weightKg, 9);
    final stale = fresh.copyWith(qty: 11);
    expect(stale.unitPrice, 60, reason: 'строка посчитана для другого количества — не используется');
  });

  test('CartItem: JSON-кэш сохраняет offer и строку сервера', () {
    final p = Product.fromJson(_productJson());
    const line = CartLine(qty: 2, unitPrice: 60, subtotal: 120, unitWeightKg: 0.9, weightKg: 1.8);
    final back = CartItem.fromJson(CartItem(product: p, qty: 2, offer: 'SNP', line: line).toJson());
    expect(back.offer, 'SNP');
    expect(back.line!.subtotal, 120);
    expect(back.product.offers.length, 2);
  });

  test('Список корзины: общий вес', () {
    final p = Product.fromJson(_productJson());
    final items = <CartItem>[
      CartItem(product: p, qty: 2, offer: 'SNP'),
      CartItem(product: p, qty: 1, offer: 'ORG'),
    ];
    expect(items.weightKg, closeTo(2.7, 1e-9));
    expect(items.hasMissingWeight, isFalse);
  });

  test('Статусы заказа backend', () {
    expect(OrderStatus.parse('accepted'), OrderStatus.accepted);
    expect(OrderStatus.parse('in_transit'), OrderStatus.inTransit);
    expect(OrderStatus.parse('processing'), OrderStatus.processing);
    expect(OrderStatus.parse('unknown'), OrderStatus.accepted);
  });

  test('Order: суммы в валюте заказа, вес и доставка', () {
    final o = Order.fromJson(<String, dynamic>{
      'id': 'o1',
      'number': '1',
      'createdAt': '2026-10-22T10:00:00Z',
      'status': 'in_transit',
      'items': <Map<String, dynamic>>[
        <String, dynamic>{'productId': 'p1', 'name': 'Фильтр', 'article': 'A', 'qty': 1, 'price': 5400, 'displayPrice': 60, 'displaySubtotal': 60, 'offer': 'SNP', 'weightKg': 0.9},
      ],
      'total': 6007.5,
      'displayTotal': 66.75,
      'displayDeliveryTotal': 6.75,
      'currency': 'USD',
      'totalWeightKg': 0.9,
      'deliveryMethod': 'delivery',
      'delivery': <String, dynamic>{'distanceKm': 3000, 'weightKg': 0.9, 'price': 6.75, 'lat': 67.1, 'lng': 44.5},
    });
    expect(o.status, OrderStatus.inTransit);
    expect(o.shownTotal, 66.75);
    expect(o.items.first.total, 60);
    expect(o.delivery!.distanceKm, 3000);
    expect(o.totalWeightKg, 0.9);
  });

  test('Fmt.kg', () {
    expect(Fmt.kg(0.9), '0,9');
    expect(Fmt.kg(16.8), '16,8');
    expect(Fmt.kg(2), '2');
    expect(Fmt.kg(null), '—');
  });
}
