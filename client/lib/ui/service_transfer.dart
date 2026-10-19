import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../app_model.dart';
import '../data/library.dart';
import '../data/link_transfer.dart';
import '../data/music_link.dart';
import '../data/yandex_page.dart';
import 'cosmos.dart';

class ServiceTransferActions extends StatefulWidget {
  final AppModel model;
  final MusicService service;
  final Future<dynamic> Function(String) execute;
  final ValueChanged<bool> onBusy;
  const ServiceTransferActions({
    super.key,
    required this.model,
    required this.service,
    required this.execute,
    required this.onBusy,
  });
  @override
  State<ServiceTransferActions> createState() => ServiceTransferActionsState();
}

class ServiceTransferActionsState extends State<ServiceTransferActions> {
  bool busy = false, _cancelled = false, saving = false;
  String? message;
  Future<void> _run(Future<void> Function() action) async {
    if (busy) return;
    _cancelled = false;
    setState(() {
      busy = true;
      message = null;
    });
    widget.onBusy(true);
    try {
      await action();
    } on TransferCancelled {
      if (mounted) {
        setState(() => message = 'Перенос отменён. Библиотека не изменена');
      }
    } catch (e) {
      if (mounted) {
        setState(() => message = 'Не удалось выполнить действие: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
          saving = false;
        });
        widget.onBusy(false);
      }
    }
  }

  Future<ServiceTrack> _current() async {
    if (widget.service == MusicService.yandex) {
      return YandexPage(widget.execute).currentTrack();
    }
    final raw = await widget.execute(
      'JSON.stringify({url:location.href,title:document.querySelector("h1")?.innerText||document.title})',
    );
    final data = jsonDecode(raw as String) as Map<String, dynamic>;
    final link = MusicLink.parse(data['url'] as String);
    if (link.service != widget.service || link.kind != 'track') {
      throw const FormatException('Откройте страницу конкретного трека');
    }
    final title = (data['title'] as String).trim();
    return ServiceTrack.fromMap({
      'url': link.uri.toString(),
      'title': title.length > 160 ? title.substring(0, 160) : title,
    });
  }

  Future<void> addTrack() => _run(() async {
    final track = await _current();
    if (!mounted || _cancelled) return;
    final action = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Трек в OPTIMUM'),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(track.title, style: const TextStyle(fontSize: 18)),
              const SizedBox(height: 10),
              Text(
                track.link.uri.toString(),
                style: const TextStyle(fontSize: 12, color: muted),
              ),
              const SizedBox(height: 14),
              const Text(
                'Добавление сохраняет название и ссылку для прослушивания через ваш аккаунт сервиса. Для офлайна можно прикрепить собственный аудиофайл.',
                style: TextStyle(color: muted),
              ),
              if (widget.service == MusicService.yandex) ...[
                const SizedBox(height: 10),
                const Text(
                  'Яндекс не предоставляет отдельный MP3: его скачанные записи зашифрованы для приложения Яндекса.',
                  style: TextStyle(fontSize: 12, color: muted),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'file'),
            child: const Text('Прикрепить аудиофайл'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'save'),
            child: const Text('Добавить в OPTIMUM'),
          ),
        ],
      ),
    );
    if (action == null || !mounted) return;
    String? filePath;
    if (action == 'file') {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: audioExtensions,
        dialogTitle: 'Аудиофайл для ${track.title}',
      );
      if (file?.path == null) return;
      filePath = file!.path;
    }
    if (!mounted || _cancelled) throw const TransferCancelled();
    setState(() => saving = true);
    final existed = widget.model.links.any((s) => s.link.uri == track.link.uri);
    await widget.model.store.saveLink(track.link, track.title);
    if (filePath != null) {
      final saved = (await widget.model.store.links()).firstWhere(
        (s) => s.link.uri == track.link.uri,
      );
      await widget.model.store.linkDownload(saved.id, filePath, track.title);
    }
    await widget.model.refresh();
    if (mounted) {
      setState(
        () => message = filePath != null
            ? 'Трек и аудиофайл добавлены. Доступен офлайн в Библиотека → По ссылке'
            : existed
            ? 'Трек уже есть в Библиотека → По ссылке'
            : 'Трек добавлен в Библиотека → По ссылке',
      );
    }
  });
  Future<void> transferPlaylist() => _run(() async {
    final transfer = await YandexPage(widget.execute).playlist(
      cancelled: () => _cancelled || !mounted,
      progress: (read, total) {
        if (mounted) {
          setState(
            () => message =
                'Проверено позиций: $read из $total. Не переключайте страницу',
          );
        }
      },
    );
    if (!mounted || _cancelled) throw const TransferCancelled();
    final previous = (await widget.model.store.db.query(
      'playlists',
      columns: ['id'],
      where: 'source_url=?',
      whereArgs: [transfer.source.uri.toString()],
    )).isNotEmpty;
    if (!mounted) return;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (_) => _TransferPreview(transfer: transfer, updating: previous),
    );
    if (accepted != true || !mounted) {
      if (mounted) {
        setState(() => message = 'Перенос отменён. Библиотека не изменена');
      }
      return;
    }
    setState(() => saving = true);
    await widget.model.store.importLinkPlaylist(transfer);
    await widget.model.refresh();
    if (mounted) {
      setState(
        () => message =
            'Плейлист ${previous ? 'обновлён' : 'добавлен'}: ${transfer.name}, ${transfer.tracks.length} треков. Откройте раздел «Плейлисты»',
      );
    }
  });
  @override
  void dispose() {
    _cancelled = true;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: busy ? null : addTrack,
              icon: const Icon(Icons.playlist_add, size: 18),
              label: const Text('Добавить текущий трек'),
            ),
            if (widget.service == MusicService.yandex)
              FilledButton.icon(
                onPressed: busy ? null : transferPlaylist,
                icon: const Icon(Icons.library_add_outlined, size: 18),
                label: const Text('Перенести плейлист'),
              ),
            if (busy)
              TextButton(
                onPressed: saving
                    ? null
                    : () => setState(() => _cancelled = true),
                child: Text(saving ? 'Сохраняем…' : 'Отменить перенос'),
              ),
          ],
        ),
        if (busy) const LinearProgressIndicator(minHeight: 2),
        if (message != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(message!, style: const TextStyle(fontSize: 12)),
          ),
        const SizedBox(height: 5),
        const Text(
          'В OPTIMUM переносятся названия, порядок и ссылки. Аудиофайлы сервиса автоматически не скачиваются.',
          style: TextStyle(fontSize: 11, color: muted),
        ),
      ],
    ),
  );
}

