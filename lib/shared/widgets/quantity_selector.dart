import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';

import '../../core/l10n/app_text.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

/// Выбор количества: [-] 2 [+]. Нажатие на число открывает ввод с клавиатуры.
/// Если задан [onRemove], то при минимальном количестве «минус» превращается в «удалить».
class QuantitySelector extends StatelessWidget {
  const QuantitySelector({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 1,
    this.max = 9999,
    this.compact = false,
    this.onRemove,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;
  final bool compact;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final height = compact ? 38.0 : 48.0;
    final atMin = value <= min;
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border, width: 1.4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _StepButton(
            icon: atMin && onRemove != null ? Icons.delete_outline : Icons.remove,
            enabled: !atMin || onRemove != null,
            size: height,
            onTap: () {
              if (atMin) {
                onRemove?.call();
              } else {
                onChanged(value - 1);
              }
            },
          ),
          InkWell(
            onTap: () => _edit(context),
            child: SizedBox(
              width: compact ? 40 : 54,
              height: height,
              child: Center(
                child: Text(
                  '$value',
                  style: TextStyle(
                    fontSize: compact ? 15 : 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          ),
          _StepButton(
            icon: Icons.add,
            enabled: value < max,
            size: height,
            onTap: () => onChanged(value + 1),
          ),
        ],
      ),
    );
  }

  Future<void> _edit(BuildContext context) async {
    final result = await showDialog<int>(
      context: context,
      builder: (_) => _QuantityDialog(initial: value, min: min, max: max),
    );
    if (result != null && result != value) onChanged(result);
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.enabled,
    required this.size,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: SizedBox(
        width: size,
        height: size,
        child: Icon(
          icon,
          size: 20,
          color: enabled ? AppColors.primary : AppColors.textHint,
        ),
      ),
    );
  }
}

class _QuantityDialog extends StatefulWidget {
  const _QuantityDialog({required this.initial, required this.min, required this.max});

  final int initial;
  final int min;
  final int max;

  @override
  State<_QuantityDialog> createState() => _QuantityDialogState();
}

class _QuantityDialogState extends State<_QuantityDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial.toString());

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final parsed = int.tryParse(_controller.text) ?? widget.initial;
    var value = parsed;
    if (value < widget.min) value = widget.min;
    if (value > widget.max) value = widget.max;
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      title: const Text('Количество', style: AppText.h2),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
        decoration: AppInput.of(helper: 'От ${widget.min} до ${widget.max} шт.'),
        onSubmitted: (_) => _submit(),
      ),
      actions: <Widget>[
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Отмена')),
        TextButton(onPressed: _submit, child: const Text('Готово')),
      ],
    );
  }
}
