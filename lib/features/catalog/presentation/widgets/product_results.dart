import 'package:flutter/material.dart' hide Text;

import '../../../../core/l10n/app_text.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/common.dart';
import '../../../../shared/widgets/product_card.dart';
import '../../../../shared/widgets/skeleton.dart';
import '../../../../shared/widgets/state_views.dart';
import '../controllers/product_list_controller.dart';

/// Список/сетка товаров с бесконечной прокруткой, pull-to-refresh, skeleton,
/// пустым состоянием и ошибками.
class ProductResults extends StatefulWidget {
  const ProductResults({
    super.key,
    required this.controller,
    this.grid = false,
    this.headerBuilder,
    this.onOpenProduct,
    this.emptyTitle = 'Ничего не найдено',
    this.emptyMessage = 'Измените запрос или сбросьте фильтры.',
  });

  final ProductListController controller;
  final bool grid;
  final Widget Function(BuildContext context, ProductListController controller)? headerBuilder;
  final VoidCallback? onOpenProduct;
  final String emptyTitle;
  final String emptyMessage;

  @override
  State<ProductResults> createState() => _ProductResultsState();
}

class _ProductResultsState extends State<ProductResults> {
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    if (position.pixels > position.maxScrollExtent - 500) {
      widget.controller.loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        if (c.loading && c.items.isEmpty) return const ProductListSkeleton();
        if (c.error != null && c.items.isEmpty) {
          return ErrorState(error: c.error!, onRetry: c.reload);
        }
        if (c.isEmpty) {
          return Column(
            children: <Widget>[
              if (widget.headerBuilder != null) widget.headerBuilder!(context, c),
              Expanded(
                child: EmptyState(
                  icon: Icons.search_off_rounded,
                  title: widget.emptyTitle,
                  message: widget.emptyMessage,
                  actionLabel: 'Обновить',
                  onAction: c.reload,
                ),
              ),
            ],
          );
        }

        final Widget content;
        if (widget.grid) {
          content = SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                mainAxisExtent: 312,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, i) => ProductCard(product: c.items[i]),
                childCount: c.items.length,
              ),
            ),
          );
        } else {
          content = SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) => ProductTile(product: c.items[i], onOpen: widget.onOpenProduct),
              childCount: c.items.length,
            ),
          );
        }

        return RefreshIndicator(
          color: AppColors.accent,
          onRefresh: c.reload,
          child: CustomScrollView(
            controller: _scroll,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: <Widget>[
              if (widget.headerBuilder != null)
                SliverToBoxAdapter(child: widget.headerBuilder!(context, c)),
              if (c.fromCache) const SliverToBoxAdapter(child: OfflineBanner()),
              const SliverToBoxAdapter(child: SizedBox(height: 6)),
              content,
              SliverToBoxAdapter(child: _Footer(controller: c)),
            ],
          ),
        );
      },
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.controller});

  final ProductListController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.loadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator(strokeWidth: 3)),
      );
    }
    if (controller.moreError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: TextButton.icon(
            onPressed: controller.loadMore,
            icon: const Icon(Icons.refresh),
            label: const Text('Не удалось загрузить. Повторить'),
          ),
        ),
      );
    }
    return const SizedBox(height: 28);
  }
}
