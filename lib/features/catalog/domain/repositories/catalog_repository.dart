import '../../../../core/constants/app_config.dart';
import '../../../product/domain/entities/product.dart';
import '../entities/catalog_entities.dart';

abstract class CatalogRepository {
  Future<List<Brand>> brands();

  Future<List<Category>> categories();

  Future<FilterOptions> filterOptions();

  /// Постраничная выборка. Первая страница при отсутствии сети отдаётся из кэша.
  Future<PagedResult<Product>> products(
    ProductFilter filter, {
    int page = 1,
    int pageSize = AppConfig.pageSize,
  });

  Future<List<Product>> productsByIds(List<String> ids);

  Future<List<SearchSuggestion>> suggest(String query);

  Future<List<String>> popularQueries();
}
