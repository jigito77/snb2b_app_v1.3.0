import '../entities/cart_item.dart';

abstract class CartRepository {
  /// Корзина, сохранённая на устройстве (мгновенно, работает офлайн).
  List<CartItem> loadLocal();

  Future<void> saveLocal(List<CartItem> items);

  /// Корзина авторизованного пользователя на сервере.
  Future<List<CartItem>> fetchRemote();

  /// Полная замена серверной корзины (идемпотентная синхронизация).
  Future<void> pushRemote(List<CartItem> items);

  /// Расчёт цен и веса на сервере (POST /api/prices) — по одной строке на позицию, null если не посчитано.
  Future<List<CartLine?>> quote(List<CartItem> items);
}
