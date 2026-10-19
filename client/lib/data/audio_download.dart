import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:path/path.dart' as p;
import 'music_link.dart';

/// Downloads only explicitly supplied public audio files, never provider streams.
class AudioDownload {
  static const maxBytes = 512 * 1024 * 1024;
  final HttpClient _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 20);
  bool _cancelled = false;
  void cancel() {
    _cancelled = true;
    _client.close(force: true);
  }

  Future<File> fetch(
    MusicLink link,
    Directory directory, {
    void Function(int, int?)? progress,
  }) async {
    if (link.service != MusicService.audio) {
      throw const FormatException('Нужна прямая ссылка на аудиофайл');
    }
    var uri = link.uri;
    var timedOut = false;
    final deadline = Timer(const Duration(minutes: 5), () {
      timedOut = true;
      _client.close(force: true);
    });
    try {
      return await (() async {
        for (var redirects = 0; redirects <= 5; redirects++) {
          if (_cancelled) throw const DownloadCancelled();
          if (uri.scheme != 'https' ||
              uri.userInfo.isNotEmpty ||
              uri.port != 443) {
            throw const FormatException(
              'Перенаправление должно использовать HTTPS',
            );
          }
          final request = await _client.getUrl(uri);
          request.followRedirects = false;
          final response = await request.close().timeout(
            const Duration(seconds: 20),
          );
          if ([301, 302, 303, 307, 308].contains(response.statusCode)) {
            final location = response.headers.value(HttpHeaders.locationHeader);
            if (location == null) {
              throw const FormatException('Пустое перенаправление');
            }
            uri = uri.resolve(location);
            await response.listen((_) {}).cancel();
            continue;
          }
          if (response.statusCode != 200) {
            throw HttpException('Сервер вернул HTTP ${response.statusCode}');
          }
          final length =
              response.contentLength < 0 ||
                  response.compressionState ==
                      HttpClientResponseCompressionState.decompressed
              ? null
              : response.contentLength;
          if (length != null && length > maxBytes) {
            throw const FormatException('Файл больше 512 МБ');
          }
          return await saveAudioStream(
            response.timeout(const Duration(seconds: 20)),
            directory,
            extension: p.extension(link.uri.path).toLowerCase(),
            expectedBytes: length,
            cancelled: () => _cancelled || timedOut,
            progress: progress,
          );
        }
        throw const FormatException('Слишком много перенаправлений');
      })();
    } catch (_) {
      if (_cancelled) throw const DownloadCancelled();
      if (timedOut) throw TimeoutException('Превышено время скачивания');
      rethrow;
    } finally {
      deadline.cancel();
      _client.close(force: true);
    }
  }
}

class DownloadCancelled implements Exception {
  const DownloadCancelled();
}

/// Atomic streaming writer. A failed or cancelled transfer never becomes music.
Future<File> saveAudioStream(
  Stream<List<int>> stream,
  Directory directory, {
  required String extension,
  int? expectedBytes,
  int limit = AudioDownload.maxBytes,
  bool Function()? cancelled,
  void Function(int, int?)? progress,
}) async {
  await directory.create(recursive: true);
  final key =
      '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';
  final temporary = File(p.join(directory.path, '$key.part'));
  final destination = File(p.join(directory.path, '$key$extension'));
  final output = await temporary.open(mode: FileMode.write);
  var closed = false;
  var count = 0;
  final header = <int>[];
  try {
    await for (final chunk in stream) {
      if (cancelled?.call() ?? false) throw const DownloadCancelled();
      count += chunk.length;
      if (count > limit) {
        throw const FormatException('Превышен лимит размера файла');
      }
      if (header.length < 16) header.addAll(chunk.take(16 - header.length));
      await output.writeFrom(chunk);
      progress?.call(count, expectedBytes);
    }
    await output.flush();
    await output.close();
    closed = true;
    if (cancelled?.call() ?? false) throw const DownloadCancelled();
    if (expectedBytes != null && count != expectedBytes) {
      throw const FormatException('Файл получен не полностью');
    }
    if (!_audioHeader(header)) {
      throw const FormatException('Ссылка вернула не аудиофайл');
    }
    return await temporary.rename(destination.path);
  } catch (_) {
    try {
      if (!closed) await output.close();
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
    rethrow;
  }
}

bool _audioHeader(List<int> h) {
  if (h.length < 12) return false;
  String at(int start, int count) =>
      String.fromCharCodes(h.sublist(start, start + count));
  return (at(0, 4) == 'RIFF' && at(8, 4) == 'WAVE') ||
      at(0, 4) == 'fLaC' ||
      at(0, 4) == 'OggS' ||
      at(0, 3) == 'ID3' ||
      (h[0] == 0xff && h[1] & 0xe0 == 0xe0) ||
      at(4, 4) == 'ftyp' ||
      (at(0, 4) == 'FORM' && ['AIFF', 'AIFC'].contains(at(8, 4)));
}
