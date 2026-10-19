"""Original procedural ambient studies. No samples or third-party recordings.

Reproducible mono PCM, 24 kHz, 28 s; deliberately quiet with fade-in/out.
These are actual playable onboarding tracks, explicitly labelled as sound studies.
"""
import math
import struct
import wave
from pathlib import Path

RATE = 24000
SECONDS = 28
CHORDS = [(130.8128, 164.8138, 195.9977, 246.9417),
          (146.8324, 174.6141, 220.0, 261.6256),
          (110.0, 130.8128, 164.8138, 195.9977)]


def generate(target, frequencies, phase):
    samples = bytearray()
    for i in range(RATE * SECONDS):
        t = i / RATE
        envelope = min(1, t / 3, (SECONDS - t) / 5)
        pad = sum(math.sin(2 * math.pi * f * t + .12 * math.sin(t * .4 + j)) *
                  (.7 + .3 * math.sin(t * .31 + j)) for j, f in enumerate(frequencies)) / 4
        note = frequencies[int(t * 1.5 + phase) % 4] * 4
        pluck = math.sin(2 * math.pi * note * t) * math.exp(-5 * ((t * 1.5) % 1))
        value = max(-1, min(1, envelope * (.20 * pad + .045 * pluck)))
        samples.extend(struct.pack('<h', int(value * 32767)))
    with wave.open(str(target), 'wb') as out:
        out.setparams((1, 2, RATE, 0, 'NONE', 'not compressed'))
        out.writeframes(samples)


if __name__ == '__main__':
    root = Path(__file__).resolve().parents[1] / 'client/assets/audio'
    root.mkdir(parents=True, exist_ok=True)
    for i, frequencies in enumerate(CHORDS):
        generate(root / f'orbit_{i+1}.wav', frequencies, i)
    print('Created three original 28-second PCM sound studies.')
