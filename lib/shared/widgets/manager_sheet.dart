import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_text.dart';
import '../../core/constants/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/launcher.dart';
import '../../features/orders/presentation/providers/orders_providers.dart';
import 'common.dart';
import 'contact_channels.dart';
import 'state_views.dart';

/// «Связаться с менеджером»: звонок, письмо, запрос коммерческого предложения.
Future<void> showManagerSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _ManagerSheet(),
  );
}

class _ManagerSheet extends ConsumerWidget {
  const _ManagerSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final manager = ref.watch(managerProvider);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('Связаться с менеджером', style: AppText.h2),
            const SizedBox(height: 16),
            manager.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => InlineError(error: e, onRetry: () => ref.invalidate(managerProvider)),
              data: (m) {
                final phone = m.phone.isNotEmpty ? m.phone : AppConfig.supportPhone;
                final email = m.email.isNotEmpty ? m.email : AppConfig.supportEmail;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        const CircleAvatar(
                          radius: 26,
                          backgroundColor: AppColors.surfaceAlt,
                          child: Icon(Icons.support_agent, color: AppColors.primary, size: 28),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(m.name.isEmpty ? 'Отдел продаж' : m.name, style: AppText.h3),
                              const SizedBox(height: 2),
                              Text(phone, style: AppText.bodySecondary),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: () async {
                        final ok = await callPhone(phone);
                        if (!ok && context.mounted) {
                          showSnack(context, 'Не удалось открыть звонилку.', error: true);
                        }
                      },
                      icon: const Icon(Icons.call_outlined),
                      label: const Text('Позвонить'),
                    ),
                    const SizedBox(height: 10),
                    if (email.isNotEmpty) ...<Widget>[
                      OutlinedButton.icon(
                        onPressed: () => sendMail(email, subject: 'Запрос из приложения ${AppConfig.appName}'),
                        icon: const Icon(Icons.mail_outline),
                        label: const Text('Написать на email'),
                      ),
                      const SizedBox(height: 10),
                    ],
                    const ContactChannels(),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        context.push('/quote');
                      },
                      icon: const Icon(Icons.request_quote_outlined),
                      label: const Text('Запросить коммерческое предложение'),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
