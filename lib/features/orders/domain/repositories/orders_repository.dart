import '../../../auth/domain/entities/user.dart';
import '../../../cart/domain/entities/cart_item.dart';
import '../../../delivery/delivery_models.dart';
import '../entities/order.dart';

abstract class OrdersRepository {
  Future<List<Order>> orders();

  Future<Order> order(String id);

  Future<Order> create(CheckoutData data, List<CartItem> items);

  /// Расчёт доставки на сервере по точке на карте и позициям корзины.
  Future<DeliveryQuote> calculateDelivery(GeoPoint point, List<CartItem> items);

  /// Поиск адреса (GET /api/geo/search).
  Future<List<GeoPoint>> searchAddress(String query);

  /// Адрес по координатам (GET /api/geo/reverse).
  Future<String> reverseGeocode(double lat, double lng);

  /// «Купить в 1 клик»: заявка менеджеру без оформления корзины.
  Future<void> quickOrder({
    required String productId,
    required int qty,
    required String name,
    required String phone,
  });

  Future<void> requestInvoice(String orderId);

  Future<void> requestQuote({
    required List<CartItem> items,
    required String contactName,
    required String phone,
    required String email,
    required String comment,
  });

  Future<ManagerInfo> manager();
}
