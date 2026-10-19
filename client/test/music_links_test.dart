import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:optimum/data/audio_download.dart';
import 'package:optimum/data/backup.dart';
import 'package:optimum/data/library.dart';
import 'package:optimum/data/music_link.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Provider permalinks normalize without tracking; hostile and unsupported URLs fail',
    () {
      final spotify = MusicLink.parse(
        ' https://open.spotify.com/intl-ru/track/0Lr4kGOYn9l83EjuK6cZFQ?si=tracking ',
      );
      expect(
        spotify.uri.toString(),
        'https://open.spotify.com/track/0Lr4kGOYn9l83EjuK6cZFQ',
      );
      expect(spotify.embedUri.path, '/embed/track/0Lr4kGOYn9l83EjuK6cZFQ');
      expect(
        MusicLink.parse(
          'https://open.spotify.com/playlist/37i9dQZF1DXcBWIGoYBM5M',
        ).kind,
        'playlist',
      );
      expect(
        MusicLink.parse(
          'https://music.yandex.kz/album/419460/track/71263?utm=x',
        ).embedUri.path,
        '/iframe/album/419460/track/71263',
      );
      expect(
        MusicLink.parse(
          'https://music.yandex.ru/users/music-blog/playlists/1000',
        ).embedUri.fragment,
        'playlist/music-blog/1000',
      );
      final sc = MusicLink.parse(
        'https://m.soundcloud.com/artist/sets/my-playlist?si=x',
      );
      expect(
        sc.embedUri.queryParameters['url'],
        'https://soundcloud.com/artist/sets/my-playlist',
      );
      expect(sc.kind, 'playlist');
      expect(
        MusicLink.parse('https://example.com/song.FLAC?download=1').service,
        MusicService.audio,
      );
      for (final url in [
        'http://soundcloud.com/a/b',
        'javascript:alert(1)',
        'file:///D:/audio.mp3',
        'https://open.spotify.com.evil.test/track/0Lr4kGOYn9l83EjuK6cZFQ',
        'https://user:secret@soundcloud.com/a/b',
        'https://soundcloud.com:444/a/b',
        'https://soundcloud.com/a/%3Cscript%3E',
        'https://soundcloud.com/a/b?secret_token=x',
        'https://soundcloud.com/discover/music',
        'https://open.spotify.com/artist/0Lr4kGOYn9l83EjuK6cZFQ',
        'https://example.com/page.html',
        'https://spotify.link/abc',
      ]) {
        expect(() => MusicLink.parse(url), throwsFormatException, reason: url);
      }
    },
  );

  test(
    'Links persist, deduplicate, survive v2 backup merge; v1 backups remain readable',
    () async {
      final folder = await Directory.systemTemp.createTemp('optimum-links-');
      var store = await LibraryStore.open(
        databasePath: p.join(folder.path, 'library.db'),
      );
      try {
        final link = MusicLink.parse(
          'https://soundcloud.com/artist/sets/playlist',
        );
        await store.saveLink(link, 'Моя подборка');
        await store.saveLink(
          MusicLink.parse('${link.uri}?si=tracking'),
          'Не перезаписывать',
        );
        await store.addStudies();
        final legacyPlaylist = await store.createPlaylist('Старый плейлист');
        await store.addToPlaylist(
          legacyPlaylist,
          (await store.tracks()).first.id,
        );
        final legacy =
            jsonDecode(await LibraryBackup(store).exportJson())
                as Map<String, dynamic>;
        legacy['version'] = 2;
        for (final row in legacy['playlists'] as List) {
          (row as Map).remove('source_url');
          row.remove('links');
        }
        final backup = jsonEncode(legacy);
        await store.close();
        store = await LibraryStore.open(
          databasePath: p.join(folder.path, 'library.db'),
        );
        expect((await store.links()).single.title, 'Моя подборка');
        final target = await LibraryStore.open(
          databasePath: p.join(folder.path, 'target.db'),
        );
        try {
          await LibraryBackup(target).restoreJson(backup);
          await LibraryBackup(target).restoreJson(backup);
          expect(await target.links(), hasLength(1));
          expect((await target.playlists()).single.count, 1);
          final old = jsonDecode(backup) as Map<String, dynamic>;
          old['version'] = 1;
          old.remove('links');
          await LibraryBackup(target).restoreJson(jsonEncode(old));
          expect(await target.links(), hasLength(1));
          final invalid = jsonDecode(backup) as Map<String, dynamic>;
          invalid['links'] = [
            {'url': 'javascript:alert(1)', 'title': 'Bad'},
          ];
          await expectLater(
            LibraryBackup(target).restoreJson(jsonEncode(invalid)),
            throwsFormatException,
          );
          expect(await target.tracks(), hasLength(3));
          await target.removeLink((await target.links()).single.id);
          expect(await target.links(), isEmpty);
          expect(await target.tracks(), hasLength(3));
        } finally {
          await target.close();
        }
      } finally {
        await store.close();
        await folder.delete(recursive: true);
      }
    },
  );

  test(
    'Downloaded link and local path survive restart and backup without replacing existing associations',
    () async {
      final folder = await Directory.systemTemp.createTemp(
        'optimum-download-link-',
      );
      var source = await LibraryStore.open(
        databasePath: p.join(folder.path, 'source.db'),
      );
      final target = await LibraryStore.open(
        databasePath: p.join(folder.path, 'target.db'),
      );
      try {
        final file = await File(
          'test/fixtures/audio/signal.wav',
        ).copy(p.join(folder.path, 'download.wav'));
        final link = MusicLink.parse('https://example.com/song.wav');
        await source.saveLink(link, 'Мой этюд');
        await source.linkDownload(
          (await source.links()).single.id,
          file.path,
          'Мой этюд',
        );
        await source.close();
        source = await LibraryStore.open(
          databasePath: p.join(folder.path, 'source.db'),
        );
        expect((await source.links()).single.downloadPath, file.path);
        final snapshot = await LibraryBackup(source).exportJson();
        // Existing URL without a download association must acquire the restored path.
        await target.saveLink(link, 'Текущее название');
        await LibraryBackup(target).restoreJson(snapshot);
        await LibraryBackup(target).restoreJson(snapshot);
        expect((await target.links()).single.title, 'Текущее название');
        expect((await target.links()).single.downloadPath, file.path);
        expect(await target.tracks(), hasLength(1));
        await target.remove((await target.tracks()).single.id);
        expect((await target.links()).single.downloadPath, isNull);
        await LibraryBackup(target).exportJson();
        await LibraryBackup(target).restoreJson(snapshot);
        await target.removeLink((await target.links()).single.id);
        expect(await file.exists(), true);
        expect(await target.tracks(), hasLength(1));
      } finally {
        await source.close();
        await target.close();
        await folder.delete(recursive: true);
      }
    },
  );

  test(
    'v3 to v4 migration backs up old schema and rolls back if migration fails',
    () async {
      final folder = await Directory.systemTemp.createTemp('optimum-v4-');
      final path = p.join(folder.path, 'library.db');
      var store = await LibraryStore.open(databasePath: path);
      await store.addStudies();
      await store.db.execute('DROP TABLE playlist_links');
      await store.db.execute('DROP INDEX playlists_source_url');
      await store.db.execute('ALTER TABLE playlists DROP COLUMN source_url');
      await store.db.setVersion(3);
      await store.close();
      store = await LibraryStore.open(databasePath: path);
      expect(await store.db.getVersion(), 4);
      expect(await store.tracks(), hasLength(3));
      expect(await store.links(), isEmpty);
      await store.close();
      final snapshots = (await folder.list().toList()).where(
        (f) => f.path.contains('.before-v4-'),
      );
      final original = await openDatabase(
        snapshots.single.path,
        readOnly: true,
      );
      expect(await original.getVersion(), 3);
      expect(await original.query('tracks'), hasLength(3));
      await original.close();
      // Duplicate column deliberately causes ALTER to fail, preserving old version/data.
      final broken = await openDatabase(path);
      await broken.setVersion(3);
      await broken.close();
      await expectLater(
        LibraryStore.open(databasePath: path),
        throwsA(isA<DatabaseException>()),
      );
      final after = await openDatabase(path, readOnly: true);
      expect(await after.getVersion(), 3);
      expect(await after.query('tracks'), hasLength(3));
      await after.close();
      await folder.delete(recursive: true);
    },
  );

  test(
    'Streaming download commits exact bytes, cleans failures/cancellation, never deletes existing audio',
    () async {
      final folder = await Directory.systemTemp.createTemp('optimum-download-');
      final audio = await File('test/fixtures/audio/signal.wav').readAsBytes();
      try {
        final saved = await saveAudioStream(
          Stream.fromIterable([audio.sublist(0, 7), audio.sublist(7)]),
          folder,
          extension: '.wav',
          expectedBytes: audio.length,
        );
        expect(await saved.readAsBytes(), audio);
        Future<void> rejects(
          Stream<List<int>> stream, {
          int? length,
          int limit = AudioDownload.maxBytes,
          bool Function()? cancel,
        }) async {
          await expectLater(
            saveAudioStream(
              stream,
              folder,
              extension: '.wav',
              expectedBytes: length,
              limit: limit,
              cancelled: cancel,
            ),
            throwsA(anything),
          );
          expect((await folder.list().toList()).map((f) => f.path), [
            saved.path,
          ]);
          expect(await saved.readAsBytes(), audio);
        }

        await rejects(Stream.value(utf8.encode('<html>not music</html>')));
        await rejects(Stream.value(audio), length: audio.length + 1);
        await rejects(Stream.value(audio), limit: audio.length - 1);
        await rejects(Stream.value(audio), cancel: () => true);
        await rejects(
          Stream<List<int>>.error(const SocketException('Disconnected')),
        );
        var cancelled = false;
        await expectLater(
          saveAudioStream(
            Stream.value(audio),
            folder,
            extension: '.wav',
            cancelled: () => cancelled,
            progress: (_, _) => cancelled = true,
          ),
          throwsA(isA<DownloadCancelled>()),
        );
        expect((await folder.list().toList()), hasLength(1));
      } finally {
        await folder.delete(recursive: true);
      }
    },
  );
}
