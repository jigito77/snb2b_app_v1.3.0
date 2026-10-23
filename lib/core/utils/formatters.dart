import 'dart:async';

import '../constants/app_config.dart';
import '../l10n/l10n.dart';
import 'currency.dart';

class Fmt {
  Fmt._();

  /// Сумма в выбранной валюте (backend считает сам; в режиме Mock — из рублей): 12345.5 → "12 345,50 ₽" / "144,04 $" / "52 156 ֏".
  /// [currency] — принудительная валюта (например, 'RUB' для фильтров и сообщения менеджеру).
  static String price(num value, {String? currency}) {
    final c = currency == null ? AppCurrency.current : AppCurrency.byCode(currency);
    // Реальный backend отдаёт суммы уже в выбранной валюте (заголовок X-Currency), курсы считает сервер.
    // Конвертация на устройстве нужна только встроенному Mock API (цены в рублях).
    final v = AppConfig.useMockApi ? value * c.perRub : value;
    final isWhole = c.decimals == 0 || v == v.roundToDouble();
    final s = c.decimals == 0 ? v.round().toString() : (isWhole ? v.round().toString() : v.toStringAsFixed(c.decimals));
    final parts = s.split('.');
    final intPart = parts[0];
    final buf = StringBuffer();
    for (var i = 0; i < intPart.length; i++) {
      final fromEnd = intPart.length - i;
      buf.write(intPart[i]);
      if (fromEnd > 1 && fromEnd % 3 == 1) buf.write(' ');
    }
    if (parts.length > 1) buf.write(',${parts[1]}');
    buf.write(' ${c.symbol}');
    return buf.toString();
  }

  /// Вес в кг: 0.9 → "0,9", 16.8 → "16,8", 2 → "2".
  static String kg(num? v) {
    if (v == null) return '—';
    var s = v.toDouble().toStringAsFixed(3);
    s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
    return s.replaceAll('.', ',');
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  static String date(DateTime d) => '${_two(d.day)}.${_two(d.month)}.${d.year}';

  static String dateTime(DateTime d) => '${date(d)} ${_two(d.hour)}:${_two(d.minute)}';

  /// Русские формы слова; на других языках результат переводится по словарю.
  static String plural(int n, String one, String few, String many) {
    final n10 = n % 10;
    final n100 = n % 100;
    String form;
    if (n10 == 1 && n100 != 11) {
      form = one;
    } else if (n10 >= 2 && n10 <= 4 && (n100 < 12 || n100 > 14)) {
      form = few;
    } else {
      form = many;
    }
    if (L10n.lang == 'en') {
      // В английском: единственное число только для 1.
      return L10n.tr(n == 1 ? one : many);
    }
    return L10n.tr(form);
  }

  static String products(int n) => '$n ${plural(n, 'товар', 'товара', 'товаров')}';

  static String pieces(int n) => '$n шт.';

  static String days(int min, int max) {
    if (min == max) return '$min ${plural(min, 'день', 'дня', 'дней')}';
    return '$min–$max ${plural(max, 'день', 'дня', 'дней')}';
  }
}

/// Откладывает вызов, пока пользователь продолжает вводить данные.
class Debouncer {
  Debouncer(this.milliseconds);

  final int milliseconds;
  Timer? _timer;

  void run(void Function() action) {
    _timer?.cancel();
    _timer = Timer(Duration(milliseconds: milliseconds), action);
  }

  void cancel() => _timer?.cancel();
}
