import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:flutter/widgets.dart' as w show Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/di.dart';
import '../../../core/l10n/app_text.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/state_views.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../data/chat_repository.dart';
import '../domain/chat_models.dart';
import 'chat_attachments.dart';

enum _UpState { uploading, done, failed }

/// Файл, выбранный для отправки: загружается на сервер сразу, к сообщению привязывается при отправке.
class _Pending {
  _Pending({required this.id, required this.name, required this.size, required this.path});

  final String id; // uploadId: повтор запроса не создаёт дубль на сервере
  final String name;
  final int size;
  final String path;
  _UpState state = _UpState.uploading;
  double progress = 0;
  String? error;
  ChatAttachment? attachment;

  bool get isImage => <String>['jpg', 'jpeg', 'png', 'webp'].contains(chatExtOf(name));
}

final chatRepositoryProvider = Provider<ChatRepository>((ref) => ChatRepository(ref.watch(apiClientProvider)));

/// Онлайн-поддержка: переписка с реальным оператором. Обновление — опрос раз в 3 секунды,
/// пока экран открыт (ответ приходит и в «Уведомления», если приложение закрыто).
class SupportChatPage extends ConsumerStatefulWidget {
  const SupportChatPage({super.key});

  @override
  ConsumerState<SupportChatPage> createState() => _SupportChatPageState();
}

class _SupportChatPageState extends ConsumerState<SupportChatPage> with WidgetsBindingObserver {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  Timer? _timer;
  ChatState _chat = const ChatState();
  bool _loading = true;
  bool _sending = false;
  Object? _error;
  ChatFilesConfig _files = const ChatFilesConfig();
  final List<_Pending> _pending = <_Pending>[];
  final ImagePicker _imagePicker = ImagePicker();
  String? _clientId; // один на сообщение, живёт до успешной отправки

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (ref.read(authControllerProvider).isAuthenticated) {
      _refresh(initial: true);
      unawaited(_loadFilesConfig());
      _timer = Timer.periodic(const Duration(seconds: 3), (_) => _refresh());
    } else {
      _loading = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _timer != null) _refresh();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _refresh({bool initial = false}) async {
    try {
      final next = await ref.read(chatRepositoryProvider).load();
      if (!mounted) return;
      final grew = next.messages.length != _chat.messages.length;
      setState(() {
        _chat = next;
        _loading = false;
        _error = null;
      });
      if (next.unread > 0) unawaited(ref.read(chatRepositoryProvider).markRead());
      if (grew || initial) _toBottom();
    } catch (e) {
      if (!mounted) return;
      if (initial || _chat.messages.isEmpty) {
        setState(() {
          _loading = false;
          _error = e;
        });
      }
    }
  }

