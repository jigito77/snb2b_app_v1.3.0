import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class PushPayload {
  const PushPayload({this.title, this.body, this.type, this.data = const <String, dynamic>{}});

  final String? title;
  final String? body;

  /// Тип уведомления (см. NotificationType): order_shipped, price_changed, ...
  final String? type;
  final Map<String, dynamic> data;
}

/// Абстракция push-уведомлений. UI и бизнес-логика не зависят от Firebase напрямую.
abstract class PushService {
  Future<void> init();

  /// FCM-токен устройства или null, если Firebase не настроен.
  Future<String?> token();

  Stream<PushPayload> get foregroundMessages;

  Stream<String> get tokenRefreshes;

  bool get isAvailable;
}

/// Обработчик фоновых сообщений должен быть top-level функцией.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

class FcmPushService implements PushService {
  final StreamController<PushPayload> _messages = StreamController<PushPayload>.broadcast();
  final StreamController<String> _tokens = StreamController<String>.broadcast();
  bool _ready = false;

  @override
  bool get isAvailable => _ready;

  @override
  Stream<PushPayload> get foregroundMessages => _messages.stream;

  @override
  Stream<String> get tokenRefreshes => _tokens.stream;

  @override
  Future<void> init() async {
    try {
      // Требует google-services.json (Android) / GoogleService-Info.plist (iOS).
      // Без них инициализация бросает исключение — приложение продолжает работать без push.
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();
      FirebaseMessaging.onMessage.listen((RemoteMessage m) {
        _messages.add(PushPayload(
          title: m.notification?.title,
          body: m.notification?.body,
          type: m.data['type']?.toString(),
          data: Map<String, dynamic>.from(m.data),
        ));
      });
      messaging.onTokenRefresh.listen(_tokens.add);
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  @override
  Future<String?> token() async {
    if (!_ready) return null;
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (_) {
      return null;
    }
  }
}
