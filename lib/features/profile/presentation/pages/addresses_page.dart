import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/app_text.dart';
import '../../../../app/di.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/common.dart';
import '../../../../shared/widgets/skeleton.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../domain/entities/address.dart';
import '../providers/profile_providers.dart';

class AddressesPage extends ConsumerWidget {
  const AddressesPage({super.key});

  Future<void> _delete(BuildContext context, WidgetRef ref, Address a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить адрес?'),
        content: Text(a.fullAddress),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Отмена')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Удалить', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(profileRepositoryProvider).deleteAddress(a.id);
      ref.invalidate(addressesProvider);
    } catch (e) {
      if (context.mounted) showSnack(context, errorMessage(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(addressesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Адреса доставки')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.onAccent,
        onPressed: () => showAddressSheet(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Добавить'),
      ),
      body: async.when(
        loading: () => ListView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.only(top: 12),
          children: const <Widget>[
            BlockSkeleton(height: 90, margin: EdgeInsets.fromLTRB(16, 0, 16, 12)),
            BlockSkeleton(height: 90, margin: EdgeInsets.fromLTRB(16, 0, 16, 12)),
          ],
        ),
        error: (e, _) => ErrorState(error: e, onRetry: () => ref.invalidate(addressesProvider)),
        data: (list) {
          if (list.isEmpty) {
            return EmptyState(
              icon: Icons.location_off_outlined,
              title: 'Адресов пока нет',
              message: 'Добавьте адрес, чтобы быстрее оформлять заказы.',
              actionLabel: 'Добавить адрес',
              onAction: () => showAddressSheet(context, ref),
            );
          }
          return RefreshIndicator(
            color: AppColors.accent,
            onRefresh: () async {
              ref.invalidate(addressesProvider);
              try {
                await ref.read(addressesProvider.future);
              } catch (_) {
                // ошибка отобразится на экране
              }
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              children: <Widget>[
                for (final a in list)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: SurfaceCard(
                      onTap: () => showAddressSheet(context, ref, address: a),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Icon(Icons.location_on_outlined, color: AppColors.primary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Row(
                                  children: <Widget>[
                                    Flexible(
                                      child: Text(a.title.isEmpty ? 'Адрес' : a.title, style: AppText.h3),
                                    ),
                                    if (a.isDefault) ...<Widget>[
                                      const SizedBox(width: 8),
                                      const InfoPill(
                                        text: 'Основной',
                                        background: AppColors.successSoft,
                                        foreground: AppColors.success,
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(a.fullAddress, style: AppText.body),
                                if (a.comment.isNotEmpty) ...<Widget>[
                                  const SizedBox(height: 4),
                                  Text(a.comment, style: AppText.caption),
                                ],
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: tr('Удалить'),
                            onPressed: () => _delete(context, ref, a),
                            icon: const Icon(Icons.delete_outline, color: AppColors.textHint),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

Future<void> showAddressSheet(BuildContext context, WidgetRef ref, {Address? address}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _AddressForm(address: address, ref: ref),
  );
}

class _AddressForm extends StatefulWidget {
  const _AddressForm({this.address, required this.ref});

  final Address? address;
  final WidgetRef ref;

  @override
  State<_AddressForm> createState() => _AddressFormState();
}

class _AddressFormState extends State<_AddressForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _city;
  late final TextEditingController _street;
  late final TextEditingController _comment;
  late bool _isDefault;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final a = widget.address;
    _title = TextEditingController(text: a?.title ?? '');
    _city = TextEditingController(text: a?.city ?? '');
    _street = TextEditingController(text: a?.street ?? '');
    _comment = TextEditingController(text: a?.comment ?? '');
    _isDefault = a?.isDefault ?? false;
  }

  @override
  void dispose() {
    _title.dispose();
    _city.dispose();
    _street.dispose();
    _comment.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await widget.ref.read(profileRepositoryProvider).saveAddress(
            Address(
              id: widget.address?.id ?? '',
              title: _title.text.trim(),
              city: _city.text.trim(),
              street: _street.text.trim(),
              comment: _comment.text.trim(),
              isDefault: _isDefault,
            ),
          );
      widget.ref.invalidate(addressesProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showSnack(context, errorMessage(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 4, 20, 20 + bottom),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(widget.address == null ? 'Новый адрес' : 'Редактирование адреса', style: AppText.h2),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _title,
                  decoration: AppInput.of(label: 'Название', hint: 'Склад, Офис, Гараж…'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _city,
                  decoration: AppInput.of(label: 'Город'),
                  validator: (v) => (v ?? '').trim().isEmpty ? tr('Укажите город') : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _street,
                  decoration: AppInput.of(label: 'Улица, дом, офис'),
                  validator: (v) => (v ?? '').trim().isEmpty ? tr('Укажите адрес') : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _comment,
                  decoration: AppInput.of(label: 'Комментарий для курьера'),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Основной адрес'),
                  value: _isDefault,
                  activeTrackColor: AppColors.accent,
                  onChanged: (v) => setState(() => _isDefault = v),
                ),
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
        ),
      ),
    );
  }
}
