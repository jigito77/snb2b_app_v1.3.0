import '../../../core/network/api_client.dart';
import '../../../core/utils/json_utils.dart';
import '../domain/entities/app_notification.dart';
import '../domain/repositories/notifications_repository.dart';

class NotificationsRepositoryImpl implements NotificationsRepository {
  NotificationsRepositoryImpl(this._api);

  final ApiClient _api;

  @override
  Future<List<AppNotification>> list() async {
    final json = await _api.get('/api/notifications');
    return asJson(json).list('items').map(AppNotification.fromJson).toList();
  }

  @override
  Future<void> registerDevice({required String token, required String platform}) async {
    await _api.post(
      '/api/devices',
      body: <String, dynamic>{'fcmToken': token, 'platform': platform},
    );
  }

  @override
  Future<void> saveSettings(Map<String, bool> settings) async {
    await _api.put('/api/notifications/settings', body: settings);
  }
}
