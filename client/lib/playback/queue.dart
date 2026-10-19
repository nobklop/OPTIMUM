import 'dart:math';
import '../data/library.dart';

enum RepeatMode { off, all, one }

class PlaybackQueue {
  List<Track> tracks = [];
  int index = 0;
  RepeatMode repeat = RepeatMode.off;
  bool shuffled = false;
  List<Track> _original = [];
  Track? get current => tracks.isEmpty ? null : tracks[index];
  void set(List<Track> source, int selected) {
    if (source.isEmpty || selected < 0 || selected >= source.length) {
      throw ArgumentError('Invalid queue selection');
    }
    tracks = List.of(source);
    _original = List.of(source);
    index = selected;
    shuffled = false;
  }

  bool next({bool completed = false}) {
    if (tracks.isEmpty) return false;
    if (completed && repeat == RepeatMode.one) return true;
    if (index + 1 < tracks.length) {
      index++;
      return true;
    }
    if (repeat == RepeatMode.all) {
      index = 0;
      return true;
    }
    return false;
  }

  void previous() {
    if (index > 0) index--;
  }

  bool remove(int id) {
    final selectedId = current?.id;
    final removedCurrent = selectedId == id;
    tracks.removeWhere((track) => track.id == id);
    _original.removeWhere((track) => track.id == id);
    if (tracks.isEmpty) {
      index = 0;
    } else if (removedCurrent) {
      index = min(index, tracks.length - 1);
    } else {
      index = tracks.indexWhere((track) => track.id == selectedId);
    }
    return removedCurrent;
  }

  void toggleShuffle({Random? random}) {
    if (tracks.isEmpty) return;
    final selected = current!;
    shuffled = !shuffled;
    if (shuffled) {
      final rest = tracks.where((t) => t.id != selected.id).toList()
        ..shuffle(random);
      tracks = [selected, ...rest];
      index = 0;
    } else {
      tracks = List.of(_original);
      index = tracks.indexWhere((t) => t.id == selected.id);
    }
  }
}
