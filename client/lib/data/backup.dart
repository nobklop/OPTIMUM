import 'dart:convert';
import 'package:path/path.dart' as p;
import 'library.dart';
import 'music_link.dart';

/// Versioned, metadata-only snapshots. Restore merges atomically and never deletes music.
class LibraryBackup {
  static const maxBytes = 32 * 1024 * 1024;
  final LibraryStore store;
  LibraryBackup(this.store);

  Future<String> exportJson() => store.db.transaction((txn) async {
    final tracks = await txn.query('tracks');
    final byId = {for (final track in tracks) track['id']: track['path']};
    final playlists = await txn.query('playlists', orderBy: 'id');
    final links = await txn.query(
      'music_links',
      columns: ['id', 'url', 'title', 'download_path'],
      orderBy: 'id',
    );
    final linkUrls = {for (final row in links) row['id']: row['url']};
    final exportedPlaylists = <Map<String, Object?>>[];
    for (final playlist in playlists) {
      final entries = await txn.query(
        'playlist_tracks',
        where: 'playlist_id=?',
        whereArgs: [playlist['id']],
        orderBy: 'position',
      );
      exportedPlaylists.add({
        'key': playlist['backup_key'],
        'name': playlist['name'],
        'source_url': playlist['source_url'],
        'links': (await txn.query(
          'playlist_links',
          where: 'playlist_id=?',
          whereArgs: [playlist['id']],
          orderBy: 'position',
        )).map((e) => linkUrls[e['link_id']]).toList(),
        'tracks': entries.map((entry) => byId[entry['track_id']]).toList(),
      });
    }
    final history = await txn.query(
      'history',
      orderBy: 'julianday(played_at) DESC,id DESC',
      limit: 5000,
    );
    final settings = await txn.query(
      'settings',
      where: 'key=?',
      whereArgs: ['reduce_motion'],
    );
    final content = const JsonEncoder.withIndent('  ').convert({
      'format': 'optimum-library',
      'version': 3,
      'links': links
          .map(
            (e) => {
              'url': e['url'],
              'title': e['title'],
              'download_path': e['download_path'],
            },
          )
          .toList(),
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'tracks': tracks
          .map(
            (t) => {
              'path': t['path'],
              'title': t['title'],
              'artist': t['artist'],
              'album': t['album'],
              'duration_ms': t['duration_ms'],
              'liked': t['liked'] == 1,
            },
          )
          .toList(),
      'playlists': exportedPlaylists,
      'history': history.reversed
          .map(
            (h) => {'path': byId[h['track_id']], 'played_at': h['played_at']},
          )
          .toList(),
      'settings': {for (final s in settings) s['key'] as String: s['value']},
    });
    _validate(content); // Never export a file that this version cannot restore.
    return content;
  });

