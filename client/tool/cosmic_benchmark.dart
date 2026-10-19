// Run with flutter run --profile -d windows -t tool/cosmic_benchmark.dart
// --dart-define=BENCHMARK_NAME=before (or after). Uses no user database.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:optimum/app_model.dart';
import 'package:optimum/data/library.dart';
import 'package:optimum/playback/controller.dart';
import 'package:optimum/ui/app.dart';
import 'package:optimum/ui/cosmos.dart';
import 'package:path/path.dart' as p;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  JustAudioMediaKit.ensureInitialized(windows: true, linux: false);
  final store = await LibraryStore.open(databasePath: ':memory:');
  await store.addStudies();
  final model = AppModel(store);
  await model.refresh();
  final player = PlaybackController(store);
  final frames = <FrameTiming>[];
  final ticks = <int>[];
  ValueListenable<double>? clock;
  var measuring = false;
  void timings(List<FrameTiming> batch) {
    if (measuring) frames.addAll(batch);
  }

  void motion() {
    if (measuring) {
      ticks.add(SchedulerBinding.instance.currentFrameTimeStamp.inMicroseconds);
    }
  }

  SchedulerBinding.instance.addTimingsCallback(timings);
  runApp(OptimumApp(model: model, player: player));
  await Future<void>.delayed(const Duration(seconds: 2));
  void findClock(Element element) {
    final widget = element.widget;
    if (widget is CosmicMotion) {
      clock ??= widget.clock;
    }
    element.visitChildren(findClock);
  }

  WidgetsBinding.instance.rootElement!.visitChildren(findClock);
  if (clock == null) throw StateError('Cosmic clock was not found');
  // Measure the active animation even if an editor window currently has focus.
  WidgetsBinding.instance.handleAppLifecycleStateChanged(
    AppLifecycleState.resumed,
  );
  clock!.addListener(motion);
  measuring = true;
  await Future<void>.delayed(const Duration(seconds: 6));
  measuring = false;
  clock!.removeListener(motion);
  SchedulerBinding.instance.removeTimingsCallback(timings);
  Map<String, double> summary(List<double> values) {
    if (values.isEmpty) return {};
    values.sort();
    double percentile(double q) => values[((values.length - 1) * q).round()];
    return {'p50': percentile(.5), 'p95': percentile(.95), 'max': values.last};
  }

  final intervals = <double>[
    for (var i = 1; i < ticks.length; i++) (ticks[i] - ticks[i - 1]) / 1000,
  ];
  final result = {
    'mode': 'profile',
    'active_lifecycle_explicit': true,
    'seconds': 6,
    'motion_ticks': ticks.length,
    'motion_hz': ticks.length > 1
        ? (ticks.length - 1) * 1000000 / (ticks.last - ticks.first)
        : 0,
    'motion_interval_ms': summary(intervals),
    'rendered_frames': frames.length,
    'build_ms': summary(
      frames.map((f) => f.buildDuration.inMicroseconds / 1000).toList(),
    ),
    'raster_ms': summary(
      frames.map((f) => f.rasterDuration.inMicroseconds / 1000).toList(),
    ),
  };
  const name = String.fromEnvironment('BENCHMARK_NAME', defaultValue: 'before');
  if (!RegExp(r'^[a-z0-9-]+$').hasMatch(name)) {
    throw ArgumentError('Benchmark name');
  }
  final target = File(
    p.join(
      Directory.current.path,
      '..',
      'artifacts',
      'cosmic-pacing-$name.json',
    ),
  );
  await target.parent.create(recursive: true);
  await target.writeAsString(
    const JsonEncoder.withIndent('  ').convert(result),
  );
  stdout.writeln(jsonEncode(result));
  await player.shutdown();
  model.dispose();
  await model.idle;
  await store.close();
  exit(0);
}
