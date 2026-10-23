import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/currency.dart';
import '../core/utils/rates_service.dart';
import '../features/cart/presentation/providers/cart_provider.dart';
import 'di.dart';

/// Выбранная валюта отображения цен (₽ / ֏ / $ / €). Хранится в настройках устройства.
/// Курсы обновляются из интернета при запуске приложения и по кнопке в окне выбора валюты.
class CurrencyController extends Notifier<AppCurrency> {
  static const String _key = 'app.currency';

  @override
  AppCurrency build() {
    final prefs = ref.read(sharedPreferencesProvider);
    RatesService.loadCached(prefs);
    final c = AppCurrency.byCode(prefs.getString(_key));
    AppCurrency.current = c;
    unawaited(Future<void>.microtask(refreshRates));
    return c;
  }

  void _repaint() {
    // Цены форматируются через Fmt.price во время build() — перерисовываем всё дерево.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(WidgetsBinding.instance.reassembleApplication());
    });
  }

  /// Обновляет курсы из сети. Возвращает true, если получилось.
  Future<bool> refreshRates() async {
    final ok = await RatesService.refresh(ref.read(sharedPreferencesProvider));
    if (ok) _repaint();
    return ok;
  }

  Future<void> setCurrency(AppCurrency c) async {
    if (c.code == state.code) return;
    AppCurrency.current = c;
    state = c;
    _repaint();
    await ref.read(sharedPreferencesProvider).setString(_key, c.code);
    // Цены в кэше были в старой валюте — сбрасываем кэш каталога и пересчитываем корзину на сервере.
    final cache = ref.read(localCacheProvider);
    for (final prefix in <String>['catalog:', 'product:', 'analogs:', 'index.catalog', 'index.product', 'index.analogs']) {
      await cache.clearPrefix(prefix);
    }
    unawaited(ref.read(cartProvider.notifier).refresh());
  }
}

final currencyProvider = NotifierProvider<CurrencyController, AppCurrency>(CurrencyController.new);
