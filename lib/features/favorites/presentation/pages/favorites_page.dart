import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/currency_button.dart';
import '../../../../core/l10n/app_text.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/state/product_collections.dart';
import '../../../../shared/widgets/product_card.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

class FavoritesPage extends ConsumerStatefulWidget {
  const FavoritesPage({super.key});

  @override
  ConsumerState<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends ConsumerState<FavoritesPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(favoritesProvider.notifier).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(favoritesProvider);
    final auth = ref.watch(authControllerProvider);
    final compareCount = ref.watch(comparisonProvider.select((l) => l.length));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Избранное'),
        actions: <Widget>[
          const CurrencyButton(),
          IconButton(
            tooltip: tr('Сравнение'),
            onPressed: () => context.push('/compare'),
            icon: Badge(
              isLabelVisible: compareCount > 0,
              label: Text('$compareCount'),
              child: const Icon(Icons.compare_arrows),
            ),
          ),
        ],
      ),
      body: items.isEmpty
          ? EmptyState(
              icon: Icons.favorite_border,
              title: 'В избранном пока пусто',
              message: 'Нажмите на сердечко у товара, чтобы сохранить его здесь.',
              actionLabel: 'Перейти в каталог',
              onAction: () => context.go('/catalog'),
            )
          : RefreshIndicator(
              color: AppColors.accent,
              onRefresh: () => ref.read(favoritesProvider.notifier).refresh(),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(top: 8, bottom: 24),
                children: <Widget>[
                  if (!auth.isAuthenticated)
                    InkWell(
                      onTap: () => context.push('/login?from=${Uri.encodeComponent('/favorites')}'),
                      child: Container(
                        margin: const EdgeInsets.fromLTRB(16, 4, 16, 6),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.infoSoft,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: const Row(
                          children: <Widget>[
                            Icon(Icons.sync, color: AppColors.info, size: 20),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Избранное хранится на устройстве. Войдите, чтобы синхронизировать его с аккаунтом.',
                                style: TextStyle(fontSize: 13, color: AppColors.info, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
                    child: Text(Fmt.products(items.length), style: AppText.caption),
                  ),
                  for (final p in items) ProductTile(product: p),
                ],
              ),
            ),
    );
  }
}
