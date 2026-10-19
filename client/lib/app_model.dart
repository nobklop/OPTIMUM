import 'dart:convert';
import 'dart:io';
import 'dart:typed_data' show BytesBuilder;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'data/library.dart';
import 'data/backup.dart';
import 'data/music_link.dart';

class AppModel extends ChangeNotifier {
  final LibraryStore store;
  List<Track> tracks = [], recent = [];
  List<Playlist> playlists = [];
  List<SavedMusicLink> links = [];
  bool busy = false, reduceMotion = false;
  String? message;
  bool _disposed = false;
  Future<void> _refreshTail = Future.value();
  Future<void> get idle => _refreshTail;
  AppModel(this.store);
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> refresh() {
    _refreshTail = _refreshTail.then((_) => _readLibrary()).catchError((
      Object e,
    ) {
      message = 'Не удалось прочитать библиотеку: $e';
      _notify();
    });
    return _refreshTail;
  }

  Future<void> _readLibrary() async {
    if (_disposed) return;
    tracks = await store.tracks();
    if (_disposed) return;
    playlists = await store.playlists();
    if (_disposed) return;
    recent = await store.recent();
    if (_disposed) return;
    links = await store.links();
    if (_disposed) return;
    reduceMotion = await store.setting('reduce_motion') == 'true';
    _notify();
  }

  Future<void> task(Future<void> Function() operation) async {
    if (busy || _disposed) return;
    busy = true;
    message = null;
    _notify();
    try {
      await operation();
      await refresh();
    } catch (e) {
      message = 'Операция не завершена: $e';
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> importFiles() => task(() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: audioExtensions,
    );
    if (result.isEmpty) return;
    final added = await store.importPaths(
      result.map((file) => file.path).whereType<String>().toList(),
    );
    message = 'Добавлено треков: $added';
  });
  Future<void> importFolder() => task(() async {
    final path = await FilePicker.getDirectoryPath();
    if (path == null) return;
    var added = 0;
    final batch = <String>[];
    await for (final entity in Directory(
      path,
    ).list(recursive: true, followLinks: false)) {
      if (entity is! File ||
          !audioExtensions.contains(
            p.extension(entity.path).replaceFirst('.', '').toLowerCase(),
          )) {
        continue;
      }
      batch.add(entity.path);
      if (batch.length >= 50) {
        added += await store.importPaths(batch);
        batch.clear();
      }
    }
    added += await store.importPaths(batch);
    message = 'Добавлено треков: $added';
  });
  Future<void> addStudies() => task(() async {
    await store.addStudies();
    message = 'Три авторских звуковых этюда добавлены в библиотеку';
  });
  Future<void> exportBackup() => task(() async {
    final content = await LibraryBackup(store).exportJson();
    final bytes = Uint8List.fromList(utf8.encode(content));
    if (bytes.length > LibraryBackup.maxBytes) {
      throw const FormatException('Резервная копия больше 32 МБ');
    }
    final result = await FilePicker.saveFile(
      dialogTitle: 'Сохранить библиотеку OPTIMUM',
      fileName:
          'OPTIMUM-library-${DateTime.now().toIso8601String().substring(0, 10)}.json',
      bytes: bytes,
      mimeType: 'application/json',
    );
    if (result != null) message = 'Резервная копия библиотеки сохранена';
  });
  Future<void> restoreBackup() => task(() async {
    final file = await FilePicker.pickFile(
      dialogTitle: 'Восстановить библиотеку OPTIMUM',
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (file == null) return;
    if ((await file.length() ?? 0) > LibraryBackup.maxBytes) {
      throw const FormatException('Резервная копия больше 32 МБ');
    }
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in file.readAsByteStream()) {
      if (bytes.length + chunk.length > LibraryBackup.maxBytes) {
        throw const FormatException('Резервная копия больше 32 МБ');
      }
      bytes.add(chunk);
    }
    final result = await LibraryBackup(
      store,
    ).restoreJson(utf8.decode(bytes.takeBytes()));
    message =
        'Библиотека объединена. Добавлено треков: ${result.tracksAdded}, плейлистов: ${result.playlistsAdded}';
  });
  Future<void> like(Track track) =>
      task(() => store.like(track.id, !track.liked));
  Future<void> motion(bool value) =>
      task(() => store.setSetting('reduce_motion', '$value'));
  void dismissMessage() {
    message = null;
    _notify();
  }
}
