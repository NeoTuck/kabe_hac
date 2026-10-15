#!/usr/bin/env python3
"""Resize the supplied app logo into the checked-in native icon sizes.

Only Pillow is needed to regenerate assets. Native builds use checked-in PNGs.
"""

import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
IOS = ROOT / 'ios/Runner/Assets.xcassets/AppIcon.appiconset'
ANDROID = ROOT / 'android/app/src/main/res'
SIZE = 1024
SOURCE = ROOT / 'assets/branding/app_icon_source.jpg'


def render():
    with Image.open(SOURCE) as supplied:
        return supplied.convert('RGB').resize(
            (SIZE, SIZE), Image.Resampling.LANCZOS)


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