  Future<BackupResult> restoreJson(String content) async {
    final snapshot = _validate(
      content,
    ); // Validate everything before the first mutation.
    return store.db.transaction((txn) async {
      var added = 0, restoredPlaylists = 0;
      final ids = <String, int>{};
      final playlistIds = <String, int>{};
      for (final track in snapshot.tracks) {
        final path = track['path'] as String;
        final existing = await txn.query(
          'tracks',
          where: 'path=?',
          whereArgs: [path],
          limit: 1,
        );
        if (existing.isEmpty) {
          ids[path] = await txn.insert('tracks', {
            ...track,
            'liked': track['liked'] == true ? 1 : 0,
          });
          added++;
        } else {
          final id = existing.first['id'] as int;
          ids[path] = id;
          // A restore never removes a current like or overwrites current metadata.
          if (track['liked'] == true) {
            await txn.update(
              'tracks',
              {'liked': 1},
              where: 'id=?',
              whereArgs: [id],
            );
          }
        }
      }
      for (final playlist in snapshot.playlists) {
        final existing = await txn.query(
          'playlists',
          where: playlist['source_url'] == null
              ? 'backup_key=?'
              : 'backup_key=? OR source_url=?',
          whereArgs: [
            playlist['key'],
            if (playlist['source_url'] != null) playlist['source_url'],
          ],
          limit: 1,
        );
        final int id;
        if (existing.isEmpty) {
          id = await txn.insert('playlists', {
            'name': playlist['name'],
            'backup_key': playlist['key'],
            'source_url': playlist['source_url'],
          });
          restoredPlaylists++;
        } else {
          id = existing.first['id'] as int;
        }
        playlistIds[playlist['key'] as String] = id;
        for (final path in playlist['tracks'] as List<String>) {
          await txn.rawInsert(
            '''INSERT OR IGNORE INTO playlist_tracks(playlist_id,track_id,position)
            VALUES(?,?,COALESCE((SELECT MAX(position)+1 FROM playlist_tracks WHERE playlist_id=?),0))''',
            [id, ids[path], id],
          );
        }
      }
      for (final entry in snapshot.history) {
        final trackId = ids[entry['path']];
        final existing = await txn.query(
          'history',
          columns: ['id'],
          where: 'track_id=? AND played_at=?',
          whereArgs: [trackId, entry['played_at']],
          limit: 1,
        );
        if (existing.isEmpty) {
          await txn.insert('history', {
            'track_id': trackId,
            'played_at': entry['played_at'],
          });
        }
      }
      await txn.rawDelete(
        'DELETE FROM history WHERE id NOT IN (SELECT id FROM history ORDER BY julianday(played_at) DESC,id DESC LIMIT 5000)',
      );
      for (final entry in snapshot.settings.entries) {
        await txn.rawInsert(
          'INSERT OR IGNORE INTO settings(key,value) VALUES(?,?)',
          [entry.key, entry.value],
        );
      }
      for (final link in snapshot.links) {
        await txn.rawInsert(
          'INSERT OR IGNORE INTO music_links(url,title,download_path) VALUES(?,?,?)',
          [link['url'], link['title'], link['download_path']],
        );
        if (link['download_path'] != null) {
          await txn.rawUpdate(
            'UPDATE music_links SET download_path=? WHERE url=? AND download_path IS NULL',
            [link['download_path'], link['url']],
          );
        }
      }
      for (final playlist in snapshot.playlists) {
        final id = playlistIds[playlist['key']]!;
        final present = await txn.rawQuery(
          'SELECT p.position,l.url FROM playlist_links p JOIN music_links l ON l.id=p.link_id WHERE p.playlist_id=? ORDER BY p.position',
          [id],
        );
        final counts = <String, int>{};
        for (final row in present) {
          final url = row['url'] as String;
          counts[url] = (counts[url] ?? 0) + 1;
        }
        final seen = <String, int>{};
        var position = present.isEmpty
            ? 0
            : (present.last['position'] as int) + 1;
        for (final url in playlist['links'] as List<String>) {
          seen[url] = (seen[url] ?? 0) + 1;
          if (seen[url]! <= (counts[url] ?? 0)) continue;
          final link = await txn.query(
            'music_links',
            columns: ['id'],
            where: 'url=?',
            whereArgs: [url],
          );
          await txn.insert('playlist_links', {
            'playlist_id': id,
            'link_id': link.single['id'],
            'position': position++,
          });
        }
      }
      return BackupResult(added, restoredPlaylists);
    });
  }

