import '../../../core/network/api_client.dart';
import '../../../core/storage/local_cache.dart';
import '../../../core/utils/json_utils.dart';
import '../domain/entities/product.dart';
import '../domain/repositories/product_repository.dart';

class ProductRepositoryImpl implements ProductRepository {
  ProductRepositoryImpl(ApiClient api, LocalCache cache)
      : _api = api,
        _fetch = CachedFetcher(cache);

  final ApiClient _api;
  final CachedFetcher _fetch;

  @override
  Future<Product> product(String id) async {
    final result = await _fetch<Product>(
      key: 'product:$id',
      group: 'product',
      max: 80,
      request: () => _api.get('/api/products/$id'),
      parse: (json) => Product.fromJson(asJson(json)),
    );
    return result.value;
  }

  @override
  Future<List<Product>> analogs(String id) async {
    final result = await _fetch<List<Product>>(
      key: 'analogs:$id',
      group: 'analogs',
      max: 40,
      request: () => _api.get('/api/products/$id/analogs'),
      parse: (json) => asJson(json).list('items').map(Product.fromJson).toList(),
    );
    return result.value;
  }
}
