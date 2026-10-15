#!/usr/bin/env python3
"""Export draft narration intake rows without changing the app catalogs."""

import csv
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUTPUT = ROOT / 'docs/content-review/2026-10-09-kayit-metni-calisma.csv'
FIELDS = [
    'kind', 'textId', 'textVersion', 'proposedAudioId', 'proposedFile',
    'language', 'scriptDraft', 'estimatedSecondsLow', 'estimatedSecondsHigh',
    'reviewStatus', 'rightsStatus',
]


def duration_range(text):
    # Editing estimate only, not an actual audio measurement.
    words = len(re.findall(r'\S+', text))
    return round(words * 60 / 150 + 2), round(words * 60 / 100 + 5)


def main():
    rows = []
    for name in ('umre', 'hac'):
        data = json.loads((ROOT / f'assets/content/{name}_inventory.v1.json').read_text())
        audios = {a.get('textId'): a for a in data.get('audioRecords', [])
                  if a.get('kind') == 'turkishNarration'}
        for step in data['steps']:
            audio_id = audios.get(step['id'], {}).get('id',
                       f"A-{step['id']}-TR-01")
            script = f"{step['summary']}\n{step['details']}"
            low, high = duration_range(script)
            rows.append({
                'kind': 'step_narration', 'textId': step['id'],
                'textVersion': step['textVersion'],
                'proposedAudioId': audio_id,
                'proposedFile': f'{audio_id}.m4a', 'language': 'tr-TR',
                'scriptDraft': script, 'estimatedSecondsLow': low,
                'estimatedSecondsHigh': high, 'reviewStatus': 'draft_unapproved',
                'rightsStatus': 'recording_and_distribution_permission_pending',
            })
        for prayer in data.get('prayerRecords', []):
            for kind, language, text in (
                ('arabic', 'ar', prayer.get('arabic', '')),
                ('turkishMeaning', 'tr-TR', prayer.get('meaningTr', '')),
            ):
                audio = next((a for a in data.get('audioRecords', [])
                              if a.get('textId') == prayer['id']
                              and a.get('kind') == kind), None)
                if audio is None:
                    continue
                low, high = duration_range(text) if language == 'tr-TR' else ('', '')
                rows.append({
                    'kind': kind, 'textId': prayer['id'],
                    'textVersion': prayer['textVersion'],
                    'proposedAudioId': audio['id'],
                    'proposedFile': f"{audio['id']}.m4a",
                    'language': language, 'scriptDraft': text,
                    'estimatedSecondsLow': low,
                    'estimatedSecondsHigh': high,
                    'reviewStatus': 'draft_unapproved',
                    'rightsStatus': 'recording_and_distribution_permission_pending',
                })
    with OUTPUT.open('w', newline='', encoding='utf-8-sig') as target:
        writer = csv.DictWriter(target, fieldnames=FIELDS, lineterminator='\n')
        writer.writeheader()
        writer.writerows(rows)
    print(f'{len(rows)} draft recording rows written')


if __name__ == '__main__':
    main()
