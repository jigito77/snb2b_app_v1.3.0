import '../entities/app_notification.dart';

abstract class NotificationsRepository {
  Future<List<AppNotification>> list();

  /// Регистрация FCM-токена устройства на backend.
  Future<void> registerDevice({required String token, required String platform});

  Future<void> saveSettings(Map<String, bool> settings);
}
