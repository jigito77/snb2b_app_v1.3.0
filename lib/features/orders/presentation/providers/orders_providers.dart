import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di.dart';
import '../../../auth/domain/entities/user.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/order.dart';

final ordersProvider = FutureProvider.autoDispose<List<Order>>((ref) {
  ref.watch(authControllerProvider.select((s) => s.user?.id));
  return ref.watch(ordersRepositoryProvider).orders();
});

final orderProvider = FutureProvider.autoDispose.family<Order, String>((ref, id) {
  return ref.watch(ordersRepositoryProvider).order(id);
});

/// Персональный менеджер клиента (для гостей — менеджер по умолчанию).
final managerProvider = FutureProvider.autoDispose<ManagerInfo>((ref) {
  ref.watch(authControllerProvider.select((s) => s.user?.id));
  return ref.watch(ordersRepositoryProvider).manager();
});
