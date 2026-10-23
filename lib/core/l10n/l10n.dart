import 'dart:ui' show Locale, PlatformDispatcher;

import 'rules.dart';
import 'strings_en.dart';
import 'strings_hy.dart';
import 'strings_ka.dart';

/// Поддерживаемые языки интерфейса. Исходный язык строк в коде — русский.
class AppLanguage {
  const AppLanguage(this.code, this.nativeName, this.flag);

  final String code;
  final String nativeName;
  final String flag;

  Locale get locale => Locale(code);
}

class L10n {
  L10n._();

  static const List<AppLanguage> languages = <AppLanguage>[
    AppLanguage('hy', 'Հայերեն', '🇦🇲'),
    AppLanguage('en', 'English', '🇬🇧'),
    AppLanguage('ka', 'ქართული', '🇬🇪'),
    AppLanguage('ru', 'Русский', '🇷🇺'),
  ];

  static const List<Locale> supportedLocales = <Locale>[
    Locale('ru'),
    Locale('en'),
    Locale('hy'),
    Locale('ka'),
  ];

  /// Текущий язык. Обновляется провайдером локали; доступен и вне виджетов.
  static String lang = 'ru';

  static Locale get current => Locale(lang);

  static bool isSupported(String? code) =>
      code != null && languages.any((l) => l.code == code);

  /// Язык устройства, если он поддерживается, иначе русский.
  static String deviceLanguage() {
    final code = PlatformDispatcher.instance.locale.languageCode;
    return isSupported(code) ? code : 'ru';
  }

  static final Map<String, Map<String, String>> _tables = <String, Map<String, String>>{
    'en': stringsEn,
    'hy': stringsHy,
    'ka': stringsKa,
  };

  static final Map<String, Map<String, String>> _cache = <String, Map<String, String>>{};

  /// Переводит русскую строку на текущий язык. Неизвестные строки
  /// (названия, артикулы, данные пользователя) возвращаются как есть.
  static String tr(String ru, [String? forLang]) {
    final target = forLang ?? lang;
    if (target == 'ru' || ru.isEmpty) return ru;
    if (!_hasCyrillic(ru)) return ru;
    final cache = _cache.putIfAbsent(target, () => <String, String>{});
    final cached = cache[ru];
    if (cached != null) return cached;
    final table = _tables[target];
    var result = table?[ru];
    result ??= translateByRules(ru, target, (s) => tr(s, target));
    result ??= _translateLines(ru, target);
    result ??= _translatePrefix(ru, target);
    result ??= ru;
    if (cache.length > 4000) cache.clear();
    cache[ru] = result;
    return result;
  }

  // Многострочный текст переводим построчно, если целиком его нет в словаре.
  static String? _translateLines(String ru, String target) {
    if (!ru.contains('\n')) return null;
    final parts = ru.split('\n');
    var changed = false;
    final out = <String>[];
    for (final p in parts) {
      final t = tr(p, target);
      if (t != p) changed = true;
      out.add(t);
    }
    return changed ? out.join('\n') : null;
  }

  static final Map<String, List<String>> _prefixKeys = <String, List<String>>{};

  // «Фильтр масляный Volvo FH» → известное начало + остаток, переведённый отдельно.
  static String? _translatePrefix(String ru, String target) {
    final table = _tables[target];
    if (table == null) return null;
    final keys = _prefixKeys.putIfAbsent(target, () {
      final list = table.keys.where((k) => k.length >= 4 && !k.endsWith(' ') && !k.startsWith(' ')).toList();
      list.sort((a, b) => b.length.compareTo(a.length));
      return list;
    });
    for (final key in keys) {
      if (ru.length > key.length + 1 && ru.startsWith('$key ')) {
        final rest = ru.substring(key.length + 1);
        return '${table[key]} ${tr(rest, target)}';
      }
    }
    return null;
  }

  static bool _hasCyrillic(String s) {
    for (final unit in s.codeUnits) {
      if (unit >= 0x0400 && unit <= 0x04FF) return true;
    }
    return false;
  }
}

/// Короткий алиас для строк вне виджета Text (подсказки, валидаторы, лейблы).
String tr(String ru) => L10n.tr(ru);
