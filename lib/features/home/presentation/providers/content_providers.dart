import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di.dart';
import '../../domain/entities/content.dart';

final bannersProvider = FutureProvider.autoDispose<List<PromoBanner>>(
  (ref) => ref.watch(contentRepositoryProvider).banners(),
);

final newsProvider = FutureProvider.autoDispose<List<NewsItem>>(
  (ref) => ref.watch(contentRepositoryProvider).news(),
);

final newsItemProvider = FutureProvider.autoDispose.family<NewsItem, String>(
  (ref, id) => ref.watch(contentRepositoryProvider).newsItem(id),
);
