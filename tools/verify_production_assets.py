#!/usr/bin/env python3
"""Reject technical audio and QA entry-point fixture assets in production APKs."""
import pathlib
import sys
import zipfile


def audit(apk):
    with zipfile.ZipFile(apk) as archive:
        names = archive.namelist()
    rejected = [
        name for name in names
        if 'teknik_demo' in name or '/audio-qa/' in name
    ]
    if rejected:
        raise RuntimeError(f'QA fixture packaged in {pathlib.Path(apk).name}: {rejected}')


if __name__ == '__main__':
    if len(sys.argv) < 2:
        raise SystemExit('Pass at least one production APK')
    for file in sys.argv[1:]:
        audit(file)
        print(f'PASS production fixture exclusion: {pathlib.Path(file).name}')
