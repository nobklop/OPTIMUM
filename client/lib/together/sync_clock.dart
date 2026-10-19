import 'dart:math';

class ClockSample {
  final double offsetMs, rttMs;
  const ClockSample(this.offsetMs, this.rttMs);
}

class SyncClock {
  final List<ClockSample> _samples = [];
  bool add({
    required double sent,
    required double serverReceived,
    required double serverSent,
    required double received,
  }) {
    final values = [sent, serverReceived, serverSent, received];
    if (values.any((v) => !v.isFinite) ||
        received < sent ||
        serverSent < serverReceived) {
      return false;
    }
    final rtt = received - sent - (serverSent - serverReceived);
    if (rtt < 0 || rtt > 2000) return false;
    _samples.add(
      ClockSample(((serverReceived - sent) + (serverSent - received)) / 2, rtt),
    );
    if (_samples.length > 20) _samples.removeAt(0);
    return true;
  }

  double? get offsetMs {
    if (_samples.isEmpty) return null;
    final best = List<ClockSample>.of(_samples)
      ..sort((a, b) => a.rttMs.compareTo(b.rttMs));
    final offsets =
        best.take(min(5, best.length)).map((s) => s.offsetMs).toList()..sort();
    return offsets[offsets.length ~/ 2];
  }
}

class DriftCorrection {
  final double speed;
  final bool seek;
  const DriftCorrection(this.speed, this.seek);
  factory DriftCorrection.forDrift(double targetMinusActualMs) {
    if (!targetMinusActualMs.isFinite) throw ArgumentError('Non-finite drift');
    if (targetMinusActualMs.abs() >= 250) return const DriftCorrection(1, true);
    if (targetMinusActualMs.abs() <= 40) return const DriftCorrection(1, false);
    return DriftCorrection(
      (1 + targetMinusActualMs / 10000).clamp(.98, 1.02),
      false,
    );
  }
}
