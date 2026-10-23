import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/app_text.dart';
import '../../../../app/di.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/select_chip.dart';
import '../../domain/entities/catalog_entities.dart';
import '../providers/catalog_providers.dart';

/// Нижняя панель фильтров. Возвращает выбранный [ProductFilter] или null при закрытии.
Future<ProductFilter?> showFilterSheet(BuildContext context, ProductFilter initial) {
  return showModalBottomSheet<ProductFilter>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.92,
      child: FilterSheet(initial: initial),
    ),
  );
}

class FilterSheet extends ConsumerStatefulWidget {
  const FilterSheet({super.key, required this.initial});

  final ProductFilter initial;

  @override
  ConsumerState<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<FilterSheet> {
  late ProductFilter _filter = widget.initial;
  late final TextEditingController _from = TextEditingController(
    text: widget.initial.priceFrom == null ? '' : widget.initial.priceFrom!.round().toString(),
  );
  late final TextEditingController _to = TextEditingController(
    text: widget.initial.priceTo == null ? '' : widget.initial.priceTo!.round().toString(),
  );
  final Debouncer _debounce = Debouncer(350);
  int? _count;
  bool _countLoading = false;
  int _generation = 0;
  bool _showAllManufacturers = false;

  @override
  void initState() {
    super.initState();
    _loadCount();
  }

  @override
  void dispose() {
    _debounce.cancel();
    _from.dispose();
    _to.dispose();
    super.dispose();
  }

  void _update(ProductFilter filter) {
    setState(() => _filter = filter);
    _debounce.run(_loadCount);
  }

  Future<void> _loadCount() async {
    final generation = ++_generation;
    if (mounted) setState(() => _countLoading = true);
    try {
      final result = await ref.read(catalogRepositoryProvider).products(_filter, pageSize: 1);
      if (!mounted || generation != _generation) return;
      setState(() {
        _count = result.total;
        _countLoading = false;
      });
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _count = null;
        _countLoading = false;
      });
    }
  }

  double? _parse(String text) => double.tryParse(text.replaceAll(',', '.').replaceAll(' ', ''));

  void _onPriceChanged() {
    _update(_filter.withPrice(_parse(_from.text), _parse(_to.text)));
  }

  void _reset() {
    _from.clear();
    _to.clear();
    _update(_filter.reset());
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider).valueOrNull ?? const <Category>[];
    final brands = ref.watch(brandsProvider).valueOrNull ?? const <Brand>[];
    final options = ref.watch(filterOptionsProvider).valueOrNull;

    final roots = categories.where((c) => c.isRoot).toList();
    String? selectedRoot;
    if (_filter.categoryId != null) {
      final selected = categories.where((c) => c.id == _filter.categoryId);
      if (selected.isNotEmpty) selectedRoot = selected.first.parentId ?? selected.first.id;
    }
    final children = selectedRoot == null
        ? const <Category>[]
        : categories.where((c) => c.parentId == selectedRoot).toList();

    final manufacturers = options?.manufacturers ?? const <String>[];
    final visibleManufacturers =
        _showAllManufacturers || manufacturers.length <= 12 ? manufacturers : manufacturers.sublist(0, 12);

    final label = _countLoading
        ? 'Подсчёт…'
        : (_count == null
            ? 'Показать товары'
            : (_count == 0 ? 'Ничего не найдено' : 'Показать ${Fmt.products(_count!)}'));

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 8, 4),
          child: Row(
            children: <Widget>[
              const Expanded(child: Text('Фильтры', style: AppText.h1)),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
        const Divider(),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            children: <Widget>[
              const _Title('Цена, ₽'),
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _from,
                      keyboardType: TextInputType.number,
                      inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.allow(RegExp(r'[0-9 ,.]'))],
                      decoration: AppInput.of(
                        label: 'От',
                        hint: options == null ? null : Fmt.price(options.priceMin, currency: 'RUB').replaceAll(' ₽', ''),
                      ),
                      onChanged: (_) => _onPriceChanged(),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Text('—', style: AppText.bodySecondary),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _to,
                      keyboardType: TextInputType.number,
                      inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.allow(RegExp(r'[0-9 ,.]'))],
                      decoration: AppInput.of(
                        label: 'До',
                        hint: options == null ? null : Fmt.price(options.priceMax, currency: 'RUB').replaceAll(' ₽', ''),
                      ),
                      onChanged: (_) => _onPriceChanged(),
                    ),
                  ),
                ],
              ),
              if (roots.isNotEmpty) ...<Widget>[
                const _Title('Категория'),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: <Widget>[
                    for (final c in roots)
                      SelectChip(
                        label: c.name,
                        selected: selectedRoot == c.id,
                        onTap: () => _update(
                          selectedRoot == c.id
                              ? _filter.copyWith(clearCategory: true)
                              : _filter.copyWith(categoryId: c.id),
                        ),
                      ),
                  ],
                ),
              ],
              if (children.isNotEmpty) ...<Widget>[
                const _Title('Подкатегория'),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: <Widget>[
                    for (final c in children)
                      SelectChip(
                        label: c.name,
                        selected: _filter.categoryId == c.id,
                        onTap: () => _update(
                          _filter.categoryId == c.id
                              ? _filter.copyWith(categoryId: selectedRoot)
                              : _filter.copyWith(categoryId: c.id),
                        ),
                      ),
                  ],
                ),
              ],
              if (brands.isNotEmpty) ...<Widget>[
                const _Title('Бренд'),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: <Widget>[
                    for (final b in brands)
                      SelectChip(
                        label: b.shortName,
                        selected: _filter.brandId == b.id,
                        onTap: () => _update(
                          _filter.brandId == b.id
                              ? _filter.copyWith(clearBrand: true)
                              : _filter.copyWith(brandId: b.id),
                        ),
                      ),
                  ],
                ),
              ],
              if (manufacturers.isNotEmpty) ...<Widget>[
                const _Title('Производитель'),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: <Widget>[
                    for (final m in visibleManufacturers)
                      SelectChip(
                        label: m,
                        selected: _filter.manufacturer == m,
                        onTap: () => _update(
                          _filter.manufacturer == m
                              ? _filter.copyWith(clearManufacturer: true)
                              : _filter.copyWith(manufacturer: m),
                        ),
                      ),
                  ],
                ),
                if (manufacturers.length > 12)
                  TextButton(
                    onPressed: () => setState(() => _showAllManufacturers = !_showAllManufacturers),
                    child: Text(_showAllManufacturers ? 'Свернуть' : 'Показать все (${manufacturers.length})'),
                  ),
              ],
              if ((options?.compatibilities ?? const <String>[]).isNotEmpty) ...<Widget>[
                const _Title('Совместимость'),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: <Widget>[
                    for (final m in options!.compatibilities)
                      SelectChip(
                        label: m,
                        selected: _filter.compatibility == m,
                        onTap: () => _update(
                          _filter.compatibility == m
                              ? _filter.copyWith(clearCompatibility: true)
                              : _filter.copyWith(compatibility: m),
                        ),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              _SwitchRow(
                title: 'Только в наличии',
                value: _filter.inStock,
                onChanged: (v) => _update(_filter.copyWith(inStock: v)),
              ),
              _SwitchRow(
                title: 'Новинки',
                value: _filter.isNew,
                onChanged: (v) => _update(_filter.copyWith(isNew: v)),
              ),
              _SwitchRow(
                title: 'Выбор покупателей',
                value: _filter.isPopular,
                onChanged: (v) => _update(_filter.copyWith(isPopular: v)),
              ),
              _SwitchRow(
                title: 'Специальное предложение',
                value: _filter.isSpecial,
                onChanged: (v) => _update(_filter.copyWith(isSpecial: v)),
              ),
            ],
          ),
        ),
        const Divider(),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Row(
            children: <Widget>[
              SizedBox(
                width: 120,
                child: OutlinedButton(
                  onPressed: _filter.activeCount == 0 ? null : _reset,
                  child: const Text('Сбросить'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _count == 0 ? null : () => Navigator.of(context).pop(_filter),
                  child: Text(label),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Title extends StatelessWidget {
  const _Title(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 10),
      child: Text(text, style: AppText.h3),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({required this.title, required this.value, required this.onChanged});

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(child: Text(title, style: AppText.body)),
        Switch(
          value: value,
          onChanged: onChanged,
          activeTrackColor: AppColors.accent,
        ),
      ],
    );
  }
}
