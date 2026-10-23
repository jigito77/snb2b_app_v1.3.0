import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/app_text.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/state/product_collections.dart';
import '../../../../shared/widgets/common.dart';
import '../../../../shared/widgets/product_image.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../cart/presentation/providers/cart_provider.dart';
import '../../../product/domain/entities/product.dart';

class _CompareRow {
  const _CompareRow(this.label, this.values);

  final String label;
  final List<String> values;

  bool get differs => values.toSet().length > 1;
}

class ComparisonPage extends ConsumerStatefulWidget {
  const ComparisonPage({super.key});

  @override
  ConsumerState<ComparisonPage> createState() => _ComparisonPageState();
}

class _ComparisonPageState extends ConsumerState<ComparisonPage> {
  bool _onlyDifferences = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(comparisonProvider.notifier).refresh();
    });
  }

  List<_CompareRow> _rows(List<Product> items) {
    final rows = <_CompareRow>[
      _CompareRow('Цена', items.map((p) => Fmt.price(p.unitPrice(p.effectiveMinQty))).toList()),
      _CompareRow('Бренд', items.map((p) => p.brandName).toList()),
      _CompareRow('Производитель', items.map((p) => p.manufacturer.isEmpty ? '—' : p.manufacturer).toList()),
      _CompareRow('Артикул', items.map((p) => p.article).toList()),
      _CompareRow('OEM номер', items.map((p) => p.oem.isEmpty ? '—' : p.oem).toList()),
      _CompareRow(
        'Наличие',
        items.map((p) => p.inStock ? (p.offers.isEmpty ? 'В наличии (${Fmt.pieces(p.stock.available)})' : 'В наличии') : (p.offers.isEmpty ? 'Нет в наличии' : 'Под заказ')).toList(),
      ),
      _CompareRow('Срок поставки', items.map((p) => p.deliveryLabel).toList()),
    ];

    final names = <String>[];
    for (final p in items) {
      for (final a in p.attributes) {
        if (!names.contains(a.name) && a.name != 'Производитель') names.add(a.name);
      }
    }
    for (final name in names) {
      rows.add(
        _CompareRow(
          name,
          items.map((p) {
            for (final a in p.attributes) {
              if (a.name == name) return a.value;
            }
            return '—';
          }).toList(),
        ),
      );
    }
    rows.add(
      _CompareRow(
        'Совместимость',
        items.map((p) => p.compatibility.isEmpty ? '—' : p.compatibility.join('\n')).toList(),
      ),
    );
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(comparisonProvider);

    if (items.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Сравнение')),
        body: EmptyState(
          icon: Icons.compare_arrows,
          title: 'Нечего сравнивать',
          message: 'Добавьте до 4 товаров кнопкой «Сравнить» в карточке товара.',
          actionLabel: 'Перейти в каталог',
          onAction: () => context.go('/catalog'),
        ),
      );
    }

    final allRows = _rows(items);
    final rows = _onlyDifferences ? allRows.where((r) => r.differs).toList() : allRows;
    const labelWidth = 112.0;
    const columnWidth = 156.0;

    return Scaffold(
      appBar: AppBar(
        title: Text('Сравнение · ${items.length}'),
        actions: <Widget>[
          IconButton(
            tooltip: tr('Очистить'),
            onPressed: () {
              for (final p in List<Product>.from(items)) {
                ref.read(comparisonProvider.notifier).remove(p.id);
              }
            },
            icon: const Icon(Icons.delete_sweep_outlined),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(16, 0, 8, 4),
            child: Row(
              children: <Widget>[
                const Expanded(child: Text('Только отличия', style: AppText.body)),
                Switch(
                  value: _onlyDifferences,
                  onChanged: (v) => setState(() => _onlyDifferences = v),
                  activeTrackColor: AppColors.accent,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Table(
                  defaultVerticalAlignment: TableCellVerticalAlignment.top,
                  columnWidths: <int, TableColumnWidth>{
                    0: const FixedColumnWidth(labelWidth),
                    for (var i = 0; i < items.length; i++) i + 1: const FixedColumnWidth(columnWidth),
                  },
                  border: const TableBorder(
                    horizontalInside: BorderSide(color: AppColors.divider),
                    bottom: BorderSide(color: AppColors.divider),
                  ),
                  children: <TableRow>[
                    TableRow(
                      decoration: const BoxDecoration(color: AppColors.surface),
                      children: <Widget>[
                        const SizedBox(),
                        for (final p in items) _HeaderCell(product: p),
                      ],
                    ),
                    for (final row in rows)
                      TableRow(
                        decoration: BoxDecoration(
                          color: row.differs ? AppColors.accentSoft : AppColors.surface,
                        ),
                        children: <Widget>[
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(row.label, style: AppText.label),
                          ),
                          for (final value in row.values)
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Text(
                                value,
                                style: AppText.body.copyWith(
                                  fontWeight: row.differs ? FontWeight.w700 : FontWeight.w400,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderCell extends ConsumerWidget {
  const _HeaderCell({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = product;
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Stack(
            children: <Widget>[
              InkWell(
                onTap: () => context.push('/product/${p.id}'),
                child: SizedBox(
                  width: 80,
                  height: 80,
                  child: ProductImage(
                    categoryId: p.categoryId,
                    url: p.images.isEmpty ? null : p.images.first,
                    borderRadius: 12,
                  ),
                ),
              ),
              Positioned(
                right: -4,
                top: -4,
                child: IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: tr('Убрать из сравнения'),
                  onPressed: () => ref.read(comparisonProvider.notifier).remove(p.id),
                  icon: const Icon(Icons.cancel, color: AppColors.textHint),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            p.name,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, height: 1.25),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 36,
            child: FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(36),
                textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              onPressed: p.canOrder
                  ? () {
                      final error = ref.read(cartProvider.notifier).add(p);
                      showSnack(context, error ?? 'Добавлено в корзину', error: error != null);
                    }
                  : null,
              child: Text(p.canOrder ? 'В корзину' : 'Нет в наличии'),
            ),
          ),
        ],
      ),
    );
  }
}
