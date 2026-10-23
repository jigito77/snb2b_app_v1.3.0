import '../../../core/network/api_client.dart';
import '../../../core/storage/local_cache.dart';
import '../../../core/utils/json_utils.dart';
import '../../product/domain/entities/product.dart';

/// Общий репозиторий для списков товаров пользователя: избранное, сравнение,
/// недавно просмотренные. Локальная копия — источник правды для UI, на сервер
/// отправляется только список id (`PUT {path}` с телом `{"ids": [...]}`).
class CollectionRepository {
  CollectionRepository(this._api, this._cache);

  final ApiClient _api;
  final LocalCache _cache;

  List<Product> loadLocal(String key) {
    final raw = _cache.getJson(key);
    if (raw is! List) return <Product>[];
    try {
      return asJsonList(raw).map(Product.fromJson).toList();
    } catch (_) {
      return <Product>[];
    }
  }

  Future<void> saveLocal(String key, List<Product> items) =>
      _cache.putJson(key, items.map((e) => e.toJson()).toList());

  Future<List<String>> fetchRemoteIds(String path) async {
    final json = await _api.get(path);
    return asJson(json).strings('ids');
  }

  Future<void> pushRemoteIds(String path, List<String> ids) async {
    await _api.put(path, body: <String, dynamic>{'ids': ids});
  }
}
