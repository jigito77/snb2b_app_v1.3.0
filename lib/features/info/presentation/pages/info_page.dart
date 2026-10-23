import 'package:flutter/material.dart' hide Text;
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/app_text.dart';
import '../../../../core/constants/app_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/launcher.dart';
import '../../../../core/constants/contacts.dart';
import '../../../../shared/widgets/common.dart';
import '../../../../shared/widgets/contact_channels.dart';
import '../../../../shared/widgets/state_views.dart';

class _Section {
  const _Section(this.title, this.text);

  final String title;
  final String text;
}

class _Info {
  const _Info(this.title, this.icon, this.sections);

  final String title;
  final IconData icon;
  final List<_Section> sections;
}

/// Справочные страницы. Тексты нейтральные — замените реальными условиями компании
/// или отдавайте их с backend (GET /api/content/pages/{slug}).
const Map<String, _Info> _pages = <String, _Info>{
  'delivery': _Info('Доставка', Icons.local_shipping_outlined, <_Section>[
    _Section('Транспортные компании', 'Отправляем заказы по России транспортными компаниями. Стоимость и срок рассчитывает менеджер при подтверждении заказа.'),
    _Section('Курьер по городу', 'Доставка курьером по городу — на следующий рабочий день после подтверждения заказа и наличия товара на складе.'),
    _Section('Самовывоз', 'Заберите заказ на складе после подтверждения менеджером. Адрес и время работы уточняйте по телефону.'),
    _Section('Сроки', 'Товары в наличии отгружаются в течение 1–2 рабочих дней. Под заказ — срок указан в карточке товара.'),
  ]),
  'payment': _Info('Оплата', Icons.payments_outlined, <_Section>[
    _Section('Безналичный расчёт', 'Для юридических лиц — оплата по счёту. Счёт можно запросить в карточке заказа.'),
    _Section('Оплата при получении', 'Доступна для части заказов, наличными или картой при получении.'),
    _Section('Отсрочка платежа', 'Постоянным B2B-клиентам менеджер может предложить отсрочку. Условия обсуждаются индивидуально.'),
  ]),
  'warranty': _Info('Гарантия и возврат', Icons.verified_outlined, <_Section>[
    _Section('Гарантия', 'На запчасти действует гарантия производителя. Срок указан в документах к товару.'),
    _Section('Возврат', 'Возврат товара надлежащего качества возможен в течение 14 дней при сохранении товарного вида и упаковки.'),
    _Section('Как оформить', 'Свяжитесь с менеджером, назовите номер заказа и причину обращения — он подскажет порядок действий.'),
  ]),
  'contacts': _Info('Контакты', Icons.contact_phone_outlined, <_Section>[
    _Section('Режим работы', 'Пн–Пт: 9:00–18:00. Заявки из приложения принимаются круглосуточно.'),
  ]),
};

class InfoPage extends StatelessWidget {
  const InfoPage({super.key, required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context) {
    final page = _pages[slug];
    if (page == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(icon: Icons.search_off, title: 'Страница не найдена'),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(page.title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: <Widget>[
          Center(
            child: CircleAvatar(
              radius: 32,
              backgroundColor: AppColors.surfaceAlt,
              child: Icon(page.icon, size: 30, color: AppColors.primary),
            ),
          ),
          const SizedBox(height: 16),
          if (slug == 'contacts') ...<Widget>[
            const ContactChannels(),
            const SizedBox(height: 12),
            SurfaceCard(
              child: Column(
                children: <Widget>[
                  _ContactTile(
                    icon: Icons.call_outlined,
                    title: 'Телефон · Армения',
                    value: Contacts.phoneArmenia,
                    onTap: () => callPhone(Contacts.phoneArmenia),
                  ),
                  const Divider(height: 1),
                  _ContactTile(
                    icon: Icons.call_outlined,
                    title: 'Телефон · Россия',
                    value: Contacts.phoneRussia,
                    onTap: () => callPhone(Contacts.phoneRussia),
                  ),
                  const Divider(height: 1),
                  _ContactTile(
                    icon: Icons.chat_bubble_outline,
                    title: 'WhatsApp · Армения',
                    value: '+374 94 003907',
                    onTap: () => openWhatsApp(number: Contacts.whatsappArmenia),
                  ),
                  const Divider(height: 1),
                  _ContactTile(
                    icon: Icons.send_outlined,
                    title: 'Telegram',
                    value: '@${Contacts.telegramUser}',
                    onTap: () => openTelegram(),
                  ),
                  const Divider(height: 1),
                  _ContactTile(
                    icon: Icons.campaign_outlined,
                    title: 'Telegram-канал',
                    value: '@${Contacts.telegramChannel}',
                    onTap: () => openTelegram(user: Contacts.telegramChannel),
                  ),
                  const Divider(height: 1),
                  _ContactTile(
                    icon: Icons.mail_outline,
                    title: 'Email',
                    value: Contacts.email,
                    onTap: () => sendMail(Contacts.email),
                  ),
                  const Divider(height: 1),
                  _ContactTile(
                    icon: Icons.language,
                    title: 'Сайт',
                    value: Contacts.website.replaceFirst('https://', ''),
                    onTap: () => openWebsite(Contacts.website),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SurfaceCard(
              margin: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text('Россия', style: AppText.h3),
                  const SizedBox(height: 4),
                  const Text(Contacts.addressRussia, style: AppText.bodySecondary),
                  const Text(Contacts.hoursRussia, style: AppText.caption),
                  const SizedBox(height: 14),
                  const Text('Армения', style: AppText.h3),
                  const SizedBox(height: 4),
                  const Text(Contacts.addressArmenia, style: AppText.bodySecondary),
                  const Text(Contacts.hoursArmenia, style: AppText.caption),
                ],
              ),
            ),
          ],
          for (final s in page.sections) ...<Widget>[
            SurfaceCard(
              margin: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(s.title, style: AppText.h3),
                  const SizedBox(height: 6),
                  Text(s.text, style: AppText.bodySecondary),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => context.push('/quote'),
            icon: const Icon(Icons.request_quote_outlined),
            label: const Text('Задать вопрос менеджеру'),
          ),
        ],
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({required this.icon, required this.title, required this.value, required this.onTap});

  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title, style: AppText.caption),
      subtitle: Text(value, style: AppText.h3),
      onTap: onTap,
    );
  }
}
