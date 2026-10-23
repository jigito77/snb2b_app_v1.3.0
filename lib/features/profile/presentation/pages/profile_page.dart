import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/language_sheet.dart';
import '../../../../core/l10n/app_text.dart';
import '../../../../app/session_coordinator.dart';
import '../../../../core/constants/app_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/launcher.dart';
import '../../../../shared/state/product_collections.dart';
import '../../../../shared/widgets/common.dart';
import '../../../../shared/widgets/manager_sheet.dart';
import '../../../auth/domain/entities/user.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../notifications/presentation/providers/notifications_providers.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Выйти из аккаунта?'),
        content: const Text('Корзина и избранное на устройстве будут очищены. Данные аккаунта сохранятся на сервере.'),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Отмена')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Выйти', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(authControllerProvider.notifier).logout();
    ref.read(sessionCoordinatorProvider).onLogout();
    if (context.mounted) showSnack(context, 'Вы вышли из аккаунта');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final user = auth.user;
    final compareCount = ref.watch(comparisonProvider.select((l) => l.length));
    final unread = ref.watch(notificationsProvider).maybeWhen(
          data: (list) => list.where((n) => !n.isRead).length,
          orElse: () => 0,
        );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Профиль'),
        actions: <Widget>[
          IconButton(
            tooltip: tr('Язык'),
            onPressed: () => showLanguageSheet(context),
            icon: const Icon(Icons.translate),
          ),
          IconButton(
            tooltip: tr('Настройки'),
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 28),
        children: <Widget>[
          if (auth.isAuthenticated && user != null)
            _UserHeader(user: user)
          else
            _GuestHeader(onLogin: () => context.push('/login?from=${Uri.encodeComponent('/profile')}')),
          if (auth.isAuthenticated && user != null) ...<Widget>[
            const SectionHeader(title: 'Аккаунт'),
            _MenuGroup(children: <Widget>[
              _MenuTile(
                icon: Icons.receipt_long_outlined,
                title: 'Мои заказы',
                onTap: () => context.push('/orders'),
              ),
              _MenuTile(
                icon: Icons.person_outline,
                title: 'Данные профиля',
                onTap: () => context.push('/profile/data'),
              ),
              _MenuTile(
                icon: Icons.business_outlined,
                title: 'Реквизиты компании',
                onTap: () => context.push('/profile/requisites'),
              ),
              _MenuTile(
                icon: Icons.location_on_outlined,
                title: 'Адреса доставки',
                onTap: () => context.push('/profile/addresses'),
              ),
              _MenuTile(
                icon: Icons.notifications_none,
                title: 'Уведомления',
                badge: unread,
                onTap: () => context.push('/notifications'),
              ),
            ]),
          ],
          const SectionHeader(title: 'Покупателю'),
          _MenuGroup(children: <Widget>[
            _MenuTile(
              icon: Icons.compare_arrows,
              title: 'Сравнение товаров',
              badge: compareCount,
              onTap: () => context.push('/compare'),
            ),
            _MenuTile(
              icon: Icons.request_quote_outlined,
              title: 'Запросить коммерческое предложение',
              onTap: () => context.push('/quote'),
            ),
            _MenuTile(
              icon: Icons.chat_bubble_outline,
              title: 'Чат с поддержкой',
              onTap: () => context.push('/support/chat'),
            ),
            _MenuTile(
              icon: Icons.support_agent,
              title: 'Связаться с менеджером',
              onTap: () => showManagerSheet(context),
            ),
            _MenuTile(
              icon: Icons.newspaper_outlined,
              title: 'Новости',
              onTap: () => context.push('/news'),
            ),
          ]),
          const SectionHeader(title: 'Информация'),
          _MenuGroup(children: <Widget>[
            _MenuTile(
              icon: Icons.local_shipping_outlined,
              title: 'Доставка',
              onTap: () => context.push('/info/delivery'),
            ),
            _MenuTile(
              icon: Icons.payments_outlined,
              title: 'Оплата',
              onTap: () => context.push('/info/payment'),
            ),
            _MenuTile(
              icon: Icons.verified_outlined,
              title: 'Гарантия и возврат',
              onTap: () => context.push('/info/warranty'),
            ),
            _MenuTile(
              icon: Icons.contact_phone_outlined,
              title: 'Контакты',
              onTap: () => context.push('/info/contacts'),
            ),
            _MenuTile(
              icon: Icons.language,
              title: 'Сайт ${AppConfig.websiteUrl.replaceFirst('https://', '')}',
              onTap: () => openWebsite(AppConfig.websiteUrl),
            ),
          ]),
          if (auth.isAuthenticated) ...<Widget>[
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                onPressed: () => _logout(context, ref),
                icon: const Icon(Icons.logout),
                label: const Text('Выйти'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _GuestHeader extends StatelessWidget {
  const _GuestHeader({required this.onLogin});

  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Войдите, чтобы видеть ваши цены',
            style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'Оптовые и персональные цены, история заказов, закреплённый менеджер и синхронизация избранного.',
            style: TextStyle(color: Color(0xCCFFFFFF), fontSize: 13.5, height: 1.4),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: onLogin, child: const Text('Войти или зарегистрироваться')),
        ],
      ),
    );
  }
}

