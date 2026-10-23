import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/app_text.dart';
import '../../../../app/session_coordinator.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/user.dart';
import '../providers/auth_providers.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key, this.from});

  final String? from;

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _company = TextEditingController();
  final _inn = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _company.dispose();
    _inn.dispose();
    _password.dispose();
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
      await ref.read(authControllerProvider.notifier).register(
            RegisterData(
              name: _name.text.trim(),
              email: _email.text.trim(),
              password: _password.text,
              phone: _phone.text.trim(),
              companyName: _company.text.trim(),
              inn: _inn.text.trim(),
            ),
          );
      await ref.read(sessionCoordinatorProvider).onLogin();
      if (!mounted) return;
      final target = widget.from;
      context.go(target != null && target.isNotEmpty ? target : '/profile');
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
      appBar: AppBar(title: const Text('Регистрация')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            children: <Widget>[
              const Text(
                'Создайте аккаунт. Для юридических лиц укажите компанию и ИНН — менеджер подтвердит статус B2B и откроет оптовые цены.',
                style: AppText.bodySecondary,
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: AppInput.of(label: 'Контактное лицо', prefixIcon: const Icon(Icons.person_outline)),
                validator: (v) => (v ?? '').trim().length < 2 ? tr('Введите имя') : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: AppInput.of(label: 'Email', prefixIcon: const Icon(Icons.mail_outline)),
                validator: (v) {
                  final s = (v ?? '').trim();
                  if (s.isEmpty) return tr('Введите email');
                  if (!s.contains('@') || !s.contains('.')) return tr('Некорректный email');
                  return null;
                },
              ),
              const SizedBox(height: 14),
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
              const SizedBox(height: 14),
              TextFormField(
                controller: _company,
                textInputAction: TextInputAction.next,
                decoration: AppInput.of(
                  label: 'Компания (необязательно)',
                  prefixIcon: const Icon(Icons.business_outlined),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _inn,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                decoration: AppInput.of(
                  label: 'ИНН (необязательно)',
                  prefixIcon: const Icon(Icons.badge_outlined),
                ),
                validator: (v) {
                  final s = (v ?? '').trim();
                  if (s.isEmpty) return null;
                  if (!RegExp(r'^\d{10}$|^\d{12}$').hasMatch(s)) return tr('ИНН — 10 или 12 цифр');
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _password,
                obscureText: _obscure,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                decoration: AppInput.of(
                  label: 'Пароль',
                  helper: 'Не менее 6 символов',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  ),
                ),
                validator: (v) => (v ?? '').length < 6 ? tr('Минимум 6 символов') : null,
              ),
              if (_error != null) ...<Widget>[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.dangerSoft,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Row(
                    children: <Widget>[
                      const Icon(Icons.error_outline, color: AppColors.danger, size: 20),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_error!, style: AppText.body)),
                    ],
                  ),
                ),
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
                    : const Text('Создать аккаунт'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
