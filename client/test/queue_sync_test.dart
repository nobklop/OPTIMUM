import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:optimum/data/library.dart';
import 'package:optimum/playback/queue.dart';
import 'package:optimum/together/sync_clock.dart';

void main() {
  final tracks = List.generate(
    5,
    (i) => Track(id: i, path: '$i.wav', title: '$i'),
  );
  test(
    'Queue boundaries, repeat and shuffle preserve current track without duplicates',
    () {
      final queue = PlaybackQueue();
      expect(queue.next(), false);
      expect(() => queue.set([], 0), throwsArgumentError);
      queue.set(tracks, 2);
      queue.toggleShuffle(random: Random(17));
      expect(queue.current!.id, 2);
      expect(queue.tracks.map((t) => t.id).toSet().length, 5);
      queue.toggleShuffle();
      expect(queue.index, 2);
      expect(queue.tracks, tracks);
      queue.repeat = RepeatMode.one;
      expect(queue.next(completed: true), true);
      expect(queue.index, 2);
      queue.index = 4;
      queue.repeat = RepeatMode.off;
      expect(queue.next(), false);
      queue.repeat = RepeatMode.all;
      expect(queue.next(), true);
      expect(queue.index, 0);
      queue.previous();
      expect(queue.index, 0);
      expect(queue.remove(0), true);
      expect(queue.current!.id, 1);
      expect(queue.remove(4), false);
      expect(queue.current!.id, 1);
      for (final id in [1, 2, 3]) {
        queue.remove(id);
      }
      expect(queue.current, null);
    },
  );
  test(
    'Clock estimation uses four timestamps, rejects corrupt and slow samples',
    () {
      final clock = SyncClock();
      expect(clock.offsetMs, null);
      expect(
        clock.add(
          sent: 100,
          serverReceived: 620,
          serverSent: 625,
          received: 145,
        ),
        true,
      );
      expect(clock.offsetMs, 500);
      expect(
        clock.add(
          sent: 100,
          serverReceived: 620,
          serverSent: 625,
          received: 99,
        ),
        false,
      );
      expect(
        clock.add(
          sent: 100,
          serverReceived: 620,
          serverSent: 625,
          received: 5000,
        ),
        false,
      );
      expect(
        clock.add(
          sent: double.nan,
          serverReceived: 1,
          serverSent: 2,
          received: 3,
        ),
        false,
      );
      for (var i = 0; i < 6; i++) {
        clock.add(
          sent: 100,
          serverReceived: 620,
          serverSent: 625,
          received: 145,
        );
      }
      clock.add(
        sent: 100,
        serverReceived: 1200,
        serverSent: 1205,
        received: 1200,
      );
      expect(clock.offsetMs, 500);
    },
  );
  test(
    'Drift correction has a deadband, smooth speed and explicit seek threshold',
    () {
      expect(DriftCorrection.forDrift(20).speed, 1);
      expect(DriftCorrection.forDrift(100).speed, closeTo(1.01, .00001));
      expect(DriftCorrection.forDrift(-100).speed, closeTo(.99, .00001));
      expect(DriftCorrection.forDrift(240).speed, 1.02);
      expect(DriftCorrection.forDrift(250).seek, true);
      expect(DriftCorrection.forDrift(-400).seek, true);
      expect(
        () => DriftCorrection.forDrift(double.infinity),
        throwsArgumentError,
      );
    },
  );
}
