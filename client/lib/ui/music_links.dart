import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_windows/webview_windows.dart';
import '../app_model.dart';
import '../data/audio_download.dart';
import '../data/music_link.dart';
import '../data/link_resolver.dart';
import '../data/service_account.dart';
import '../playback/model.dart';
import 'cosmos.dart';
import 'web_profile.dart';

Future<void> openMusicLink(
  BuildContext context,
  AppModel model,
  PlaybackModel player,
  SavedMusicLink saved,
) async {
  await player.stop();
  if (!context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ServicePlayer(saved: saved, model: model),
    ),
  );
}

Future<void> importMusicLink(
  BuildContext context,
  AppModel model,
  PlaybackModel player,
) async {
  final saved = await showDialog<SavedMusicLink>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _LinkDialog(model: model),
  );
  if (saved != null && context.mounted) {
    await openMusicLink(context, model, player, saved);
  }
}

class _LinkDialog extends StatefulWidget {
  final AppModel model;
  const _LinkDialog({required this.model});
  @override
  State<_LinkDialog> createState() => _LinkDialogState();
}

class _LinkDialogState extends State<_LinkDialog> {
  final url = TextEditingController(), title = TextEditingController();
  String? error;
  bool saving = false;
  Future<void> save(bool play) async {
    if (saving) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final link = await resolveMusicLink(url.text);
      await widget.model.store.saveLink(link, title.text);
      await widget.model.refresh();
      final saved = widget.model.links.firstWhere(
        (s) => s.link.uri == link.uri,
      );
      if (mounted) Navigator.pop(context, play ? saved : null);
    } catch (e) {
      if (mounted) {
        setState(() {
          error = '$e';
          saving = false;
        });
      }
    }
  }

  @override
  void dispose() {
    url.dispose();
    title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Музыка по ссылке'),
    content: SizedBox(
      width: 490,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Spotify · Яндекс Музыка · SoundCloud',
              style: TextStyle(color: muted),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: url,
              autofocus: true,
              enabled: !saving,
              maxLength: 4096,
              decoration: const InputDecoration(
                labelText: 'Ссылка на трек или плейлист',
                hintText: 'https://…',
                counterText: '',
              ),
              onSubmitted: (_) => save(true),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: title,
              enabled: !saving,
              maxLength: 160,
              decoration: const InputDecoration(
                labelText: 'Ваше название (необязательно)',
              ),
            ),
            const Text(
              'Сохраняется ссылка. Музыка играет в плеере сервиса внутри OPTIMUM; доступ зависит от сервиса и аккаунта. Состав плейлиста не копируется в локальные треки.',
              style: TextStyle(fontSize: 12, color: muted),
            ),
            const SizedBox(height: 10),
            const Text(
              'Для скачивания вставьте прямую HTTPS-ссылку на аудиофайл. Файлы останутся на устройстве для прослушивания без сети.',
              style: TextStyle(fontSize: 12, color: muted),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  error!,
                  style: const TextStyle(color: Colors.orangeAccent),
                ),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: saving ? null : () => Navigator.pop(context),
        child: const Text('Отмена'),
      ),
      TextButton(
        onPressed: saving ? null : () => save(false),
        child: const Text('Сохранить ссылку'),
      ),
      FilledButton(
        onPressed: saving ? null : () => save(true),
        child: Text(saving ? 'Сохраняем…' : 'Сохранить и открыть'),
      ),
    ],
  );
}

