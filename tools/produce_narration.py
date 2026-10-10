#!/usr/bin/env python3
"""Prepare all 55 bindings; generate only reviewed Turkish text with rights input.

No credentials enter plans, receipts or mobile assets. Generation is offline
pack preparation, never phone-side synthesis or automatic religious approval.
"""
import argparse
import base64
import datetime
import hashlib
import json
import os
import re
from pathlib import Path
import subprocess
import tempfile
import urllib.request

ROOT = Path(__file__).resolve().parent.parent
API = 'https://texttospeech.googleapis.com/v1/text:synthesize'
TERMS = 'https://cloud.google.com/terms'


def sha(data):
    return hashlib.sha256(data).hexdigest()


def checked_date(raw):
    date = datetime.date.fromisoformat(raw)
    if date > datetime.datetime.now(datetime.timezone.utc).date():
        raise ValueError('Future review date')
    return date


def reviewed(record):
    if record.get('status') != 'approved':
        return False
    for field in ('reviewedBy', 'reviewedAt', 'sourceTitle', 'sourceUrl',
                  'sourceLocation', 'sourceUsageRights', 'textVersion'):
        if not isinstance(record.get(field), str) or not record[field].strip():
            return False
    try:
        checked_date(record['reviewedAt'][:10])
    except (ValueError, TypeError):
        return False
    rights = record['sourceUsageRights'].lower()
    return not any(marker in rights for marker in
                   ('bekliyor', 'bilinmiyor', 'teyit edilmedi', 'pending', 'unknown'))


def plan(catalogs):
    result, ids = [], set()
    for catalog in catalogs:
        existing = {(a['textId'], a['kind']): a for a in catalog.get('audioRecords', [])}
        for text, is_step in [(t, True) for t in catalog['steps']] + [(t, False) for t in catalog.get('prayerRecords', [])]:
            scripts = [('turkishNarration', 'tr-TR', text['summary'] + '\n' + text['details'])] \
                if is_step else [('arabic', 'ar', text['arabic']),
                                         ('turkishMeaning', 'tr-TR', text['meaningTr'])]
            for kind, language, script in scripts:
                suffix = {'turkishNarration': 'TR', 'arabic': 'AR', 'turkishMeaning': 'ANLAM'}[kind]
                audio_id = existing.get((text['id'], kind), {}).get('id', f"A-{text['id']}-{suffix}-01")
                if not re.fullmatch(r'A-[A-Z0-9][A-Z0-9._-]{1,80}', audio_id):
                    raise ValueError('Unsafe audio ID')
                if audio_id in ids:
                    raise ValueError('Duplicate audio ID')
                ids.add(audio_id)
                result.append({
                    'audioId': audio_id, 'textId': text['id'], 'textVersion': text['textVersion'],
                    'kind': kind, 'language': language, 'script': script,
                    'scriptSha256': sha(script.encode()), 'textReview': text.get('status'),
                    'eligibleForSynthesis': language == 'tr-TR' and reviewed(text),
                    'file': f'recordings/{audio_id}.m4a',
                    'requiredOrigin': 'reviewed-human-recording' if language == 'ar' else 'synthetic-or-human',
                    'sourceUrl': text.get('sourceUrl'),
                })
    return {'schemaVersion': 1, 'records': result,
            'note': 'Intake only. Neither rights nor pronunciation approval is granted.'}


def request_body(record, voice):
    if not record['eligibleForSynthesis'] or record['language'] != 'tr-TR':
        raise ValueError('Unreviewed or non-Turkish text cannot be synthesized for release')
    if not voice.startswith('tr-TR-'):
        raise ValueError('Explicit Turkish voice required')
    if sha(record['script'].encode()) != record['scriptSha256']:
        raise ValueError('Script changed after binding')
    return {'input': {'text': record['script']},
            'voice': {'languageCode': 'tr-TR', 'name': voice},
            'audioConfig': {'audioEncoding': 'LINEAR16'}}


def rights_input(data, voice):
    if (data.get('provider') != 'google-cloud-tts' or data.get('termsUrl') != TERMS or
            data.get('usageScope') != 'application-and-offline-distribution' or
            data.get('voice') != voice or data.get('result') != 'accepted'):
        raise ValueError('Provider output-use evidence does not cover this generation')
    for field in ('reviewedBy', 'reviewedAt', 'projectId', 'evidenceReference'):
        if not isinstance(data.get(field), str) or not data[field].strip():
            raise ValueError('Missing provider evidence: ' + field)
    checked_date(data['reviewedAt'])
    return data


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *args):
        return None


def google_synthesize(body, token, project):
    request = urllib.request.Request(API, json.dumps(body).encode(), headers={
        'Authorization': 'Bearer ' + token,
        'x-goog-user-project': project,
        'Content-Type': 'application/json; charset=utf-8',
    })
    with urllib.request.build_opener(NoRedirect()).open(request, timeout=90) as response:
        raw = response.read(32 * 1024 * 1024 + 1)
    if len(raw) > 32 * 1024 * 1024:
        raise ValueError('Oversized TTS response')
    audio = base64.b64decode(json.loads(raw)['audioContent'], validate=True)
    if len(audio) > 24 * 1024 * 1024 or not audio.startswith(b'RIFF'):
        raise ValueError('Expected bounded WAV master')
    return audio


def matching_receipt(record, receipt, destination, fingerprint):
    if (receipt.get('generationFingerprint') != fingerprint or
            receipt.get('textVersion') != record['textVersion'] or
            receipt.get('scriptSha256') != record['scriptSha256'] or
            receipt.get('declaredOrigin') != 'synthetic'):
        return False
    if destination.is_symlink() or not destination.is_file():
        return False
    return receipt.get('sha256') == sha(destination.read_bytes())


