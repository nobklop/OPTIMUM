import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optimum/app_model.dart';
import 'package:optimum/data/library.dart';
import 'package:optimum/playback/model.dart';
import 'package:optimum/playback/queue.dart';
import 'package:optimum/ui/app.dart';

void main() {
  setUpAll(() async {
    final fonts = FontLoader('Manrope')
      ..addFont(rootBundle.load('assets/fonts/Manrope.ttf'));
    await fonts.load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  for (final size in [const Size(1440, 960), const Size(390, 844)]) {
    testWidgets(
      'Real Flutter layout and navigation at ${size.width}x${size.height}',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        final model = (await tester.runAsync(() async {
          final store = await LibraryStore.open(databasePath: ':memory:');
          await store.setSetting('reduce_motion', 'true');
          final model = AppModel(store);
          await model.refresh();
          return model;
        }))!;
        final store = model.store;
        final player = IdlePlayback();
        final boundary = GlobalKey();
        try {
          await tester.pumpWidget(
            RepaintBoundary(
              key: boundary,
              child: OptimumApp(model: model, player: player),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('Музыка.\nБлиже к вам.'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.runAsync(() async {
            final image =
                await (boundary.currentContext!.findRenderObject()
                        as RenderRepaintBoundary)
                    .toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await Directory('../artifacts').create(recursive: true);
            await File(
              '../artifacts/flutter-home-${size.width.toInt()}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
          await tester.tap(find.text('Библиотека').first);
          await tester.pumpAndSettle();
          expect(find.text('Ваша библиотека'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.tap(find.text('Плейлисты').first);
          await tester.pumpAndSettle();
          await tester.tap(find.text('Создать плейлист'));
          await tester.pumpAndSettle();
          await tester.enterText(find.byType(TextField).last, 'Моя орбита');
          await tester.tap(find.text('Сохранить'));
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 150)),
          );
          await tester.pumpAndSettle();
          expect(find.text('Моя орбита'), findsOneWidget);
          await tester.tap(find.text('Together').first);
          await tester.pumpAndSettle();
          expect(find.text('Разработка модуля'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.tap(find.text('Настройки').first);
          await tester.pumpAndSettle();
          expect(find.text('Уменьшить движение'), findsOneWidget);
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox());
          model.dispose();
          player.dispose();
          await tester.runAsync(() async {
            await model.idle;
            await store.close();
          });
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        }
      },
    );
  }
}

// Test double for layout tests only. Real audio is covered by the Windows integration test.
class IdlePlayback extends PlaybackModel {
  @override
  final queue = PlaybackQueue();
  @override
  Track? get current => null;
  @override
  bool get playing => false;
  @override
  bool get loading => false;
  @override
  Duration get position => Duration.zero;
  @override
  Duration get duration => Duration.zero;
  @override
  double get volume => 1;
  @override
  Uint8List? get cover => null;
  @override
  String? get error => null;
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('Audio operation in layout test');
}
