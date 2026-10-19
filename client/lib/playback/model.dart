import 'package:flutter/foundation.dart';
import '../data/library.dart';
import 'queue.dart';

/// UI-facing playback contract; native decoding is tested on a real platform.
abstract class PlaybackModel extends ChangeNotifier {
  PlaybackQueue get queue;
  Track? get current;
  bool get playing;
  bool get loading;
  Duration get position;
  Duration get duration;
  double get volume;
  Uint8List? get cover;
  String? get error;
  Future<void> select(List<Track> tracks, int index);
  Future<void> toggle();
  Future<void> next();
  Future<void> previous();
  Future<void> seek(Duration value);
  Future<void> setVolume(double value);
  Future<void> stop();
  Future<void> removeFromQueue(int id);
  void shuffle();
  void repeat();
}
