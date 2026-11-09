#!/usr/bin/env python3
"""Stage the male synthetic recordings for review, never for user bundling.

The source folder is supplied by the user. --check validates the staged copy
without requiring that folder to remain on the developer's machine.
"""

import argparse
import csv
import hashlib
import json
from pathlib import Path
import shutil


ROOT = Path(__file__).resolve().parent.parent
STAGED = ROOT / 'docs/audio-review/male-v1'
AUDIO = ROOT / 'assets/audio/review-male-v1'
CATALOGS = [ROOT / f'assets/content/{name}_inventory.v1.json'
            for name in ('umre', 'hac')]
VERSION = 'inventory-2026-10-26-male-review-v1'


def digest(data):
    return hashlib.sha256(data).hexdigest()


def read_json(path):
    return json.loads(path.read_text(encoding='utf-8'))


def collect(source, audio_dir=None):
    audio_dir = audio_dir or source / 'm4a'
    with (source / 'ses_envanteri.csv').open(encoding='utf-8-sig', newline='') as file:
        rows = list(csv.DictReader(file))
    if len(rows) != 54 or len({r['ses_kimligi'] for r in rows}) != 54:
        raise ValueError('Expected 54 distinct male recording IDs')

    catalogs = [read_json(path) for path in CATALOGS]
    targets = {item['id']: item for catalog in catalogs
               for key in ('steps', 'prayerRecords') for item in catalog[key]}
    audios = {item['id']: item for catalog in catalogs
              for item in catalog['audioRecords']}
    expected = {audio_id for audio_id, record in audios.items()
                if record.get('asset') and record.get('kind') in
                ('turkishNarration', 'turkishMeaning')}
    if {r['ses_kimligi'] for r in rows} != expected:
        raise ValueError('Male recordings do not cover the existing Turkish audio IDs')

    files = []
    for row in rows:
        audio_id = row['ses_kimligi']
        target = targets[row['metin_kimligi']]
        audio = audios[audio_id]
        if (row['metin_surumu'] != target['textVersion'] or
                audio['textId'] != target['id'] or
                audio['textVersion'] != target['textVersion']):
            raise ValueError(f'Text identity/version mismatch: {audio_id}')
        receipt_path = source / 'makbuzlar' / f'{audio_id}.json'
        receipt = read_json(receipt_path)
        if receipt.get('script'):
            script = receipt['script']
        else:
            script = (target['summary'] + '\n' + target['details']
                      if 'summary' in target else target['meaningTr'])
        script_hash = digest(script.encode('utf-8'))
        if script_hash != row['metin_sha256']:
            raise ValueError(f'Script mismatch: {audio_id}')
        if (receipt['audioId'] != audio_id or
                receipt['textId'] != target['id'] or
                receipt['textVersion'] != target['textVersion'] or
                receipt['scriptSha256'] != script_hash or
                receipt['sourceCommit'] !=
                '824e540a20ef3024445437d4fe43f23c8550a559' or
                receipt['model'] not in ('Supertone/supertonic-3', 'google/gemini-2.5-flash-tts', 'google/gemini-tts') or
                receipt['speakerId'] not in ('M1', 'Fenrir', 'Charon') or
                receipt['humanListeningReview'] != 'bekliyor' or
                receipt['files']['m4a']['sha256'] != row['m4a_sha256'] or
                receipt.get('formalExpertApprovalCreated') is True or
                receipt.get('previousAudioApprovalsInherited') is True):
            raise ValueError(f'Review receipt mismatch: {audio_id}')
        source_audio = audio_dir / f'{audio_id}.m4a'
        if digest(source_audio.read_bytes()) != row['m4a_sha256']:
            raise ValueError(f'Audio hash mismatch: {audio_id}')
        files.append((audio_id, source_audio, receipt_path, row['m4a_sha256']))
    return catalogs, files


