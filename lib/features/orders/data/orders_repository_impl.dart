import '../../../core/network/api_client.dart';
import '../../../core/storage/local_cache.dart';
import '../../../core/utils/currency.dart';
import '../../delivery/delivery_models.dart';
import '../../../core/utils/json_utils.dart';
import '../../auth/domain/entities/user.dart';
import '../../cart/domain/entities/cart_item.dart';
import '../domain/entities/order.dart';
import '../domain/repositories/orders_repository.dart';

class OrdersRepositoryImpl implements OrdersRepository {
  OrdersRepositoryImpl(ApiClient api, LocalCache cache)
      : _api = api,
        _fetch = CachedFetcher(cache);

  final ApiClient _api;
  final CachedFetcher _fetch;

  @override
  Future<List<Order>> orders() async {
    final result = await _fetch<List<Order>>(
      key: 'orders',
      request: () => _api.get('/api/orders'),
      parse: (json) => asJson(json).list('items').map(Order.fromJson).toList(),
    );
    return result.value;
  }

  @override
  Future<Order> order(String id) async {
    final json = await _api.get('/api/orders/$id');
    return Order.fromJson(asJson(json));
  }

  List<Map<String, dynamic>> _lines(List<CartItem> items) => items
      .map((e) => <String, dynamic>{'productId': e.product.id, 'offer': e.offer, 'qty': e.qty})
      .toList();

  @override
  Future<Order> create(CheckoutData data, List<CartItem> items) async {
    // Цены, скидки, вес, расстояние и стоимость доставки приложение НЕ отправляет — сервер считает сам.
    final isDelivery = data.deliveryMethod != 'pickup';
    final json = await _api.post(
      '/api/orders',
      body: <String, dynamic>{
        'currency': AppCurrency.current.code,
        'contact': <String, dynamic>{
          'name': data.contactName,
          'company': data.company,
          'phone': data.phone,
          'email': data.email,
        },
        'delivery': <String, dynamic>{
          'method': isDelivery ? 'delivery' : 'pickup',
          'address': isDelivery ? data.address : '',
          if (isDelivery && data.lat != null && data.lng != null) ...<String, dynamic>{
            'lat': data.lat,
            'lng': data.lng,
          },
        },
        'payment': <String, dynamic>{'method': data.paymentMethod},
        'comment': data.comment,
        'saveAddress': isDelivery && data.lat != null,
        'items': _lines(items),
      },
    );
    return Order.fromJson(asJson(json));
  }

  @override
  Future<DeliveryQuote> calculateDelivery(GeoPoint point, List<CartItem> items) async {
    final json = await _api.post(
      '/api/delivery/calculate',
      body: <String, dynamic>{
        'lat': point.lat,
        'lng': point.lng,
        'currency': AppCurrency.current.code,
        'items': _lines(items),
      },
    );
    return DeliveryQuote.fromJson(asJson(json));
  }

  @override
  Future<List<GeoPoint>> searchAddress(String query) async {
    final json = await _api.get('/api/geo/search', query: <String, dynamic>{'q': query});
    return asJson(json).list('items').map(GeoPoint.fromJson).toList();
  }

  @override
  Future<String> reverseGeocode(double lat, double lng) async {
    final json = await _api.get('/api/geo/reverse', query: <String, dynamic>{'lat': lat, 'lng': lng});
    return asJson(json).str('address');
  }

  @override
  Future<void> quickOrder({
    required String productId,
    required int qty,
    required String name,
    required String phone,
  }) async {
    await _api.post(
      '/api/orders/quick',
      body: <String, dynamic>{'productId': productId, 'qty': qty, 'name': name, 'phone': phone},
    );
  }

  @override
  Future<void> requestInvoice(String orderId) async {
    await _api.post('/api/orders/$orderId/invoice');
  }

  @override
  Future<void> requestQuote({
    required List<CartItem> items,
    required String contactName,
    required String phone,
    required String email,
    required String comment,
  }) async {
    await _api.post(
      '/api/requests/quote',
      body: <String, dynamic>{
        'contact': <String, dynamic>{'name': contactName, 'phone': phone, 'email': email},
        'comment': comment,
        'items': items
            .map((e) => <String, dynamic>{'productId': e.product.id, 'offer': e.offer, 'qty': e.qty})
            .toList(),
      },
    );
  }

  @override
  Future<ManagerInfo> manager() async {
    final result = await _fetch<ManagerInfo>(
      key: 'manager',
      request: () => _api.get('/api/manager'),
      parse: (json) => ManagerInfo.fromJson(asJson(json)),
    );
    return result.value;
  }
}
