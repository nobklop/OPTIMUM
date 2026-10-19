import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:optimum/data/backup.dart';
import 'package:optimum/data/library.dart';
import 'package:optimum/data/link_transfer.dart';
import 'package:optimum/data/music_link.dart';
import 'package:optimum/data/yandex_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final source = MusicLink.parse(
    'https://music.yandex.ru/playlists/lk.12345678-1234-1234-1234-123456789012',
  );
  ServiceTrack track(int i) => ServiceTrack(
    MusicLink.parse('https://music.yandex.ru/album/419460/track/${10000 + i}'),
    'Исполнитель — Трек $i',
  );
  PlaylistTransfer selection(List<ServiceTrack> entries) =>
      PlaylistTransfer(source, 'Моя коллекция', entries.length, entries);

  test(
    '1295 ordered entries including repeats, atomic refresh, source identity and backup v3 merge',
    () async {
      final folder = await Directory.systemTemp.createTemp('optimum-transfer-');
      final store = await LibraryStore.open(
        databasePath: '${folder.path}/source.db',
      );
      final target = await LibraryStore.open(
        databasePath: '${folder.path}/target.db',
      );
      try {
        final entries = List.generate(1295, (i) => track(i % 1294));
        final full = selection(entries);
        final id = await store.importLinkPlaylist(full);
        expect((await store.playlists()).single.count, 1295);
        expect(await store.links(), hasLength(1294));
        expect(
          (await store.playlistLinks(id)).map((s) => s.link.uri),
          entries.map((s) => s.link.uri),
        );
        await store.renamePlaylist(id, 'Моё название');
        expect(await store.importLinkPlaylist(full), id);
        expect((await store.playlists()).single.name, 'Моё название');
        await store.db.execute(
          'CREATE TRIGGER reject_transfer BEFORE INSERT ON playlist_links WHEN NEW.position=5 BEGIN SELECT RAISE(ABORT,\'fixture failure\'); END',
        );
        await expectLater(
          store.importLinkPlaylist(selection(entries.reversed.toList())),
          throwsA(anything),
        );
        expect(
          (await store.playlistLinks(id)).map((s) => s.link.uri),
          entries.map((s) => s.link.uri),
        );
        await store.db.execute('DROP TRIGGER reject_transfer');
        await expectLater(
          store.importLinkPlaylist(
            PlaylistTransfer(source, 'Incomplete', 1296, entries),
          ),
          throwsFormatException,
        );
        final snapshot = await LibraryBackup(store).exportJson();
        expect(jsonDecode(snapshot)['version'], 3);
        // Same source imported independently has a different backup key and must merge.
        final targetId = await target.importLinkPlaylist(
          selection(entries.take(2).toList()),
        );
        await LibraryBackup(target).restoreJson(snapshot);
        await LibraryBackup(target).restoreJson(snapshot);
        expect(await target.playlists(), hasLength(1));
        expect(
          (await target.playlistLinks(targetId)).map((s) => s.link.uri),
          entries.map((s) => s.link.uri),
        );
        expect(await target.db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
        await target.removePlaylistLink(targetId, 0);
        expect(await target.playlistLinks(targetId), hasLength(1294));
        expect(
          (await target.playlistLinks(targetId)).last.link.uri,
          entries.last.link.uri,
        );
        expect(await target.links(), hasLength(1294));
        await target.deletePlaylist(targetId);
        expect(
          (await LibraryBackup(target).restoreJson(snapshot)).playlistsAdded,
          1,
        );
        expect((await target.playlists()).single.count, 1295);
        expect(
          await store.importLinkPlaylist(
            selection([entries.last, entries[4], entries.last]),
          ),
          id,
        );
        expect((await store.playlistLinks(id)).map((s) => s.link.uri), [
          entries.last.link.uri,
          entries[4].link.uri,
          entries.last.link.uri,
        ]);
        expect(
          await store.links(),
          hasLength(1294),
        ); // Refresh never deletes user links/audio.
      } finally {
        await store.close();
        await target.close();
        await folder.delete(recursive: true);
      }
    },
  );

  test(
    'Virtual rows are collected by position; cancellation or source changes restore scrolling and reject transfer',
    () async {
      Map<String, Object?> page(List<int> positions, {String? url}) => {
        'url': url ?? source.uri.toString(),
        'name': 'Коллекция',
        'totalSlots': 8,
        'declaredTracks': 7,
        'slots': positions
            .map(
              (i) => {
                'position': i,
                'track': i == 0
                    ? null
                    : {
                        'url': track(i).link.uri.toString(),
                        'title': track(i).title,
                      },
              },
            )
            .toList(),
      };
      var inspected = 0, restored = false;
      final reader = YandexPage((script) async {
        if (script == YandexPage.inspectScript) {
          return jsonEncode(
            page(inspected++ < 2 ? [0, 1, 2, 3] : [3, 4, 5, 6, 7]),
          );
        }
        if (script == YandexPage.restoreScript) { restored = true; }
        return false;
      });
      final result = await reader.playlist(cancelled: () => false);
      expect(
        result.tracks.map((s) => s.title),
        List.generate(7, (i) => track(i + 1).title),
      );
      expect(restored, true);
      restored = false;
      inspected = 0;
      final mismatch = YandexPage((script) async {
        if (script == YandexPage.inspectScript) {
          final data = page(List.generate(8, (i) => i));
          data['declaredTracks'] = inspected++ == 0 ? 8 : null;
          return jsonEncode(data);
        }
        if (script == YandexPage.restoreScript) restored = true;
        return false;
      });
      await expectLater(
        mismatch.playlist(cancelled: () => false),
        throwsFormatException,
      );
      expect(restored, true);
      inspected = 0;
      restored = false;
      final changed = YandexPage((script) async {
        if (script == YandexPage.inspectScript) {
          return jsonEncode(
            page(
              [0, 1],
              url: inspected++ == 0
                  ? null
                  : 'https://music.yandex.ru/album/419460',
            ),
          );
        }
        if (script == YandexPage.restoreScript) restored = true;
        return false;
      });
      await expectLater(
        changed.playlist(cancelled: () => false),
        throwsFormatException,
      );
      expect(restored, true);
      restored = false;
      await expectLater(
        reader.playlist(cancelled: () => true),
        throwsA(isA<TransferCancelled>()),
      );
      expect(restored, true);
    },
  );
}
