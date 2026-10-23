import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/app_text.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/common.dart';
import '../../../../shared/widgets/skeleton.dart';
import '../../../../shared/widgets/state_views.dart';
import '../providers/content_providers.dart';

class NewsListPage extends ConsumerWidget {
  const NewsListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(newsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Новости')),
      body: async.when(
        loading: () => ListView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.only(top: 12),
          children: const <Widget>[
            BlockSkeleton(height: 110, margin: EdgeInsets.fromLTRB(16, 0, 16, 12)),
            BlockSkeleton(height: 110, margin: EdgeInsets.fromLTRB(16, 0, 16, 12)),
            BlockSkeleton(height: 110, margin: EdgeInsets.fromLTRB(16, 0, 16, 12)),
          ],
        ),
        error: (e, _) => ErrorState(error: e, onRetry: () => ref.invalidate(newsProvider)),
        data: (list) {
          if (list.isEmpty) {
            return const EmptyState(icon: Icons.newspaper_outlined, title: 'Новостей пока нет');
          }
          return RefreshIndicator(
            color: AppColors.accent,
            onRefresh: () async {
              ref.invalidate(newsProvider);
              try {
                await ref.read(newsProvider.future);
              } catch (_) {
                // ошибка отобразится на экране
              }
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: <Widget>[
                for (final n in list)
                  SurfaceCard(
                    margin: const EdgeInsets.only(bottom: 12),
                    onTap: () => context.push('/news/${n.id}'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(Fmt.date(n.date), style: AppText.caption),
                        const SizedBox(height: 4),
                        Text(n.title, style: AppText.h3),
                        const SizedBox(height: 6),
                        Text(n.summary, maxLines: 3, overflow: TextOverflow.ellipsis, style: AppText.bodySecondary),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class NewsDetailPage extends ConsumerWidget {
  const NewsDetailPage({super.key, required this.newsId});

  final String newsId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(newsItemProvider(newsId));
    return Scaffold(
      appBar: AppBar(title: const Text('Новость')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(error: e, onRetry: () => ref.invalidate(newsItemProvider(newsId))),
        data: (n) => ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            Text(Fmt.date(n.date), style: AppText.caption),
            const SizedBox(height: 6),
            Text(n.title, style: AppText.h1),
            const SizedBox(height: 14),
            Text(n.body.isEmpty ? n.summary : n.body, style: AppText.body.copyWith(height: 1.5)),
          ],
        ),
      ),
    );
  }
}
