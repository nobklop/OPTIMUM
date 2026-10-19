import 'dart:io';
import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart'
    show databaseFactoryFfi, sqfliteFfiInit;

const audioExtensions = [
  'mp3',
  'flac',
  'wav',
  'ogg',
  'opus',
  'm4a',
  'aac',
  'aiff',
];

class Track {
  final int id;
  final String path, title, artist, album;
  final int durationMs;
  final bool liked;
  const Track({
    required this.id,
    required this.path,
    required this.title,
    this.artist = 'Неизвестный исполнитель',
    this.album = '',
    this.durationMs = 0,
    this.liked = false,
  });
  bool get isAsset => path.startsWith('asset:');
  factory Track.fromMap(Map<String, Object?> m) => Track(
    id: m['id'] as int,
    path: m['path'] as String,
    title: m['title'] as String,
    artist: m['artist'] as String,
    album: m['album'] as String,
    durationMs: m['duration_ms'] as int,
    liked: m['liked'] == 1,
  );
}

class Playlist {
  final int id, count;
  final String name;
  const Playlist(this.id, this.name, this.count);
}

Map<String, Object?> readTrack(String path) {
  var title = p.basenameWithoutExtension(path);
  var artist = 'Неизвестный исполнитель';
  var album = '';
  var duration = 0;
  try {
    final metadata = readMetadata(File(path), getImage: false);
    if (metadata.title?.trim().isNotEmpty ?? false) {
      title = metadata.title!.trim();
    }
    if (metadata.artist?.trim().isNotEmpty ?? false) {
      artist = metadata.artist!.trim();
    }
    album = metadata.album ?? '';
    duration = metadata.duration?.inMilliseconds ?? 0;
  } catch (_) {
    // Missing tags do not imply an unplayable audio stream; playback reports decode errors.
  }
  return {
    'path': p.normalize(p.absolute(path)),
    'title': title,
    'artist': artist,
    'album': album,
    'duration_ms': duration,
  };
}

