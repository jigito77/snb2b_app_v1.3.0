import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/app_notification.dart';

final notificationsProvider = FutureProvider.autoDispose<List<AppNotification>>((ref) {
  ref.watch(authControllerProvider.select((s) => s.user?.id));
  return ref.watch(notificationsRepositoryProvider).list();
});

/// Локальные настройки типов уведомлений. Дублируются на сервер (PUT /api/notifications/settings).
class NotificationSettingsNotifier extends Notifier<Map<String, bool>> {
  static const List<String> keys = <String>['orderStatus', 'priceChange', 'inStock', 'promo'];

  @override
  Map<String, bool> build() {
    final cache = ref.read(localCacheProvider);
    return <String, bool>{
      for (final k in keys) k: cache.getBool('notif.$k', fallback: true),
    };
  }

  Future<void> set(String key, bool value) async {
    state = <String, bool>{...state, key: value};
    await ref.read(localCacheProvider).setBool('notif.$key', value);
    try {
      await ref.read(notificationsRepositoryProvider).saveSettings(state);
    } catch (_) {
      // применим при следующей синхронизации настроек
    }
  }
}

final notificationSettingsProvider =
    NotifierProvider<NotificationSettingsNotifier, Map<String, bool>>(
        NotificationSettingsNotifier.new);
