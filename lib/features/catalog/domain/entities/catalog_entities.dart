import '../../../../core/utils/json_utils.dart';

class Brand {
  const Brand({
    required this.id,
    required this.name,
    required this.shortName,
    this.productCount = 0,
    this.logoUrl,
  });

  final String id;
  final String name;
  final String shortName;
  final int productCount;
  final String? logoUrl;

  factory Brand.fromJson(Json j) => Brand(
        id: j.str('id'),
        name: j.str('name'),
        shortName: j.str('shortName', j.str('name')),
        productCount: j.integer('productCount'),
        logoUrl: j.strOrNull('logoUrl'),
      );
}

class Category {
  const Category({
    required this.id,
    required this.name,
    this.parentId,
    this.productCount = 0,
  });

  final String id;
  final String name;
  final String? parentId;
  final int productCount;

  bool get isRoot => parentId == null;

  factory Category.fromJson(Json j) => Category(
        id: j.str('id'),
        name: j.str('name'),
        parentId: j.strOrNull('parentId'),
        productCount: j.integer('productCount'),
      );
}

class FilterOptions {
  const FilterOptions({
    this.manufacturers = const <String>[],
    this.compatibilities = const <String>[],
    this.priceMin = 0,
    this.priceMax = 0,
  });

  final List<String> manufacturers;
  final List<String> compatibilities;
  final double priceMin;
  final double priceMax;

  factory FilterOptions.fromJson(Json j) => FilterOptions(
        manufacturers: j.strings('manufacturers'),
        compatibilities: j.strings('compatibilities'),
        priceMin: j.dbl('priceMin'),
        priceMax: j.dbl('priceMax'),
      );
}

class SearchSuggestion {
  const SearchSuggestion({required this.text, required this.type, this.id, this.subtitle});

  final String text;

  /// product | brand | category | query
  final String type;
  final String? id;
  final String? subtitle;

  factory SearchSuggestion.fromJson(Json j) => SearchSuggestion(
        text: j.str('text'),
        type: j.str('type', 'query'),
        id: j.strOrNull('id'),
        subtitle: j.strOrNull('subtitle'),
      );
}

class PagedResult<T> {
  const PagedResult({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
    this.fromCache = false,
  });

  final List<T> items;
  final int total;
  final int page;
  final int pageSize;
  final bool fromCache;

  bool get hasMore => page * pageSize < total;
}

/// Параметры выборки каталога. Сериализуются в query-параметры /api/products.
class ProductFilter {
  const ProductFilter({
    this.query = '',
    this.categoryId,
    this.brandId,
    this.manufacturer,
    this.priceFrom,
    this.priceTo,
    this.inStock = false,
    this.isNew = false,
    this.isPopular = false,
    this.isSpecial = false,
    this.compatibility,
    this.sort = 'popular',
  });

  final String query;
  final String? categoryId;
  final String? brandId;
  final String? manufacturer;
  final double? priceFrom;
  final double? priceTo;
  final bool inStock;
  final bool isNew;
  final bool isPopular;
  final bool isSpecial;
  final String? compatibility;

  /// popular | price_asc | price_desc | name | new
  final String sort;

  ProductFilter copyWith({
    String? query,
    String? categoryId,
    String? brandId,
    String? manufacturer,
    double? priceFrom,
    double? priceTo,
    bool? inStock,
    bool? isNew,
    bool? isPopular,
    bool? isSpecial,
    String? compatibility,
    String? sort,
    bool clearCategory = false,
    bool clearBrand = false,
    bool clearManufacturer = false,
    bool clearPrice = false,
    bool clearCompatibility = false,
  }) {
    return ProductFilter(
      query: query ?? this.query,
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      brandId: clearBrand ? null : (brandId ?? this.brandId),
      manufacturer: clearManufacturer ? null : (manufacturer ?? this.manufacturer),
      priceFrom: clearPrice ? null : (priceFrom ?? this.priceFrom),
      priceTo: clearPrice ? null : (priceTo ?? this.priceTo),
      inStock: inStock ?? this.inStock,
      isNew: isNew ?? this.isNew,
      isPopular: isPopular ?? this.isPopular,
      isSpecial: isSpecial ?? this.isSpecial,
      compatibility: clearCompatibility ? null : (compatibility ?? this.compatibility),
      sort: sort ?? this.sort,
    );
  }

  /// Устанавливает (или снимает, если null) диапазон цены.
  ProductFilter withPrice(double? from, double? to) => ProductFilter(
        query: query,
        categoryId: categoryId,
        brandId: brandId,
        manufacturer: manufacturer,
        priceFrom: from,
        priceTo: to,
        inStock: inStock,
        isNew: isNew,
        isPopular: isPopular,
        isSpecial: isSpecial,
        compatibility: compatibility,
        sort: sort,
      );

  /// Сбрасывает все фильтры, сохраняя поисковую строку и сортировку.
  ProductFilter reset() => ProductFilter(query: query, sort: sort);

  /// Количество активных фильтров (без строки поиска и сортировки).
  int get activeCount {
    var n = 0;
    if (categoryId != null) n++;
    if (brandId != null) n++;
    if (manufacturer != null) n++;
    if (priceFrom != null || priceTo != null) n++;
    if (inStock) n++;
    if (isNew) n++;
    if (isPopular) n++;
    if (isSpecial) n++;
    if (compatibility != null) n++;
    return n;
  }

  Map<String, dynamic> toQuery() {
    final q = <String, dynamic>{};
    if (query.trim().isNotEmpty) q['q'] = query.trim();
    if (categoryId != null) q['categoryId'] = categoryId;
    if (brandId != null) q['brandId'] = brandId;
    if (manufacturer != null) q['manufacturer'] = manufacturer;
    if (priceFrom != null) q['priceFrom'] = priceFrom;
    if (priceTo != null) q['priceTo'] = priceTo;
    if (inStock) q['inStock'] = true;
    if (isNew) q['isNew'] = true;
    if (isPopular) q['isPopular'] = true;
    if (isSpecial) q['isSpecial'] = true;
    if (compatibility != null) q['compat'] = compatibility;
    q['sort'] = sort;
    return q;
  }

  String get cacheKey {
    final q = toQuery();
    final keys = q.keys.toList()..sort();
    return keys.map((k) => '$k=${q[k]}').join('&');
  }
}
