import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/address.dart';

final addressesProvider = FutureProvider.autoDispose<List<Address>>((ref) {
  ref.watch(authControllerProvider.select((s) => s.user?.id));
  return ref.watch(profileRepositoryProvider).addresses();
});