def stage(source):
    catalogs, files = collect(source)
    AUDIO.mkdir(parents=True, exist_ok=True)
    (STAGED / 'makbuzlar').mkdir(parents=True, exist_ok=True)
    for audio_id, audio_file, receipt_file, sha256 in files:
        shutil.copyfile(audio_file, AUDIO / f'{audio_id}.m4a')
        shutil.copyfile(receipt_file, STAGED / 'makbuzlar' / f'{audio_id}.json')
        for catalog in catalogs:
            for record in catalog['audioRecords']:
                if record['id'] == audio_id:
                    record.update(status='draft', origin='synthetic',
                                  voiceStyle='M1',
                                  reviewOnly=True,
                                  asset=f'assets/audio/review-male-v1/{audio_id}.m4a',
                                  assetSha256=sha256)
    for name in ('ses_envanteri.csv', 'asr_ozet.csv', 'KALITE_RAPORU.md',
                 'LISANS_VE_KAYNAKLAR.md', 'teknik_ozet.json',
                 'model_hashleri.json', 'ortam.json', 'uretim_plani.json',
                 'yeniden_deneme_raporu.json'):
        shutil.copyfile(source / name, STAGED / name)
    shutil.copytree(source / 'lisanslar', STAGED / 'lisanslar', dirs_exist_ok=True)
    shutil.copytree(source / 'asr', STAGED / 'asr', dirs_exist_ok=True)
    shutil.copytree(source / 'gecmis_kontroller', STAGED / 'gecmis_kontroller',
                    dirs_exist_ok=True)
    for path, catalog in zip(CATALOGS, catalogs):
        catalog['contentVersion'] = VERSION
        path.write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + '\n',
                        encoding='utf-8')


def check():
    catalogs, files = collect(STAGED, AUDIO)
    summary = read_json(STAGED / 'teknik_ozet.json')
    if (summary.get('records') != 54 or
            summary.get('humanListeningApproved') != 0 or
            summary.get('humanListeningPending') != 54 or
            summary.get('asrAttentionCount') != 22):
        raise ValueError('Review summary changed or approvals are not yet recorded')
    license_file = STAGED / 'lisanslar/Supertonic3_OpenRAIL-M.txt'
    first_receipt = read_json(files[0][2])
    if digest(license_file.read_bytes()) != first_receipt['modelSha256']['LICENSE']:
        raise ValueError('Model license differs from recording provenance')
    if len(list((STAGED / 'asr').glob('*.json'))) != 54:
        raise ValueError('ASR review evidence is incomplete')
    if {path.stem for path in AUDIO.glob('*.m4a')} != {
            audio_id for audio_id, _, _, _ in files}:
        raise ValueError('Unexpected male review audio file')
    if any(catalog['contentVersion'] != VERSION for catalog in catalogs):
        raise ValueError('Review catalog version differs')
    for audio_id, _, _, sha256 in files:
        staged_audio = AUDIO / f'{audio_id}.m4a'
        if digest(staged_audio.read_bytes()) != sha256:
            raise ValueError(f'Staged audio hash mismatch: {audio_id}')
        matches = [record for catalog in catalogs for record in catalog['audioRecords']
                   if record['id'] == audio_id]
        if len(matches) != 1 or matches[0].get('asset') != (
                f'assets/audio/review-male-v1/{audio_id}.m4a') or (
                matches[0].get('assetSha256') != sha256 or
                matches[0].get('voiceStyle') not in ('M1', 'Fenrir', 'Charon') or
                matches[0].get('status') != 'draft' or
                matches[0].get('reviewOnly') is not True):
            raise ValueError(f'Catalog binding mismatch: {audio_id}')
    print('PASS: 54 male review recordings match text, receipts, files and catalogs')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--source', type=Path, help='User-supplied male audio folder')
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    if args.check:
        check()
    elif args.source:
        stage(args.source)
        check()
    else:
        parser.error('pass --source to stage or --check to verify')
