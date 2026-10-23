import 'dart:async';

import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/app_text.dart';
import '../../../../app/di.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/common.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../cart/domain/entities/cart_item.dart';
import '../../../cart/presentation/providers/cart_provider.dart';
import '../../../delivery/delivery_map_page.dart';
import '../../../delivery/delivery_models.dart';
import '../../domain/entities/order.dart';
import '../providers/orders_providers.dart';

// Контакты → Доставка (способ + точка на карте + расчёт сервера) → Оплата → Итог.
const List<String> _stepTitles = <String>['Контакты', 'Доставка', 'Оплата', 'Итог'];
const int _lastStep = 3;

class CheckoutPage extends ConsumerStatefulWidget {
  const CheckoutPage({super.key});

  @override
  ConsumerState<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends ConsumerState<CheckoutPage> {
  final GlobalKey<FormState> _contactForm = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _company;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  final TextEditingController _extra = TextEditingController();
  final TextEditingController _comment = TextEditingController();

  int _step = 0;
  String _delivery = 'delivery';
  String _payment = 'invoice';
  bool _submitting = false;
  String? _error;

  GeoPoint? _point;
  DeliveryQuote? _quote;
  bool _quoting = false;
  String? _quoteError;
  int _quoteSeq = 0;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authControllerProvider).user;
    _name = TextEditingController(text: user?.name ?? '');
    _company = TextEditingController(text: user?.company?.name ?? '');
    _phone = TextEditingController(text: user?.phone ?? '');
    _email = TextEditingController(text: user?.email ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _company.dispose();
    _phone.dispose();
    _email.dispose();
    _extra.dispose();
    _comment.dispose();
    super.dispose();
  }

  /// Полный адрес для заказа: адрес с карты + уточнение (подъезд, офис, склад).
  String get _addressText {
    final base = _point?.address.trim() ?? '';
    final extra = _extra.text.trim();
    return <String>[base, extra].where((s) => s.isNotEmpty).join(', ');
  }

  Future<void> _pickPoint() async {
    final picked = await DeliveryMapPage.open(context, initial: _point);
    if (picked == null || !mounted) return;
    setState(() {
      _point = picked;
      _quote = null;
      _quoteError = null;
    });
    await _recalc();
  }

  /// Расстояние, вес и стоимость доставки считает backend (POST /api/delivery/calculate).
  Future<void> _recalc() async {
    final point = _point;
    if (point == null || _delivery == 'pickup') return;
    final seq = ++_quoteSeq;
    setState(() {
      _quoting = true;
      _quoteError = null;
    });
    try {
      // Сначала актуальные цены/вес корзины с сервера.
      await ref.read(cartProvider.notifier).requote();
      final quote = await ref.read(ordersRepositoryProvider).calculateDelivery(point, ref.read(cartProvider));
      if (!mounted || seq != _quoteSeq) return;
      setState(() {
        _quote = quote;
        _quoting = false;
      });
    } catch (e) {
      if (!mounted || seq != _quoteSeq) return;
      setState(() {
        _quote = null;
        _quoting = false;
        _quoteError = errorMessage(e);
      });
    }
  }

  void _selectMethod(String v) {
    setState(() => _delivery = v);
    if (v == 'delivery' && _point != null && _quote == null) unawaited(_recalc());
  }

  void _next() {
    switch (_step) {
      case 0:
        if (!_contactForm.currentState!.validate()) return;
        break;
      case 1:
        if (_delivery != 'pickup') {
          if (_point == null) {
            showSnack(context, 'Выберите точку доставки на карте.', error: true);
            return;
          }
          if (_quote == null) {
            showSnack(
              context,
              _quoting ? 'Идёт расчёт доставки…' : (_quoteError ?? 'Доставка не рассчитана.'),
              error: true,
            );
            if (!_quoting) unawaited(_recalc());
            return;
          }
        }
        break;
    }
    setState(() {
      _error = null;
      _step += 1;
    });
    if (_step == _lastStep && _delivery != 'pickup') unawaited(_recalc());
  }

