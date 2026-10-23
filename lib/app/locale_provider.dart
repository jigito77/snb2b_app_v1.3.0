import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/l10n/l10n.dart';
import 'di.dart';

/// Выбранный язык интерфейса. Хранится отдельно от кэша каталога,
/// поэтому «Очистить кэш» язык не сбрасывает.
class LocaleController extends Notifier<Locale> {
  static const String _key = 'app.locale';

  @override
  Locale build() {
    final saved = ref.read(sharedPreferencesProvider).getString(_key);
    final code = L10n.isSupported(saved) ? saved! : L10n.deviceLanguage();
    L10n.lang = code;
    return Locale(code);
  }

  Future<void> setLanguage(String code) async {
    if (!L10n.isSupported(code) || code == state.languageCode) return;
    L10n.lang = code;
    state = Locale(code);
    // Перерисовываем всё дерево: строки вне виджета Text (подсказки, подписи полей)
    // берутся из L10n во время build().
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(WidgetsBinding.instance.reassembleApplication());
    });
    await ref.read(sharedPreferencesProvider).setString(_key, code);
  }
}

final localeProvider = NotifierProvider<LocaleController, Locale>(LocaleController.new);
