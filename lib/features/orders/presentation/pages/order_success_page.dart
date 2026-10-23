import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/app_text.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/common.dart';
import '../../../../shared/widgets/manager_sheet.dart';
import '../../../../app/di.dart';
import '../../../../core/constants/app_config.dart';
import '../../../../core/constants/contacts.dart';
import '../../../../core/utils/launcher.dart';
import '../../domain/order_message.dart';
import '../providers/orders_providers.dart';

class OrderSuccessPage extends ConsumerStatefulWidget {
  const OrderSuccessPage({super.key, required this.number, required this.orderId});

  final String number;
  final String orderId;

  @override
  ConsumerState<OrderSuccessPage> createState() => _OrderSuccessPageState();
}

class _OrderSuccessPageState extends ConsumerState<OrderSuccessPage> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  )..forward();
  bool _invoiceSent = false;
  bool _invoiceLoading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _requestInvoice() async {
    setState(() => _invoiceLoading = true);
    try {
      await ref.read(ordersRepositoryProvider).requestInvoice(widget.orderId);
      if (!mounted) return;
      setState(() {
        _invoiceSent = true;
        _invoiceLoading = false;
      });
      showSnack(context, 'Запрос счёта отправлен менеджеру.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _invoiceLoading = false);
      showSnack(context, errorMessage(e), error: true);
    }
  }

  Future<void> _sendWhatsApp(String number) async {
    final order = await ref.read(orderProvider(widget.orderId).future);
    var text = buildOrderMessage(order);
    if (Uri.encodeComponent(text).length > 1700) {
      // Слишком длинный текст для ссылки: полный список — в буфер обмена.
      await Clipboard.setData(ClipboardData(text: text));
      text = buildOrderMessage(order, maxItems: 5);
      if (mounted) showSnack(context, 'Полный список скопирован — при необходимости вставьте его в чат.');
    }
    final ok = await openWhatsApp(text: text, number: number);
    if (!ok && mounted) showSnack(context, 'Не удалось открыть WhatsApp.', error: true);
  }

  Future<void> _sendTelegram() async {
    final order = await ref.read(orderProvider(widget.orderId).future);
    await Clipboard.setData(ClipboardData(text: buildOrderMessage(order)));
    if (mounted) showSnack(context, 'Текст заказа скопирован — вставьте его в чат и отправьте.');
    final ok = await openTelegram();
    if (!ok && mounted) showSnack(context, 'Не удалось открыть Telegram.', error: true);
  }

  Widget _sendBlock() {
    final ready = ref.watch(orderProvider(widget.orderId)).hasValue;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.successSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Text(
            'Отправьте заказ менеджеру, чтобы он начал обработку:',
            textAlign: TextAlign.center,
            style: AppText.bodySecondary,
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: ready ? () => _sendWhatsApp(Contacts.whatsappRussia) : null,
            icon: const Icon(Icons.chat_rounded),
            label: const Text('WhatsApp — Россия'),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: ready ? () => _sendWhatsApp(Contacts.whatsappArmenia) : null,
            icon: const Icon(Icons.chat_rounded),
            label: const Text('WhatsApp — Армения'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: ready ? _sendTelegram : null,
            icon: const Icon(Icons.send_rounded),
            label: const Text('Telegram'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) context.go('/');
      },
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: <Widget>[
                const Spacer(),
                ScaleTransition(
                  scale: CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
                  child: Container(
                    width: 112,
                    height: 112,
                    decoration: const BoxDecoration(color: AppColors.successSoft, shape: BoxShape.circle),
                    child: const Icon(Icons.check_rounded, size: 64, color: AppColors.success),
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'Заказ №${widget.number} успешно создан',
                  textAlign: TextAlign.center,
                  style: AppText.h1,
                ),
                const SizedBox(height: 10),
                Text(
                  AppConfig.useMockApi
                      ? 'Заказ сохранён в приложении. Отправьте его менеджеру кнопками ниже — '
                          'он подтвердит наличие, цену и срок.'
                      : 'Менеджер свяжется с вами для подтверждения заказа. '
                          'Статус заказа можно отслеживать в разделе «Мои заказы».',
                  textAlign: TextAlign.center,
                  style: AppText.bodySecondary,
                ),
                const Spacer(),
                if (AppConfig.useMockApi) ...<Widget>[
                  _sendBlock(),
                  const SizedBox(height: 14),
                ],
                FilledButton(
                  onPressed: () => context.go('/orders'),
                  child: const Text('Мои заказы'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: (_invoiceSent || _invoiceLoading) ? null : _requestInvoice,
                  icon: _invoiceLoading
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : Icon(_invoiceSent ? Icons.check : Icons.description_outlined),
                  label: Text(_invoiceSent ? 'Счёт запрошен' : 'Запросить счёт'),
                ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: TextButton(
                        onPressed: () => context.go('/catalog'),
                        child: const Text('В каталог'),
                      ),
                    ),
                    Expanded(
                      child: TextButton(
                        onPressed: () => showManagerSheet(context),
                        child: const Text('Связаться с менеджером'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
