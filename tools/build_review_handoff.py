#!/usr/bin/env python3
"""Export a review handoff without changing catalogs or inventing signatories."""
import argparse
import csv
import hashlib
import json
import pathlib
import shutil

from review_evidence import record_digest, requirements

ROOT = pathlib.Path(__file__).resolve().parent.parent
SOURCES = (
    '2026-10-09-adim-onay-calisma.csv', '2026-10-09-dua-onay-calisma.csv',
    '2026-10-09-kayit-metni-calisma.csv', 'kayit-ve-hak-talebi.md',
    '2026-10-09-kritik-osm-yer-incelemesi.csv', 'dil-kartlari-taslak.csv')


def build(output):
    # Never overwrite a human's filled worksheet.
    output.mkdir(parents=True, exist_ok=False)
    sources = {}
    for name in SOURCES:
        source = ROOT / 'docs/content-review' / name
        shutil.copyfile(source, output / name)
        sources[name] = hashlib.sha256(source.read_bytes()).hexdigest()
    rows = []
    catalogs = {}
    counts = {}
    for name in ('umre', 'hac'):
        source = ROOT / f'assets/content/{name}_inventory.v1.json'
        data = json.loads(source.read_text())
        catalogs[name] = {'contentVersion': data['contentVersion'],
                          'sha256': hashlib.sha256(source.read_bytes()).hexdigest()}
        for kind in ('steps', 'prayerRecords', 'audioRecords'):
            counts[f'{name}_{kind}'] = len(data[kind])
            for record in data[kind]:
                for decision in requirements(kind, data['guideType']):
                    rows.append({'guideType': data['guideType'], 'kind': kind, 'id': record['id'],
                                 'textVersion': record.get('textVersion', ''),
                                 'assetSha256': record.get('assetSha256', ''),
                                 'recordSha256': record_digest(record), 'decisionKind': decision,
                                 'decision': '', 'reviewedBy': '', 'reviewedAt': '',
                                 'document': '', 'documentSha256': '', 'scope': ''})
    with (output / 'decisions.csv').open('w', encoding='utf-8-sig', newline='') as stream:
        writer = csv.DictWriter(stream, fieldnames=list(rows[0]), lineterminator='\n')
        writer.writeheader()
        writer.writerows(rows)
    (output / 'inventory.json').write_text(json.dumps({
        'schemaVersion': 1, 'status': 'awaiting_real_decisions',
        'catalogs': catalogs, 'counts': counts, 'sources': sources,
        'decisionRows': len(rows)}, ensure_ascii=False, indent=2) + '\n')
    return len(rows)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('output', type=pathlib.Path)
    args = parser.parse_args()
    print(f'Created {build(args.output)} unsigned decision rows at {args.output}')
