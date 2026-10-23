import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/errors/app_exception.dart';
import '../features/auth/presentation/providers/auth_providers.dart';
import '../features/cart/presentation/providers/cart_provider.dart';
import '../features/catalog/presentation/providers/catalog_providers.dart';
import '../features/notifications/presentation/providers/notifications_providers.dart';
import '../features/orders/presentation/providers/orders_providers.dart';
import '../features/profile/presentation/providers/profile_providers.dart';
import '../shared/state/product_collections.dart';
import 'di.dart';

/// Связывает жизненный цикл сессии с пользовательскими данными:
/// вход → слияние и синхронизация корзины/избранного/сравнения, регистрация push-токена;
/// выход → очистка пользовательских данных и персональных цен из кэша;
/// возврат сети / возврат в приложение → повторная синхронизация.
class SessionCoordinator {
  SessionCoordinator(this._ref);

  final Ref _ref;

  Future<void> onLogin() async {
    await Future.wait<void>(<Future<void>>[
      _ref.read(cartProvider.notifier).mergeRemote(),
      _ref.read(favoritesProvider.notifier).mergeRemote(),
      _ref.read(comparisonProvider.notifier).mergeRemote(),
    ]);
    _invalidateData();
    unawaited(registerDevice());
  }

  void onLogout() {
    _ref.read(cartProvider.notifier).clearLocal();
    _ref.read(favoritesProvider.notifier).clearLocal();
    _ref.read(comparisonProvider.notifier).clearLocal();
    final cache = _ref.read(localCacheProvider);
    for (final prefix in <String>['catalog', 'product', 'analogs', 'orders', 'addresses', 'manager', 'recent']) {
      unawaited(cache.clearPrefix(prefix));
    }
    _ref.read(recentlyViewedProvider.notifier).clearLocal();
    _invalidateData();
  }

  /// Повторная синхронизация (возврат сети, возврат в приложение).
  Future<void> syncAll() async {
    final auth = _ref.read(authControllerProvider);
    if (auth.status == AuthStatus.unknown) return;
    if (auth.isAuthenticated) {
      await Future.wait<void>(<Future<void>>[
        _ref.read(cartProvider.notifier).mergeRemote(),
        _ref.read(favoritesProvider.notifier).mergeRemote(),
        _ref.read(comparisonProvider.notifier).mergeRemote(),
      ]);
    } else {
      await Future.wait<void>(<Future<void>>[
        _ref.read(cartProvider.notifier).refresh(),
        _ref.read(favoritesProvider.notifier).refresh(),
      ]);
    }
    _invalidateData();
  }

  Future<void> registerDevice() async {
    try {
      final token = await _ref.read(pushServiceProvider).token();
      if (token == null) return;
      await _ref.read(notificationsRepositoryProvider).registerDevice(
            token: token,
            platform: defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
          );
    } on AppException {
      // повторим при следующей синхронизации
    }
  }

  void _invalidateData() {
    _ref.invalidate(brandsProvider);
    _ref.invalidate(categoriesProvider);
    _ref.invalidate(homeSectionProvider);
    _ref.invalidate(ordersProvider);
    _ref.invalidate(notificationsProvider);
    _ref.invalidate(addressesProvider);
  }
}

final sessionCoordinatorProvider = Provider<SessionCoordinator>((ref) => SessionCoordinator(ref));
