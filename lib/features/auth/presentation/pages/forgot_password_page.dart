import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/app_text.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/auth_providers.dart';

class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _loading = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).forgotPassword(_email.text.trim());
      if (!mounted) return;
      setState(() {
        _loading = false;
        _sent = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = errorMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Восстановление пароля')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: <Widget>[
            if (_sent) ...<Widget>[
              const SizedBox(height: 24),
              const Center(
                child: CircleAvatar(
                  radius: 38,
                  backgroundColor: AppColors.successSoft,
                  child: Icon(Icons.mark_email_read_outlined, size: 36, color: AppColors.success),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Письмо отправлено', style: AppText.h1, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                'Если аккаунт с адресом ${_email.text.trim()} существует, мы отправили на него ссылку для смены пароля.',
                style: AppText.bodySecondary,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text('Вернуться ко входу'),
              ),
            ] else
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const Text(
                      'Укажите email, с которым вы регистрировались. Мы пришлём ссылку для сброса пароля.',
                      style: AppText.bodySecondary,
                    ),
                    const SizedBox(height: 18),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      decoration: AppInput.of(label: 'Email', prefixIcon: const Icon(Icons.mail_outline)),
                      validator: (v) {
                        final s = (v ?? '').trim();
                        if (s.isEmpty) return tr('Введите email');
                        if (!s.contains('@') || !s.contains('.')) return tr('Некорректный email');
                        return null;
                      },
                    ),
                    if (_error != null) ...<Widget>[
                      const SizedBox(height: 12),
                      Text(_error!, style: const TextStyle(color: AppColors.danger)),
                    ],
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.onAccent),
                            )
                          : const Text('Отправить ссылку'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
