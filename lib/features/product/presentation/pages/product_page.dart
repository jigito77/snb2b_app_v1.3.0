import 'dart:async';

import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/currency_button.dart';
import '../../../../core/l10n/app_text.dart';
import '../../../../app/di.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/utils/launcher.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/state/product_collections.dart';
import '../../../../shared/widgets/common.dart';
import '../../../../shared/widgets/manager_sheet.dart';
import '../../../../shared/widgets/product_card.dart';
import '../../../../shared/widgets/product_image.dart';
import '../../../../shared/widgets/quantity_selector.dart';
import '../../../../shared/widgets/skeleton.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../cart/domain/entities/cart_item.dart';
import '../../../cart/presentation/providers/cart_provider.dart';
import '../../domain/entities/product.dart';
import '../providers/product_providers.dart';

class ProductPage extends ConsumerWidget {
  const ProductPage({super.key, required this.productId});

  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(productProvider(productId));
    return async.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Карточка товара')),
        body: const _ProductSkeleton(),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Карточка товара')),
        body: ErrorState(error: e, onRetry: () => ref.invalidate(productProvider(productId))),
      ),
      data: (product) => _ProductView(key: ValueKey<String>(product.id), product: product),
    );
  }
}

class _ProductSkeleton extends StatelessWidget {
  const _ProductSkeleton();

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      physics: NeverScrollableScrollPhysics(),
      child: Column(
        children: <Widget>[
          AspectRatio(aspectRatio: 1.2, child: Skeleton(height: double.infinity, radius: 0)),
          SizedBox(height: 16),
          BlockSkeleton(height: 110),
          SizedBox(height: 12),
          BlockSkeleton(height: 140),
          SizedBox(height: 12),
          BlockSkeleton(height: 90),
        ],
      ),
    );
  }
}

class _ProductView extends ConsumerStatefulWidget {
  const _ProductView({super.key, required this.product});

  final Product product;

  @override
  ConsumerState<_ProductView> createState() => _ProductViewState();
}

class _ProductViewState extends ConsumerState<_ProductView> {
  // Ступени опта на сервере: 1–9 розница, 10–49 MALI OPT, 50–99 OPT, от 100 KRUPNI OPT.
  static const List<int> _tierQtys = <int>[1, 10, 50, 100];

  late String _offer = widget.product.offerOf(null)?.type ?? '';
  late int _qty = widget.product.offerOf(null)?.minQty ?? widget.product.effectiveMinQty;
  CartLine? _line;
  Map<int, CartLine> _tiers = const <int, CartLine>{};
  Timer? _quoteTimer;

