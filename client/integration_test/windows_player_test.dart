import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:optimum/app_model.dart';
import 'package:optimum/data/library.dart';
import 'package:optimum/playback/controller.dart';
import 'package:optimum/playback/queue.dart' as playback;
import 'package:optimum/ui/app.dart';
import 'package:path/path.dart' as p;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Windows: real decoding, pause, seek, queue, errors and rendered UI',
    (tester) async {
      JustAudioMediaKit.ensureInitialized(windows: true, linux: false);
      JustAudioMediaKit.bufferSize = 8 * 1024 * 1024;
      final folder = await Directory.systemTemp.createTemp('optimum-native-');
      final store = await LibraryStore.open(
        databasePath: p.join(folder.path, 'library.db'),
      );
      final model = AppModel(store);
      final player = PlaybackController(store);
      final boundary = GlobalKey();
      try {
        await store.setSetting('reduce_motion', 'true');
        await model.refresh();
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: OptimumApp(model: model, player: player),
          ),
        );
        await tester.pumpAndSettle();
        await model.addStudies();
        await player.setVolume(.15);
        await player.select(model.tracks, 0);
        await tester.pump(const Duration(seconds: 2));
        expect(player.error, isNull);
        expect(player.playing, true);
        expect(player.position.inMilliseconds, greaterThan(500));
        expect(player.duration.inSeconds, 28);
        await player.toggle();
        final pausedAt = player.position;
        await tester.pump(const Duration(milliseconds: 600));
        expect(
          (player.position - pausedAt).inMilliseconds.abs(),
          lessThan(100),
        );
        await player.seek(const Duration(seconds: 12));
        expect(player.position.inMilliseconds, closeTo(12000, 300));
        await player.toggle();
        await tester.pump(const Duration(milliseconds: 500));
        final firstId = player.current!.id;
        await player.next();
        await tester.pump(const Duration(milliseconds: 500));
        expect(player.current!.id, isNot(firstId));
        expect(player.error, isNull);
        await player.toggle();
        await tester.tap(find.text('Библиотека').first);
        await model.idle;
        await tester.pumpAndSettle();
        expect(find.text('Ваша библиотека'), findsOneWidget);
        expect(tester.takeException(), isNull);
        final image =
            await (boundary.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final artifacts = Directory(
          p.join(Directory.current.path, '..', 'artifacts'),
        );
        await artifacts.create(recursive: true);
        await File(
          p.join(artifacts.path, 'windows-library.png'),
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
        expect(
          await store.recent(),
          isEmpty,
        ); // Seeking does not count as listening.
        player.queue.repeat = playback.RepeatMode.one;
        final repeatingId = player.current!.id;
        await player.toggle();
        await player.seek(const Duration(milliseconds: 27500));
        await tester.pump(const Duration(seconds: 2));
        expect(player.current!.id, repeatingId);
        expect(player.playing, true);
        expect(player.position.inSeconds, lessThan(4));
        player.queue.repeat = playback.RepeatMode.off;
        await player.seek(const Duration(milliseconds: 27500));
        await tester.pump(const Duration(seconds: 2));
        expect(player.current!.id, isNot(repeatingId));
        await player.seek(const Duration(milliseconds: 27500));
        await tester.pump(const Duration(seconds: 2));
        expect(player.playing, false);
        await player.select(model.tracks, 0);
        await tester.pump(const Duration(seconds: 11));
        expect((await store.recent()).first.id, player.current!.id);
        await player.toggle();

        await tester.tap(find.text('Главная').first);
        await model.idle;
        await model.motion(false);
        await tester.pump(const Duration(milliseconds: 400));
        final frames = Directory(p.join(artifacts.path, 'cosmic-frames'));
        await frames.create(recursive: true);
        Uint8List? firstFrame;
        Uint8List? lastFrame;
        Future<Uint8List> capture() async {
          final image =
              await (boundary.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          image.dispose();
          return bytes!.buffer.asUint8List();
        }

        for (var i = 0; i < 36; i++) {
          await tester.pump(const Duration(milliseconds: 140));
          final bytes = await capture();
          firstFrame ??= bytes;
          lastFrame = bytes;
          await File(
            p.join(frames.path, '${i.toString().padLeft(3, '0')}.png'),
          ).writeAsBytes(bytes);
        }
        expect(listEquals(firstFrame, lastFrame), false);
        await File(
          p.join(artifacts.path, 'windows-cosmic.png'),
        ).writeAsBytes(lastFrame!);
        await model.motion(true);
        await tester.pump(const Duration(milliseconds: 400));
        final frozen = await capture();
        await tester.pump(const Duration(seconds: 1));
        expect(listEquals(frozen, await capture()), true);
        expect(tester.takeException(), isNull);
        await player.select([
          const Track(
            id: -1,
            path: 'Z:\\missing-optimum.wav',
            title: 'Missing test file',
          ),
        ], 0);
        expect(player.error, contains('Файл перемещён или удалён'));
        expect(player.playing, false);
        await player.toggle();
        expect(player.error, contains('Файл перемещён или удалён'));
        expect(
          player.playing,
          false,
        ); // A failed load must never resume the previous recording.
      } finally {
        await tester.pumpWidget(const SizedBox());
        await player.shutdown();
        model.dispose();
        await model.idle;
        await store.close();
        await folder.delete(recursive: true);
      }
    },
  );
}
