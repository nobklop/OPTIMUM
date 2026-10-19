import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import '../data/library.dart';
import 'queue.dart';
import 'model.dart';

Uint8List? readCover(String path) {
  try {
    final pictures = readMetadata(File(path), getImage: true).pictures;
    if (pictures.isNotEmpty && pictures.first.bytes.length <= 2 * 1024 * 1024) {
      return pictures.first.bytes;
    }
  } catch (_) {
    /* A cover is optional. Audio errors are reported by the player. */
  }
  return null;
}

class PlaybackController extends PlaybackModel {
  final LibraryStore store;
  final AudioPlayer audio;
  @override
  final PlaybackQueue queue = PlaybackQueue();
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  Future<void> _operations = Future.value();
  @override
  bool loading = false;
  bool _disposed = false, _recorded = false;
  bool _loaded = false;
  final Stopwatch _listened = Stopwatch();
  @override
  String? error;
  @override
  Uint8List? cover;
  @override
  Track? get current => queue.current;
  @override
  bool get playing =>
      _loaded &&
      audio.playing &&
      audio.processingState != ProcessingState.completed;
  @override
  Duration get position => _loaded ? audio.position : Duration.zero;
  @override
  Duration get duration =>
      (_loaded ? audio.duration : null) ??
      Duration(milliseconds: current?.durationMs ?? 0);
  @override
  double get volume => audio.volume;

  PlaybackController(this.store, {AudioPlayer? player})
    : audio = player ?? AudioPlayer() {
    _subscriptions.add(
      audio.playerStateStream.listen((state) {
        if (state.playing &&
            state.processingState == ProcessingState.ready &&
            !loading) {
          _listened.start();
        } else {
          _listened.stop();
        }
        _notify();
        if (state.playing &&
            state.processingState == ProcessingState.completed &&
            !loading) {
          unawaited(
            _enqueue(() async {
              if (queue.next(completed: true)) {
                await _load();
              } else {
                await audio.pause();
              }
            }),
          );
        }
      }),
    );
    _subscriptions.add(
      audio.positionStream.listen((position) {
        if (!_recorded &&
            current != null &&
            playing &&
            _listened.elapsedMilliseconds >=
                min(10000, duration.inMilliseconds ~/ 2) &&
            duration.inMilliseconds > 0) {
          _recorded = true;
          unawaited(
            store.recordPlay(current!.id).catchError((Object e) {
              error = 'История не сохранена: $e';
              _notify();
            }),
          );
        }
        _notify();
      }),
    );
    _subscriptions.add(
      audio.errorStream.listen((e) {
        _loaded = false;
        error = 'Ошибка воспроизведения: ${e.message}';
        _notify();
      }),
    );
  }
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _enqueue(Future<void> Function() operation) {
    final next = _operations.then((_) async {
      if (_disposed) return;
      try {
        await operation();
      } catch (e) {
        error = 'Не удалось воспроизвести. Проверьте файл и формат.\n$e';
      } finally {
        loading = false;
        _notify();
      }
    });
    _operations = next;
    return next;
  }

  @override
  Future<void> select(List<Track> tracks, int index) => _enqueue(() async {
    queue.set(tracks, index);
    await _load();
  });
  Future<void> _load({bool autoplay = true}) async {
    final track = current;
    if (track == null) return;
    loading = true;
    _loaded = false;
    error = null;
    cover = null;
    _recorded = false;
    _listened
      ..stop()
      ..reset();
    _notify();
    await audio.pause();
    if (track.isAsset) {
      await audio.setAsset(track.path.substring(6));
    } else {
      if (!await File(track.path).exists()) {
        throw FileSystemException('Файл перемещён или удалён', track.path);
      }
      await audio.setFilePath(track.path);
      cover = await compute(readCover, track.path);
    }
    loading = false;
    _loaded = true;
    if (autoplay) {
      unawaited(
        audio.play().catchError((Object e) {
          error = 'Ошибка аудио: $e';
          _notify();
        }),
      );
    }
  }

  @override
  Future<void> toggle() => _enqueue(() async {
    if (current == null) return;
    if (!_loaded) {
      await _load();
      return;
    }
    if (playing) {
      await audio.pause();
    } else {
      if (audio.processingState == ProcessingState.completed) {
        await audio.seek(Duration.zero);
      }
      unawaited(
        audio.play().catchError((Object e) {
          error = '$e';
          _notify();
        }),
      );
    }
  });
  @override
  Future<void> next() => _enqueue(() async {
    if (queue.next()) await _load();
  });
  @override
  Future<void> previous() => _enqueue(() async {
    if (position.inSeconds > 3) {
      await audio.seek(Duration.zero);
    } else {
      queue.previous();
      await _load();
    }
  });
  @override
  Future<void> seek(Duration value) => _enqueue(() => audio.seek(value));
  @override
  Future<void> setVolume(double value) => _enqueue(() async {
    await audio.setVolume(value);
  });
  @override
  void shuffle() {
    queue.toggleShuffle();
    _notify();
  }

  @override
  void repeat() {
    queue.repeat =
        RepeatMode.values[(queue.repeat.index + 1) % RepeatMode.values.length];
    _notify();
  }

  @override
  Future<void> stop() => _enqueue(() => audio.stop());
  @override
  Future<void> removeFromQueue(int id) => _enqueue(() async {
    final wasPlaying = playing;
    if (queue.remove(id)) {
      _loaded = false;
      if (current == null) {
        cover = null;
        await audio.stop();
      } else {
        await _load(autoplay: wasPlaying);
      }
    }
  });
  Future<void> shutdown() async {
    _disposed = true;
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _operations;
    await audio.dispose();
    super.dispose();
  }
}
