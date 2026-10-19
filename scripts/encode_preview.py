"""Encode full-cycle frames produced by the actual Flutter painters.

Requires Pillow from the bundled workspace Python runtime. This packages rendered
frames without inventing image content. The app's 90-second cycle is compressed
into 9.6 seconds solely to inspect the seam; it is slower in the running app.
"""
from pathlib import Path
from PIL import Image

root = Path(__file__).resolve().parents[1] / 'artifacts'
paths = sorted((root / 'cosmic-loop-frames').glob('*.png'))
if len(paths) != 120:
    raise RuntimeError(f'Expected 120 Flutter-rendered full-cycle frames, got {len(paths)}')
frames = [Image.open(path).convert('RGB') for path in paths]
frames[0].save(root / 'optimum-cosmic.gif', save_all=True, append_images=frames[1:],
               duration=80, loop=0, optimize=True, disposal=2)
for frame in frames:
    frame.close()
print(root / 'optimum-cosmic.gif')
