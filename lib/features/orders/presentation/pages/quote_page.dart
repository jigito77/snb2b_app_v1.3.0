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
import '../../../product/presentation/providers/product_providers.dart';

/// Запрос коммерческого предложения. Позиции: товар из карточки (productId+qty)
/// или содержимое корзины. Можно отправить и без позиций — произвольный запрос.
class QuotePage extends ConsumerStatefulWidget {
  const QuotePage({super.key, this.productId, this.qty = 1});

  final String? productId;
  final int qty;

  @override
  ConsumerState<QuotePage> createState() => _QuotePageState();
}

class _QuotePageState extends ConsumerState<QuotePage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  final _comment = TextEditingController();
  List<CartItem> _items = const <CartItem>[];
  bool _loadingItems = false;
  bool _sending = false;
  bool _sent = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authControllerProvider).user;
    _name = TextEditingController(text: user?.name ?? '');
    _phone = TextEditingController(text: user?.phone ?? '');
    _email = TextEditingController(text: user?.email ?? '');
    if (widget.productId != null) {
      _loadingItems = true;
      _loadProduct(widget.productId!);
    } else {
      _items = List<CartItem>.from(ref.read(cartProvider));
    }
  }

  Future<void> _loadProduct(String id) async {
    try {
      final p = await ref.read(productProvider(id).future);
      if (!mounted) return;
      setState(() {
        _items = <CartItem>[CartItem(product: p, qty: widget.qty < 1 ? 1 : widget.qty)];
        _loadingItems = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingItems = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _comment.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _sending = true);
    try {
      await ref.read(ordersRepositoryProvider).requestQuote(
            items: _items,
            contactName: _name.text.trim(),
            phone: _phone.text.trim(),
            email: _email.text.trim(),
            comment: _comment.text.trim(),
          );
      if (!mounted) return;
      setState(() {
        _sending = false;
        _sent = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      showSnack(context, errorMessage(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_sent) {
      return Scaffold(
        appBar: AppBar(title: const Text('Коммерческое предложение')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const CircleAvatar(
                  radius: 40,
                  backgroundColor: AppColors.successSoft,
                  child: Icon(Icons.check, size: 40, color: AppColors.success),
                ),
                const SizedBox(height: 20),
                const Text('Запрос отправлен', style: AppText.h1),
                const SizedBox(height: 8),
                const Text(
                  'Менеджер подготовит предложение и свяжется с вами.',
                  style: AppText.bodySecondary,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton(onPressed: () => context.go('/home'), child: const Text('На главную')),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Коммерческое предложение')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            const Text(
              'Опишите потребность — менеджер подготовит предложение с оптовыми ценами.',
              style: AppText.bodySecondary,
            ),
            const SizedBox(height: 16),
            if (_loadingItems)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_items.isNotEmpty) ...<Widget>[
              const Text('Позиции', style: AppText.h3),
              const SizedBox(height: 8),
              SurfaceCard(
                child: Column(
                  children: <Widget>[
                    for (var i = 0; i < _items.length; i++) ...<Widget>[
                      if (i > 0) const Divider(height: 18),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(_items[i].product.name, style: AppText.body, maxLines: 2, overflow: TextOverflow.ellipsis),
                                Text('Арт. ${_items[i].product.article}', style: AppText.caption),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(Fmt.pieces(_items[i].qty), style: AppText.body.copyWith(fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: AppInput.of(label: 'Контактное лицо', prefixIcon: const Icon(Icons.person_outline)),
              validator: (v) => (v ?? '').trim().length < 2 ? tr('Введите имя') : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              decoration: AppInput.of(label: 'Телефон', prefixIcon: const Icon(Icons.phone_outlined)),
              validator: (v) {
                final digits = (v ?? '').replaceAll(RegExp(r'[^0-9]'), '');
                return digits.length < 10 ? tr('Введите номер телефона') : null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: AppInput.of(label: 'Email', prefixIcon: const Icon(Icons.mail_outline)),
              validator: (v) {
                final s = (v ?? '').trim();
                if (s.isEmpty) return null;
                return (!s.contains('@') || !s.contains('.')) ? tr('Некорректный email') : null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _comment,
              minLines: 3,
              maxLines: 6,
              decoration: AppInput.of(label: 'Комментарий', hint: 'Объёмы, сроки, аналоги…'),
              validator: (v) {
                if (_items.isEmpty && (v ?? '').trim().isEmpty) {
                  return tr('Опишите, что вам нужно');
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: (_sending || _loadingItems) ? null : _send,
              child: _sending
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.onAccent),
                    )
                  : const Text('Отправить запрос'),
            ),
          ],
        ),
      ),
    );
  }
}