class MusicLinksView extends StatelessWidget {
  final AppModel model;
  final PlaybackModel player;
  final String search;
  const MusicLinksView({
    super.key,
    required this.model,
    required this.player,
    this.search = '',
  });
  @override
  Widget build(BuildContext context) {
    final links = model.links
        .where(
          (s) => '${s.title} ${s.link.provider} ${s.link.uri}'
              .toLowerCase()
              .contains(search.toLowerCase()),
        )
        .toList();
    if (links.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(28),
          child: Text(
            'Сохраните трек или плейлист по ссылке.\nДля прослушивания сервиса нужен интернет.',
            textAlign: TextAlign.center,
            style: TextStyle(color: muted),
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      itemCount: links.length,
      itemBuilder: (context, i) {
        final s = links[i];
        return ListTile(
          leading: const Icon(Icons.link_rounded),
          title: Text(s.title, maxLines: 2, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            '${s.link.provider} · ${s.link.description}\n${s.link.uri}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: muted),
          ),
          isThreeLine: true,
          onTap: () => openMusicLink(context, model, player, s),
          trailing: PopupMenuButton<String>(
            tooltip: 'Действия со ссылкой',
            onSelected: (action) {
              if (action == 'copy') {
                Clipboard.setData(ClipboardData(text: s.link.uri.toString()));
              }
              if (action == 'remove') {
                model.task(() => model.store.removeLink(s.id));
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'copy', child: Text('Копировать ссылку')),
              PopupMenuItem(value: 'remove', child: Text('Убрать из списка')),
            ],
          ),
        );
      },
    );
  }
}

class ServicePlayer extends StatefulWidget {
  final SavedMusicLink? saved;
  final ServiceAccount? account;
  final AppModel model;
  const ServicePlayer({
    super.key,
    required SavedMusicLink this.saved,
    required this.model,
  }) : account = null;
  const ServicePlayer.account({
    super.key,
    required ServiceAccount this.account,
    required this.model,
  }) : saved = null;
  @override
  State<ServicePlayer> createState() => ServicePlayerState();
}

class ServicePlayerState extends State<ServicePlayer> {
  WebviewController? controller;
  StreamSubscription<WebErrorStatus>? _errors;
  StreamSubscription<String>? _navigation;
  StreamSubscription<LoadingState>? _loading;
  bool webLoading = false;
  String? currentAddress;
  bool get isAccount => widget.account != null;
  SavedMusicLink get saved => widget.saved!;
  MusicService get service => widget.account?.service ?? saved.link.service;
  Uri get sourceUri => widget.account?.libraryUri ?? saved.link.uri;
  String get heading => widget.account == null
      ? saved.title
      : '${widget.account!.name} · ваш аккаунт';
  bool ready = false, _closing = false, downloading = false;
  bool downloaded = false;
  String? error, downloadMessage;
  AudioDownload? _download;
  int received = 0;
  int? total;

  @override
  void initState() {
    super.initState();
    _initialize();
    _checkDownload();
  }

  Future<void> _checkDownload() async {
    if (isAccount) return;
    final path = saved.downloadPath;
    final exists = path != null && await File(path).exists();
    if (mounted) setState(() => downloaded = exists);
  }

  Future<void> _initialize() async {
    try {
      if (!Platform.isWindows) {
        throw const FormatException(
          'Встроенный плеер пока поддерживается в Windows',
        );
      }
      await WebProfile.initialize();
      if (_closing) return;
      final web = WebviewController();
      await web.initialize();
      if (_closing) {
        await web.dispose();
        return;
      }
      controller = web;
      _loading = web.loadingState.listen((state) {
        if (!mounted) return;
        setState(() {
          webLoading = state == LoadingState.loading;
          if (webLoading) error = null;
        });
      });
      _navigation = web.url.listen((url) {
        if (mounted && isAccount) {
          final uri = Uri.tryParse(url);
          setState(
            () => currentAddress = uri == null
                ? ''
                : '${uri.scheme}://${uri.host}${uri.path}',
          );
        }
      });
      _errors = web.onLoadError.listen((e) {
        if (e == WebErrorStatus.WebErrorStatusOperationCanceled) {
          return;
        }
        if (mounted) {
          setState(
            () => error =
                'Не удалось загрузить страницу. Проверьте подключение и доступность сервиса.',
          );
        }
      });
      await web.setBackgroundColor(ink);
      await web.setPopupWindowPolicy(WebviewPopupWindowPolicy.deny);
      await loadPlayer();
      if (mounted) setState(() => ready = true);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    }
  }

