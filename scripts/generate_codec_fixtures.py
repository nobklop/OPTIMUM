"""Encode short original OPTIMUM audio into real codec fixtures (development only)."""
import argparse
import subprocess
import sys
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('--ffmpeg', type=Path)
args = parser.parse_args()
if args.ffmpeg:
    encoder = str(args.ffmpeg)
else:
    sys.path.insert(0, r'D:\OptimumTools\media-fixtures')
    import imageio_ffmpeg
    encoder = imageio_ffmpeg.get_ffmpeg_exe()
root = Path(__file__).resolve().parents[1]
target = root / 'client/test/fixtures/audio'
target.mkdir(parents=True, exist_ok=True)
codecs = {'wav': ['-c:a', 'pcm_s16le'], 'mp3': ['-c:a', 'libmp3lame', '-b:a', '96k'],
          'flac': ['-c:a', 'flac'], 'ogg': ['-c:a', 'libvorbis', '-q:a', '4'],
          'm4a': ['-c:a', 'aac', '-b:a', '96k']}
for extension, options in codecs.items():
    subprocess.run([encoder, '-hide_banner', '-loglevel', 'error', '-y',
                    '-i', str(root / 'client/assets/audio/orbit_1.wav'), '-t', '4',
                    '-metadata', 'title=OPTIMUM codec fixture', '-metadata', 'artist=OPTIMUM tests',
                    '-metadata', 'album=Codec validation', *options,
                    str(target / f'signal.{extension}')], check=True)
(target / 'damaged.wav').write_bytes(b'Invalid audio fixture\x00' * 256)
print('Generated WAV, MP3, FLAC, OGG, AAC/M4A and damaged fixtures from original synthesis.')
