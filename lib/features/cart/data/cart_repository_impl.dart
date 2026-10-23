import '../../../core/constants/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/currency.dart';
import '../../../core/storage/local_cache.dart';
import '../../../core/utils/json_utils.dart';
import '../domain/entities/cart_item.dart';
import '../domain/repositories/cart_repository.dart';

class CartRepositoryImpl implements CartRepository {
  CartRepositoryImpl(this._api, this._cache);

  final ApiClient _api;
  final LocalCache _cache;

  static const String _key = 'cart';

  @override
  List<CartItem> loadLocal() {
    final raw = _cache.getJson(_key);
    if (raw is! List) return <CartItem>[];
    try {
      return asJsonList(raw).map(CartItem.fromJson).toList();
    } catch (_) {
      return <CartItem>[];
    }
  }

  @override
  Future<void> saveLocal(List<CartItem> items) =>
      _cache.putJson(_key, items.map((e) => e.toJson()).toList());

  @override
  Future<List<CartItem>> fetchRemote() async {
    final json = await _api.get('/api/cart');
    return asJson(json).list('items').map(CartItem.fromJson).toList();
  }

  @override
  Future<void> pushRemote(List<CartItem> items) async {
    await _api.put(
      '/api/cart',
      body: <String, dynamic>{
        'items': items
            .map((e) => <String, dynamic>{'productId': e.product.id, 'offer': e.offer, 'qty': e.qty})
            .toList(),
      },
    );
  }

  @override
  Future<List<CartLine?>> quote(List<CartItem> items) async {
    if (items.isEmpty || AppConfig.useMockApi) return List<CartLine?>.filled(items.length, null);
    final json = await _api.post(
      '/api/prices',
      body: <String, dynamic>{
        'currency': AppCurrency.current.code,
        'items': items
            .map((e) => <String, dynamic>{'productId': e.product.id, 'offer': e.offer, 'qty': e.qty})
            .toList(),
      },
    );
    final pending = <String, List<Json>>{};
    for (final l in asJson(json).list('lines')) {
      pending.putIfAbsent('${l.str('productId')}|${l.str('offer')}|${l.integer('qty', 1)}', () => <Json>[]).add(l);
    }
    return items.map<CartLine?>((e) {
      final list = pending['${e.product.id}|${e.offer}|${e.qty}'];
      if (list == null || list.isEmpty) return null;
      return CartLine.fromJson(list.removeAt(0));
    }).toList();
  }
}
