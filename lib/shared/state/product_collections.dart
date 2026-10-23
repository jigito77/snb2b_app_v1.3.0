import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/di.dart';
import '../../core/errors/app_exception.dart';
import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/favorites/data/collection_repository.dart';
import '../../features/product/domain/entities/product.dart';

/// Базовый контроллер списков товаров пользователя (избранное, сравнение, недавние).
///
/// * UI всегда работает с локальной копией (мгновенно, офлайн);
/// * для авторизованных список id синхронизируется с сервером (debounce);
/// * после входа списки объединяются с серверными, при выходе — очищаются.
abstract class ProductCollectionNotifier extends Notifier<List<Product>> {
  String get cacheKey;

  /// Путь для синхронизации ids (`GET/PUT`). null — только локально.
  String? get remotePath => null;

  int get maxItems => 200;

  Timer? _debounce;

  CollectionRepository get _repo => ref.read(collectionRepositoryProvider);

  @override
  List<Product> build() {
    ref.onDispose(() => _debounce?.cancel());
    return _repo.loadLocal(cacheKey);
  }

  bool contains(String id) => state.any((p) => p.id == id);

  void toggle(Product product) {
    if (contains(product.id)) {
      remove(product.id);
    } else {
      add(product);
    }
  }

  void add(Product product) {
    if (contains(product.id)) return;
    final next = <Product>[product, ...state];
    state = next.length > maxItems ? next.sublist(0, maxItems) : next;
    persist();
  }

  void remove(String id) {
    state = state.where((p) => p.id != id).toList();
    persist();
  }

  void clearLocal() {
    _debounce?.cancel();
    state = <Product>[];
    unawaited(_repo.saveLocal(cacheKey, state));
  }

  /// Обновляет цены и остатки сохранённых товаров (без сети — оставляет как есть).
  Future<void> refresh() async {
    if (state.isEmpty) return;
    try {
      final fresh = await ref
          .read(catalogRepositoryProvider)
          .productsByIds(state.map((p) => p.id).toList());
      final byId = <String, Product>{for (final p in fresh) p.id: p};
      state = <Product>[for (final p in state) byId[p.id] ?? p];
      await _repo.saveLocal(cacheKey, state);
    } on AppException {
      // офлайн — показываем сохранённые данные
    }
  }

  /// Объединяет локальный и серверный списки (после входа) и отправляет результат на сервер.
  Future<void> mergeRemote() async {
    final path = remotePath;
    if (path == null) return;
    try {
      final remoteIds = await _repo.fetchRemoteIds(path);
      final localIds = state.map((p) => p.id).toSet();
      final missing = remoteIds.where((id) => !localIds.contains(id)).toList();
      if (missing.isNotEmpty) {
        final products = await ref.read(catalogRepositoryProvider).productsByIds(missing);
        final next = <Product>[...state, ...products];
        state = next.length > maxItems ? next.sublist(0, maxItems) : next;
      }
      await _repo.saveLocal(cacheKey, state);
      await _repo.pushRemoteIds(path, state.map((p) => p.id).toList());
    } on AppException {
      // синхронизируем при следующем подключении
    }
  }

  void persist() {
    unawaited(_repo.saveLocal(cacheKey, state));
    _scheduleRemote();
  }

  void _scheduleRemote() {
    final path = remotePath;
    if (path == null) return;
    if (!ref.read(authControllerProvider).isAuthenticated) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 700), () async {
      try {
        await _repo.pushRemoteIds(path, state.map((p) => p.id).toList());
      } on AppException {
        // будет отправлено при следующей синхронизации
      }
    });
  }
}

class FavoritesNotifier extends ProductCollectionNotifier {
  @override
  String get cacheKey => 'favorites';

  @override
  String? get remotePath => '/api/favorites';
}

class ComparisonNotifier extends ProductCollectionNotifier {
  @override
  String get cacheKey => 'comparison';

  @override
  String? get remotePath => '/api/comparison';

  @override
  int get maxItems => 4;

  /// В сравнении ограниченное число позиций: новые не добавляются сверх лимита.
  bool get isFull => state.length >= maxItems;

  @override
  void add(Product product) {
    if (contains(product.id) || isFull) return;
    state = <Product>[...state, product];
    persist();
  }
}

class RecentlyViewedNotifier extends ProductCollectionNotifier {
  @override
  String get cacheKey => 'recent';

  @override
  int get maxItems => 20;

  void viewed(Product product) {
    state = <Product>[product, ...state.where((p) => p.id != product.id)];
    if (state.length > maxItems) state = state.sublist(0, maxItems);
    persist();
  }
}

final favoritesProvider =
    NotifierProvider<FavoritesNotifier, List<Product>>(FavoritesNotifier.new);

final comparisonProvider =
    NotifierProvider<ComparisonNotifier, List<Product>>(ComparisonNotifier.new);

final recentlyViewedProvider =
    NotifierProvider<RecentlyViewedNotifier, List<Product>>(RecentlyViewedNotifier.new);