  Future<void> loadPlayer() async {
    if (isAccount) {
      await controller!.setPopupWindowPolicy(
        WebviewPopupWindowPolicy.sameWindow,
      );
      await controller!.loadUrl(widget.account!.libraryUrl);
      return;
    }
    final link = saved.link;
    if (link.service == MusicService.audio) {
      final escaped = const HtmlEscape(
        HtmlEscapeMode.attribute,
      ).convert(link.uri.toString());
      await controller!.loadStringContent(
        '<!doctype html><html><meta name="viewport" content="width=device-width"><body style="margin:0;background:#101016;display:flex;align-items:center;justify-content:center;height:100vh"><audio id="audio" controls preload="none" src="$escaped" style="width:90%"></audio></body></html>',
      );
    } else {
      await controller!.loadUrl(link.embedUri.toString());
    }
  }

  Future<void> download() async {
    if (downloading) return;
    setState(() {
      downloading = true;
      received = 0;
      total = null;
      downloadMessage = null;
    });
    final transfer = AudioDownload();
    _download = transfer;
    try {
      final root = await getApplicationSupportDirectory();
      var lastUpdate = DateTime.now();
      final file = await transfer.fetch(
        saved.link,
        Directory(p.join(root.path, 'Downloads')),
        progress: (bytes, length) {
          if (mounted &&
              DateTime.now().difference(lastUpdate).inMilliseconds >= 150) {
            lastUpdate = DateTime.now();
            setState(() {
              received = bytes;
              total = length;
            });
          }
        },
      );
      final title = saved.title == 'Аудиофайл · Трек'
          ? p.basenameWithoutExtension(saved.link.uri.path)
          : saved.title;
      await widget.model.store.linkDownload(saved.id, file.path, title);
      await widget.model.refresh();
      if (mounted) {
        setState(() {
          downloaded = true;
          downloadMessage =
              'Файл сохранён в локальной библиотеке. Можно слушать без сети.';
        });
      }
    } on DownloadCancelled {
      if (mounted) setState(() => downloadMessage = 'Скачивание отменено');
    } catch (e) {
      if (mounted) {
        setState(() => downloadMessage = 'Не удалось скачать файл: $e');
      }
    } finally {
      _download = null;
      if (mounted) setState(() => downloading = false);
    }
  }