def generate(record, output, voice, evidence, token, synthesize=google_synthesize):
    body = request_body(record, voice)
    evidence = rights_input(evidence, voice)
    fingerprint = sha(json.dumps({'request': body, 'rights': evidence},
                                sort_keys=True, ensure_ascii=False).encode())
    expected_file = f"recordings/{record['audioId']}.m4a"
    if not re.fullmatch(r'A-[A-Z0-9][A-Z0-9._-]{1,80}', record['audioId']) or record['file'] != expected_file:
        raise ValueError('Unsafe recording path')
    for directory in (output, output / 'recordings', output / 'receipts', output / 'masters'):
        if directory.is_symlink():
            raise ValueError('Symlink output directory rejected')
    destination = output / record['file']
    receipt_path = output / 'receipts' / (record['audioId'] + '.json')
    if destination.exists() or receipt_path.exists():
        if receipt_path.is_file() and matching_receipt(record, json.loads(receipt_path.read_text()),
                                                       destination, fingerprint):
            return 'reused'
        raise ValueError('Existing recording changed or belongs to another text/provider; use a new output directory')
    wav = synthesize(body, token, evidence['projectId'])
    destination.parent.mkdir(parents=True, exist_ok=True)
    receipt_path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(dir=output) as temp:
        master, encoded = Path(temp) / 'master.wav', Path(temp) / 'audio.m4a'
        master.write_bytes(wav)
        subprocess.run(['ffmpeg', '-nostdin', '-v', 'error', '-i', str(master),
                        '-ac', '1', '-c:a', 'aac', '-b:a', '64k', '-movflags', '+faststart', str(encoded)],
                       check=True, capture_output=True, timeout=120)
        probe = subprocess.run(['ffprobe', '-v', 'error', '-show_format', '-of', 'json', str(encoded)],
                               check=True, capture_output=True, timeout=30)
        payload = encoded.read_bytes()
        receipt = {key: record[key] for key in ('audioId', 'textId', 'textVersion', 'file', 'scriptSha256')}
        receipt.update({'sha256': sha(payload), 'sizeBytes': len(payload),
                        'durationSeconds': float(json.loads(probe.stdout)['format']['duration']),
                        'durationToleranceSeconds': 0.05, 'declaredOrigin': 'synthetic',
                        'provider': 'google-cloud-tts', 'voice': voice,
                        'generationFingerprint': fingerprint, 'rightsEvidence': evidence,
                        'status': 'pendingListeningReview', 'humanVoiceVerified': False})
        # Reuse the actual decoder/clipping check, not a mocked approval flag.
        from verify_recording import verify
        synthetic_catalog = {'steps': [{'id': record['textId'], 'textVersion': record['textVersion']}],
                             'audioRecords': [dict(record, id=record['audioId'])]}
        temp_receipt = dict(receipt, file='audio.m4a')
        receipt['technicalQA'] = verify(synthetic_catalog, temp_receipt, Path(temp))
        os.replace(encoded, destination)
        masters = output / 'masters'
        masters.mkdir(parents=True, exist_ok=True)
        (masters / (record['audioId'] + '.wav')).write_bytes(wav)
        receipt_path.write_text(json.dumps(receipt, ensure_ascii=False, indent=2) + '\n')
    return 'generated'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--plan-output', type=Path, default=ROOT / 'build/narration-plan.json')
    parser.add_argument('--generate', action='store_true')
    parser.add_argument('--audio-id', action='append')
    parser.add_argument('--voice', default='tr-TR-Chirp3-HD-Charon')
    parser.add_argument('--rights-evidence', type=Path)
    parser.add_argument('--output', type=Path, default=ROOT / 'release-inputs/generated-narration')
    args = parser.parse_args()
    try:
        catalogs = [json.loads((ROOT / f'assets/content/{name}_inventory.v1.json').read_text())
                    for name in ('umre', 'hac')]
        intake = plan(catalogs)
        args.plan_output.parent.mkdir(parents=True, exist_ok=True)
        args.plan_output.write_text(json.dumps(intake, ensure_ascii=False, indent=2) + '\n')
        records = [r for r in intake['records'] if r['language'] == 'tr-TR']
        if args.audio_id:
            wanted = set(args.audio_id)
            records = [r for r in records if r['audioId'] in wanted]
            if {r['audioId'] for r in records} != wanted:
                raise ValueError('Unknown/non-Turkish audio ID')
        if args.generate:
            # Validate every selected text and evidence before any billable request.
            for record in records:
                request_body(record, args.voice)
            if not args.rights_evidence:
                raise ValueError('Provider rights evidence is required')
            evidence = rights_input(json.loads(args.rights_evidence.read_text()), args.voice)
            token = os.environ.get('GOOGLE_TTS_ACCESS_TOKEN')
            if not token:
                token = subprocess.run(['gcloud', 'auth', 'print-access-token'], check=True,
                                       capture_output=True, text=True, timeout=30).stdout.strip()
            if not token:
                raise ValueError('No authorized Google Cloud token')
            args.output.mkdir(parents=True, exist_ok=True)
            for record in records:
                state = generate(record, args.output, args.voice, evidence, token)
                print(record['audioId'] + ': ' + state)
        print(json.dumps({'records': len(intake['records']), 'turkishRecords': len(records),
                          'eligible': sum(r['eligibleForSynthesis'] for r in records),
                          'plan': str(args.plan_output)}))
    except (OSError, ValueError, KeyError, subprocess.SubprocessError) as error:
        # Do not print provider response bodies or subprocess auth output.
        parser.exit(2, 'blocked: ' + (str(error) if isinstance(error, ValueError) else type(error).__name__) + '\n')


if __name__ == '__main__':
    main()
