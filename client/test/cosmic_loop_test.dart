import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optimum/ui/cosmos.dart';

void main() {
  testWidgets(
    'Cosmic cycle returns to the same rendered frame without a seam',
    (tester) async {
      tester.view.physicalSize = const Size(640, 400);
      tester.view.devicePixelRatio = 1;
      final key = GlobalKey();
      final pointer = ValueNotifier(Offset.zero);
      Future<ui.Image> frame(double phase) async {
        final clock = AlwaysStoppedAnimation<double>(phase);
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: ColoredBox(
              color: ink,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: CustomPaint(painter: StarPainter(clock, pointer)),
                  ),
                  Center(
                    child: SizedBox.square(
                      dimension: 350,
                      child: CustomPaint(painter: OrbitPainter(0, clock)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        return (await tester.runAsync(
          () =>
              (key.currentContext!.findRenderObject() as RenderRepaintBoundary)
                  .toImage(),
        ))!;
      }

      try {
        final target = Directory('../artifacts/cosmic-loop-frames');
        await tester.runAsync(() => target.create(recursive: true));
        List<int>? first;
        for (var i = 0; i <= 120; i++) {
          final image = await frame(i / 120);
          final raw = (await tester.runAsync(
            () => image.toByteData(),
          ))!.buffer.asUint8List();
          first ??= List.of(raw);
          if (i == 120) {
            var differences = 0;
            for (var j = 0; j < raw.length; j++) {
              if ((raw[j] - first[j]).abs() > 1) {
                differences++;
              }
            }
            expect(differences / raw.length, lessThan(.00001));
          } else {
            final png = await tester.runAsync(
              () => image.toByteData(format: ui.ImageByteFormat.png),
            );
            await tester.runAsync(
              () => File(
                '${target.path}/${i.toString().padLeft(3, '0')}.png',
              ).writeAsBytes(png!.buffer.asUint8List()),
            );
          }
          image.dispose();
        }
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        pointer.dispose();
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      }
    },
  );
}
