import 'contacts.dart';

/// Конфигурация приложения. Значения переопределяются при сборке:
///
/// flutter run --dart-define=USE_MOCK_API=false --dart-define=API_BASE_URL=https://api.your-domain.ru
class AppConfig {
  AppConfig._();

  static const String appName = 'SNP';

  /// Базовый URL реального backend (без завершающего слэша и без /api).
  static const String apiBaseUrl =
      String.fromEnvironment('API_BASE_URL', defaultValue: 'https://api.example.com');

  /// true — данные берутся из встроенного Mock API, false — из реального backend.
  static const bool useMockApi = bool.fromEnvironment('USE_MOCK_API', defaultValue: true);

  static const String supportPhone =
      String.fromEnvironment('SUPPORT_PHONE', defaultValue: Contacts.phoneArmenia);

  /// Если пусто — email в контактах не показывается.
  static const String supportEmail = String.fromEnvironment('SUPPORT_EMAIL', defaultValue: Contacts.email);

  static const String websiteUrl = Contacts.website;

  static const int pageSize = 20;
  static const int searchDebounceMs = 350;
  static const int maxCompareItems = 4;
}
