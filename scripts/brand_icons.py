"""Rasterize the project's simple geometric vector mark into native launcher icons.
Only stdlib; no third-party image assets.
"""
import json
import math
import struct
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / 'client'


def png(size):
    rows = bytearray()
    for y in range(size):
        rows.append(0)
        for x in range(size):
            light = 0
            for dx, dy in [(0.25, .25), (.75, .25), (.25, .75), (.75, .75)]:
                nx, ny = (x + dx) / size - .5, (y + dy) / size - .5
                distance = math.hypot(nx, ny)
                if .255 < distance < .29 or distance < .06 or math.hypot(nx-.22, ny+.22) < .047:
                    light += 1
            value = int(9 + 235 * light / 4)
            rows.extend((value, value, min(255, value + 2), 255))

    def chunk(kind, data):
        return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data))
    return (b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', size, size, 8, 6, 0, 0, 0))
            + chunk(b'IDAT', zlib.compress(bytes(rows))) + chunk(b'IEND', b''))


if __name__ == '__main__':
    sizes = [16, 32, 48, 256]
    images = [png(s) for s in sizes]
    offset = 6 + len(sizes) * 16
    icon = bytearray(struct.pack('<HHH', 0, 1, len(sizes)))
    for size, data in zip(sizes, images):
        icon.extend(struct.pack('<BBBBHHII', size % 256, size % 256, 0, 0, 1, 32, len(data), offset))
        offset += len(data)
    (ROOT / 'windows/runner/resources/app_icon.ico').write_bytes(icon + b''.join(images))
    for density, size in [('mdpi',48),('hdpi',72),('xhdpi',96),('xxhdpi',144),('xxxhdpi',192)]:
        (ROOT / f'android/app/src/main/res/mipmap-{density}/ic_launcher.png').write_bytes(png(size))
    ios = ROOT / 'ios/Runner/Assets.xcassets/AppIcon.appiconset'
    for item in json.loads((ios/'Contents.json').read_text())['images']:
        size = round(float(item['size'].split('x')[0]) * float(item['scale'].replace('x','')))
        (ios/item['filename']).write_bytes(png(size))
    print('Generated original OPTIMUM launcher marks for Windows/Android/iOS.')