  _Snapshot _validate(String content) {
    if (utf8.encode(content).length > maxBytes) {
      throw const FormatException('Резервная копия больше 32 МБ');
    }
    final root = jsonDecode(content);
    if (root is! Map<String, dynamic> ||
        root['format'] != 'optimum-library' ||
        ![1, 2, 3].contains(root['version'])) {
      throw const FormatException(
        'Неизвестный формат или версия резервной копии',
      );
    }
    List<dynamic> rows(String key, int max) {
      final value = root[key];
      if (value is! List || value.length > max) {
        throw FormatException('Некорректный раздел $key');
      }
      return value;
    }

    String text(dynamic value, String field, int max, {bool empty = false}) {
      if (value is! String ||
          (!empty && value.trim().isEmpty) ||
          value.length > max ||
          value.contains('\u0000')) {
        throw FormatException('Некорректное поле $field');
      }
      return value;
    }

    final paths = <String>{};
    final links = <Map<String, Object?>>[];
    if (root['version'] >= 2) {
      final seen = <String>{};
      for (final row in rows('links', 10000)) {
        if (row is! Map) throw const FormatException('Некорректная ссылка');
        final link = MusicLink.parse(text(row['url'], 'link.url', 4096));
        if (!seen.add(link.uri.toString())) {
          throw const FormatException('Повторная ссылка');
        }
        links.add({
          'url': link.uri.toString(),
          'title': text(row['title'], 'link.title', 160),
          'download_path': row['download_path'] == null
              ? null
              : text(row['download_path'], 'link.download_path', 4096),
        });
      }
    }
    final tracks = <Map<String, Object?>>[];
    for (final row in rows('tracks', 50000)) {
      if (row is! Map) throw const FormatException('Некорректный трек');
      final path = text(row['path'], 'path', 4096);
      if ((!p.isAbsolute(path) &&
              !RegExp(
                r'^asset:assets/audio/orbit_[123]\.wav$',
              ).hasMatch(path)) ||
          !paths.add(path) ||
          row['duration_ms'] is! int ||
          row['duration_ms'] < 0 ||
          row['duration_ms'] > 86400000 ||
          row['liked'] is! bool) {
        throw const FormatException(
          'Некорректный путь, длительность или дубликат трека',
        );
      }
      tracks.add({
        'path': path,
        'title': text(row['title'], 'title', 1000),
        'artist': text(row['artist'], 'artist', 1000),
        'album': text(row['album'], 'album', 1000, empty: true),
        'duration_ms': row['duration_ms'],
        'liked': row['liked'],
      });
    }
    for (final link in links) {
      if (link['download_path'] != null &&
          !paths.contains(link['download_path'])) {
        throw const FormatException(
          'Сохранённая ссылка ссылается на отсутствующий локальный трек',
        );
      }
    }
    final keys = <String>{};
    final savedUrls = links.map((l) => l['url']).toSet();
    final playlists = <Map<String, Object?>>[];
    for (final row in rows('playlists', 5000)) {
      if (row is! Map ||
          row['key'] is! String ||
          !RegExp(r'^[0-9a-f]{32}$').hasMatch(row['key']) ||
          !keys.add(row['key'])) {
        throw const FormatException('Некорректный идентификатор плейлиста');
      }
      final entries = row['tracks'];
      final linkEntries = root['version'] == 3 ? row['links'] : <String>[];
      if (linkEntries is! List ||
          linkEntries.length > 10000 ||
          linkEntries.any(
            (url) => url is! String || !savedUrls.contains(url),
          )) {
        throw const FormatException('Некорректные треки по ссылке в плейлисте');
      }
      var source = root['version'] == 3 ? row['source_url'] : null;
      if (source != null &&
          (source is! String ||
              !['playlist', 'album'].contains(MusicLink.parse(source).kind))) {
        throw const FormatException('Некорректный источник плейлиста');
      }
      if (source != null) {
        source = MusicLink.parse(source as String).uri.toString();
      }
      if (entries is! List ||
          entries.length > 50000 ||
          entries.any((p) => p is! String || !paths.contains(p)) ||
          entries.toSet().length != entries.length) {
        throw const FormatException('Плейлист ссылается на отсутствующий трек');
      }
      playlists.add({
        'key': row['key'],
        'name': text(row['name'], 'playlist.name', 80),
        'source_url': source,
        'links': linkEntries.cast<String>(),
        'tracks': entries.cast<String>(),
      });
    }
    final history = <Map<String, Object?>>[];
    for (final row in rows('history', 5000)) {
      if (row is! Map || !paths.contains(row['path'])) {
        throw const FormatException('Некорректная история');
      }
      final time = text(row['played_at'], 'played_at', 40);
      final parsed = DateTime.tryParse('${time.replaceFirst(' ', 'T')}Z');
      if (!RegExp(r'^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$').hasMatch(time) ||
          parsed == null ||
          parsed.toIso8601String().substring(0, 19).replaceFirst('T', ' ') !=
              time) {
        throw const FormatException('Некорректное время прослушивания');
      }
      history.add({'path': row['path'], 'played_at': time});
    }
    final settings = root['settings'];
    if (settings is! Map ||
        settings.keys.any((key) => key != 'reduce_motion') ||
        (settings.containsKey('reduce_motion') &&
            !['true', 'false'].contains(settings['reduce_motion']))) {
      throw const FormatException('Некорректные настройки');
    }
    return _Snapshot(
      tracks,
      playlists,
      history,
      settings.cast<String, String>(),
      links,
    );
  }
}

class BackupResult {
  final int tracksAdded, playlistsAdded;
  const BackupResult(this.tracksAdded, this.playlistsAdded);
}

class _Snapshot {
  final List<Map<String, Object?>> tracks, playlists, history, links;
  final Map<String, String> settings;
  const _Snapshot(
    this.tracks,
    this.playlists,
    this.history,
    this.settings,
    this.links,
  );
}
