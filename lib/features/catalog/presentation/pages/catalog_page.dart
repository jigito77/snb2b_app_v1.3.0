import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/currency_button.dart';
import '../../../../core/l10n/app_text.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/category_icons.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/state/product_collections.dart';
import '../../../../shared/widgets/common.dart';
import '../../../../shared/widgets/skeleton.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../domain/entities/catalog_entities.dart';
import '../providers/catalog_providers.dart';

class CatalogPage extends ConsumerStatefulWidget {
  const CatalogPage({super.key});

  @override
  ConsumerState<CatalogPage> createState() => _CatalogPageState();
}

class _CatalogPageState extends ConsumerState<CatalogPage> {
  int _tab = 0;

  Future<void> _refresh() async {
    ref.invalidate(categoriesProvider);
    ref.invalidate(brandsProvider);
    try {
      await ref.read(categoriesProvider.future);
    } catch (_) {
      // ошибки показываются в списке
    }
  }

  @override
  Widget build(BuildContext context) {
    final compareCount = ref.watch(comparisonProvider.select((l) => l.length));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Каталог'),
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
          IconButton(
            tooltip: tr('Поиск'),
            onPressed: () => context.push('/search'),
            icon: const Icon(Icons.search),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.accent,
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: <Widget>[
            SurfaceCard(
              onTap: () => context.push('/search'),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: const Row(
                children: <Widget>[
                  Icon(Icons.search, color: AppColors.primary),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Артикул, название или бренд',
                      style: TextStyle(fontSize: 15, color: AppColors.textHint),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SurfaceCard(
              onTap: () => context.push('/products?title=${Uri.encodeComponent('Все товары')}'),
              padding: const EdgeInsets.all(14),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.accentSoft,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: const Icon(Icons.inventory_2_outlined, color: AppColors.accentDark),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(child: Text('Все товары', style: AppText.h3)),
                  const Icon(Icons.chevron_right, color: AppColors.textHint),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SegmentedButton<int>(
              showSelectedIcon: false,
              segments: const <ButtonSegment<int>>[
                ButtonSegment<int>(value: 0, label: Text('Категории'), icon: Icon(Icons.category_outlined)),
                ButtonSegment<int>(value: 1, label: Text('Бренды'), icon: Icon(Icons.local_shipping_outlined)),
              ],
              selected: <int>{_tab},
              onSelectionChanged: (s) => setState(() => _tab = s.first),
              style: SegmentedButton.styleFrom(
                backgroundColor: AppColors.surface,
                foregroundColor: AppColors.textPrimary,
                selectedBackgroundColor: AppColors.primary,
                selectedForegroundColor: Colors.white,
                side: const BorderSide(color: AppColors.border),
              ),
            ),
            const SizedBox(height: 14),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: _tab == 0
                  ? const _CategoriesList(key: ValueKey<int>(0))
                  : const _BrandsList(key: ValueKey<int>(1)),
            ),
          ],
        ),
      ),
    );
  }
}

void _openProducts(BuildContext context, {String? categoryId, String? brandId, required String title}) {
  final params = <String>[
    if (categoryId != null) 'categoryId=$categoryId',
    if (brandId != null) 'brandId=$brandId',
    'title=${Uri.encodeComponent(title)}',
  ];
  context.push('/products?${params.join('&')}');
}

class _CategoriesList extends ConsumerWidget {
  const _CategoriesList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider);
    return categories.when(
      loading: () => const _ListSkeleton(),
      error: (e, _) => SizedBox(
        height: 320,
        child: ErrorState(error: e, onRetry: () => ref.invalidate(categoriesProvider)),
      ),
      data: (all) {
        final roots = all.where((c) => c.isRoot).toList();
        return Column(
          children: <Widget>[
            for (final root in roots)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _CategoryTile(
                  root: root,
                  children: all.where((c) => c.parentId == root.id).toList(),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.root, required this.children});

  final Category root;
  final List<Category> children;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          childrenPadding: const EdgeInsets.only(bottom: 8),
          shape: const Border(),
          collapsedShape: const Border(),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(CategoryIcons.of(root.id), color: AppColors.primary),
          ),
          title: Text(root.name, style: AppText.h3),
          subtitle: Text(Fmt.products(root.productCount), style: AppText.caption),
          children: <Widget>[
            ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 22),
              title: Text(
                'Все в категории «${root.name}»',
                style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.accentDark),
              ),
              onTap: () => _openProducts(context, categoryId: root.id, title: root.name),
            ),
            for (final c in children)
              ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 22),
                title: Text(c.name),
                trailing: Text('${c.productCount}', style: AppText.caption),
                onTap: () => _openProducts(context, categoryId: c.id, title: c.name),
              ),
          ],
        ),
      ),
    );
  }
}

class _BrandsList extends ConsumerWidget {
  const _BrandsList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brands = ref.watch(brandsProvider);
    return brands.when(
      loading: () => const _ListSkeleton(),
      error: (e, _) => SizedBox(
        height: 320,
        child: ErrorState(error: e, onRetry: () => ref.invalidate(brandsProvider)),
      ),
      data: (items) => Column(
        children: <Widget>[
          for (final b in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SurfaceCard(
                onTap: () => _openProducts(context, brandId: b.id, title: b.name),
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(color: AppColors.surfaceAlt, shape: BoxShape.circle),
                      child: Text(
                        b.shortName.length > 1 ? b.shortName.substring(0, 2).toUpperCase() : b.shortName,
                        style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(b.name, style: AppText.h3),
                          const SizedBox(height: 2),
                          Text(Fmt.products(b.productCount), style: AppText.caption),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: AppColors.textHint),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ListSkeleton extends StatelessWidget {
  const _ListSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: <Widget>[
        BlockSkeleton(height: 68, margin: EdgeInsets.only(bottom: 10)),
        BlockSkeleton(height: 68, margin: EdgeInsets.only(bottom: 10)),
        BlockSkeleton(height: 68, margin: EdgeInsets.only(bottom: 10)),
        BlockSkeleton(height: 68, margin: EdgeInsets.only(bottom: 10)),
      ],
    );
  }
}
