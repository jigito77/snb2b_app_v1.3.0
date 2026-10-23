import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/utils/formatters.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../product/domain/entities/product.dart';
import '../../domain/entities/cart_item.dart';
import '../../domain/repositories/cart_repository.dart';

int _clampInt(int value, int min, int max) {
  if (max < min) return max;
  if (value < min) return min;
  if (value > max) return max;
  return value;
}

/// Корзина. Локальное состояние — источник правды (изменение количества мгновенное),
/// для авторизованных пользователей корзина отправляется на сервер с debounce.
class CartNotifier extends Notifier<List<CartItem>> {
  Timer? _debounce;
  Timer? _quoteTimer;

  CartRepository get _repo => ref.read(cartRepositoryProvider);

  @override
  List<CartItem> build() {
    ref.onDispose(() {
      _debounce?.cancel();
      _quoteTimer?.cancel();
    });
    final local = _repo.loadLocal();
    if (local.isNotEmpty) Future<void>.microtask(requote);
    return local;
  }

  int qtyOf(String productId) {
    for (final item in state) {
      if (item.product.id == productId) return item.qty;
    }
    return 0;
  }

  /// Добавляет товар с выбранным предложением (ORG / OEM / SNP). Возвращает текст ошибки или null.
  String? add(Product product, {int? qty, String? offer}) {
    if (!product.canOrder) return const AppException.outOfStock().message;
    final type = offer ?? product.offerOf(null)?.type ?? '';
    final min = product.offerOf(type)?.minQty ?? product.effectiveMinQty;
    final max = product.maxQty;
    final index = state.indexWhere((e) => e.product.id == product.id && e.offer == type);
    final current = index >= 0 ? state[index].qty : 0;
    final wanted = current == 0 ? (qty ?? min) : current + (qty ?? 1);
    final target = _clampInt(wanted, min, max);

    if (index >= 0) {
      if (target == current && wanted > max) return 'Доступно только ${Fmt.pieces(max)}';
      final next = <CartItem>[...state];
      next[index] = state[index].copyWith(product: product, qty: target);
      state = next;
    } else {
      state = <CartItem>[...state, CartItem(product: product, qty: target, offer: type)];
    }
    _persist();
    return null;
  }

  void setQty(String productId, int qty, {String? offer}) {
    final index = state.indexWhere((e) => e.product.id == productId && (offer == null || e.offer == offer));
    if (index < 0) return;
    final item = state[index];
    if (!item.product.canOrder) return;
    final next = <CartItem>[...state];
    next[index] = item.copyWith(qty: _clampInt(qty, item.minQty, item.product.maxQty));
    state = next;
    _persist();
  }

  void remove(String productId, {String? offer}) {
    state = state.where((e) => !(e.product.id == productId && (offer == null || e.offer == offer))).toList();
    _persist();
  }

  void clear() {
    state = <CartItem>[];
    _persist();
  }

  /// Сброс при выходе из аккаунта (без отправки на сервер).
  void clearLocal() {
    _debounce?.cancel();
    _quoteTimer?.cancel();
    state = <CartItem>[];
    unawaited(_repo.saveLocal(state));
  }

  /// Актуализирует данные товаров и пересчитывает цены/вес на сервере. Без сети остаётся сохранённая копия.
  Future<void> refresh() async {
    if (state.isEmpty) return;
    try {
      final fresh = await ref
          .read(catalogRepositoryProvider)
          .productsByIds(state.map((e) => e.product.id).toList());
      final byId = <String, Product>{for (final p in fresh) p.id: p};
      state = <CartItem>[
        for (final item in state)
          if (byId[item.product.id] != null)
            item.copyWith(
              product: byId[item.product.id],
              qty: _clampInt(item.qty, item.minQty, byId[item.product.id]!.maxQty),
              clearLine: true,
            )
          else
            item,
      ];
      await _repo.saveLocal(state);
    } on AppException {
      // офлайн
    }
    await requote();
  }

  /// Пересчёт цен, ступеней опта и веса — только на сервере (приложению доверять нельзя).
  Future<void> requote() async {
    if (state.isEmpty) return;
    final snapshot = state;
    try {
      final lines = await _repo.quote(snapshot);
      // Корзина могла измениться, пока шёл запрос: применяем только к тем же позициям.
      final next = <CartItem>[];
      for (final item in state) {
        final i = snapshot.indexWhere((e) => e.key == item.key && e.qty == item.qty);
        final line = i >= 0 ? lines[i] : null;
        next.add(line == null ? item : item.copyWith(line: line));
      }
      state = next;
      await _repo.saveLocal(state);
    } on AppException {
      // офлайн: остаются последние посчитанные значения
    }
  }

  /// После входа объединяет локальную и серверную корзины.
  Future<void> mergeRemote() async {
    try {
      final remote = await _repo.fetchRemote();
      final merged = <String, CartItem>{for (final i in state) i.key: i};
      for (final r in remote) {
        final local = merged[r.key];
        if (local == null) {
          merged[r.key] = r;
        } else {
          merged[r.key] = r.copyWith(qty: local.qty > r.qty ? local.qty : r.qty);
        }
      }
      state = merged.values.toList();
      await _repo.saveLocal(state);
      await _repo.pushRemote(state);
      unawaited(requote());
    } on AppException {
      // синхронизируем позже
    }
  }

  void _persist() {
    unawaited(_repo.saveLocal(state));
    _quoteTimer?.cancel();
    _quoteTimer = Timer(const Duration(milliseconds: 350), () => unawaited(requote()));
    if (!ref.read(authControllerProvider).isAuthenticated) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () async {
      try {
        await _repo.pushRemote(state);
      } on AppException {
        // будет отправлено при следующей синхронизации
      }
    });
  }
}

final cartProvider = NotifierProvider<CartNotifier, List<CartItem>>(CartNotifier.new);