class _TransferPreview extends StatelessWidget {
  final PlaylistTransfer transfer;
  final bool updating;
  const _TransferPreview({required this.transfer, required this.updating});
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      updating
          ? 'Обновить плейлист в OPTIMUM?'
          : 'Перенести плейлист в OPTIMUM?',
    ),
    content: SizedBox(
      width: 560,
      height: 420,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(transfer.name, style: const TextStyle(fontSize: 20)),
          Text(
            '${transfer.tracks.length} треков · полный список проверен',
            style: const TextStyle(color: muted),
          ),
          const SizedBox(height: 10),
          const Text(
            'Сохранятся названия, порядок и ссылки. Воспроизведение — через аккаунт Яндекс Музыки; это не скачивание аудио.',
            style: TextStyle(fontSize: 12, color: muted),
          ),
          if (updating)
            const Text(
              'Текущий состав ссылок этого плейлиста будет заменён новым снимком.',
              style: TextStyle(fontSize: 12, color: Colors.orangeAccent),
            ),
          const Divider(),
          Expanded(
            child: ListView.builder(
              itemCount: transfer.tracks.length,
              itemBuilder: (_, i) => ListTile(
                dense: true,
                leading: Text('${i + 1}'),
                title: Text(
                  transfer.tracks[i].title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: const Text('Отмена'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, true),
        child: Text(
          updating
              ? 'Обновить состав'
              : 'Перенести ${transfer.tracks.length} треков',
        ),
      ),
    ],
  );
}
