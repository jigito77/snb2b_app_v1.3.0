import '../../../core/network/api_client.dart';
import '../../../core/storage/local_cache.dart';
import '../../../core/utils/json_utils.dart';
import '../../product/domain/entities/product.dart';
import '../domain/entities/catalog_entities.dart';
import '../domain/repositories/catalog_repository.dart';

class CatalogRepositoryImpl implements CatalogRepository {
  CatalogRepositoryImpl(ApiClient api, LocalCache cache)
      : _api = api,
        _fetch = CachedFetcher(cache);

  final ApiClient _api;
  final CachedFetcher _fetch;

  @override
  Future<List<Brand>> brands() async {
    final result = await _fetch<List<Brand>>(
      key: 'brands',
      request: () => _api.get('/api/brands'),
      parse: (json) => asJsonList(asJson(json)['items']).map(Brand.fromJson).toList(),
    );
    return result.value;
  }

  @override
  Future<List<Category>> categories() async {
    final result = await _fetch<List<Category>>(
      key: 'categories',
      request: () => _api.get('/api/categories'),
      parse: (json) => asJsonList(asJson(json)['items']).map(Category.fromJson).toList(),
    );
    return result.value;
  }

  @override
  Future<FilterOptions> filterOptions() async {
    final result = await _fetch<FilterOptions>(
      key: 'filter_options',
      request: () => _api.get('/api/catalog/filters'),
      parse: (json) => FilterOptions.fromJson(asJson(json)),
    );
    return result.value;
  }

  @override
  Future<PagedResult<Product>> products(
    ProductFilter filter, {
    int page = 1,
    int pageSize = 20,
  }) async {
    final query = <String, dynamic>{...filter.toQuery(), 'page': page, 'pageSize': pageSize};
    PagedResult<Product> parse(dynamic json, bool fromCache) {
      final j = asJson(json);
      return PagedResult<Product>(
        items: j.list('items').map(Product.fromJson).toList(),
        total: j.integer('total'),
        page: j.integer('page', page),
        pageSize: j.integer('pageSize', pageSize),
        fromCache: fromCache,
      );
    }

    if (page > 1) {
      return parse(await _api.get('/api/products', query: query), false);
    }
    // Первая страница каждого запроса кэшируется для офлайн-режима.
    final result = await _fetch<PagedResult<Product>>(
      key: 'catalog:${filter.cacheKey}:$pageSize',
      group: 'catalog',
      max: 40,
      request: () => _api.get('/api/products', query: query),
      parse: (json) => parse(json, false),
    );
    return PagedResult<Product>(
      items: result.value.items,
      total: result.value.total,
      page: result.value.page,
      pageSize: result.value.pageSize,
      fromCache: result.fromCache,
    );
  }

  @override
  Future<List<Product>> productsByIds(List<String> ids) async {
    if (ids.isEmpty) return <Product>[];
    final json = await _api.get(
      '/api/products',
      query: <String, dynamic>{'ids': ids.join(','), 'pageSize': ids.length, 'page': 1},
    );
    return asJson(json).list('items').map(Product.fromJson).toList();
  }

  @override
  Future<List<SearchSuggestion>> suggest(String query) async {
    final json = await _api.get('/api/search/suggest', query: <String, dynamic>{'q': query});
    return asJson(json).list('items').map(SearchSuggestion.fromJson).toList();
  }

  @override
  Future<List<String>> popularQueries() async {
    final result = await _fetch<List<String>>(
      key: 'popular_queries',
      request: () => _api.get('/api/search/popular'),
      parse: (json) => asJson(json).strings('items'),
    );
    return result.value;
  }
}
