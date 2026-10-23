import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/app_config.dart';
import '../core/network/api_client.dart';
import '../core/network/http_api_client.dart';
import '../core/network/mock/mock_api_client.dart';
import '../core/network/network_status.dart';
import '../core/notifications/push_service.dart';
import '../core/storage/local_cache.dart';
import '../core/storage/token_storage.dart';
import '../features/auth/data/auth_repository_impl.dart';
import '../features/auth/domain/repositories/auth_repository.dart';
import '../features/cart/data/cart_repository_impl.dart';
import '../features/cart/domain/repositories/cart_repository.dart';
import '../features/catalog/data/catalog_repository_impl.dart';
import '../features/catalog/domain/repositories/catalog_repository.dart';
import '../features/favorites/data/collection_repository.dart';
import '../features/home/data/content_repository_impl.dart';
import '../features/home/domain/repositories/content_repository.dart';
import '../features/notifications/data/notifications_repository_impl.dart';
import '../features/notifications/domain/repositories/notifications_repository.dart';
import '../features/orders/data/orders_repository_impl.dart';
import '../features/orders/domain/repositories/orders_repository.dart';
import '../features/product/data/product_repository_impl.dart';
import '../features/product/domain/repositories/product_repository.dart';
import '../features/profile/data/profile_repository_impl.dart';
import '../features/profile/domain/repositories/profile_repository.dart';

/// Composition root: здесь решается, откуда берутся данные (Mock API или реальный backend)
/// и как собираются репозитории. UI работает только с репозиториями из этого файла.

/// Переопределяется в main() после SharedPreferences.getInstance().
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider must be overridden in main()'),
);

final localCacheProvider = Provider<LocalCache>(
  (ref) => LocalCache(ref.watch(sharedPreferencesProvider)),
);

final tokenStorageProvider = Provider<TokenStorage>((ref) => SecureTokenStorage());

final apiClientProvider = Provider<ApiClient>((ref) {
  final tokens = ref.watch(tokenStorageProvider);
  void onStatus(bool online) => ref.read(networkStatusProvider.notifier).set(online);
  void onExpired() => ref.read(sessionExpiredProvider.notifier).fire();

  if (AppConfig.useMockApi) {
    return MockApiClient(tokens: tokens, onSessionExpired: onExpired, onStatus: onStatus);
  }
  return HttpApiClient(tokens: tokens, onSessionExpired: onExpired, onStatus: onStatus);
});

final pushServiceProvider = Provider<PushService>((ref) => FcmPushService());

final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepositoryImpl(
      ref.watch(apiClientProvider),
      ref.watch(tokenStorageProvider),
      ref.watch(localCacheProvider),
    ));

final catalogRepositoryProvider = Provider<CatalogRepository>(
  (ref) => CatalogRepositoryImpl(ref.watch(apiClientProvider), ref.watch(localCacheProvider)),
);

final productRepositoryProvider = Provider<ProductRepository>(
  (ref) => ProductRepositoryImpl(ref.watch(apiClientProvider), ref.watch(localCacheProvider)),
);

final cartRepositoryProvider = Provider<CartRepository>(
  (ref) => CartRepositoryImpl(ref.watch(apiClientProvider), ref.watch(localCacheProvider)),
);

final collectionRepositoryProvider = Provider<CollectionRepository>(
  (ref) => CollectionRepository(ref.watch(apiClientProvider), ref.watch(localCacheProvider)),
);

final ordersRepositoryProvider = Provider<OrdersRepository>(
  (ref) => OrdersRepositoryImpl(ref.watch(apiClientProvider), ref.watch(localCacheProvider)),
);

final contentRepositoryProvider = Provider<ContentRepository>(
  (ref) => ContentRepositoryImpl(ref.watch(apiClientProvider), ref.watch(localCacheProvider)),
);

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepositoryImpl(ref.watch(apiClientProvider), ref.watch(localCacheProvider)),
);

final notificationsRepositoryProvider = Provider<NotificationsRepository>(
  (ref) => NotificationsRepositoryImpl(ref.watch(apiClientProvider)),
);
