/// Валюты отображения цен. Все цены в каталоге хранятся в рублях (₽).
/// Курсы подтягиваются из интернета (ЦБ РФ, см. rates_service.dart), а если сети нет —
/// берутся последние сохранённые, либо запасные из этого файла.
class AppCurrency {
  const AppCurrency(this.code, this.symbol, this.name, this.fallbackPerRub, this.decimals);

  final String code;
  final String symbol;
  final String name;

  /// Запасной курс (единиц валюты в 1 ₽) на 07.10.2026 — если нет ни сети, ни сохранённого курса.
  final double fallbackPerRub;

  /// Знаков после запятой при показе.
  final int decimals;

  /// Актуальные курсы (единиц валюты в 1 ₽), заполняются из сети/кэша.
  static final Map<String, double> rates = <String, double>{};

  /// Дата курса ЦБ (как пришла с сервера), если загружен.
  static String? ratesDate;

  double get perRub => code == 'RUB' ? 1 : (rates[code] ?? fallbackPerRub);

  static const AppCurrency rub = AppCurrency('RUB', '₽', 'Российский рубль', 1, 2);
  static const AppCurrency amd = AppCurrency('AMD', '֏', 'Армянский драм', 100 / 23.6681, 0);
  static const AppCurrency usd = AppCurrency('USD', r'$', 'Доллар США', 1 / 85.7116, 2);
  static const AppCurrency eur = AppCurrency('EUR', '€', 'Евро', 1 / 96.0313, 2);

  static const List<AppCurrency> all = <AppCurrency>[rub, amd, usd, eur];

  static AppCurrency byCode(String? code) =>
      all.firstWhere((c) => c.code == code, orElse: () => rub);

  /// Текущая валюта интерфейса (обновляется провайдером; доступна вне виджетов).
  static AppCurrency current = rub;
}
