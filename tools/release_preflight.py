#!/usr/bin/env python3
"""Fail-closed release-input audit. This is not store approval or religious review."""
import argparse
import datetime
import hashlib
import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
EVIDENCE = ('religious_expert_review', 'human_audio_rights', 'offline_map_license',
            'verified_travel_safety_language_data', 'live_supabase_acceptance',
            'push_location_acceptance', 'physical_android_acceptance',
            'physical_iphone_acceptance', 'ios_distribution_signing',
            'privacy_store_declarations', 'signed_android_artifact')


def audit_catalog(data):
    blockers = []
    kind = data.get('guideType')
    expected = {'umrah': 18, 'hajj': 35}.get(kind)
    steps = data.get('steps', [])
    if expected is None or len(steps) != expected or len({s.get('id') for s in steps}) != expected:
        blockers.append({'id': kind, 'type': 'inventory_count_or_ids'})
    records = {r.get('id'): r for r in steps + data.get('prayerRecords', [])}
    audios = {r.get('id'): r for r in data.get('audioRecords', [])}
    for step in steps:
        linked = ([step['audioId']] if step.get('audioId') else []) + step.get('audioIds', [])
        if not any(audios.get(a, {}).get('kind') == 'turkishNarration' for a in linked):
            blockers.append({'id': step.get('id'), 'type': 'missing_step_narration'})
        if step.get('counterKey') and step.get('status') == 'approved':
            target = step.get('counterTarget')
            if type(target) is not int or not 1 <= target <= 100:
                blockers.append({'id': step.get('id'), 'type': 'practice_counter_target'})
    for audio in audios.values():
        target = records.get(audio.get('textId'), {})
        if not target or target.get('textVersion') != audio.get('textVersion'):
            blockers.append({'id': audio.get('id'), 'type': 'audio_text_binding'})
    for record_type, fields in (
        ('steps', ('summary', 'details', 'textVersion', 'sourceTitle', 'sourceUrl',
                   'sourceLocation', 'sourceAccessedAt', 'sourceUsageRights', 'reviewedBy', 'reviewedAt')),
        ('prayerRecords', ('arabic', 'transliteration', 'meaningTr', 'textVersion',
                          'sourceTitle', 'sourceUrl', 'sourceLocation', 'sourceAccessedAt',
                          'sourceUsageRights', 'reviewedBy', 'reviewedAt')),
        ('audioRecords', ('asset', 'textId', 'textVersion', 'recordingOwner', 'rights', 'reviewedBy', 'reviewedAt')),
    ):
        for record in data.get(record_type, []):
            missing = [key for key in fields if not isinstance(record.get(key), str)
                       or not record[key].strip()]
            if record.get('status') != 'approved' or missing:
                blockers.append({'id': record.get('id'), 'type': record_type,
                                 'status': record.get('status'), 'missing': missing})
            rights = str(record.get('sourceUsageRights', '')).lower()
            if record.get('status') == 'approved' and any(
                    marker in rights for marker in ('teyit edilmedi', 'bekliyor', 'bilinmiyor')):
                blockers.append({'id': record.get('id'), 'type': 'source_rights_unverified'})
    # Three profiles must be reviewed for every Hajj step, not just some steps.
    if data.get('guideType') == 'hajj':
        for step in data.get('steps', []):
            if step.get('status') != 'approved' or not all(
                step.get('profileApplicability', {}).get(profile) in ('applicable', 'notApplicable')
                for profile in ('ifrad', 'temettu', 'kiran')):
                blockers.append({'id': step.get('id'), 'type': 'hajj_profile_review'})
    return blockers


def audit_evidence(directory):
    blockers = []
    for key in EVIDENCE:
        try:
            manifest = json.loads((directory / f'{key}.json').read_text())
            path = directory / manifest['file']
            # Evidence must stay inside the supplied directory and exist locally.
            path.resolve().relative_to(directory.resolve())
            if path.is_symlink() or not path.is_file():
                raise ValueError('Evidence file missing or linked')
            actual = hashlib.sha256(path.read_bytes()).hexdigest()
            if actual != manifest['sha256'] or manifest['result'] != 'accepted':
                raise ValueError('Evidence hash/result rejected')
            for field in ('reviewedBy', 'scope', 'reviewedAt'):
                if not isinstance(manifest.get(field), str) or not manifest[field].strip():
                    raise ValueError(f'Missing {field}')
            date = datetime.date.fromisoformat(manifest['reviewedAt'])
            if date > datetime.datetime.now(datetime.timezone.utc).date():
                raise ValueError('Future review date')
        except (OSError, ValueError, KeyError, TypeError) as error:
            blockers.append({'id': key, 'type': 'external_evidence', 'reason': str(error)})
    return blockers


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--evidence-dir', type=pathlib.Path, default=ROOT / 'release-inputs')
    parser.add_argument('--output', type=pathlib.Path, default=ROOT / 'build/release-preflight.json')
    args = parser.parse_args()
    blockers = []
    for name in ('umre', 'hac'):
        data = json.loads((ROOT / f'assets/content/{name}_inventory.v1.json').read_text())
        blockers.extend(audit_catalog(data))
    blockers.extend(audit_evidence(args.evidence_dir))
    report = {'status': 'blocked' if blockers else 'inputs_checked',
              'note': 'Declared review fields and evidence hashes checked; independent human release acceptance still required.',
              'blockers': blockers}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({'status': report['status'], 'blocker_count': len(blockers),
                      'report': str(args.output)}, ensure_ascii=False))
    return 2 if blockers else 0


if __name__ == '__main__':
    sys.exit(main())
