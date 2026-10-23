import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/currency_provider.dart';
import '../../core/l10n/app_text.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency.dart';

/// Кнопка выбора валюты (₽ / ֏ / $ / €) для AppBar — рядом с корзиной.
class CurrencyButton extends ConsumerWidget {
  const CurrencyButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(currencyProvider);
    return IconButton(
      tooltip: tr('Валюта'),
      onPressed: () => showCurrencySheet(context),
      icon: Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.primary, width: 1.6),
        ),
        child: Text(c.symbol, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, height: 1.1)),
      ),
    );
  }
}

Future<void> showCurrencySheet(BuildContext context) {
  return showModalBottomSheet<void>(context: context, builder: (_) => const _CurrencySheet());
}

class _CurrencySheet extends ConsumerStatefulWidget {
  const _CurrencySheet();

  @override
  ConsumerState<_CurrencySheet> createState() => _CurrencySheetState();
}

class _CurrencySheetState extends ConsumerState<_CurrencySheet> {
  bool _loading = false;
  String? _note;

  String _rateLine() {
    String f(AppCurrency c) {
      final v = 1 / c.perRub;
      return '1 ${c.symbol} = ${v.toStringAsFixed(c.code == 'AMD' ? 4 : 2).replaceAll('.', ',')} ₽';
    }

    return '${f(AppCurrency.usd)}   ${f(AppCurrency.eur)}   ${f(AppCurrency.amd)}';
  }

  String _dateText() {
    final d = DateTime.tryParse(AppCurrency.ratesDate ?? '');
    if (d == null) return 'запасные значения (нет сохранённого курса)';
    final l = d.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return 'ЦБ РФ на ${two(l.day)}.${two(l.month)}.${l.year}';
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _note = null;
    });
    final ok = await ref.read(currencyProvider.notifier).refreshRates();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _note = ok ? 'Курсы обновлены' : 'Нет интернета — используется сохранённый курс';
    });
  }

  @override
  Widget build(BuildContext context) {
    final current = ref.watch(currencyProvider);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 0, 4, 8),
              child: Text('Валюта цен', style: AppText.h2),
            ),
            for (final c in AppCurrency.all)
              ListTile(
                leading: Text(c.symbol, style: AppText.h2),
                title: Text('${c.name} (${c.code})', style: AppText.body),
                trailing: c.code == current.code
                    ? const Icon(Icons.check_circle, color: AppColors.primary)
                    : const Icon(Icons.radio_button_unchecked, color: AppColors.textHint),
                onTap: () async {
                  Navigator.of(context).pop();
                  await ref.read(currencyProvider.notifier).setCurrency(c);
                },
              ),
            const Divider(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text('${_rateLine()}\n${_dateText()}', style: AppText.bodySecondary),
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                TextButton.icon(
                  onPressed: _loading ? null : _refresh,
                  icon: _loading
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.refresh),
                  label: const Text('Обновить курс'),
                ),
                if (_note != null) Expanded(child: Text(_note!, style: AppText.caption)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
