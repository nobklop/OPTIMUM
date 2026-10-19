import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optimum/ui/cosmos.dart';

void main() {
  testWidgets(
    'Motion follows each display frame and freezes when inactive or reduced',
    (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      ValueListenable<double>? clock;
      Widget scene(bool reduced) => Directionality(
        textDirection: TextDirection.ltr,
        child: Cosmos(
          reduced: reduced,
          child: Builder(
            builder: (context) {
              clock = CosmicMotion.of(context);
              return const SizedBox.expand();
            },
          ),
        ),
      );
      await tester.pumpWidget(scene(false));
      await tester.pump(const Duration(microseconds: 16667));
      var previous = clock!.value;
      var changes = 0;
      for (var i = 0; i < 120; i++) {
        await tester.pump(const Duration(microseconds: 16667));
        if (clock!.value > previous) changes++;
        previous = clock!.value;
      }
      expect(changes, 120);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump(const Duration(seconds: 1));
      expect(clock!.value, previous);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(scene(true));
      final reduced = clock!.value;
      await tester.pump(const Duration(seconds: 1));
      expect(clock!.value, reduced);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
