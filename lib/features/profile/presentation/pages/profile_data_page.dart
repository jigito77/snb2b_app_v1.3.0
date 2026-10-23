import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/app_text.dart';
import '../../../../app/di.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/common.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

class ProfileDataPage extends ConsumerStatefulWidget {
  const ProfileDataPage({super.key});

  @override
  ConsumerState<ProfileDataPage> createState() => _ProfileDataPageState();
}

class _ProfileDataPageState extends ConsumerState<ProfileDataPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  bool _saving = false;

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

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final updated = await ref
          .read(profileRepositoryProvider)
          .updateProfile(name: _name.text.trim(), phone: _phone.text.trim());
      ref.read(authControllerProvider.notifier).updateUser(updated);
      if (!mounted) return;
      setState(() => _saving = false);
      showSnack(context, 'Данные сохранены');
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showSnack(context, errorMessage(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).user;
    return Scaffold(
      appBar: AppBar(title: const Text('Данные профиля')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: AppInput.of(label: 'Контактное лицо', prefixIcon: const Icon(Icons.person_outline)),
              validator: (v) => (v ?? '').trim().length < 2 ? tr('Введите имя') : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              initialValue: user?.email ?? '',
              enabled: false,
              decoration: AppInput.of(
                label: 'Email',
                helper: 'Email изменить нельзя — обратитесь к менеджеру',
                prefixIcon: const Icon(Icons.mail_outline),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: AppInput.of(label: 'Телефон', prefixIcon: const Icon(Icons.phone_outlined)),
              validator: (v) {
                final digits = (v ?? '').replaceAll(RegExp(r'[^0-9]'), '');
                return digits.length < 10 ? tr('Введите номер телефона') : null;
              },
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.onAccent),
                    )
                  : const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
  }
}
