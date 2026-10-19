import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:optimum/data/library.dart';
import 'package:optimum/playback/controller.dart';
import 'package:path/path.dart' as p;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Windows codec matrix, Unicode paths, damaged file and recovery',
    (tester) async {
      JustAudioMediaKit.ensureInitialized(windows: true, linux: false);
      JustAudioMediaKit.bufferSize = 8 * 1024 * 1024;
      final folder = await Directory.systemTemp.createTemp('optimum-codecs-');
      final store = await LibraryStore.open(
        databasePath: p.join(folder.path, 'library.db'),
      );
      final player = PlaybackController(store);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Text('OPTIMUM · codec integration test')),
        ),
      );
      try {
        for (final extension in ['wav', 'mp3', 'flac', 'ogg', 'm4a']) {
          final source = File('test/fixtures/audio/signal.$extension');
          final local = await source.copy(
            p.join(folder.path, 'Звёздный сигнал.$extension'),
          );
          expect(await store.importPaths([local.path]), 1);
          final track = (await store.tracks()).first;
          expect(track.artist, 'OPTIMUM tests');
          await player.select([track], 0).timeout(const Duration(seconds: 15));
          await tester.pump(const Duration(milliseconds: 850));
          expect(player.error, isNull, reason: extension);
          expect(player.playing, true, reason: extension);
          expect(
            player.duration.inMilliseconds,
            closeTo(4000, 300),
            reason: extension,
          );
          expect(
            player.position.inMilliseconds,
            greaterThan(300),
            reason: extension,
          );
          await player.toggle();
          await player.seek(const Duration(seconds: 2));
          await tester.pump(const Duration(milliseconds: 350));
          expect(
            player.position.inMilliseconds,
            closeTo(2000, 300),
            reason: extension,
          );
        }
        final damaged = await File(
          'test/fixtures/audio/damaged.wav',
        ).copy(p.join(folder.path, 'damaged.wav'));
        await store.importPaths([damaged.path]);
        final broken = (await store.tracks()).first;
        await player.select([broken], 0).timeout(const Duration(seconds: 15));
        expect(player.error, isNotNull);
        expect(player.playing, false);
        final valid = (await store.tracks()).firstWhere(
          (t) => t.path.endsWith('.mp3'),
        );
        await player.select([valid], 0).timeout(const Duration(seconds: 15));
        await tester.pump(const Duration(milliseconds: 500));
        expect(player.error, isNull);
        expect(player.playing, true);
      } finally {
        await player.shutdown();
        await store.close();
        await folder.delete(recursive: true);
      }
    },
  );
}