class LibraryStore {
  static bool _ffiConfigured = false;
  final Database db;
  LibraryStore(this.db);
  static Future<LibraryStore> open({String? databasePath}) async {
    if ((Platform.isWindows || Platform.isLinux) && !_ffiConfigured) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      _ffiConfigured = true;
    }
    final path =
        databasePath ??
        p.join((await getApplicationSupportDirectory()).path, 'library.db');
    if (databasePath == null) {
      await Directory(p.dirname(path)).create(recursive: true);
    }
    final db = await openDatabase(
      path,
      version: 2,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys=ON');
        if (await db.getVersion() == 1 && path != ':memory:') {
          // A consistent SQLite snapshot, even if another app instance is open.
          await db.execute('VACUUM INTO ?', [
            '$path.before-v2-${DateTime.now().toUtc().microsecondsSinceEpoch}.db',
          ]);
        }
      },
      onCreate: (db, version) async {
        await db.execute('''CREATE TABLE tracks (
          id INTEGER PRIMARY KEY, path TEXT NOT NULL UNIQUE COLLATE NOCASE,
          title TEXT NOT NULL, artist TEXT NOT NULL, album TEXT NOT NULL DEFAULT '',
          duration_ms INTEGER NOT NULL DEFAULT 0, liked INTEGER NOT NULL DEFAULT 0,
          imported_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP)''');
        await db.execute(
          'CREATE TABLE playlists (id INTEGER PRIMARY KEY, name TEXT NOT NULL, backup_key TEXT)',
        );
        await db.execute('''CREATE TABLE playlist_tracks (
          playlist_id INTEGER NOT NULL REFERENCES playlists(id) ON DELETE CASCADE,
          track_id INTEGER NOT NULL REFERENCES tracks(id) ON DELETE CASCADE,
          position INTEGER NOT NULL, PRIMARY KEY(playlist_id, track_id))''');
        await db.execute('''CREATE TABLE history (id INTEGER PRIMARY KEY,
          track_id INTEGER NOT NULL REFERENCES tracks(id) ON DELETE CASCADE,
          played_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP)''');
        await db.execute('CREATE INDEX history_recent ON history(id DESC)');
        await db.execute(
          'CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
        );
        await _playlistKeys(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE playlists ADD COLUMN backup_key TEXT');
          await _playlistKeys(db);
        }
      },
    );
    return LibraryStore(db);
  }

  static Future<void> _playlistKeys(DatabaseExecutor db) async {
    await db.execute(
      'UPDATE playlists SET backup_key=lower(hex(randomblob(16))) WHERE backup_key IS NULL',
    );
    await db.execute(
      'CREATE UNIQUE INDEX playlists_backup_key ON playlists(backup_key)',
    );
    await db.execute(
      '''CREATE TRIGGER playlists_assign_key AFTER INSERT ON playlists
      WHEN NEW.backup_key IS NULL BEGIN
      UPDATE playlists SET backup_key=lower(hex(randomblob(16))) WHERE id=NEW.id; END''',
    );
  }

  Future<List<Track>> tracks({int? playlistId}) async {
    final rows = playlistId == null
        ? await db.query('tracks', orderBy: 'id DESC')
        : await db.rawQuery(
            '''SELECT t.* FROM tracks t JOIN playlist_tracks pt
          ON t.id=pt.track_id WHERE pt.playlist_id=? ORDER BY pt.position''',
            [playlistId],
          );
    return rows.map(Track.fromMap).toList();
  }

  Future<int> importPaths(List<String> paths) async {
    var added = 0;
    for (final path in paths) {
      final extension = p.extension(path);
      if (extension.isEmpty ||
          !audioExtensions.contains(extension.substring(1).toLowerCase())) {
        continue;
      }
      if (!await File(path).exists()) continue;
      final row = await compute(readTrack, path);
      await db.transaction((txn) async {
        final existing = await txn.query(
          'tracks',
          columns: ['id'],
          where: 'path=?',
          whereArgs: [row['path']],
        );
        if (existing.isEmpty) {
          await txn.insert('tracks', row);
          added++;
        }
      });
    }
    return added;
  }

  Future<void> addStudies() async {
    const names = ['Тихая орбита', 'Свет далёких звёзд', 'Невесомость'];
    await db.transaction((txn) async {
      for (var i = 0; i < names.length; i++) {
        final path = 'asset:assets/audio/orbit_${i + 1}.wav';
        if ((await txn.query(
          'tracks',
          columns: ['id'],
          where: 'path=?',
          whereArgs: [path],
        )).isEmpty) {
          await txn.insert('tracks', {
            'path': path,
            'title': names[i],
            'artist': 'OPTIMUM · звуковой этюд',
            'album': 'Первые сигналы',
            'duration_ms': 28000,
          });
        }
      }
    });
  }

  Future<void> like(int id, bool value) async {
    await db.update(
      'tracks',
      {'liked': value ? 1 : 0},
      where: 'id=?',
      whereArgs: [id],
    );
  }

  Future<void> remove(int id) async {
    await db.delete('tracks', where: 'id=?', whereArgs: [id]);
  }

  Future<void> recordPlay(int id) async {
    await db.transaction((txn) async {
      await txn.insert('history', {'track_id': id});
      await txn.rawDelete(
        'DELETE FROM history WHERE id NOT IN (SELECT id FROM history ORDER BY julianday(played_at) DESC,id DESC LIMIT 5000)',
      );
    });
  }

  Future<List<Track>> recent() async => (await db.rawQuery(
    '''SELECT t.*, MAX(julianday(h.played_at)) AS recent_time, MAX(h.id) AS recent_id
      FROM tracks t JOIN history h ON t.id=h.track_id GROUP BY t.id ORDER BY recent_time DESC,recent_id DESC LIMIT 30''',
  )).map(Track.fromMap).toList();
  Future<List<Playlist>> playlists() async =>
      (await db.rawQuery(
            '''SELECT p.id,p.name,COUNT(pt.track_id) AS count
      FROM playlists p LEFT JOIN playlist_tracks pt ON p.id=pt.playlist_id GROUP BY p.id ORDER BY p.id DESC''',
          ))
          .map(
            (m) => Playlist(
              m['id'] as int,
              m['name'] as String,
              m['count'] as int,
            ),
          )
          .toList();
  Future<int> createPlaylist(String name) {
    _validateName(name);
    return db.insert('playlists', {'name': name.trim()});
  }

  Future<void> renamePlaylist(int id, String name) async {
    _validateName(name);
    await db.update(
      'playlists',
      {'name': name.trim()},
      where: 'id=?',
      whereArgs: [id],
    );
  }

  void _validateName(String name) {
    if (name.trim().isEmpty || name.trim().length > 80) {
      throw ArgumentError('Название: от 1 до 80 символов');
    }
  }

  Future<void> deletePlaylist(int id) async {
    await db.delete('playlists', where: 'id=?', whereArgs: [id]);
  }

  Future<void> addToPlaylist(int playlist, int track) async {
    await db.transaction((txn) async {
      await txn.rawInsert(
        '''INSERT OR IGNORE INTO playlist_tracks(playlist_id,track_id,position)
        VALUES (?,?,COALESCE((SELECT MAX(position)+1 FROM playlist_tracks WHERE playlist_id=?),0))''',
        [playlist, track, playlist],
      );
    });
  }

  Future<void> removeFromPlaylist(int playlist, int track) async {
    await db.delete(
      'playlist_tracks',
      where: 'playlist_id=? AND track_id=?',
      whereArgs: [playlist, track],
    );
  }

  Future<String?> setting(String key) async {
    final rows = await db.query('settings', where: 'key=?', whereArgs: [key]);
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  Future<void> setSetting(String key, String value) async {
    await db.insert('settings', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> close() => db.close();
}
