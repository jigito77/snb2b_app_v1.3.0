import 'dart:io';

import '../../../core/l10n/l10n.dart';
import '../../../core/network/api_client.dart';
import '../domain/chat_models.dart';

/// Чат поддержки: тот же backend и та же база, что у виджета на сайте и раздела «Чат» в админ-панели.
/// Авторизация — обычный Bearer-токен пользователя (диалог привязан к его аккаунту).
class ChatRepository {
  ChatRepository(this._api);

  final ApiClient _api;

  Future<ChatState> load() async {
    final j = await _api.get('/api/chat/me');
    return ChatState.fromJson(Map<String, dynamic>.from(j as Map));
  }

  /// Настройки вложений (разрешённые типы, лимит размера).
  Future<ChatFilesConfig> filesConfig() async {
    final j = await _api.get('/api/chat/status');
    return ChatFilesConfig.fromJson(j is Map ? j['files'] : null);
  }

  /// Загрузка одного файла. Файл «ждёт» отправки на сервере и привязывается к сообщению в [send].
  /// Повтор с тем же [uploadId] не создаёт дубль.
  Future<ChatAttachment> uploadFile({
    required String path,
    required String name,
    required int size,
    required String uploadId,
    void Function(int sent, int total)? onProgress,
  }) async {
    final j = await _api.upload(
      '/api/chat/files',
      data: File(path).openRead(),
      length: size,
      contentType: chatMimeFor(name),
      fileName: name,
      uploadId: uploadId,
      onProgress: onProgress,
    );
    return ChatAttachment.fromJson(Map<String, dynamic>.from((j as Map)['attachment'] as Map));
  }

  /// [clientId] один на сообщение: если ответ потерялся и пользователь нажал «Отправить» снова, дубля не будет.
  Future<ChatState> send(String text, {List<String> attachmentIds = const <String>[], String? clientId}) async {
    final j = await _api.post('/api/chat/messages', body: <String, dynamic>{
      'text': text,
      'attachments': attachmentIds,
      if (clientId != null) 'clientId': clientId,
      'lang': L10n.lang,
      'page': <String, dynamic>{'url': '/app', 'title': 'SNP mobile app', 'kind': 'other'},
    });
    return ChatState.fromJson(Map<String, dynamic>.from(j as Map));
  }

  /// Отметить ответы поддержки прочитанными. Ошибки не критичны.
  Future<void> markRead() async {
    try {
      await _api.post('/api/chat/read', body: <String, dynamic>{});
    } catch (_) {
      // не мешаем пользователю: отметка повторится при следующем обновлении
    }
  }
}
