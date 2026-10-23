import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/app_text.dart';
import '../../../../app/di.dart';
import '../../../../app/currency_provider.dart';
import '../../../../app/locale_provider.dart';
import '../../../../core/utils/currency.dart';
import '../../../../shared/widgets/language_sheet.dart';
import '../../../../core/constants/app_config.dart';
import '../../../../core/network/mock/mock_api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/common.dart';
import '../../../notifications/presentation/providers/notifications_providers.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  static const Map<String, List<String>> _labels = <String, List<String>>{
    'orderStatus': <String>['Статусы заказов', 'Принят, отправлен, доставлен'],
    'priceChange': <String>['Изменение цен', 'На товары из избранного'],
    'inStock': <String>['Поступление товара', 'Когда товар снова в наличии'],
    'promo': <String>['Акции и новости', 'Спецпредложения компании'],
  };

  Future<void> _clearCache() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Очистить кэш?'),
        content: const Text('Сохранённые для офлайн-режима данные каталога будут удалены. Корзина и избранное не затрагиваются.'),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Отмена')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Очистить')),
        ],
      ),
    );
    if (ok != true) return;
    final cache = ref.read(localCacheProvider);
    for (final prefix in <String>['catalog', 'product', 'analogs', 'orders', 'addresses', 'manager', 'content', 'news']) {
      await cache.clearPrefix(prefix);
    }
    if (mounted) showSnack(context, 'Кэш очищен');
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(notificationSettingsProvider);
    final langCode = ref.watch(localeProvider).languageCode;
    final currency = ref.watch(currencyProvider);
    final lang = L10n.languages.firstWhere((l) => l.code == langCode, orElse: () => L10n.languages.last);
    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 28),
        children: <Widget>[
          const SectionHeader(title: 'Язык приложения'),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.divider),
            ),
            child: ListTile(
              leading: const Icon(Icons.translate, color: AppColors.primary),
              title: Text('${lang.flag}  ${lang.nativeName}', style: AppText.body),
              trailing: const Icon(Icons.chevron_right, color: AppColors.textHint),
              onTap: () => showLanguageSheet(context),
            ),
          ),
          const SectionHeader(title: 'Валюта цен'),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.divider),
            ),
            child: Column(
              children: <Widget>[
                for (final c in AppCurrency.all)
                  ListTile(
                    leading: Text(c.symbol, style: AppText.h2),
                    title: Text('${c.name} (${c.code})', style: AppText.body),
                    trailing: c.code == currency.code
                        ? const Icon(Icons.check_circle, color: AppColors.primary)
                        : const Icon(Icons.radio_button_unchecked, color: AppColors.textHint),
                    onTap: () => ref.read(currencyProvider.notifier).setCurrency(c),
                  ),
              ],
            ),
          ),
          const SectionHeader(title: 'Уведомления'),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.divider),
            ),
            child: Column(
              children: <Widget>[
                for (final key in NotificationSettingsNotifier.keys)
                  SwitchListTile(
                    title: Text(_labels[key]![0], style: AppText.body),
                    subtitle: Text(_labels[key]![1], style: AppText.caption),
                    value: settings[key] ?? true,
                    activeTrackColor: AppColors.accent,
                    onChanged: (v) => ref.read(notificationSettingsProvider.notifier).set(key, v),
                  ),
              ],
            ),
          ),
          const SectionHeader(title: 'Данные'),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.divider),
            ),
            child: Column(
              children: <Widget>[
                ListTile(
                  leading: const Icon(Icons.cleaning_services_outlined, color: AppColors.primary),
                  title: const Text('Очистить кэш', style: AppText.body),
                  onTap: _clearCache,
                ),
                if (AppConfig.useMockApi) ...<Widget>[
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: const Icon(Icons.cloud_off_outlined, color: AppColors.primary),
                    title: const Text('Имитировать отсутствие сети', style: AppText.body),
                    subtitle: const Text('Только демо-режим: проверка офлайн-кэша', style: AppText.caption),
                    value: MockApiClient.simulateOffline,
                    activeTrackColor: AppColors.accent,
                    onChanged: (v) => setState(() => MockApiClient.simulateOffline = v),
                  ),
                ],
              ],
            ),
          ),
          const SectionHeader(title: 'О приложении'),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.divider),
            ),
            child: Column(
              children: <Widget>[
                const ListTile(
                  leading: Icon(Icons.info_outline, color: AppColors.primary),
                  title: Text('Версия', style: AppText.body),
                  trailing: Text('1.0.0', style: AppText.bodySecondary),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.dns_outlined, color: AppColors.primary),
                  title: const Text('Источник данных', style: AppText.body),
                  trailing: Text(
                    AppConfig.useMockApi ? 'Демо (Mock API)' : 'Сервер',
                    style: AppText.bodySecondary,
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
