import 'dart:async';

import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/language_sheet.dart';
import '../../../../shared/widgets/currency_button.dart';
import '../../../../core/l10n/app_text.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/category_icons.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/state/product_collections.dart';
import '../../../../shared/widgets/common.dart';
import '../../../../shared/widgets/manager_sheet.dart';
import '../../../../shared/widgets/product_card.dart';
import '../../../../shared/widgets/skeleton.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../cart/presentation/providers/cart_provider.dart';
import '../../../catalog/presentation/providers/catalog_providers.dart';
import '../../domain/entities/content.dart';
import '../providers/content_providers.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(brandsProvider);
    ref.invalidate(categoriesProvider);
    ref.invalidate(bannersProvider);
    ref.invalidate(newsProvider);
    ref.invalidate(homeSectionProvider);
    try {
      await ref.read(brandsProvider.future);
    } catch (_) {
      // ошибки отображаются в самих секциях
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recent = ref.watch(recentlyViewedProvider);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.accent,
          onRefresh: () => _refresh(ref),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: <Widget>[
              const SliverToBoxAdapter(child: _Header()),
              const SliverToBoxAdapter(child: _SearchField()),
              const SliverToBoxAdapter(child: _BrandsRow()),
              const SliverToBoxAdapter(child: _QuickActions()),
              const SliverToBoxAdapter(child: _BannersCarousel()),
              SliverToBoxAdapter(
                child: SectionHeader(title: 'Популярные категории', onAction: () => context.go('/catalog')),
              ),
              const SliverToBoxAdapter(child: _CategoriesGrid()),
              const SliverToBoxAdapter(
                child: _ProductSection(
                  kind: 'new',
                  title: 'Новинки',
                  route: '/products?isNew=true&title=Новинки',
                ),
              ),
              const SliverToBoxAdapter(
                child: _ProductSection(
                  kind: 'popular',
                  title: 'Популярные товары',
                  route: '/products?isPopular=true&title=Популярные товары',
                ),
              ),
              const SliverToBoxAdapter(
                child: _ProductSection(
                  kind: 'special',
                  title: 'Специальные предложения',
                  route: '/products?isSpecial=true&title=Специальные предложения',
                ),
              ),
              if (recent.isNotEmpty)
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const SectionHeader(title: 'Вы смотрели'),
                      SizedBox(
                        height: 312,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          itemCount: recent.length > 10 ? 10 : recent.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 12),
                          itemBuilder: (_, i) => ProductCard(product: recent[i], width: 176),
                        ),
                      ),
                    ],
                  ),
                ),
              const SliverToBoxAdapter(child: _NewsSection()),
              const SliverToBoxAdapter(child: SizedBox(height: 28)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoritesProvider.select((l) => l.length));
    final cart = ref.watch(cartProvider.select((l) => l.length));
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 6, 0),
      child: Row(
        children: <Widget>[
          const AppLogo(size: 36, wordmark: true),
          const Spacer(),
          IconButton(
            tooltip: tr('Язык'),
            onPressed: () => showLanguageSheet(context),
            icon: const Icon(Icons.translate),
          ),
          IconButton(
            tooltip: tr('Поиск'),
            onPressed: () => context.push('/search'),
            icon: const Icon(Icons.search),
          ),
          IconButton(
            tooltip: tr('Избранное'),
            onPressed: () => context.go('/favorites'),
            icon: Badge(
              isLabelVisible: favorites > 0,
              label: Text('$favorites'),
              child: const Icon(Icons.favorite_border),
            ),
          ),
          const CurrencyButton(),
          IconButton(
            tooltip: tr('Корзина'),
            onPressed: () => context.go('/cart'),
            icon: Badge(
              isLabelVisible: cart > 0,
              label: Text('$cart'),
              child: const Icon(Icons.shopping_cart_outlined),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: SurfaceCard(
        onTap: () => context.push('/search'),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: const Row(
          children: <Widget>[
            Icon(Icons.search, color: AppColors.primary),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Поиск по артикулу, названию или бренду',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 15, color: AppColors.textHint),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _initials(String name) {
  final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return '?';
  if (words.length > 1) return (words[0][0] + words[1][0]).toUpperCase();
  final w = words[0];
  return (w.length > 1 ? w.substring(0, 2) : w).toUpperCase();
}

class _BrandsRow extends ConsumerWidget {
  const _BrandsRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brands = ref.watch(brandsProvider);
    return SizedBox(
      height: 108,
      child: brands.when(
        loading: () => ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
          itemCount: 6,
          separatorBuilder: (_, __) => const SizedBox(width: 14),
          itemBuilder: (_, __) => const Column(
            children: <Widget>[
              Skeleton(width: 56, height: 56, radius: 28),
              SizedBox(height: 8),
              Skeleton(width: 44, height: 10),
            ],
          ),
        ),
        error: (e, _) => Padding(
          padding: const EdgeInsets.only(top: 18),
          child: InlineError(error: e, onRetry: () => ref.invalidate(brandsProvider)),
        ),
        data: (items) => ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
          itemCount: items.length + 1,
          separatorBuilder: (_, __) => const SizedBox(width: 14),
          itemBuilder: (context, i) {
            if (i == items.length) {
              return _BrandChip(
                label: 'Все',
                child: const Icon(Icons.grid_view_rounded, color: AppColors.primary, size: 22),
                onTap: () => context.go('/catalog'),
              );
            }
            final b = items[i];
            return _BrandChip(
              label: b.shortName,
              child: Text(
                _initials(b.shortName),
                style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary, fontSize: 16),
              ),
              onTap: () => context.push(
                '/products?brandId=${b.id}&title=${Uri.encodeComponent(b.name)}',
              ),
            );
          },
        ),
      ),
    );
  }
}

class _BrandChip extends StatelessWidget {
  const _BrandChip({required this.label, required this.child, required this.onTap});

  final String label;
  final Widget child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: SizedBox(
        width: 64,
        child: Column(
          children: <Widget>[
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border, width: 1.4),
                boxShadow: AppShadows.card,
              ),
              child: child,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Row(
        children: <Widget>[
          _ActionTile(
            icon: Icons.manage_search,
            label: 'Найти\nзапчасть',
            onTap: () => context.push('/search'),
          ),
          const SizedBox(width: 10),
          _ActionTile(
            icon: Icons.grid_view_rounded,
            label: 'Каталог',
            onTap: () => context.go('/catalog'),
          ),
          const SizedBox(width: 10),
          _ActionTile(
            icon: Icons.receipt_long_outlined,
            label: 'Заказы',
            onTap: () => context.push('/orders'),
          ),
          const SizedBox(width: 10),
          _ActionTile(
            icon: Icons.support_agent,
            label: 'Связаться\nс менеджером',
            onTap: () => showManagerSheet(context),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: SurfaceCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Column(
          children: <Widget>[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.accentSoft,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(icon, color: AppColors.accentDark, size: 22),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 30,
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  height: 1.25,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BannersCarousel extends ConsumerStatefulWidget {
  const _BannersCarousel();

  @override
  ConsumerState<_BannersCarousel> createState() => _BannersCarouselState();
}

class _BannersCarouselState extends ConsumerState<_BannersCarousel> {
  final PageController _controller = PageController(viewportFraction: 0.92);
  Timer? _timer;
  int _page = 0;
  int _count = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || _count < 2 || !_controller.hasClients) return;
      final next = (_page + 1) % _count;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  List<Color> _gradient(String color) {
    switch (color) {
      case 'orange':
        return const <Color>[AppColors.accent, AppColors.accentDark];
      case 'teal':
        return const <Color>[Color(0xFF1F2933), Color(0xFF3A4654)];
      default:
        return const <Color>[AppColors.primary, AppColors.primaryLight];
    }
  }

  @override
  Widget build(BuildContext context) {
    final banners = ref.watch(bannersProvider);
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: banners.when(
        loading: () => const BlockSkeleton(height: 150),
        error: (e, _) => InlineError(error: e, onRetry: () => ref.invalidate(bannersProvider)),
        data: (items) {
          _count = items.length;
          if (items.isEmpty) return const SizedBox.shrink();
          return Column(
            children: <Widget>[
              SizedBox(
                height: 150,
                child: PageView.builder(
                  controller: _controller,
                  itemCount: items.length,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemBuilder: (context, i) => _BannerCard(
                    banner: items[i],
                    colors: _gradient(items[i].color),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  for (var i = 0; i < items.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == _page ? 20 : 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: i == _page ? AppColors.accent : AppColors.border,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BannerCard extends StatelessWidget {
  const _BannerCard({required this.banner, required this.colors});

  final PromoBanner banner;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    final light = colors.first.computeLuminance() > 0.4;
    final fg = light ? AppColors.onAccent : Colors.white;
    final fgSoft = light ? const Color(0xCC14181D) : const Color(0xE6FFFFFF);
    final badgeBg = light ? AppColors.primary : AppColors.accent;
    final badgeFg = light ? AppColors.accent : AppColors.onAccent;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        clipBehavior: Clip.antiAlias,
        color: colors.first,
        child: InkWell(
          onTap: () => context.push(banner.action),
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: colors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              children: <Widget>[
                Positioned(
                  right: -14,
                  bottom: -18,
                  child: Icon(
                    Icons.local_shipping_outlined,
                    size: 120,
                    color: light ? const Color(0x2214181D) : const Color(0x26FFFFFF),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      if (banner.badge.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: badgeBg,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            banner.badge,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: badgeFg,
                            ),
                          ),
                        )
                      else
                        const SizedBox(height: 22),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            banner.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: fg,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Padding(
                            padding: const EdgeInsets.only(right: 70),
                            child: Text(
                              banner.subtitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12.5, color: fgSoft, height: 1.3),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoriesGrid extends ConsumerWidget {
  const _CategoriesGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider);
    return categories.when(
      loading: () => const BlockSkeleton(height: 170),
      error: (e, _) => InlineError(error: e, onRetry: () => ref.invalidate(categoriesProvider)),
      data: (all) {
        final roots = all.where((c) => c.isRoot).toList();
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 4,
          childAspectRatio: 0.86,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: <Widget>[
            for (final c in roots)
              SurfaceCard(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                onTap: () => context.push(
                  '/products?categoryId=${c.id}&title=${Uri.encodeComponent(c.name)}',
                ),
                child: Column(
                  children: <Widget>[
                    Icon(CategoryIcons.of(c.id), color: AppColors.primary, size: 26),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Text(
                        c.name,
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10.5,
                          height: 1.2,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ProductSection extends ConsumerWidget {
  const _ProductSection({required this.kind, required this.title, required this.route});

  final String kind;
  final String title;
  final String route;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(homeSectionProvider(kind));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SectionHeader(title: title, onAction: () => context.push(route)),
        products.when(
          loading: () => const HorizontalProductsSkeleton(),
          error: (e, _) => InlineError(error: e, onRetry: () => ref.invalidate(homeSectionProvider(kind))),
          data: (items) {
            if (items.isEmpty) return const SizedBox.shrink();
            return SizedBox(
              height: 312,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, i) => ProductCard(product: items[i], width: 176),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _NewsSection extends ConsumerWidget {
  const _NewsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final news = ref.watch(newsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SectionHeader(title: 'Новости', onAction: () => context.push('/news')),
        news.when(
          loading: () => const BlockSkeleton(height: 90),
          error: (e, _) => InlineError(error: e, onRetry: () => ref.invalidate(newsProvider)),
          data: (items) => Column(
            children: <Widget>[
              for (final n in items.take(3)) NewsTile(item: n),
            ],
          ),
        ),
      ],
    );
  }
}

class NewsTile extends StatelessWidget {
  const NewsTile({super.key, required this.item});

  final NewsItem item;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      onTap: () => context.push('/news/${item.id}'),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(Fmt.date(item.date), style: AppText.caption),
                const SizedBox(height: 4),
                Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.h3),
                const SizedBox(height: 4),
                Text(
                  item.summary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.bodySecondary,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right, color: AppColors.textHint),
        ],
      ),
    );
  }
}
