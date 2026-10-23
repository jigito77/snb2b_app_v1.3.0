import 'package:flutter_riverpod/flutter_riverpod.dart';

/// true — последний запрос к API прошёл, false — не было сети.
class NetworkStatusNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  void set(bool online) {
    if (state != online) state = online;
  }
}

final networkStatusProvider =
    NotifierProvider<NetworkStatusNotifier, bool>(NetworkStatusNotifier.new);

/// Счётчик «сессия истекла»: HTTP-клиент увеличивает его, когда refresh token не сработал.
class SessionExpiredNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void fire() => state = state + 1;
}

final sessionExpiredProvider =
    NotifierProvider<SessionExpiredNotifier, int>(SessionExpiredNotifier.new);
