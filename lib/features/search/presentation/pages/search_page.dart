import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/app_text.dart';
import '../../../../app/di.dart';
import '../../../../core/constants/app_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../catalog/domain/entities/catalog_entities.dart';
import '../../../catalog/presentation/controllers/product_list_controller.dart';
import '../../../catalog/presentation/providers/catalog_providers.dart';
import '../../../catalog/presentation/widgets/product_results.dart';

/// Поиск по названию, артикулу, OEM-номеру, бренду и категории: результаты обновляются
/// по мере ввода (debounce), есть автодополнение, история и популярные запросы.
class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key, this.initialQuery = ''});

  final String initialQuery;

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  late final TextEditingController _text = TextEditingController(text: widget.initialQuery);
  late final ProductListController _results;
  final Debouncer _debounce = Debouncer(AppConfig.searchDebounceMs);
  List<SearchSuggestion> _suggestions = <SearchSuggestion>[];
  int _suggestGeneration = 0;

  String get _query => _text.text.trim();

  @override
  void initState() {
    super.initState();
    _results = ProductListController(
      repository: ref.read(catalogRepositoryProvider),
      filter: ProductFilter(query: widget.initialQuery),
    );
    if (widget.initialQuery.isNotEmpty) _results.reload();
  }

  @override
  void dispose() {
    _debounce.cancel();
    _text.dispose();
    _results.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    setState(() {});
    if (_query.isEmpty) {
      _debounce.cancel();
      _suggestGeneration++;
      setState(() => _suggestions = <SearchSuggestion>[]);
      return;
    }
    _debounce.run(() {
      _results.setFilter(ProductFilter(query: _query));
      _loadSuggestions(_query);
    });
  }

  Future<void> _loadSuggestions(String query) async {
    final generation = ++_suggestGeneration;
    try {
      final items = await ref.read(catalogRepositoryProvider).suggest(query);
      if (!mounted || generation != _suggestGeneration) return;
      setState(() => _suggestions = items);
    } catch (_) {
      // подсказки необязательны — результаты поиска продолжают работать
    }
  }

  void _setQuery(String value) {
    _text.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
    setState(() {});
    _results.setFilter(ProductFilter(query: value.trim()));
    _loadSuggestions(value.trim());
  }

  void _saveHistory() => ref.read(searchHistoryProvider.notifier).add(_query);

  void _openSuggestion(SearchSuggestion s) {
    switch (s.type) {
      case 'product':
        _saveHistory();
        context.push('/product/${s.id}');
        break;
      case 'brand':
        context.push('/products?brandId=${s.id}&title=${Uri.encodeComponent(s.text)}');
        break;
      case 'category':
        context.push('/products?categoryId=${s.id}&title=${Uri.encodeComponent(s.text)}');
        break;
      default:
        _setQuery(s.text);
    }
  }

  IconData _suggestionIcon(String type) {
    switch (type) {
      case 'product':
        return Icons.inventory_2_outlined;
      case 'brand':
        return Icons.local_shipping_outlined;
      case 'category':
        return Icons.category_outlined;
      default:
        return Icons.search;
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasQuery = _query.isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _text,
          autofocus: widget.initialQuery.isEmpty,
          textInputAction: TextInputAction.search,
          onChanged: _onChanged,
          onSubmitted: (_) {
            _saveHistory();
            FocusScope.of(context).unfocus();
          },
          style: const TextStyle(fontSize: 16),
          decoration: InputDecoration(
            hintText: tr('Артикул, название или бренд'),
            hintStyle: const TextStyle(color: AppColors.textHint),
            border: InputBorder.none,
          ),
        ),
        actions: <Widget>[
          if (hasQuery)
            IconButton(
              tooltip: tr('Очистить'),
              icon: const Icon(Icons.close),
              onPressed: () {
                _text.clear();
                _onChanged('');
              },
            ),
        ],
      ),
      body: hasQuery ? _buildResults() : _buildStart(),
    );
  }

  Widget _buildResults() {
    return Column(
      children: <Widget>[
        if (_suggestions.isNotEmpty)
          Container(
            color: AppColors.surface,
            height: 52,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
              itemCount: _suggestions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final s = _suggestions[i];
                return ActionChip(
                  avatar: Icon(_suggestionIcon(s.type), size: 16, color: AppColors.primary),
                  label: Text(
                    s.type == 'product' && s.subtitle != null ? '${s.subtitle} · ${s.text}' : s.text,
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                  onPressed: () => _openSuggestion(s),
                  backgroundColor: AppColors.surface,
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                );
              },
            ),
          ),
        Expanded(
          child: ProductResults(
            controller: _results,
            onOpenProduct: _saveHistory,
            emptyTitle: 'Ничего не найдено',
            emptyMessage: 'Проверьте артикул или попробуйте другой запрос.',
            headerBuilder: (context, c) => Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
              child: Text(
                c.loading ? 'Поиск…' : 'Найдено: ${Fmt.products(c.total)}',
                style: AppText.caption,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStart() {
    final history = ref.watch(searchHistoryProvider);
    final popular = ref.watch(popularQueriesProvider);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: <Widget>[
        if (history.isNotEmpty) ...<Widget>[
          Row(
            children: <Widget>[
              const Expanded(child: Text('История поиска', style: AppText.h3)),
              TextButton(
                onPressed: () => ref.read(searchHistoryProvider.notifier).clear(),
                child: const Text('Очистить'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final q in history)
                InputChip(
                  avatar: const Icon(Icons.history, size: 16, color: AppColors.textSecondary),
                  label: Text(q, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  onPressed: () => _setQuery(q),
                  onDeleted: () => ref.read(searchHistoryProvider.notifier).remove(q),
                  backgroundColor: AppColors.surface,
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                ),
            ],
          ),
          const SizedBox(height: 24),
        ],
        const Text('Популярные запросы', style: AppText.h3),
        const SizedBox(height: 10),
        popular.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => const Text('Не удалось загрузить популярные запросы.', style: AppText.bodySecondary),
          data: (items) => Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final q in items)
                ActionChip(
                  avatar: const Icon(Icons.trending_up, size: 16, color: AppColors.accentDark),
                  label: Text(q, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  onPressed: () => _setQuery(q),
                  backgroundColor: AppColors.surface,
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const SurfaceHint(),
      ],
    );
  }
}

class SurfaceHint extends StatelessWidget {
  const SurfaceHint({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.infoSoft,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.lightbulb_outline, color: AppColors.info, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Введите артикул или OEM-номер целиком или частично — товар найдётся сразу. '
              'Дефисы и пробелы в номере можно не вводить.',
              style: TextStyle(fontSize: 13, color: AppColors.textPrimary, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}