  @override
  void dispose() {
    _closing = true;
    _download?.cancel();
    _errors?.cancel();
    _navigation?.cancel();
    _loading?.cancel();
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(heading, maxLines: 1, overflow: TextOverflow.ellipsis),
      actions: [
        IconButton(
          tooltip: 'Копировать ссылку',
          icon: const Icon(Icons.copy_rounded),
          onPressed: () =>
              Clipboard.setData(ClipboardData(text: sourceUri.toString())),
        ),
        IconButton(
          tooltip: 'Открыть сайт в браузере',
          icon: const Icon(Icons.open_in_new),
          onPressed: () async {
            await controller?.loadUrl('about:blank');
            final launched = await launchUrl(
              sourceUri,
              mode: LaunchMode.externalApplication,
            );
            if (context.mounted) {
              if (launched) {
                Navigator.pop(context);
              } else {
                setState(
                  () =>
                      error = 'Не удалось открыть браузер. Скопируйте ссылку.',
                );
              }
            }
          },
        ),
      ],
    ),
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isAccount
                    ? widget.account!.name
                    : '${saved.link.provider} · ${saved.link.description}',
                style: const TextStyle(color: muted),
              ),
              const SizedBox(height: 6),
              Text(
                isAccount
                    ? 'Войдите на официальной странице сервиса. Ваша сессия сохраняется в OPTIMUM; пароли не попадают в библиотеку или резервную копию.'
                    : service == MusicService.audio
                    ? 'Слушайте файл онлайн или сохраните его в локальную библиотеку. Закрытие этого экрана останавливает веб-плеер.'
                    : 'Управляйте музыкой в плеере ниже. Сервис может предложить вход, подписку или только фрагмент. Закрытие этого экрана останавливает его воспроизведение.',
                style: const TextStyle(fontSize: 12, color: muted),
              ),
              if (isAccount) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    FilledButton.icon(
                      onPressed: ready
                          ? () => controller!.loadUrl(widget.account!.loginUrl)
                          : null,
                      icon: const Icon(Icons.login, size: 18),
                      label: const Text('Войти / сменить аккаунт'),
                    ),
                    OutlinedButton.icon(
                      onPressed: ready ? loadPlayer : null,
                      icon: const Icon(Icons.library_music_outlined, size: 18),
                      label: const Text('Моя библиотека'),
                    ),
                    IconButton(
                      tooltip: 'Обновить страницу',
                      onPressed: ready ? () => controller!.reload() : null,
                      icon: const Icon(Icons.refresh),
                    ),
                    if (controller != null)
                      StreamBuilder<HistoryChanged>(
                        stream: controller!.historyChanged,
                        builder: (_, snapshot) => IconButton(
                          tooltip: 'Назад на странице',
                          onPressed: snapshot.data?.canGoBack == true
                              ? () => controller!.goBack()
                              : null,
                          icon: const Icon(Icons.undo),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                SelectableText(
                  currentAddress ?? sourceUri.toString(),
                  maxLines: 1,
                  style: const TextStyle(fontSize: 11, color: muted),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Для выхода используйте меню самого сервиса. Вход через Google/Apple и воспроизведение могут ограничиваться сервисом во встроенном браузере.',
                  style: TextStyle(fontSize: 11, color: muted),
                ),
              ] else if (service == MusicService.audio) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    FilledButton.icon(
                      onPressed: downloading || downloaded ? null : download,
                      icon: const Icon(Icons.download),
                      label: Text(
                        downloaded
                            ? 'Сохранено на устройстве'
                            : 'Скачать и сохранить',
                      ),
                    ),
                    if (downloading)
                      TextButton(
                        onPressed: () => _download?.cancel(),
                        child: const Text('Отменить скачивание'),
                      ),
                    if (downloading)
                      Text(
                        '${(received / 1048576).toStringAsFixed(1)} МБ${total == null ? '' : ' / ${(total! / 1048576).toStringAsFixed(1)} МБ'}',
                      ),
                  ],
                ),
                if (downloading)
                  LinearProgressIndicator(
                    value: total == null || total == 0
                        ? null
                        : received / total!,
                  ),
                if (downloadMessage != null) Text(downloadMessage!),
              ] else ...[
                const SizedBox(height: 6),
                const Text(
                  'Ссылка сохранена; аудиофайл не скачан. Если плеер недоступен, откройте сайт кнопкой ↗.',
                  style: TextStyle(fontSize: 11, color: muted),
                ),
              ],
            ],
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text(
                  error!,
                  style: const TextStyle(color: Colors.orangeAccent),
                ),
                const SizedBox(height: 10),
                if (controller != null)
                  TextButton(
                    onPressed: () async {
                      setState(() => error = null);
                      await loadPlayer();
                    },
                    child: const Text('Повторить загрузку'),
                  ),
                if (controller == null && Platform.isWindows)
                  TextButton(
                    onPressed: () => launchUrl(
                      Uri.parse(
                        'https://developer.microsoft.com/microsoft-edge/webview2/',
                      ),
                      mode: LaunchMode.externalApplication,
                    ),
                    child: const Text('Microsoft WebView2 Runtime'),
                  ),
              ],
            ),
          ),
        if (webLoading) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: ready && controller != null
              ? Webview(
                  controller!,
                  permissionRequested: (_, _, _) =>
                      WebviewPermissionDecision.deny,
                )
              : Center(
                  child: error == null
                      ? const CircularProgressIndicator()
                      : const Icon(Icons.cloud_off, size: 44),
                ),
        ),
      ],
    ),
  );
}
