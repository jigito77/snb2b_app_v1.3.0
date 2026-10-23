import '../../../core/constants/app_config.dart';

/// Вложение сообщения (изображение или документ). Формат совпадает с `attachments[]` в ответах `/api/chat/*`.
/// Ссылка `url` подписана сервером и действует ограниченное время; при каждом обновлении чата приходит свежая.
class ChatAttachment {
  const ChatAttachment({
    required this.id,
    required this.name,
    required this.ext,
    required this.kind,
    required this.size,
    required this.at,
    required this.url,
  });

  final String id;
  final String name;
  final String ext;

  /// image | pdf | word | excel | text
  final String kind;
  final int size;
  final DateTime at;
  final String url;

  bool get isImage => kind == 'image';

  /// Полный адрес для открытия/показа (сервер отдаёт относительный путь).
  String get fullUrl => url.isEmpty ? '' : (url.startsWith('http') ? url : '${AppConfig.apiBaseUrl}$url');

  /// Адрес принудительного скачивания.
  String get downloadUrl => fullUrl.isEmpty ? '' : '$fullUrl${fullUrl.contains('?') ? '&' : '?'}dl=1';

  factory ChatAttachment.fromJson(Map<String, dynamic> j) => ChatAttachment(
        id: '${j['id'] ?? ''}',
        name: '${j['name'] ?? ''}',
        ext: '${j['ext'] ?? ''}',
        kind: '${j['kind'] ?? 'text'}',
        size: (j['size'] as num?)?.toInt() ?? 0,
        at: DateTime.tryParse('${j['at'] ?? ''}')?.toLocal() ?? DateTime.now(),
        url: '${j['url'] ?? ''}',
      );
}

/// Настройки вложений с сервера (Админка → Чат → «Файлы»). Проверки всё равно выполняет сервер.
class ChatFilesConfig {
  const ChatFilesConfig({
    this.enabled = true,
    this.maxMb = 25,
    this.exts = const <String>['jpg', 'jpeg', 'png', 'webp', 'pdf', 'doc', 'docx', 'xls', 'xlsx', 'txt'],
  });

  final bool enabled;
  final int maxMb;
  final List<String> exts;

  int get maxBytes => maxMb * 1024 * 1024;

  List<String> get docExts => exts.where((e) => <String>['pdf', 'doc', 'docx', 'txt'].contains(e)).toList();
  List<String> get excelExts => exts.where((e) => e == 'xls' || e == 'xlsx').toList();
  List<String> get imageExts => exts.where((e) => <String>['jpg', 'jpeg', 'png', 'webp'].contains(e)).toList();

  factory ChatFilesConfig.fromJson(Object? j) {
    if (j is! Map) return const ChatFilesConfig();
    final raw = j['exts'];
    return ChatFilesConfig(
      enabled: j['enabled'] != false,
      maxMb: (j['maxMb'] as num?)?.toInt() ?? 25,
      exts: raw is List ? raw.map((e) => '$e'.toLowerCase()).toList() : const ChatFilesConfig().exts,
    );
  }
}

/// MIME по расширению (сервер всё равно проверяет содержимое файла).
String chatMimeFor(String fileName) {
  final dot = fileName.lastIndexOf('.');
  final ext = dot >= 0 ? fileName.substring(dot + 1).toLowerCase() : '';
  switch (ext) {
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'png':
      return 'image/png';
    case 'webp':
      return 'image/webp';
    case 'pdf':
      return 'application/pdf';
    case 'doc':
      return 'application/msword';
    case 'docx':
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    case 'xls':
      return 'application/vnd.ms-excel';
    case 'xlsx':
      return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    case 'txt':
      return 'text/plain';
    default:
      return 'application/octet-stream';
  }
}

String chatExtOf(String fileName) {
  final dot = fileName.lastIndexOf('.');
  return dot >= 0 ? fileName.substring(dot + 1).toLowerCase() : '';
}

/// Сообщение диалога поддержки. Формат совпадает с ответами `/api/chat/*` сайта и админ-панели.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.sender,
    required this.senderName,
    required this.text,
    required this.at,
    this.readAt,
    this.attachments = const <ChatAttachment>[],
  });

  final String id;

  /// customer | agent | ai | system
  final String sender;
  final String senderName;
  final String text;
  final DateTime at;
  final DateTime? readAt;
  final List<ChatAttachment> attachments;

  bool get isMine => sender == 'customer';
  bool get isSystem => sender == 'system';

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        id: '${j['id'] ?? ''}',
        sender: '${j['sender'] ?? ''}',
        senderName: '${j['senderName'] ?? ''}',
        text: '${j['text'] ?? ''}',
        at: DateTime.tryParse('${j['at'] ?? ''}')?.toLocal() ?? DateTime.now(),
        readAt: j['readAt'] == null ? null : DateTime.tryParse('${j['readAt']}')?.toLocal(),
        attachments: j['attachments'] is List
            ? <ChatAttachment>[
                for (final a in j['attachments'] as List)
                  if (a is Map) ChatAttachment.fromJson(Map<String, dynamic>.from(a)),
              ]
            : const <ChatAttachment>[],
      );
}

/// Состояние чата: онлайн ли поддержка и сообщения текущего диалога.
class ChatState {
  const ChatState({
    this.online = false,
    this.conversationId,
    this.status = 'open',
    this.messages = const <ChatMessage>[],
    this.unread = 0,
  });

  final bool online;
  final String? conversationId;
  final String status;
  final List<ChatMessage> messages;

  /// Непрочитанные ответы поддержки.
  final int unread;

  bool get closed => status == 'closed';

  /// Разбор ответа `/api/chat/me` и `/api/chat/messages`: `{online, conversation: {...}|null}`.
  factory ChatState.fromJson(Map<String, dynamic> j) {
    final conv = j['conversation'];
    final msgs = <ChatMessage>[];
    String? id;
    var status = 'open';
    var unread = 0;
    if (conv is Map) {
      id = '${conv['id']}';
      status = '${conv['status'] ?? 'open'}';
      unread = (conv['unread'] as num?)?.toInt() ?? 0;
      final list = conv['messages'];
      if (list is List) {
        for (final m in list) {
          if (m is Map) msgs.add(ChatMessage.fromJson(Map<String, dynamic>.from(m)));
        }
      }
    }
    return ChatState(online: j['online'] == true, conversationId: id, status: status, messages: msgs, unread: unread);
  }
}
