import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/app_text.dart';
import '../../../../app/di.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/common.dart';
import '../../../auth/domain/entities/user.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

class RequisitesPage extends ConsumerStatefulWidget {
  const RequisitesPage({super.key});

  @override
  ConsumerState<RequisitesPage> createState() => _RequisitesPageState();
}

class _RequisitesPageState extends ConsumerState<RequisitesPage> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _c;
  bool _saving = false;

  static const List<String> _keys = <String>[
    'name',
    'inn',
    'kpp',
    'ogrn',
    'legalAddress',
    'bankName',
    'bik',
    'account',
    'corrAccount',
  ];

  @override
  void initState() {
    super.initState();
    final json = ref.read(authControllerProvider).user?.company?.toJson() ?? const <String, dynamic>{};
    _c = <String, TextEditingController>{
      for (final k in _keys) k: TextEditingController(text: (json[k] ?? '').toString()),
    };
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _v(String key) => _c[key]!.text.trim();

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final company = Company(
        name: _v('name'),
        inn: _v('inn'),
        kpp: _v('kpp'),
        ogrn: _v('ogrn'),
        legalAddress: _v('legalAddress'),
        bankName: _v('bankName'),
        bik: _v('bik'),
        account: _v('account'),
        corrAccount: _v('corrAccount'),
      );
      final updated = await ref.read(profileRepositoryProvider).updateProfile(company: company);
      ref.read(authControllerProvider.notifier).updateUser(updated);
      if (!mounted) return;
      setState(() => _saving = false);
      showSnack(context, 'Реквизиты сохранены');
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showSnack(context, errorMessage(e), error: true);
    }
  }

  Widget _field(
    String key,
    String label, {
    TextInputType type = TextInputType.text,
    String? Function(String)? check,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: _c[key],
        keyboardType: type,
        decoration: AppInput.of(label: label),
        validator: (v) {
          final s = (v ?? '').trim();
          if (s.isEmpty || check == null) return null;
          return check(s);
        },
      ),
    );
  }

  String? _digits(String s, List<int> lengths, String label) {
    if (!RegExp(r'^\d+$').hasMatch(s) || !lengths.contains(s.length)) {
      return '$label: ${lengths.join(' или ')} цифр';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Реквизиты компании')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            const Text(
              'Реквизиты используются для выставления счетов и документов.',
              style: AppText.bodySecondary,
            ),
            const SizedBox(height: 16),
            _field('name', 'Название организации'),
            _field('inn', 'ИНН', type: TextInputType.number, check: (s) => _digits(s, <int>[10, 12], 'ИНН')),
            _field('kpp', 'КПП', type: TextInputType.number, check: (s) => _digits(s, <int>[9], 'КПП')),
            _field('ogrn', 'ОГРН / ОГРНИП', type: TextInputType.number, check: (s) => _digits(s, <int>[13, 15], 'ОГРН')),
            _field('legalAddress', 'Юридический адрес'),
            const Divider(height: 28),
            _field('bankName', 'Банк'),
            _field('bik', 'БИК', type: TextInputType.number, check: (s) => _digits(s, <int>[9], 'БИК')),
            _field('account', 'Расчётный счёт', type: TextInputType.number, check: (s) => _digits(s, <int>[20], 'Счёт')),
            _field('corrAccount', 'Корр. счёт', type: TextInputType.number, check: (s) => _digits(s, <int>[20], 'Счёт')),
            const SizedBox(height: 8),
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
