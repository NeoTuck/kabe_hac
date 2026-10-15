#!/usr/bin/env python3
"""Audit inventory structure and export worksheets without approving content."""
import argparse
import collections
import csv
import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
FIELDS = ['id', 'order', 'groupId', 'title', 'status', 'textVersion', 'summary', 'details',
          'arabic', 'transliteration', 'meaningTr', 'sourceTitle', 'sourceUrl',
          'sourceLocation', 'sourceAccessedAt', 'sourceUsageRights', 'reviewedBy', 'reviewedAt']


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--export', action='store_true', help='Write review CSVs and a declared-status snapshot')
    args = parser.parse_args()
    if args.export:
        for name in ('umre', 'hac'):
            target = ROOT / f'docs/content-review/{name}-inceleme.csv'
            if target.exists():
                sys.exit(f'FAIL: worksheet exists, preserve its edits: {target}')
    summary = {'note': 'Declared inventory statuses only; not expert approval or release acceptance.', 'guides': {}}
    for name, kind, count in [('umre', 'umrah', 18), ('hac', 'hajj', 35)]:
        path = ROOT / f'assets/content/{name}_inventory.v1.json'
        data = json.loads(path.read_text())
        steps = data['steps']
        if data['guideType'] != kind or len(steps) != count:
            sys.exit(f'FAIL: {name} inventory count/type mismatch')
        ids = [step['id'] for step in steps]
        if len(set(ids)) != count or sorted(step['order'] for step in steps) != list(range(1, count + 1)):
            sys.exit(f'FAIL: {name} duplicate IDs or noncontiguous order')
        if any(step['status'] not in ('draft', 'pendingReview', 'approved') for step in steps):
            sys.exit(f'FAIL: {name} invalid declared status')
        summary['guides'][name] = {'content_version': data['contentVersion'], 'step_count': count,
                                  'declared_status_counts': dict(collections.Counter(s['status'] for s in steps)),
                                  'prayer_records': len(data.get('prayerRecords', [])),
                                  'audio_records': len(data.get('audioRecords', []))}
        if args.export:
            destination = ROOT / 'docs/content-review'
            destination.mkdir(parents=True, exist_ok=True)
            target = destination / f'{name}-inceleme.csv'
            # Worksheets may contain expert edits; never overwrite them silently.
            if target.exists():
                sys.exit(f'FAIL: worksheet exists, preserve its edits: {target}')
            with target.open('w', newline='', encoding='utf-8-sig') as file:
                writer = csv.DictWriter(file, fieldnames=FIELDS)
                writer.writeheader()
                writer.writerows({key: s.get(key, '') for key in FIELDS} for s in sorted(steps, key=lambda s: s['order']))
    if args.export:
        destination = ROOT / 'docs/qa/content-inventory.json'
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_text(json.dumps(summary, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps(summary, ensure_ascii=False, indent=2))
    return 0


if __name__ == '__main__':
    sys.exit(main())
