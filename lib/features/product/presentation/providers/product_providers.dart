import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/product.dart';

final productProvider = FutureProvider.autoDispose.family<Product, String>((ref, id) {
  ref.watch(authControllerProvider.select((s) => s.user?.id));
  return ref.watch(productRepositoryProvider).product(id);
});

final analogsProvider = FutureProvider.autoDispose.family<List<Product>, String>((ref, id) {
  ref.watch(authControllerProvider.select((s) => s.user?.id));
  return ref.watch(productRepositoryProvider).analogs(id);
});
