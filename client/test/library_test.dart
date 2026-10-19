import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:optimum/data/library.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'SQLite library survives restart; import, likes, playlists and deletion are safe',
    () async {
      final folder = await Directory.systemTemp.createTemp('optimum-library-');
      final path = p.join(folder.path, 'test.db');
      final source = File(p.join(folder.path, 'Музыка.wav'));
      await File('assets/audio/orbit_1.wav').copy(source.path);
      var store = await LibraryStore.open(databasePath: path);
      try {
        expect(
          await store.importPaths([
            source.path,
            source.path,
            p.join(folder.path, 'missing.wav'),
          ]),
          1,
        );
        var tracks = await store.tracks();
        expect(tracks, hasLength(1));
        expect(tracks.first.title, 'Музыка');
        final id = tracks.first.id;
        await store.like(id, true);
        final playlist = await store.createPlaylist(' Ночная орбита ');
        await store.addToPlaylist(playlist, id);
        await store.addToPlaylist(playlist, id);
        expect((await store.playlists()).single.count, 1);
        expect((await store.playlists()).single.name, 'Ночная орбита');
        await store.renamePlaylist(playlist, 'Космос');
        await store.recordPlay(id);
        await store.setSetting('reduce_motion', 'true');
        await store.close();
        store = await LibraryStore.open(databasePath: path);
        tracks = await store.tracks(playlistId: playlist);
        expect(tracks.single.liked, true);
        expect((await store.recent()).single.id, id);
        expect(await store.setting('reduce_motion'), 'true');
        await store.removeFromPlaylist(playlist, id);
        expect(await store.tracks(playlistId: playlist), isEmpty);
        await store.addToPlaylist(playlist, id);
        await store.remove(id);
        expect(await store.recent(), isEmpty);
        expect((await store.playlists()).single.count, 0);
        expect(await source.exists(), true);
        await store.deletePlaylist(playlist);
        expect(await store.playlists(), isEmpty);
        expect(() => store.createPlaylist(' '), throwsArgumentError);
      } finally {
        await store.close();
        await folder.delete(recursive: true);
      }
    },
  );
  test(
    'Sound studies are real audio assets and idempotently imported',
    () async {
      final store = await LibraryStore.open(databasePath: ':memory:');
      try {
        await store.addStudies();
        await store.addStudies();
        final tracks = await store.tracks();
        expect(tracks, hasLength(3));
        for (final track in tracks) {
          final bytes = await File(track.path.substring(6)).readAsBytes();
          expect(String.fromCharCodes(bytes.take(4)), 'RIFF');
          expect(track.artist, contains('звуковой этюд'));
        }
      } finally {
        await store.close();
      }
    },
  );
}
