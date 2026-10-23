import 'package:flutter_test/flutter_test.dart';
import 'package:snb2b_app/features/support/domain/chat_models.dart';

void main() {
  test('ChatState разбирает ответ /api/chat/me', () {
    final s = ChatState.fromJson(<String, dynamic>{
      'online': true,
      'conversation': <String, dynamic>{
        'id': 'c1',
        'status': 'open',
        'unread': 2,
        'messages': <Map<String, dynamic>>[
          <String, dynamic>{'id': 'm1', 'sender': 'customer', 'senderName': 'A', 'text': 'Hello', 'at': '2026-10-22T10:00:00.000Z', 'readAt': null},
          <String, dynamic>{'id': 'm2', 'sender': 'agent', 'senderName': 'admin', 'text': 'Hi', 'at': '2026-10-22T10:01:00.000Z', 'readAt': null},
        ],
      },
    });
    expect(s.online, true);
    expect(s.conversationId, 'c1');
    expect(s.unread, 2);
    expect(s.messages.length, 2);
    expect(s.messages.first.isMine, true);
    expect(s.messages.last.isMine, false);
  });

  test('ChatState без диалога', () {
    final s = ChatState.fromJson(<String, dynamic>{'online': false, 'conversation': null});
    expect(s.conversationId, null);
    expect(s.messages, isEmpty);
    expect(s.closed, false);
  });

  test('Сообщение с вложениями разбирается (картинка и Excel)', () {
    final s = ChatState.fromJson(<String, dynamic>{
      'online': true,
      'conversation': <String, dynamic>{
        'id': 'c1',
        'status': 'open',
        'messages': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'm1',
            'sender': 'agent',
            'senderName': 'admin',
            'text': '',
            'at': '2026-10-22T10:00:00.000Z',
            'attachments': <Map<String, dynamic>>[
              <String, dynamic>{'id': 'f1', 'name': 'photo.png', 'ext': 'png', 'mime': 'image/png', 'kind': 'image', 'size': 2048, 'at': '2026-10-22T10:00:00.000Z', 'url': '/api/chat/f/f1?e=1&s=x'},
              <String, dynamic>{'id': 'f2', 'name': 'products.xlsx', 'ext': 'xlsx', 'kind': 'excel', 'size': 2400000, 'at': '2026-10-22T10:00:00.000Z', 'url': '/api/chat/f/f2?e=1&s=y'},
            ],
          },
          <String, dynamic>{'id': 'm2', 'sender': 'customer', 'senderName': 'A', 'text': 'ok', 'at': '2026-10-22T10:01:00.000Z'},
        ],
      },
    });
    final m = s.messages.first;
    expect(m.attachments.length, 2);
    expect(m.attachments.first.isImage, true);
    expect(m.attachments.last.isImage, false);
    expect(m.attachments.last.kind, 'excel');
    expect(m.attachments.last.size, 2400000);
    expect(m.attachments.first.downloadUrl.endsWith('&dl=1'), true);
    expect(s.messages.last.attachments, isEmpty);
  });

  test('Настройки вложений и MIME по расширению', () {
    final c = ChatFilesConfig.fromJson(<String, dynamic>{'enabled': true, 'maxMb': 10, 'exts': <String>['jpg', 'pdf', 'xlsx']});
    expect(c.maxBytes, 10 * 1024 * 1024);
    expect(c.imageExts, <String>['jpg']);
    expect(c.docExts, <String>['pdf']);
    expect(c.excelExts, <String>['xlsx']);
    expect(ChatFilesConfig.fromJson(null).maxMb, 25);
    expect(chatMimeFor('Report.XLSX'), contains('spreadsheetml'));
    expect(chatMimeFor('a.png'), 'image/png');
    expect(chatMimeFor('x.exe'), 'application/octet-stream');
    expect(chatExtOf('a.b.PDF'), 'pdf');
  });
}
