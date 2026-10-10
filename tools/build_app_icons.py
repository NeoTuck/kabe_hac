#!/usr/bin/env python3
"""Render the project's original book-and-path mark into native icon sizes.

Only Pillow is needed to regenerate assets. Native builds use checked-in PNGs.
"""

import json
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
IOS = ROOT / 'ios/Runner/Assets.xcassets/AppIcon.appiconset'
ANDROID = ROOT / 'android/app/src/main/res'
SIZE = 1024
SCALE = 4


def render():
    canvas = Image.new('RGB', (SIZE * SCALE, SIZE * SCALE), '#12443f')
    draw = ImageDraw.Draw(canvas)

    def polygon(points, fill):
        draw.polygon([(int(x * SCALE), int(y * SCALE)) for x, y in points], fill=fill)

    def line(points, fill, width, joint='curve'):
        draw.line([(int(x * SCALE), int(y * SCALE)) for x, y in points],
                  fill=fill, width=int(width * SCALE), joint=joint)

    # Two pages form an open guidebook. The curved gold path is a journey
    # marker; it deliberately avoids a depiction of a sacred site.
    polygon([(164, 444), (485, 516), (485, 790), (164, 716)], '#f8f3e8')
    polygon([(539, 516), (860, 444), (860, 716), (539, 790)], '#f8f3e8')
    line([(512, 528), (512, 816)], '#e7bb69', 20)
    line([(204, 665), (456, 724)], '#d3ded5', 15)
    line([(568, 724), (820, 665)], '#d3ded5', 15)
    line([(512, 480), (447, 402), (470, 324), (576, 304), (604, 220)],
         '#e7bb69', 42)
    draw.ellipse((578 * SCALE, 190 * SCALE, 630 * SCALE, 242 * SCALE),
                 fill='#e7bb69')
    return canvas.resize((SIZE, SIZE), Image.Resampling.LANCZOS)


def main():
    icon = render()
    contents = json.loads((IOS / 'Contents.json').read_text())
    for item in contents['images']:
        size = float(item['size'].split('x')[0])
        scale = int(item['scale'][0])
        pixels = round(size * scale)
        icon.resize((pixels, pixels), Image.Resampling.LANCZOS).save(
            IOS / item['filename'])
    for density, pixels in {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96,
                            'xxhdpi': 144, 'xxxhdpi': 192}.items():
        icon.resize((pixels, pixels), Image.Resampling.LANCZOS).save(
            ANDROID / f'mipmap-{density}/ic_launcher.png')


if __name__ == '__main__':
    main()