class _UserHeader extends StatelessWidget {
  const _UserHeader({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final manager = user.manager;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.accent,
                child: Text(
                  user.initials,
                  style: const TextStyle(color: AppColors.onAccent, fontWeight: FontWeight.w800, fontSize: 18),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      user.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              if (user.verificationStatus.isNotEmpty)
                InfoPill(
                  text: user.verificationStatus == 'VERIFIED'
                      ? 'Аккаунт верифицирован'
                      : (user.verificationStatus == 'PENDING'
                          ? 'Ожидает верификации'
                          : (user.verificationStatus == 'REJECTED' ? 'Верификация отклонена' : 'Доступ заблокирован')),
                  background: user.verificationStatus == 'VERIFIED' ? AppColors.successSoft : AppColors.warningSoft,
                  foreground: user.verificationStatus == 'VERIFIED' ? AppColors.success : AppColors.warning,
                  icon: user.verificationStatus == 'VERIFIED' ? Icons.verified_user : Icons.hourglass_top,
                ),
              if (user.isB2b)
                const InfoPill(
                  text: 'B2B клиент',
                  background: AppColors.accent,
                  foreground: AppColors.onAccent,
                  icon: Icons.verified,
                ),
              if (user.discountPercent > 0)
                InfoPill(
                  text: 'Скидка ${user.discountPercent.toStringAsFixed(user.discountPercent % 1 == 0 ? 0 : 1)}%',
                  background: AppColors.successSoft,
                  foreground: AppColors.success,
                ),
              if (user.company != null && user.company!.name.isNotEmpty)
                InfoPill(
                  text: user.company!.name,
                  background: const Color(0x22FFFFFF),
                  foreground: Colors.white,
                  icon: Icons.business,
                ),
            ],
          ),
          if (manager != null && manager.name.isNotEmpty) ...<Widget>[
            const SizedBox(height: 14),
            InkWell(
              borderRadius: BorderRadius.circular(AppRadius.md),
              onTap: () => showManagerSheet(context),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0x1AFFFFFF),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Row(
                  children: <Widget>[
                    const Icon(Icons.support_agent, color: Colors.white),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Text('Ваш менеджер', style: TextStyle(color: Color(0xAAFFFFFF), fontSize: 11.5)),
                          Text(
                            manager.name,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Colors.white),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MenuGroup extends StatelessWidget {
  const _MenuGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: <Widget>[
          for (var i = 0; i < children.length; i++) ...<Widget>[
            if (i > 0) const Divider(height: 1, indent: 56),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({required this.icon, required this.title, required this.onTap, this.badge = 0});

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title, style: AppText.body),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (badge > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(10)),
              child: Text('$badge', style: const TextStyle(color: AppColors.onAccent, fontSize: 12, fontWeight: FontWeight.w700)),
            ),
          const Icon(Icons.chevron_right, color: AppColors.textHint),
        ],
      ),
    );
  }
}