  Future<void> _submit() async {
    final items = ref.read(cartProvider);
    if (items.isEmpty) {
      showSnack(context, 'Корзина пуста.', error: true);
      context.go('/cart');
      return;
    }
    if (items.hasUnavailable) {
      setState(() => _error = const AppException.outOfStock().message);
      return;
    }
    final account = ref.read(authControllerProvider).user;
    if (account != null && !account.canOrder) {
      // Статус верификации задаёт администратор; заказ может оформить только верифицированный клиент.
      setState(() => _error = account.verificationMessage.isEmpty
          ? 'Оформление заказов доступно после верификации аккаунта.'
          : account.verificationMessage);
      return;
    }
    if (_delivery != 'pickup' && (_point == null || _quote == null)) {
      setState(() => _error = _quoteError ?? 'Доставка не рассчитана. Вернитесь на шаг «Доставка».');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final order = await ref.read(ordersRepositoryProvider).create(
            CheckoutData(
              contactName: _name.text.trim(),
              company: _company.text.trim(),
              phone: _phone.text.trim(),
              email: _email.text.trim(),
              address: _delivery == 'pickup' ? '' : _addressText,
              deliveryMethod: _delivery,
              paymentMethod: _payment,
              comment: _comment.text.trim(),
              lat: _delivery == 'pickup' ? null : _point?.lat,
              lng: _delivery == 'pickup' ? null : _point?.lng,
            ),
            items,
          );
      ref.read(cartProvider.notifier).clear();
      ref.invalidate(ordersProvider);
      if (!mounted) return;
      context.go('/checkout/success?number=${order.number}&id=${order.id}');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = errorMessage(e);
      });
    }
  }

  double _grandTotal(List<CartItem> items) =>
      items.total + (_delivery != 'pickup' && _quote != null ? _quote!.price : 0);

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(cartProvider);
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) setState(() => _step -= 1);
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Оформление заказа')),
        body: Column(
          children: <Widget>[
            _StepHeader(current: _step),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: KeyedSubtree(
                    key: ValueKey<int>(_step),
                    child: _buildStep(items),
                  ),
                ),
              ),
            ),
            Container(
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.divider)),
              ),
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: SafeArea(
                top: false,
                child: Row(
                  children: <Widget>[
                    if (_step > 0) ...<Widget>[
                      SizedBox(
                        width: 112,
                        child: OutlinedButton(
                          onPressed: _submitting ? null : () => setState(() => _step -= 1),
                          child: const Text('Назад'),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: FilledButton(
                        onPressed: _submitting || (_step == _lastStep && _quoting)
                            ? null
                            : (_step < _lastStep ? _next : _submit),
                        child: _submitting
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.onAccent),
                              )
                            : Text(
                                _step < _lastStep
                                    ? 'Далее'
                                    : 'Подтвердить заказ · ${Fmt.price(_grandTotal(items))}',
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(List<CartItem> items) {
    switch (_step) {
      case 0:
        return _ContactStep(
          formKey: _contactForm,
          name: _name,
          company: _company,
          phone: _phone,
          email: _email,
        );
      case 1:
        return _DeliveryStep(
          method: _delivery,
          onMethod: _selectMethod,
          point: _point,
          extra: _extra,
          quote: _quote,
          quoting: _quoting,
          quoteError: _quoteError,
          weightKg: items.weightKg,
          onPick: _pickPoint,
          onRetry: _recalc,
        );
      case 2:
        return _OptionsStep(
          title: 'Способ оплаты',
          options: CheckoutOptions.payment,
          icons: const <String, IconData>{
            'invoice': Icons.description_outlined,
            'card': Icons.credit_card_outlined,
            'cash': Icons.payments_outlined,
          },
          selected: _payment,
          onSelect: (v) => setState(() => _payment = v),
        );
      default:
        return _ConfirmStep(
          items: items,
          contact: '${_name.text.trim()}\n${_phone.text.trim()} · ${_email.text.trim()}'
              '${_company.text.trim().isEmpty ? '' : '\n${_company.text.trim()}'}',
          delivery: CheckoutOptions.deliveryTitle(_delivery),
          isPickup: _delivery == 'pickup',
          address: _delivery == 'pickup' ? 'Самовывоз, адрес согласует менеджер' : _addressText,
          quote: _delivery == 'pickup' ? null : _quote,
          quoting: _quoting,
          grandTotal: _grandTotal(items),
          payment: CheckoutOptions.paymentTitle(_payment),
          commentController: _comment,
          error: _error ?? (_delivery != 'pickup' ? _quoteError : null),
        );
    }
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.current});

  final int current;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
      child: Row(
        children: <Widget>[
          for (var i = 0; i < _stepTitles.length; i++) ...<Widget>[
            Expanded(
              child: Column(
                children: <Widget>[
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i <= current ? AppColors.accent : AppColors.surfaceAlt,
                    ),
                    child: i < current
                        ? const Icon(Icons.check, size: 18, color: AppColors.onAccent)
                        : Text(
                            '${i + 1}',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: i == current ? AppColors.onAccent : AppColors.textSecondary,
                            ),
                          ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _stepTitles[i],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: i == current ? FontWeight.w700 : FontWeight.w500,
                      color: i == current ? AppColors.textPrimary : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ContactStep extends StatelessWidget {
  const _ContactStep({
    required this.formKey,
    required this.name,
    required this.company,
    required this.phone,
    required this.email,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController name;
  final TextEditingController company;
  final TextEditingController phone;
  final TextEditingController email;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('Контактные данные', style: AppText.h2),
          const SizedBox(height: 4),
          const Text('Менеджер свяжется с вами для подтверждения заказа.', style: AppText.bodySecondary),
          const SizedBox(height: 18),
          TextFormField(
            controller: name,
            textCapitalization: TextCapitalization.words,
            decoration: AppInput.of(label: 'Контактное лицо', prefixIcon: const Icon(Icons.person_outline)),
            validator: (v) => (v == null || v.trim().isEmpty) ? tr('Укажите имя') : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: company,
            decoration: AppInput.of(label: 'Компания', prefixIcon: const Icon(Icons.business_outlined)),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: phone,
            keyboardType: TextInputType.phone,
            decoration: AppInput.of(label: 'Телефон', prefixIcon: const Icon(Icons.phone_outlined)),
            validator: (v) {
              final digits = (v ?? '').replaceAll(RegExp(r'[^0-9]'), '');
              return digits.length < 6 ? tr('Укажите номер телефона') : null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: email,
            keyboardType: TextInputType.emailAddress,
            decoration: AppInput.of(label: 'Email', prefixIcon: const Icon(Icons.mail_outline)),
            validator: (v) {
              final value = (v ?? '').trim();
              return (value.isEmpty || !value.contains('@')) ? tr('Укажите корректный email') : null;
            },
          ),
        ],
      ),
    );
  }
}

class _DeliveryStep extends StatelessWidget {
  const _DeliveryStep({
    required this.method,
    required this.onMethod,
    required this.point,
    required this.extra,
    required this.quote,
    required this.quoting,
    required this.quoteError,
    required this.weightKg,
    required this.onPick,
    required this.onRetry,
  });

  final String method;
  final ValueChanged<String> onMethod;
  final GeoPoint? point;
  final TextEditingController extra;
  final DeliveryQuote? quote;
  final bool quoting;
  final String? quoteError;
  final double? weightKg;
  final VoidCallback onPick;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final q = quote;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text('Способ доставки', style: AppText.h2),
        const SizedBox(height: 16),
        for (final o in CheckoutOptions.delivery)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _SelectableCard(
              selected: method == o.id,
              onTap: () => onMethod(o.id),
              child: Row(
                children: <Widget>[
                  Icon(
                    o.id == 'pickup' ? Icons.store_outlined : Icons.local_shipping_outlined,
                    color: AppColors.primary,
                    size: 28,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(o.title, style: AppText.h3),
                        const SizedBox(height: 2),
                        Text(o.subtitle, style: AppText.bodySecondary),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (method != 'pickup') ...<Widget>[
          const SizedBox(height: 8),
          const Text('Адрес доставки', style: AppText.h3),
          const SizedBox(height: 8),
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (point == null)
                  const Text('Точка на карте не выбрана.', style: AppText.bodySecondary)
                else ...<Widget>[
                  Text(point!.address.isEmpty ? 'Адрес не определён' : point!.address, style: AppText.body),
                  Text(
                    '${point!.lat.toStringAsFixed(5)}, ${point!.lng.toStringAsFixed(5)}',
                    style: AppText.caption,
                  ),
                ],
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: onPick,
                  icon: const Icon(Icons.map_outlined),
                  label: Text(point == null ? 'Выбрать на карте' : 'Изменить точку'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: extra,
            decoration: AppInput.of(
              label: 'Уточнение адреса',
              hint: 'Подъезд, офис, склад, ориентир',
              prefixIcon: const Icon(Icons.home_work_outlined),
            ),
          ),
          const SizedBox(height: 16),
          if (point != null)
            SurfaceCard(
              child: quoting
                  ? const Row(
                      children: <Widget>[
                        SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                        SizedBox(width: 12),
                        Text('Считаем доставку на сервере…', style: AppText.body),
                      ],
                    )
                  : (q != null
                      ? Column(
                          children: <Widget>[
                            KeyValueRow(label: 'Расстояние', value: '${Fmt.kg(q.distanceKm)} км'),
                            KeyValueRow(label: 'Вес товаров', value: '${Fmt.kg(q.weightKg)} кг'),
                            KeyValueRow(
                              label: 'Тариф',
                              value: '${Fmt.price(q.ratePer1000KmPerKg, currency: q.rateCurrency)} / кг / 1000 км',
                            ),
                            const Divider(height: 16),
                            Row(
                              children: <Widget>[
                                const Text('Доставка', style: AppText.h3),
                                const Spacer(),
                                Text(Fmt.price(q.price, currency: q.priceCurrency), style: AppText.price),
                              ],
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(quoteError ?? 'Доставка не рассчитана.', style: AppText.body),
                            const SizedBox(height: 8),
                            OutlinedButton(onPressed: onRetry, child: const Text('Повторить расчёт')),
                          ],
                        )),
            ),
        ],
      ],
    );
  }
}

class _OptionsStep extends StatelessWidget {
  const _OptionsStep({
    required this.title,
    required this.options,
    required this.icons,
    required this.selected,
    required this.onSelect,
  });

  final String title;
  final List<ChoiceOption> options;
  final Map<String, IconData> icons;
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: AppText.h2),
        const SizedBox(height: 16),
        for (final o in options)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _SelectableCard(
              selected: selected == o.id,
              onTap: () => onSelect(o.id),
              child: Row(
                children: <Widget>[
                  Icon(icons[o.id] ?? Icons.check_circle_outline, color: AppColors.primary, size: 28),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(o.title, style: AppText.h3),
                        const SizedBox(height: 2),
                        Text(o.subtitle, style: AppText.bodySecondary),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _SelectableCard extends StatelessWidget {
  const _SelectableCard({required this.selected, required this.onTap, required this.child});

  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.lg);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: selected ? AppColors.accentSoft : AppColors.surface,
        borderRadius: radius,
        border: Border.all(color: selected ? AppColors.accent : AppColors.border, width: selected ? 1.8 : 1.2),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: <Widget>[
                Expanded(child: child),
                const SizedBox(width: 8),
                Icon(
                  selected ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: selected ? AppColors.accent : AppColors.textHint,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ConfirmStep extends StatelessWidget {
  const _ConfirmStep({
    required this.items,
    required this.contact,
    required this.delivery,
    required this.isPickup,
    required this.address,
    required this.quote,
    required this.quoting,
    required this.grandTotal,
    required this.payment,
    required this.commentController,
    required this.error,
  });

  final List<CartItem> items;
  final String contact;
  final String delivery;
  final bool isPickup;
  final String address;
  final DeliveryQuote? quote;
  final bool quoting;
  final double grandTotal;
  final String payment;
  final TextEditingController commentController;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final q = quote;
    final weight = items.weightKg;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text('Подтверждение заказа', style: AppText.h2),
        const SizedBox(height: 16),
        SurfaceCard(
          child: Column(
            children: <Widget>[
              for (final item in items)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(item.product.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.body),
                            Text(
                              '${item.offer.isEmpty ? '' : '${item.offer} · '}${Fmt.pieces(item.qty)} × ${Fmt.price(item.unitPrice)}'
                              '${item.priceLevel.isEmpty ? '' : ' · ${item.priceLevel}'}',
                              style: AppText.caption,
                            ),
                            if (item.weightKg != null)
                              Text('Вес: ${Fmt.kg(item.weightKg)} кг', style: AppText.caption),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(Fmt.price(item.total), style: AppText.body.copyWith(fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              const Divider(height: 24),
              KeyValueRow(label: 'Товары', value: Fmt.price(items.total)),
              if (weight != null) KeyValueRow(label: 'Вес товаров', value: '${Fmt.kg(weight)} кг'),
              if (!isPickup && q != null) ...<Widget>[
                KeyValueRow(label: 'Расстояние', value: '${Fmt.kg(q.distanceKm)} км'),
                KeyValueRow(label: 'Доставка', value: Fmt.price(q.price, currency: q.priceCurrency)),
              ],
              if (!isPickup && q == null && quoting)
                const KeyValueRow(label: 'Доставка', value: 'считаем…'),
              const Divider(height: 24),
              Row(
                children: <Widget>[
                  const Text('Итого', style: AppText.h3),
                  const Spacer(),
                  Text(Fmt.price(grandTotal), style: AppText.h1),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Окончательную сумму фиксирует сервер при оформлении.',
                style: AppText.caption,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SurfaceCard(
          child: Column(
            children: <Widget>[
              KeyValueRow(label: 'Контакты', value: contact),
              const Divider(height: 1),
              KeyValueRow(label: 'Доставка', value: delivery),
              KeyValueRow(label: 'Адрес', value: address.isEmpty ? '—' : address),
              const Divider(height: 1),
              KeyValueRow(label: 'Оплата', value: payment),
            ],
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: commentController,
          minLines: 2,
          maxLines: 4,
          decoration: AppInput.of(label: 'Комментарий к заказу', hint: 'Необязательно'),
        ),
        if (error != null) ...<Widget>[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.dangerSoft, borderRadius: BorderRadius.circular(AppRadius.md)),
            child: Row(
              children: <Widget>[
                const Icon(Icons.error_outline, color: AppColors.danger),
                const SizedBox(width: 10),
                Expanded(child: Text(error!, style: AppText.body)),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
