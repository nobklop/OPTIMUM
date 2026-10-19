import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'data/library.dart';

class AppModel extends ChangeNotifier {
  final LibraryStore store;
  List<Track> tracks = [], recent = [];
  List<Playlist> playlists = [];
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
  Future<void> like(Track track) =>
      task(() => store.like(track.id, !track.liked));
  Future<void> motion(bool value) =>
      task(() => store.setSetting('reduce_motion', '$value'));
  void dismissMessage() {
    message = null;
    _notify();
  }
}
