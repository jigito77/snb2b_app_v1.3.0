import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/language_sheet.dart';
import '../../../../core/l10n/app_text.dart';
import '../../../../app/session_coordinator.dart';
import '../../../../core/auth/google_sign_in_service.dart';
import '../../../../core/constants/app_config.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/common.dart';
import '../../domain/entities/user.dart';
import '../providers/auth_providers.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key, this.from});

  /// Маршрут, на который вернуться после входа.
  final String? from;

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _fillDemo() {
    _email.text = 'b2b@demo.ru';
    _password.text = 'demo123';
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref
          .read(authControllerProvider.notifier)
          .signIn(EmailPasswordCredentials(_email.text.trim(), _password.text));
      await ref.read(sessionCoordinatorProvider).onLogin();
      if (!mounted) return;
      final target = widget.from;
      if (target != null && target.isNotEmpty && target != '/login') {
        context.go(target);
      } else {
        context.go('/profile');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = errorMessage(e);
      });
    }
  }

  Future<void> _google() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await GoogleSignInService.signIn();
      if (result == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      await ref
          .read(authControllerProvider.notifier)
          .signIn(OAuthCredentials('google', result.idToken, name: result.name));
      await ref.read(sessionCoordinatorProvider).onLogin();
      if (!mounted) return;
      final target = widget.from;
      context.go(target != null && target.isNotEmpty && target != '/login' ? target : '/profile');
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
      appBar: AppBar(
        actions: <Widget>[
          IconButton(
            tooltip: tr('Язык'),
            onPressed: () => showLanguageSheet(context),
            icon: const Icon(Icons.translate),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          children: <Widget>[
            const Center(child: AppLogo(size: 84)),
            const SizedBox(height: 24),
            const Text('Вход в личный кабинет', style: AppText.h1, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            const Text(
              'Персональные цены, история заказов и менеджер — после входа.',
              style: AppText.bodySecondary,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (AppConfig.useMockApi)
              InkWell(
                onTap: _fillDemo,
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.infoSoft,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: const Row(
                    children: <Widget>[
                      Icon(Icons.info_outline, color: AppColors.info, size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Демо-режим: b2b@demo.ru / demo123. Нажмите, чтобы подставить.',
                          style: TextStyle(fontSize: 13, color: AppColors.info, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Form(
              key: _formKey,
              child: Column(
                children: <Widget>[
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const <String>[AutofillHints.email],
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
                    controller: _password,
                    obscureText: _obscure,
                    textInputAction: TextInputAction.done,
                    autofillHints: const <String>[AutofillHints.password],
                    onFieldSubmitted: (_) => _submit(),
                    decoration: AppInput.of(
                      label: 'Пароль',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => _obscure = !_obscure),
                        icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      ),
                    ),
                    validator: (v) => (v ?? '').isEmpty ? tr('Введите пароль') : null,
                  ),
                ],
              ),
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
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => context.push('/forgot-password'),
                child: const Text('Забыли пароль?'),
              ),
            ),
            const SizedBox(height: 4),
            FilledButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.onAccent),
                    )
                  : const Text('Войти'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _loading
                  ? null
                  : () => context.push('/register${widget.from == null ? '' : '?from=${Uri.encodeComponent(widget.from!)}'}'),
              child: const Text('Зарегистрироваться'),
            ),
            if (!AppConfig.useMockApi && GoogleSignInService.isConfigured) ...<Widget>[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _loading ? null : _google,
                icon: const Icon(Icons.g_mobiledata, size: 28),
                label: const Text('Войти через Google'),
              ),
            ],
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => context.go('/home'),
              child: const Text('Продолжить без входа'),
            ),
          ],
        ),
      ),
    );
  }
}
