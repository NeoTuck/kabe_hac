#!/usr/bin/env python3
"""Reject unreviewed religious text and audio in user APKs."""
import pathlib
import json
import sys
import zipfile


def audit(apk):
    with zipfile.ZipFile(apk) as archive:
        names = archive.namelist()
        rejected = [name for name in names if
                    'teknik_demo' in name or '/audio-qa/' in name or
                    '/audio/draft-v2/' in name]
        for name in names:
            if not name.endswith(('/content/umre_inventory.v1.json',
                                  '/content/hac_inventory.v1.json')):
                continue
            try:
                catalog = json.loads(archive.read(name))
                records = [*catalog['steps'], *catalog['prayerRecords'],
                           *catalog['audioRecords']]
                if any(record['status'] != 'approved' for record in records):
                    rejected.append(name)
            except (ValueError, KeyError, TypeError):
                rejected.append(name)
    if rejected:
        raise RuntimeError(f'Unreviewed content packaged in {pathlib.Path(apk).name}: {rejected}')


if __name__ == '__main__':
    if len(sys.argv) < 2:
        raise SystemExit('Pass at least one production APK')
    for file in sys.argv[1:]:
        audit(file)
        print(f'PASS production fixture exclusion: {pathlib.Path(file).name}')
