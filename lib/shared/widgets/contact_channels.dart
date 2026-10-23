import 'package:flutter/material.dart' hide Text;

import '../../core/constants/contacts.dart';
import '../../core/l10n/app_text.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/launcher.dart';
import 'common.dart';

/// Кнопки мессенджеров и соцсетей: WhatsApp, Telegram, Instagram, Facebook.
/// [message] подставляется в WhatsApp (например, название товара).
class ContactChannels extends StatelessWidget {
  const ContactChannels({super.key, this.message});

  final String? message;

  Future<void> _open(BuildContext context, Future<bool> action) async {
    final ok = await action;
    if (!ok && context.mounted) {
      showSnack(context, 'Не удалось открыть приложение.', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: _Channel(
            label: 'WhatsApp',
            icon: Icons.chat_bubble_outline,
            color: const Color(0xFF25D366),
            onTap: () => _open(context, openWhatsApp(text: message)),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _Channel(
            label: 'Telegram',
            icon: Icons.send_outlined,
            color: const Color(0xFF2AABEE),
            onTap: () => _open(context, openTelegram()),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _Channel(
            label: 'Instagram',
            icon: Icons.camera_alt_outlined,
            color: const Color(0xFFE1306C),
            onTap: () => _open(context, openWebsite(Contacts.instagramUrl)),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _Channel(
            label: 'Facebook',
            icon: Icons.facebook_outlined,
            color: const Color(0xFF1877F2),
            onTap: () => _open(context, openWebsite(Contacts.facebookUrl)),
          ),
        ),
      ],
    );
  }
}

class _Channel extends StatelessWidget {
  const _Channel({required this.label, required this.icon, required this.color, required this.onTap});

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
