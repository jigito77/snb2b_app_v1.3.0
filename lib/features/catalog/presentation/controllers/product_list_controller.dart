import 'package:flutter/foundation.dart';

import '../../../product/domain/entities/product.dart';
import '../../domain/entities/catalog_entities.dart';
import '../../domain/repositories/catalog_repository.dart';

/// Постраничная загрузка товаров для экранов каталога и поиска.
/// Каждый экран владеет своим экземпляром, поэтому несколько списков могут жить одновременно.
class ProductListController extends ChangeNotifier {
  ProductListController({required CatalogRepository repository, required ProductFilter filter})
      : _repo = repository,
        _filter = filter;

  final CatalogRepository _repo;
  ProductFilter _filter;

  List<Product> items = <Product>[];
  int total = 0;
  bool loading = false;
  bool loadingMore = false;
  bool fromCache = false;
  Object? error;
  Object? moreError;

  int _page = 0;
  int _generation = 0;
  bool _disposed = false;

  ProductFilter get filter => _filter;

  bool get hasMore => items.length < total;

  bool get isEmpty => !loading && error == null && items.isEmpty;

  Future<void> reload() async {
    final generation = ++_generation;
    loading = true;
    error = null;
    moreError = null;
    _notify();
    try {
      final result = await _repo.products(_filter, page: 1);
      if (generation != _generation) return;
      items = result.items;
      total = result.total;
      fromCache = result.fromCache;
      _page = 1;
    } catch (e) {
      if (generation != _generation) return;
      error = e;
    }
    loading = false;
    _notify();
  }

  Future<void> loadMore() async {
    if (loading || loadingMore || !hasMore || fromCache) return;
    final generation = _generation;
    loadingMore = true;
    moreError = null;
    _notify();
    try {
      final result = await _repo.products(_filter, page: _page + 1);
      if (generation != _generation) return;
      items = <Product>[...items, ...result.items];
      total = result.total;
      _page += 1;
    } catch (e) {
      if (generation != _generation) return;
      moreError = e;
    }
    loadingMore = false;
    _notify();
  }

  void setFilter(ProductFilter filter) {
    _filter = filter;
    reload();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
