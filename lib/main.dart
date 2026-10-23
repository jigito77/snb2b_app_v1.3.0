import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'app/di.dart';
import 'app/session_coordinator.dart';
import 'core/network/mock/catalog_loader.dart';
import 'features/auth/presentation/providers/auth_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );

  await loadCatalogAsset();

  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: <Override>[sharedPreferencesProvider.overrideWithValue(prefs)],
  );

  // Восстанавливаем сессию до первого кадра, чтобы не мигал экран «гостя».
  await container.read(authControllerProvider.notifier).restore();

  // Push не блокирует запуск: без google-services.json сервис просто неактивен.
  unawaited(() async {
    await container.read(pushServiceProvider).init();
    if (container.read(authControllerProvider).isAuthenticated) {
      await container.read(sessionCoordinatorProvider).registerDevice();
    }
  }());

  // Фоновая синхронизация корзины/избранного с сервером.
  unawaited(container.read(sessionCoordinatorProvider).syncAll());

  runApp(UncontrolledProviderScope(container: container, child: const B2bApp()));
}