  bool get _hasOffers => widget.product.offers.isNotEmpty;
  ProductOffer? get _selected => widget.product.offerOf(_offer);
  int get _minQty => _selected?.minQty ?? widget.product.effectiveMinQty;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(recentlyViewedProvider.notifier).viewed(widget.product);
    });
    _scheduleQuote(immediate: true);
  }

  @override
  void dispose() {
    _quoteTimer?.cancel();
    super.dispose();
  }

  void _scheduleQuote({bool immediate = false}) {
    if (!_hasOffers) return;
    _quoteTimer?.cancel();
    _quoteTimer = Timer(Duration(milliseconds: immediate ? 0 : 300), _quote);
  }

  /// Цена за выбранное количество и ступени опта приходят с сервера (POST /api/prices).
  Future<void> _quote() async {
    final offer = _offer;
    final qty = _qty;
    final p = widget.product;
    try {
      final asked = <int>[..._tierQtys, qty];
      final lines = await ref
          .read(cartRepositoryProvider)
          .quote(<CartItem>[for (final q in asked) CartItem(product: p, qty: q, offer: offer)]);
      if (!mounted || offer != _offer) return;
      setState(() {
        _tiers = <int, CartLine>{
          for (var i = 0; i < _tierQtys.length; i++)
            if (lines[i] != null) _tierQtys[i]: lines[i]!,
        };
        _line = qty == _qty ? lines.last : _line;
      });
    } catch (_) {
      // офлайн: остаётся цена предложения из карточки
    }
  }

  void _selectOffer(String type) {
    if (type == _offer) return;
    final min = widget.product.offerOf(type)?.minQty ?? 1;
    setState(() {
      _offer = type;
      _line = null;
      _tiers = const <int, CartLine>{};
      if (_qty < min) _qty = min;
    });
    _scheduleQuote(immediate: true);
  }

  void _setQty(int v) {
    setState(() => _qty = v);
    _scheduleQuote();
  }

  /// Цена за штуку / сумма для выбранного количества (расчёт сервера, пока его нет — цена предложения).
  CartLine? get _freshLine => (_line != null && _line!.qty == _qty) ? _line : null;
  double get _unit => _freshLine?.unitPrice ?? _selected?.price ?? widget.product.unitPrice(_qty);
  double get _sum => _freshLine?.subtotal ?? _unit * _qty;

  void _addToCart() {
    final error = ref.read(cartProvider.notifier).add(widget.product, qty: _qty, offer: _hasOffers ? _offer : null);
    showSnack(
      context,
      error ?? 'Добавлено в корзину: $_qty шт.',
      error: error != null,
      action: error == null
          ? SnackBarAction(label: tr('Корзина'), textColor: AppColors.accent, onPressed: () => context.go('/cart'))
          : null,
    );
  }

  void _toggleCompare() {
    final notifier = ref.read(comparisonProvider.notifier);
    final inCompare = notifier.contains(widget.product.id);
    if (!inCompare && notifier.isFull) {
      showSnack(context, 'В сравнении может быть не более 4 товаров.', error: true);
      return;
    }
    notifier.toggle(widget.product);
    showSnack(
      context,
      inCompare ? 'Убрано из сравнения' : 'Добавлено к сравнению',
      action: inCompare
          ? null
          : SnackBarAction(label: tr('Открыть'), textColor: AppColors.accent, onPressed: () => context.push('/compare')),
    );
  }

  void _copy(String value) {
    Clipboard.setData(ClipboardData(text: value));
    showSnack(context, 'Скопировано: $value');
  }

  Future<void> _quickBuy() async {
    final sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _QuickBuySheet(product: widget.product, qty: _qty),
    );
    if (sent == true && mounted) {
      showSnack(context, 'Заявка отправлена. Менеджер свяжется с вами.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final compareCount = ref.watch(comparisonProvider.select((l) => l.length));
    final inCompare = ref.watch(comparisonProvider.select((l) => l.any((e) => e.id == p.id)));
    final isFavorite = ref.watch(favoritesProvider.select((l) => l.any((e) => e.id == p.id)));
    final cartCount = ref.watch(cartProvider.select((l) => l.length));
    final min = _hasOffers ? _minQty : p.effectiveMinQty;
    final max = p.canOrder ? p.maxQty : min;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Карточка товара'),
        actions: <Widget>[
          IconButton(
            tooltip: tr('Сравнение'),
            onPressed: () => context.push('/compare'),
            icon: Badge(
              isLabelVisible: compareCount > 0,
              label: Text('$compareCount'),
              child: const Icon(Icons.compare_arrows),
            ),
          ),
          const CurrencyButton(),
          IconButton(
            tooltip: tr('Корзина'),
            onPressed: () => context.go('/cart'),
            icon: Badge(
              isLabelVisible: cartCount > 0,
              label: Text('$cartCount'),
              child: const Icon(Icons.shopping_cart_outlined),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: <Widget>[
          _Gallery(product: p),
          const SizedBox(height: 12),
          SurfaceCard(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    InfoPill(
                      text: p.brandName,
                      background: AppColors.surfaceAlt,
                      foreground: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    if (p.manufacturer.isNotEmpty && p.manufacturer != p.brandName)
                      Flexible(
                        child: Text(
                          'Производитель: ${p.manufacturer}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.caption,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(p.name, style: AppText.h1),
                const SizedBox(height: 12),
                _CopyRow(label: 'Артикул', value: p.article, onCopy: () => _copy(p.article)),
                _CopyRow(label: 'OEM номер', value: p.oem, onCopy: () => _copy(p.oem)),
                KeyValueRow(label: 'Категория', value: p.categoryName),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SurfaceCard(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (_hasOffers) ...<Widget>[
                  _OfferSelector(product: p, selected: _offer, onSelect: _selectOffer),
                  const SizedBox(height: 14),
                  _ServerPrice(
                    unit: _unit,
                    sum: _sum,
                    qty: _qty,
                    level: _freshLine?.priceLevel ?? '',
                    retail: _freshLine?.retailPrice ?? _selected?.retailPrice,
                    weightUnit: _freshLine?.unitWeightKg ?? _selected?.weightKg ?? p.weightKg,
                    weightTotal: _freshLine?.weightKg,
                  ),
                  if (_selected != null && _selected!.minQty > 1) ...<Widget>[
                    const SizedBox(height: 6),
                    Text('Минимальное количество для заказа: ${Fmt.pieces(_selected!.minQty)}', style: AppText.caption),
                  ],
                  if (_tiers.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 14),
                    const Text('Оптовые цены', style: AppText.h3),
                    const SizedBox(height: 6),
                    _ServerTiers(tiers: _tiers, qty: _qty),
                  ],
                ] else ...<Widget>[
                PriceView(product: p, qty: _qty, large: true, showKind: true),
                if (p.minQty > 1) ...<Widget>[
                  const SizedBox(height: 6),
                  Text('Минимальное количество для заказа: ${Fmt.pieces(p.minQty)}', style: AppText.caption),
                ],
                ],
                if (!_hasOffers && p.tiers.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 14),
                  const Text('Оптовые цены', style: AppText.h3),
                  const SizedBox(height: 6),
                  _TiersTable(product: p, qty: _qty),
                ],
                const Divider(height: 28),
                Row(
                  children: <Widget>[
                    StockBadge(product: p, showQty: true),
                    const Spacer(),
                    if (p.stock.warehouse.isNotEmpty)
                      Text('Склад: ${p.stock.warehouse}', style: AppText.caption),
                  ],
                ),
                KeyValueRow(
                  label: p.inStock ? 'Срок поставки' : 'Под заказ, срок',
                  value: p.deliveryLabel,
                ),
                if (!p.canOrder)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.dangerSoft,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: const Row(
                      children: <Widget>[
                        Icon(Icons.info_outline, color: AppColors.danger, size: 20),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text('Товар временно отсутствует.', style: AppText.body),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: <Widget>[
                OutlinedButton.icon(
                  onPressed: p.canOrder ? _quickBuy : null,
                  icon: const Icon(Icons.bolt_outlined),
                  label: const Text('Купить в 1 клик'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => openWhatsApp(text: '${p.name} (${p.article})'),
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text('Спросить в WhatsApp'),
                ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          ref.read(favoritesProvider.notifier).toggle(p);
                          showSnack(context, isFavorite ? 'Убрано из избранного' : 'Добавлено в избранное');
                        },
                        icon: Icon(
                          isFavorite ? Icons.favorite : Icons.favorite_border,
                          color: isFavorite ? AppColors.danger : AppColors.primary,
                        ),
                        label: const Text('Избранное'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _toggleCompare,
                        icon: Icon(
                          Icons.compare_arrows,
                          color: inCompare ? AppColors.accentDark : AppColors.primary,
                        ),
                        label: Text(inCompare ? 'В сравнении' : 'Сравнить'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (p.description.isNotEmpty) ...<Widget>[
            const SectionHeader(title: 'Описание'),
            SurfaceCard(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(p.description, style: AppText.body),
            ),
          ],
          if (p.attributes.isNotEmpty) ...<Widget>[
            const SectionHeader(title: 'Характеристики'),
            SurfaceCard(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: <Widget>[
                  for (var i = 0; i < p.attributes.length; i++) ...<Widget>[
                    if (i > 0) const Divider(height: 1),
                    KeyValueRow(label: p.attributes[i].name, value: p.attributes[i].value),
                  ],
                ],
              ),
            ),
          ],
          if (p.compatibility.isNotEmpty) ...<Widget>[
            const SectionHeader(title: 'Совместимость'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  for (final c in p.compatibility)
                    InfoPill(
                      text: c,
                      background: AppColors.surface,
                      foreground: AppColors.textPrimary,
                      icon: Icons.check_circle_outline,
                    ),
                ],
              ),
            ),
          ],
          _Analogs(productId: p.id),
          const SizedBox(height: 16),
          SurfaceCard(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: EdgeInsets.zero,
            child: Column(
              children: <Widget>[
                ListTile(
                  leading: const Icon(Icons.request_quote_outlined, color: AppColors.primary),
                  title: const Text('Запросить коммерческое предложение'),
                  trailing: const Icon(Icons.chevron_right, color: AppColors.textHint),
                  onTap: () => context.push('/quote?productId=${p.id}&qty=$_qty'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.support_agent, color: AppColors.primary),
                  title: const Text('Связаться с менеджером'),
                  trailing: const Icon(Icons.chevron_right, color: AppColors.textHint),
                  onTap: () => showManagerSheet(context),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.divider)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: SafeArea(
          top: false,
          child: Row(
            children: <Widget>[
              QuantitySelector(
                value: _qty < min ? min : _qty,
                min: min,
                max: max < min ? min : max,
                onChanged: p.canOrder ? _setQty : (_) {},
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: p.canOrder ? _addToCart : null,
                  child: Text(
                    p.canOrder ? 'В корзину · ${Fmt.price(_hasOffers ? _sum : p.unitPrice(_qty) * _qty)}' : 'Нет в наличии',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CopyRow extends StatelessWidget {
  const _CopyRow({required this.label, required this.value, required this.onCopy});

  final String label;
  final String value;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: <Widget>[
          Expanded(flex: 4, child: Text(label, style: AppText.bodySecondary)),
          Expanded(
            flex: 5,
            child: InkWell(
              onTap: onCopy,
              borderRadius: BorderRadius.circular(6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  Flexible(
                    child: Text(
                      value,
                      textAlign: TextAlign.right,
                      style: AppText.body.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.copy_rounded, size: 16, color: AppColors.textHint),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TiersTable extends StatelessWidget {
  const _TiersTable({required this.product, required this.qty});

  final Product product;
  final int qty;

  @override
  Widget build(BuildContext context) {
    final base = product.hasPersonalPrice ? product.personalPrice! : product.price;
    final rows = <PriceTier>[PriceTier(minQty: 1, price: base), ...product.tiers];
    var activeIndex = 0;
    for (var i = 0; i < rows.length; i++) {
      if (qty >= rows[i].minQty) activeIndex = i;
    }
    return Column(
      children: <Widget>[
        for (var i = 0; i < rows.length; i++)
          Container(
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: i == activeIndex ? AppColors.successSoft : AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    i == 0 ? '1 шт.' : 'от ${rows[i].minQty} шт.',
                    style: AppText.body,
                  ),
                ),
                Text(
                  Fmt.price(rows[i].price),
                  style: AppText.body.copyWith(
                    fontWeight: FontWeight.w700,
                    color: i == activeIndex ? AppColors.success : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Gallery extends StatefulWidget {
  const _Gallery({required this.product});

  final Product product;

  @override
  State<_Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<_Gallery> {
  final PageController _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final images = p.images;
    final count = images.isEmpty ? 1 : images.length;
    return Container(
      color: AppColors.surface,
      child: Column(
        children: <Widget>[
          AspectRatio(
            aspectRatio: 1.2,
            child: Stack(
              children: <Widget>[
                PageView.builder(
                  controller: _controller,
                  itemCount: count,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemBuilder: (context, i) => GestureDetector(
                    onTap: images.isEmpty
                        ? null
                        : () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                fullscreenDialog: true,
                                builder: (_) => _ImageViewer(product: p, initialPage: i),
                              ),
                            ),
                    child: ProductImage(
                      categoryId: p.categoryId,
                      url: images.isEmpty ? null : images[i],
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                Positioned(
                  left: 12,
                  top: 12,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      if (p.isSpecial)
                        const InfoPill(
                          text: 'Акция',
                          background: AppColors.accentSoft,
                          foreground: AppColors.accentDark,
                        ),
                      if (p.isSpecial && p.isNew) const SizedBox(height: 4),
                      if (p.isNew) const InfoPill(text: 'Новинка'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (count > 1)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  for (var i = 0; i < count; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == _page ? 18 : 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: i == _page ? AppColors.accent : AppColors.border,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ImageViewer extends StatelessWidget {
  const _ImageViewer({required this.product, required this.initialPage});

  final Product product;
  final int initialPage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(product.article, style: const TextStyle(color: Colors.white, fontSize: 16)),
      ),
      body: PageView.builder(
        controller: PageController(initialPage: initialPage),
        itemCount: product.images.length,
        itemBuilder: (context, i) => InteractiveViewer(
          minScale: 1,
          maxScale: 4,
          child: Center(
            child: ProductImage(
              categoryId: product.categoryId,
              url: product.images[i],
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}

class _Analogs extends ConsumerWidget {
  const _Analogs({required this.productId});

  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analogs = ref.watch(analogsProvider(productId));
    return analogs.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => const SizedBox.shrink(),
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const SectionHeader(title: 'Аналоги'),
            SizedBox(
              height: 312,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, i) => ProductCard(product: items[i], width: 176),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// «Купить в 1 клик»: короткая заявка менеджеру без оформления корзины.
class _QuickBuySheet extends ConsumerStatefulWidget {
  const _QuickBuySheet({required this.product, required this.qty});

  final Product product;
  final int qty;

  @override
  ConsumerState<_QuickBuySheet> createState() => _QuickBuySheetState();
}

class _QuickBuySheetState extends ConsumerState<_QuickBuySheet> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authControllerProvider).user;
    _name = TextEditingController(text: user?.name ?? '');
    _phone = TextEditingController(text: user?.phone ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await ref.read(ordersRepositoryProvider).quickOrder(
            productId: widget.product.id,
            qty: widget.qty,
            name: _name.text.trim(),
            phone: _phone.text.trim(),
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _sending = false;
          _error = errorMessage(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final total = p.unitPrice(widget.qty) * widget.qty;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 4, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('Купить в 1 клик', style: AppText.h2),
            const SizedBox(height: 6),
            Text(
              '${p.name}\n${Fmt.pieces(widget.qty)} · ${Fmt.price(total)}',
              style: AppText.bodySecondary,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: AppInput.of(label: 'Имя', prefixIcon: const Icon(Icons.person_outline)),
              validator: (v) => (v == null || v.trim().isEmpty) ? tr('Укажите имя') : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: AppInput.of(label: 'Телефон', prefixIcon: const Icon(Icons.phone_outlined)),
              validator: (v) {
                final digits = (v ?? '').replaceAll(RegExp(r'[^0-9]'), '');
                return digits.length < 6 ? tr('Укажите номер телефона') : null;
              },
            ),
            if (_error != null) ...<Widget>[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: AppColors.danger)),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _sending ? null : _submit,
              child: _sending
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.onAccent),
                    )
                  : const Text('Отправить заявку'),
            ),
          ],
        ),
      ),
    );
  }
}


/// Переключатель предложений ORG / OEM / SNP: у каждого своя цена, производитель и вес.
class _OfferSelector extends StatelessWidget {
  const _OfferSelector({required this.product, required this.selected, required this.onSelect});

  final Product product;
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final current = product.offerOf(selected);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text('Вариант товара', style: AppText.h3),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            for (final o in product.offers)
              ChoiceChip(
                label: Text('${o.type} · ${Fmt.price(o.price)}'),
                selected: o.type == selected,
                onSelected: (_) => onSelect(o.type),
                selectedColor: AppColors.accent,
              ),
          ],
        ),
        if (current != null) ...<Widget>[
          const SizedBox(height: 8),
          if (current.manufacturer.isNotEmpty) KeyValueRow(label: 'Производитель', value: current.manufacturer),
          if (current.partNumber.isNotEmpty) KeyValueRow(label: 'Артикул', value: current.partNumber),
          if (current.oem.isNotEmpty) KeyValueRow(label: 'OEM номер', value: current.oem),
          if (current.warranty.isNotEmpty) KeyValueRow(label: 'Гарантия', value: current.warranty),
          if (current.description.isNotEmpty) Text(current.description, style: AppText.bodySecondary),
        ],
      ],
    );
  }
}

class _ServerPrice extends StatelessWidget {
  const _ServerPrice({
    required this.unit,
    required this.sum,
    required this.qty,
    required this.level,
    required this.retail,
    required this.weightUnit,
    required this.weightTotal,
  });

  final double unit;
  final double sum;
  final int qty;
  final String level;
  final double? retail;
  final double? weightUnit;
  final double? weightTotal;

  @override
  Widget build(BuildContext context) {
    final totalWeight = weightTotal ?? (weightUnit == null ? null : weightUnit! * qty);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (level.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              level,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.success),
            ),
          ),
        Text(Fmt.price(unit), style: AppText.price.copyWith(fontSize: 26)),
        if (retail != null && retail! > unit)
          Text(
            Fmt.price(retail!),
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textHint,
              decoration: TextDecoration.lineThrough,
            ),
          ),
        if (qty > 1) Text('${Fmt.pieces(qty)}: ${Fmt.price(sum)}', style: AppText.bodySecondary),
        if (weightUnit != null)
          Text(
            'Вес: ${Fmt.kg(weightUnit)} кг/шт.${totalWeight != null && qty > 1 ? ' · всего ${Fmt.kg(totalWeight)} кг' : ''}',
            style: AppText.bodySecondary,
          ),
      ],
    );
  }
}

class _ServerTiers extends StatelessWidget {
  const _ServerTiers({required this.tiers, required this.qty});

  final Map<int, CartLine> tiers;
  final int qty;

  @override
  Widget build(BuildContext context) {
    final keys = tiers.keys.toList()..sort();
    var active = keys.isEmpty ? 0 : keys.first;
    for (final k in keys) {
      if (qty >= k) active = k;
    }
    return Column(
      children: <Widget>[
        for (final k in keys)
          Container(
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: k == active ? AppColors.successSoft : AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    '${k == 1 ? '1–9 шт.' : (k == 10 ? '10–49 шт.' : (k == 50 ? '50–99 шт.' : 'от 100 шт.'))}'
                    '${tiers[k]!.priceLevel.isEmpty ? '' : ' · ${tiers[k]!.priceLevel}'}',
                    style: AppText.body,
                  ),
                ),
                Text(
                  Fmt.price(tiers[k]!.unitPrice),
                  style: AppText.body.copyWith(
                    fontWeight: FontWeight.w700,
                    color: k == active ? AppColors.success : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
