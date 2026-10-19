import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:optimum/data/backup.dart';
import 'package:optimum/data/library.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Backup round trip preserves order, distinct same-name playlists and history; merge is idempotent',
    () async {
      final source = await LibraryStore.open(databasePath: ':memory:');
      // A different filename is needed because sqflite reuses an open :memory: database.
      final folder = await Directory.systemTemp.createTemp('optimum-backup-');
      final target = await LibraryStore.open(
        databasePath: p.join(folder.path, 'target.db'),
      );
      try {
        await source.addStudies();
        final tracks = await source.tracks();
        await source.like(tracks[0].id, true);
        final first = await source.createPlaylist('Ночь');
        final second = await source.createPlaylist('Ночь');
        await source.addToPlaylist(first, tracks[1].id);
        await source.addToPlaylist(first, tracks[0].id);
        await source.addToPlaylist(second, tracks[2].id);
        await source.recordPlay(tracks[1].id);
        await source.db.update('history', {'played_at': '2001-01-01 00:00:00'});
        await source.setSetting('reduce_motion', 'true');
        final json = await LibraryBackup(source).exportJson();
        final result = await LibraryBackup(target).restoreJson(json);
        expect(result.tracksAdded, 3);
        expect(result.playlistsAdded, 2);
        expect((await target.playlists()).map((p) => p.name), ['Ночь', 'Ночь']);
        for (final playlist in await target.playlists()) {
          final contents = await target.tracks(playlistId: playlist.id);
          expect(
            contents.map((t) => t.title),
            playlist.count == 2
                ? [tracks[1].title, tracks[0].title]
                : [tracks[2].title],
          );
        }
        expect(
          (await target.tracks()).where((t) => t.liked).single.path,
          tracks[0].path,
        );
        expect((await target.recent()).single.path, tracks[1].path);
        expect(await target.setting('reduce_motion'), 'true');
        final targetId = (await target.tracks()).first.id;
        await target.recordPlay(targetId);
        await target.db.update(
          'tracks',
          {'title': 'Моё название', 'liked': 1},
          where: 'id=?',
          whereArgs: [targetId],
        );
        await target.setSetting('reduce_motion', 'false');
        await target.renamePlaylist(
          (await target.playlists()).first.id,
          'Переименовано',
        );
        final again = await LibraryBackup(target).restoreJson(json);
        expect(again.tracksAdded, 0);
        expect(again.playlistsAdded, 0);
        expect(await target.playlists(), hasLength(2));
        expect((await target.tracks()).first.title, 'Моё название');
        expect((await target.tracks()).first.liked, true);
        expect(await target.setting('reduce_motion'), 'false');
        expect((await target.playlists()).first.name, 'Переименовано');
        expect(await target.db.query('history'), hasLength(2));
        expect((await target.recent()).first.id, targetId);
        expect(await target.db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
      } finally {
        await source.close();
        await target.close();
        await folder.delete(recursive: true);
      }
    },
  );

  test(
    'Malformed backups are rejected before changes and transaction failures roll back all rows',
    () async {
      final store = await LibraryStore.open(databasePath: ':memory:');
      try {
        await store.addStudies();
        final playlist = await store.createPlaylist('Сохранить');
        await store.addToPlaylist(playlist, (await store.tracks()).first.id);
        final backup = LibraryBackup(store);
        final content = await backup.exportJson();
        for (final corrupt in <void Function(Map<String, dynamic>)>[
          (m) => m['version'] = 99,
          (m) => m['history'] = [
            {
              'path': m['tracks'][0]['path'],
              'played_at': '2026-02-30 00:00:00',
            },
          ],
          (m) => m['tracks'][0]['path'] = '../unsafe.mp3',
          (m) => m['tracks'][0]['path'] = 'asset:unowned.wav',
          (m) => m['tracks'][0]['duration_ms'] = -1,
          (m) => m['playlists'][0]['tracks'] = ['missing'],
          (m) => m['settings'] = {'unknown': 'true'},
          (m) => m['tracks'].add(m['tracks'][0]),
        ]) {
          final map = jsonDecode(content) as Map<String, dynamic>;
          corrupt(map);
          await expectLater(
            backup.restoreJson(jsonEncode(map)),
            throwsFormatException,
          );
          final after =
              jsonDecode(await backup.exportJson()) as Map<String, dynamic>;
          final before = jsonDecode(content) as Map<String, dynamic>;
          after.remove('created_at');
          before.remove('created_at');
          expect(after, before);
        }
        final map = jsonDecode(content) as Map<String, dynamic>;
        map['tracks'][0]['liked'] = true;
        map['playlists'][0]['key'] = 'a' * 32;
        await store.db.execute(
          "CREATE TRIGGER test_fail BEFORE INSERT ON playlists BEGIN SELECT RAISE(ABORT, 'test failure'); END",
        );
        await expectLater(
          backup.restoreJson(jsonEncode(map)),
          throwsA(isA<DatabaseException>()),
        );
        expect((await store.tracks()).where((t) => t.liked), isEmpty);
        expect(await store.playlists(), hasLength(1));
      } finally {
        await store.close();
      }
    },
  );

  test(
    'v1 migration keeps a consistent restorable backup and preserves library data',
    () async {
      // Initialize the FFI factory on Windows before creating the legacy schema.
      await (await LibraryStore.open(databasePath: ':memory:')).close();
      final folder = await Directory.systemTemp.createTemp(
        'optimum-migration-',
      );
      final path = p.join(folder.path, 'legacy.db');
      final old = await openDatabase(
        path,
        version: 1,
        onCreate: (db, _) async {
          await db.execute(
            "CREATE TABLE tracks(id INTEGER PRIMARY KEY,path TEXT NOT NULL UNIQUE COLLATE NOCASE,title TEXT NOT NULL,artist TEXT NOT NULL,album TEXT NOT NULL DEFAULT '',duration_ms INTEGER NOT NULL DEFAULT 0,liked INTEGER NOT NULL DEFAULT 0,imported_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP)",
          );
          await db.execute(
            'CREATE TABLE playlists(id INTEGER PRIMARY KEY,name TEXT NOT NULL)',
          );
          await db.execute(
            'CREATE TABLE playlist_tracks(playlist_id INTEGER NOT NULL REFERENCES playlists(id) ON DELETE CASCADE,track_id INTEGER NOT NULL REFERENCES tracks(id) ON DELETE CASCADE,position INTEGER NOT NULL,PRIMARY KEY(playlist_id,track_id))',
          );
          await db.execute(
            'CREATE TABLE history(id INTEGER PRIMARY KEY,track_id INTEGER NOT NULL REFERENCES tracks(id) ON DELETE CASCADE,played_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP)',
          );
          await db.execute('CREATE INDEX history_recent ON history(id DESC)');
          await db.execute(
            'CREATE TABLE settings(key TEXT PRIMARY KEY,value TEXT NOT NULL)',
          );
          await db.insert('tracks', {
            'id': 1,
            'path': 'asset:assets/audio/orbit_1.wav',
            'title': 'До обновления',
            'artist': 'OPTIMUM',
            'liked': 1,
          });
          await db.insert('playlists', {'id': 1, 'name': 'Старая орбита'});
          await db.insert('playlist_tracks', {
            'playlist_id': 1,
            'track_id': 1,
            'position': 0,
          });
          await db.insert('history', {'track_id': 1});
        },
      );
      await old.close();
      final migrated = await LibraryStore.open(databasePath: path);
      try {
        expect(await migrated.db.getVersion(), 2);
        expect((await migrated.tracks()).single.title, 'До обновления');
        expect((await migrated.tracks()).single.liked, true);
        expect((await migrated.playlists()).single.count, 1);
        expect((await migrated.recent()).single.title, 'До обновления');
        final before = (await folder.list().toList())
            .where((f) => f.path.contains('.before-v2-'))
            .single;
        final snapshot = await openDatabase(before.path, readOnly: true);
        try {
          expect(await snapshot.getVersion(), 1);
          expect(
            (await snapshot.query('tracks')).single['title'],
            'До обновления',
          );
          expect((await snapshot.query('playlist_tracks')), hasLength(1));
          expect(
            (await snapshot.query(
              'playlists',
            )).single.containsKey('backup_key'),
            false,
          );
          expect(
            (await snapshot.rawQuery(
              'PRAGMA integrity_check',
            )).single.values.single,
            'ok',
          );
        } finally {
          await snapshot.close();
        }
        final rows = await migrated.db.query('playlists');
        expect(rows.single['backup_key'], matches(r'^[0-9a-f]{32}$'));
        await migrated.createPlaylist('Новая');
        expect(
          (await migrated.db.query('playlists')).last['backup_key'],
          matches(r'^[0-9a-f]{32}$'),
        );
      } finally {
        await migrated.close();
        await folder.delete(recursive: true);
      }
    },
  );
}
