import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/currency_button.dart';
import '../../../../core/l10n/app_text.dart';
import '../../../../app/di.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/state/product_collections.dart';
import '../controllers/product_list_controller.dart';
import '../../domain/entities/catalog_entities.dart';
import '../providers/catalog_providers.dart';
import '../widgets/filter_sheet.dart';
import '../widgets/product_results.dart';

/// Собирает фильтр из query-параметров маршрута `/products?...`.
ProductFilter filterFromQuery(Map<String, String> q) {
  bool flag(String k) => q[k] == 'true';
  return ProductFilter(
    query: q['q'] ?? '',
    categoryId: q['categoryId'],
    brandId: q['brandId'],
    manufacturer: q['manufacturer'],
    priceFrom: double.tryParse(q['priceFrom'] ?? ''),
    priceTo: double.tryParse(q['priceTo'] ?? ''),
    inStock: flag('inStock'),
    isNew: flag('isNew'),
    isPopular: flag('isPopular'),
    isSpecial: flag('isSpecial'),
    compatibility: q['compat'],
    sort: q['sort'] ?? 'popular',
  );
}

const Map<String, String> _sortLabels = <String, String>{
  'popular': 'По популярности',
  'price_asc': 'Сначала дешёвые',
  'price_desc': 'Сначала дорогие',
  'name': 'По названию',
  'new': 'Сначала новинки',
};

class ProductListPage extends ConsumerStatefulWidget {
  const ProductListPage({super.key, required this.initialFilter, this.title});

  final ProductFilter initialFilter;
  final String? title;

  @override
  ConsumerState<ProductListPage> createState() => _ProductListPageState();
}

class _ProductListPageState extends ConsumerState<ProductListPage> {
  late final ProductListController _controller;
  bool _grid = false;

  @override
  void initState() {
    super.initState();
    _controller = ProductListController(
      repository: ref.read(catalogRepositoryProvider),
      filter: widget.initialFilter,
    )..reload();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openFilters() async {
    final result = await showFilterSheet(context, _controller.filter);
    if (result != null) _controller.setFilter(result);
  }

  Future<void> _openSort() async {
    final current = _controller.filter.sort;
    final result = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Align(alignment: Alignment.centerLeft, child: Text('Сортировка', style: AppText.h2)),
            ),
            for (final entry in _sortLabels.entries)
              ListTile(
                title: Text(entry.value),
                trailing: entry.key == current
                    ? const Icon(Icons.check, color: AppColors.accent)
                    : null,
                onTap: () => Navigator.of(context).pop(entry.key),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (result != null && result != current) {
      _controller.setFilter(_controller.filter.copyWith(sort: result));
    }
  }

  @override
  Widget build(BuildContext context) {
    final compareCount = ref.watch(comparisonProvider.select((l) => l.length));
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title ?? 'Товары', maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: <Widget>[
          const CurrencyButton(),
          IconButton(
            tooltip: tr(_grid ? 'Списком' : 'Плиткой'),
            onPressed: () => setState(() => _grid = !_grid),
            icon: Icon(_grid ? Icons.view_list_outlined : Icons.grid_view_rounded),
          ),
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
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          final filter = _controller.filter;
          return Column(
            children: <Widget>[
              Container(
                color: AppColors.surface,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _openFilters,
                        icon: Badge(
                          isLabelVisible: filter.activeCount > 0,
                          label: Text('${filter.activeCount}'),
                          child: const Icon(Icons.tune, size: 20),
                        ),
                        label: const Text('Фильтры'),
                        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _openSort,
                        icon: const Icon(Icons.swap_vert, size: 20),
                        label: Text(
                          _sortLabels[filter.sort] ?? 'Сортировка',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                      ),
                    ),
                  ],
                ),
              ),
              _ActiveFilters(
                filter: filter,
                onChanged: _controller.setFilter,
              ),
              Expanded(
                child: ProductResults(
                  controller: _controller,
                  grid: _grid,
                  headerBuilder: (context, c) => Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
                    child: Text(
                      c.loading ? 'Загрузка…' : 'Найдено: ${Fmt.products(c.total)}',
                      style: AppText.caption,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Чипы выбранных фильтров с возможностью быстро снять каждый.
class _ActiveFilters extends ConsumerWidget {
  const _ActiveFilters({required this.filter, required this.onChanged});

  final ProductFilter filter;
  final ValueChanged<ProductFilter> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (filter.activeCount == 0) return const SizedBox.shrink();
    final categories = ref.watch(categoriesProvider).valueOrNull ?? const <Category>[];
    final brands = ref.watch(brandsProvider).valueOrNull ?? const <Brand>[];

    String categoryName(String id) {
      for (final c in categories) {
        if (c.id == id) return c.name;
      }
      return id;
    }

    String brandName(String id) {
      for (final b in brands) {
        if (b.id == id) return b.shortName;
      }
      return id;
    }

    final chips = <Widget>[];
    void add(String label, ProductFilter next) {
      chips.add(
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: InputChip(
            label: Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
            onDeleted: () => onChanged(next),
            deleteIconColor: AppColors.textSecondary,
            backgroundColor: AppColors.surface,
            side: const BorderSide(color: AppColors.border),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
          ),
        ),
      );
    }

    if (filter.categoryId != null) {
      add(categoryName(filter.categoryId!), filter.copyWith(clearCategory: true));
    }
    if (filter.brandId != null) add(brandName(filter.brandId!), filter.copyWith(clearBrand: true));
    if (filter.manufacturer != null) {
      add(filter.manufacturer!, filter.copyWith(clearManufacturer: true));
    }
    if (filter.priceFrom != null || filter.priceTo != null) {
      final from = filter.priceFrom == null ? '' : 'от ${Fmt.price(filter.priceFrom!, currency: 'RUB')} ';
      final to = filter.priceTo == null ? '' : 'до ${Fmt.price(filter.priceTo!, currency: 'RUB')}';
      add('$from$to'.trim(), filter.withPrice(null, null));
    }
    if (filter.compatibility != null) {
      add(filter.compatibility!, filter.copyWith(clearCompatibility: true));
    }
    if (filter.inStock) add('В наличии', filter.copyWith(inStock: false));
    if (filter.isNew) add('Новинки', filter.copyWith(isNew: false));
    if (filter.isPopular) add('Выбор покупателей', filter.copyWith(isPopular: false));
    if (filter.isSpecial) add('Спецпредложения', filter.copyWith(isSpecial: false));

    return Container(
      color: AppColors.surface,
      height: 46,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
        children: <Widget>[
          ...chips,
          TextButton(
            onPressed: () => onChanged(filter.reset()),
            child: const Text('Сбросить'),
          ),
        ],
      ),
    );
  }
}