  Future<void> _loadFilesConfig() async {
    try {
      final c = await ref.read(chatRepositoryProvider).filesConfig();
      if (mounted) setState(() => _files = c);
    } catch (_) {
      // настройки по умолчанию; финальную проверку всё равно делает сервер
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: w.Text(message)));
  }

  Future<void> _showPicker() async {
    final c = _files;
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (c.imageExts.isNotEmpty) ListTile(leading: const Icon(Icons.photo_library_outlined), title: const Text('Галерея / Фото'), onTap: () => Navigator.pop(ctx, 'gallery')),
            if (c.imageExts.isNotEmpty) ListTile(leading: const Icon(Icons.photo_camera_outlined), title: const Text('Камера'), onTap: () => Navigator.pop(ctx, 'camera')),
            if (c.docExts.isNotEmpty) ListTile(leading: const Icon(Icons.description_outlined), title: const Text('Документ (PDF, Word, TXT)'), onTap: () => Navigator.pop(ctx, 'doc')),
            if (c.excelExts.isNotEmpty) ListTile(leading: const Icon(Icons.table_chart_outlined), title: const Text('Excel (XLS, XLSX)'), onTap: () => Navigator.pop(ctx, 'excel')),
          ],
        ),
      ),
    );
    if (choice != null) await _pick(choice);
  }

  Future<void> _pick(String kind) async {
    try {
      final picked = <_Pending>[];
      Future<void> addPath(String path, String name) async {
        final size = await File(path).length();
        picked.add(_Pending(id: _newId(), name: name, size: size, path: path));
      }

      if (kind == 'gallery') {
        final xs = await _imagePicker.pickMultiImage();
        for (final x in xs) {
          await addPath(x.path, x.name.isEmpty ? 'photo.jpg' : x.name);
        }
      } else if (kind == 'camera') {
        final x = await _imagePicker.pickImage(source: ImageSource.camera);
        if (x != null) await addPath(x.path, x.name.isEmpty ? 'photo.jpg' : x.name);
      } else {
        final r = await FilePicker.platform.pickFiles(
          allowMultiple: true,
          type: FileType.custom,
          allowedExtensions: kind == 'excel' ? _files.excelExts : _files.docExts,
        );
        if (r != null) {
          for (final f in r.files) {
            final path = f.path;
            if (path != null) await addPath(path, f.name);
          }
        }
      }
      _addFiles(picked);
    } catch (_) {
      _snack(tr('Не удалось выбрать файл'));
    }
  }

  String _newId() => '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${Random().nextInt(1 << 30).toRadixString(36)}';

  void _addFiles(List<_Pending> files) {
    if (!_files.enabled) {
      _snack(tr('Отправка файлов отключена'));
      return;
    }
    final errors = <String>[];
    for (final f in files) {
      if (_pending.length >= 10) {
        errors.add(tr('Не более 10 файлов в сообщении'));
        break;
      }
      if (!_files.exts.contains(chatExtOf(f.name))) {
        errors.add('${f.name}: ${tr('Тип файла не поддерживается')}');
        continue;
      }
      if (f.size <= 0) {
        errors.add('${f.name}: ${tr('Пустой файл')}');
        continue;
      }
      if (f.size > _files.maxBytes) {
        errors.add('${f.name}: ${tr('Файл слишком большой')} (${tr('Максимум')} ${_files.maxMb} MB)');
        continue;
      }
      setState(() => _pending.add(f));
      unawaited(_upload(f));
    }
    if (errors.isNotEmpty) _snack(errors.take(3).join('\n'));
  }

  Future<void> _upload(_Pending p) async {
    if (mounted) {
      setState(() {
        p.state = _UpState.uploading;
        p.progress = 0;
        p.error = null;
      });
    }
    try {
      final att = await ref.read(chatRepositoryProvider).uploadFile(
            path: p.path,
            name: p.name,
            size: p.size,
            uploadId: p.id,
            onProgress: (sent, total) {
              if (mounted && total > 0) setState(() => p.progress = sent / total);
            },
          );
      p.attachment = att;
      p.state = _UpState.done;
      p.progress = 1;
    } catch (e) {
      p.state = _UpState.failed;
      p.error = e is AppException && e.kind == ErrorKind.validation ? e.message : 'Не удалось загрузить файл';
    }
    if (mounted) setState(() {});
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    });
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (_sending) return;
    if (_pending.any((p) => p.state == _UpState.uploading)) {
      _snack(tr('Дождитесь окончания загрузки файлов'));
      return;
    }
    if (_pending.any((p) => p.state == _UpState.failed)) {
      _snack(tr('Повторите или уберите файлы с ошибкой'));
      return;
    }
    final ids = <String>[for (final p in _pending) if (p.attachment != null) p.attachment!.id];
    if (text.isEmpty && ids.isEmpty) return;
    _clientId ??= _newId();
    setState(() => _sending = true);
    try {
      final next = await ref.read(chatRepositoryProvider).send(text, attachmentIds: ids, clientId: _clientId);
      if (!mounted) return;
      _input.clear();
      _clientId = null;
      _pending.clear();
      setState(() => _chat = next);
      _toBottom();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('Не удалось отправить сообщение. Попробуйте ещё раз.')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('Онлайн-поддержка'),
            if (auth.isAuthenticated)
              Row(
                children: <Widget>[
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: _chat.online ? AppColors.success : AppColors.textHint),
                  ),
                  const SizedBox(width: 6),
                  Text(_chat.online ? 'Поддержка онлайн' : 'Поддержка не в сети', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400)),
                ],
              ),
          ],
        ),
      ),
      body: !auth.isAuthenticated
          ? EmptyState(
              icon: Icons.support_agent,
              title: 'Чат с поддержкой',
              message: 'Войдите в аккаунт, чтобы написать в поддержку.',
              actionLabel: 'Войти',
              onAction: () => context.push('/login'),
            )
          : _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? ErrorState(error: _error!, onRetry: () {
                      setState(() {
                        _loading = true;
                        _error = null;
                      });
                      _refresh(initial: true);
                    })
                  : _body(),
    );
  }

  Widget _body() {
    final note = _chat.closed
        ? 'Диалог закрыт. Напишите — мы начнём новый.'
        : (!_chat.online ? 'Сейчас мы не в сети. Оставьте сообщение — ответим, как только вернёмся.' : null);
    return Column(
      children: <Widget>[
        Expanded(
          child: ListView(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            children: <Widget>[
              _bubble(
                mine: false,
                child: const Text('Здравствуйте! Чем можем помочь? Напишите VIN, OEM или номер детали — подберём.'),
                accent: true,
              ),
              for (final m in _chat.messages) _messageRow(m),
            ],
          ),
        ),
        if (note != null)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(color: AppColors.accentSoft, border: Border(left: BorderSide(color: AppColors.accent, width: 3))),
            child: Text(note, style: const TextStyle(fontSize: 13)),
          ),
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            decoration: const BoxDecoration(color: AppColors.surface, border: Border(top: BorderSide(color: AppColors.border))),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (_pending.isNotEmpty) _tray(),
                Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                if (_files.enabled)
                  IconButton(
                    tooltip: tr('Прикрепить файл'),
                    onPressed: _sending ? null : _showPicker,
                    icon: const Icon(Icons.attach_file),
                  ),
                Expanded(
                  child: TextField(
                    controller: _input,
                    minLines: 1,
                    maxLines: 5,
                    maxLength: 2000,
                    textInputAction: TextInputAction.newline,
                    decoration: InputDecoration(
                      hintText: tr('Напишите ваш вопрос'),
                      counterText: '',
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 46,
                  width: 46,
                  child: FilledButton(
                    style: FilledButton.styleFrom(padding: EdgeInsets.zero, backgroundColor: AppColors.accent, foregroundColor: AppColors.onAccent),
                    onPressed: _sending ? null : _send,
                    child: _sending
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.send_rounded, size: 20),
                  ),
                ),
              ],
            ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Лоток выбранных файлов: превью/иконка, имя, прогресс загрузки, ошибка с «Повторить», «Убрать».
  Widget _tray() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 170),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.only(bottom: 8),
        children: <Widget>[for (final p in _pending) _pendingTile(p)],
      ),
    );
  }

  Widget _pendingTile(_Pending p) {
    final failed = p.state == _UpState.failed;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: failed ? AppColors.dangerSoft : AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: failed ? AppColors.danger : AppColors.border),
      ),
      child: Row(
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              width: 40,
              height: 40,
              child: p.isImage
                  ? Image.file(File(p.path), fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.image_outlined))
                  : Icon(chatKindIcon(_kindOfName(p.name)), color: chatKindColor(_kindOfName(p.name))),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                w.Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                if (p.state == _UpState.uploading) ...<Widget>[
                  const SizedBox(height: 3),
                  w.Text('${tr('Загрузка...')} ${(p.progress * 100).round()}%', style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                  const SizedBox(height: 3),
                  LinearProgressIndicator(value: p.progress <= 0 ? null : p.progress, minHeight: 3),
                ] else if (failed)
                  w.Text(tr(p.error ?? 'Не удалось загрузить файл'), style: const TextStyle(fontSize: 11.5, color: AppColors.danger))
                else
                  w.Text(chatFileSize(p.size), style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
              ],
            ),
          ),
          if (failed)
            TextButton(
              onPressed: () => _upload(p),
              child: const Text('Повторить'),
            ),
          IconButton(
            tooltip: tr('Убрать'),
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => setState(() => _pending.remove(p)),
          ),
        ],
      ),
    );
  }

  String _kindOfName(String name) {
    final e = chatExtOf(name);
    if (e == 'pdf') return 'pdf';
    if (e == 'doc' || e == 'docx') return 'word';
    if (e == 'xls' || e == 'xlsx') return 'excel';
    return 'text';
  }

  String _time(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  Widget _messageRow(ChatMessage m) {
    if (m.isSystem) {
      final label = m.text == 'closed' ? 'Диалог закрыт' : (m.text == 'reopened' ? 'Диалог возобновлён' : m.text);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Center(child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
      );
    }
    final mine = m.isMine;
    // Текст сообщения — пользовательский: показываем как есть, без перевода интерфейса.
    if (m.text.isEmpty && m.attachments.isNotEmpty) {
      // сообщение только с файлами: без тёмного пузыря, карточки сами оформлены
      return Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          child: Column(
            crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: <Widget>[
              ChatAttachmentsView(attachments: m.attachments, mine: mine),
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: w.Text(
                  '${mine ? '' : '${m.senderName.isEmpty ? tr('Поддержка') : m.senderName} · '}${_time(m.at)}${mine ? (m.readAt != null ? '  ✓✓' : '  ✓') : ''}',
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return _bubble(
      mine: mine,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          w.Text(m.text, style: TextStyle(fontSize: 14.5, height: 1.35, color: mine ? Colors.white : AppColors.textPrimary)),
          if (m.attachments.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            ChatAttachmentsView(attachments: m.attachments, mine: mine),
          ],
        ],
      ),
      footer: '${mine ? '' : '${m.senderName.isEmpty ? tr('Поддержка') : m.senderName} · '}${_time(m.at)}${mine ? (m.readAt != null ? '  ✓✓' : '  ✓') : ''}',
    );
  }

  Widget _bubble({required bool mine, required Widget child, String? footer, bool accent = false}) {
    final maxW = MediaQuery.of(context).size.width * 0.78;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: BoxConstraints(maxWidth: maxW),
        child: Column(
          crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
              decoration: BoxDecoration(
                color: mine ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: mine ? null : Border.all(color: AppColors.border),
                boxShadow: accent ? const <BoxShadow>[] : null,
              ),
              child: child,
            ),
            if (footer != null)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: w.Text(footer, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ),
          ],
        ),
      ),
    );
  }
}
