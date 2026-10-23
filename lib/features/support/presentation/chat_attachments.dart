import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:flutter/widgets.dart' as w show Text;
import 'package:url_launcher/url_launcher.dart';

import '../../../core/l10n/app_text.dart';
import '../../../core/theme/app_colors.dart';
import '../domain/chat_models.dart';

String chatFileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(bytes < 10240 ? 1 : 0)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(bytes < 10 * 1024 * 1024 ? 1 : 0)} MB';
}

String _two(int v) => v.toString().padLeft(2, '0');

String chatFileTime(DateTime d) => '${_two(d.day)}.${_two(d.month)}.${d.year} ${_two(d.hour)}:${_two(d.minute)}';

Future<void> _openExternal(String url) async {
  if (url.isEmpty) return;
  await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}

IconData chatKindIcon(String kind) {
  switch (kind) {
    case 'image':
      return Icons.image_outlined;
    case 'pdf':
      return Icons.picture_as_pdf_outlined;
    case 'word':
      return Icons.description_outlined;
    case 'excel':
      return Icons.table_chart_outlined;
    default:
      return Icons.text_snippet_outlined;
  }
}

Color chatKindColor(String kind) {
  switch (kind) {
    case 'pdf':
      return AppColors.danger;
    case 'word':
      return AppColors.info;
    case 'excel':
      return AppColors.success;
    case 'image':
      return AppColors.warning;
    default:
      return AppColors.textSecondary;
  }
}

/// Вложения сообщения: превью картинок (по тапу — полноэкранный просмотр с zoom) и карточки документов
/// с кнопками «Открыть» и «Скачать».
class ChatAttachmentsView extends StatelessWidget {
  const ChatAttachmentsView({super.key, required this.attachments, required this.mine});

  final List<ChatAttachment> attachments;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final images = attachments.where((a) => a.isImage).toList();
    final docs = attachments.where((a) => !a.isImage).toList();
    return Column(
      crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (images.isNotEmpty)
          Wrap(
            spacing: 4,
            runSpacing: 4,
            alignment: mine ? WrapAlignment.end : WrapAlignment.start,
            children: <Widget>[
              for (var i = 0; i < images.length; i++) _thumb(context, images, i),
            ],
          ),
        for (final d in docs)
          Padding(
            padding: EdgeInsets.only(top: images.isEmpty && d == docs.first ? 0 : 6),
            child: ChatDocCard(attachment: d),
          ),
      ],
    );
  }

  Widget _thumb(BuildContext context, List<ChatAttachment> images, int index) {
    final a = images[index];
    final single = images.length == 1;
    final size = single ? const Size(210, 160) : const Size(104, 104);
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(fullscreenDialog: true, builder: (_) => ChatImageViewer(images: images, initial: index)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: a.fullUrl.isEmpty
              ? _placeholder()
              : CachedNetworkImage(
                  imageUrl: a.fullUrl,
                  cacheKey: a.id, // ссылка подписана и меняется — кэшируем по id файла
                  fit: BoxFit.cover,
                  placeholder: (_, __) => _placeholder(),
                  errorWidget: (_, __, ___) => _placeholder(),
                ),
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
        color: AppColors.surfaceAlt,
        alignment: Alignment.center,
        child: const Icon(Icons.image_outlined, color: AppColors.textHint),
      );
}

/// Карточка документа (PDF, Word, Excel, TXT): иконка, имя, тип · размер · время, Открыть / Скачать.
class ChatDocCard extends StatelessWidget {
  const ChatDocCard({super.key, required this.attachment});

  final ChatAttachment attachment;

  @override
  Widget build(BuildContext context) {
    final a = attachment;
    final color = chatKindColor(a.kind);
    return Container(
      width: 250,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                child: Icon(chatKindIcon(a.kind), color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    w.Text(a.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    const SizedBox(height: 2),
                    w.Text('${a.ext.toUpperCase()} · ${chatFileSize(a.size)} · ${chatFileTime(a.at)}',
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 8)),
                  onPressed: a.fullUrl.isEmpty ? null : () => _openExternal(a.fullUrl),
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('Открыть'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 8)),
                  onPressed: a.downloadUrl.isEmpty ? null : () => _openExternal(a.downloadUrl),
                  icon: const Icon(Icons.download_outlined, size: 16),
                  label: const Text('Скачать'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Полноэкранный просмотр картинок: листание, zoom щипком и двойным тапом, имя/размер/время, открыть и скачать.
class ChatImageViewer extends StatefulWidget {
  const ChatImageViewer({super.key, required this.images, required this.initial});

  final List<ChatAttachment> images;
  final int initial;

  @override
  State<ChatImageViewer> createState() => _ChatImageViewerState();
}

class _ChatImageViewerState extends State<ChatImageViewer> {
  late final PageController _pages = PageController(initialPage: widget.initial);
  late int _index = widget.initial;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.images[_index];
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            w.Text(a.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            w.Text(
              '${chatFileSize(a.size)} · ${chatFileTime(a.at)}${widget.images.length > 1 ? ' · ${_index + 1}/${widget.images.length}' : ''}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: Colors.white70),
            ),
          ],
        ),
        actions: <Widget>[
          IconButton(
            tooltip: tr('Открыть'),
            icon: const Icon(Icons.open_in_new),
            onPressed: a.fullUrl.isEmpty ? null : () => _openExternal(a.fullUrl),
          ),
          IconButton(
            tooltip: tr('Скачать'),
            icon: const Icon(Icons.download_outlined),
            onPressed: a.downloadUrl.isEmpty ? null : () => _openExternal(a.downloadUrl),
          ),
        ],
      ),
      body: PageView.builder(
        controller: _pages,
        itemCount: widget.images.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (_, i) {
          final img = widget.images[i];
          return InteractiveViewer(
            minScale: 1,
            maxScale: 5,
            child: Center(
              child: img.fullUrl.isEmpty
                  ? const Icon(Icons.broken_image_outlined, color: Colors.white54, size: 64)
                  : CachedNetworkImage(
                      imageUrl: img.fullUrl,
                      cacheKey: img.id,
                      fit: BoxFit.contain,
                      placeholder: (_, __) => const CircularProgressIndicator(),
                      errorWidget: (_, __, ___) => const Icon(Icons.broken_image_outlined, color: Colors.white54, size: 64),
                    ),
            ),
          );
        },
      ),
    );
  }
}
