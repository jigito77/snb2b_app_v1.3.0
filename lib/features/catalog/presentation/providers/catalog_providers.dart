import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../product/domain/entities/product.dart';
import '../../domain/entities/catalog_entities.dart';

final brandsProvider = FutureProvider<List<Brand>>(
  (ref) => ref.watch(catalogRepositoryProvider).brands(),
);

final categoriesProvider = FutureProvider<List<Category>>(
  (ref) => ref.watch(catalogRepositoryProvider).categories(),
);

final filterOptionsProvider = FutureProvider<FilterOptions>(
  (ref) => ref.watch(catalogRepositoryProvider).filterOptions(),
);

final popularQueriesProvider = FutureProvider<List<String>>(
  (ref) => ref.watch(catalogRepositoryProvider).popularQueries(),
);

/// Товарные подборки главной: new | popular | special.
/// Перезагружаются при смене пользователя, потому что персональные цены зависят от аккаунта.
final homeSectionProvider = FutureProvider.autoDispose.family<List<Product>, String>(
  (ref, kind) async {
    ref.watch(authControllerProvider.select((s) => s.user?.id));
    final ProductFilter filter;
    switch (kind) {
      case 'new':
        filter = const ProductFilter(isNew: true, sort: 'new');
        break;
      case 'popular':
        filter = const ProductFilter(isPopular: true);
        break;
      default:
        filter = const ProductFilter(isSpecial: true);
    }
    final page = await ref.watch(catalogRepositoryProvider).products(filter, pageSize: 10);
    return page.items;
  },
);

/// История поисковых запросов (последние 10), хранится на устройстве.
class SearchHistoryNotifier extends Notifier<List<String>> {
  static const String _key = 'search_history';

  @override
  List<String> build() {
    final raw = ref.read(localCacheProvider).getJson(_key);
    return raw is List ? raw.map((e) => e.toString()).toList() : <String>[];
  }

  void add(String query) {
    final q = query.trim();
    if (q.length < 2) return;
    final next = <String>[q, ...state.where((e) => e.toLowerCase() != q.toLowerCase())];
    state = next.length > 10 ? next.sublist(0, 10) : next;
    ref.read(localCacheProvider).putJson(_key, state);
  }

  void remove(String query) {
    state = state.where((e) => e != query).toList();
    ref.read(localCacheProvider).putJson(_key, state);
  }

  void clear() {
    state = <String>[];
    ref.read(localCacheProvider).remove(_key);
  }
}

final searchHistoryProvider =
    NotifierProvider<SearchHistoryNotifier, List<String>>(SearchHistoryNotifier.new);
