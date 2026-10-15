#!/usr/bin/env python3
"""Bind real review documents to exact records; never create or infer approval."""
import datetime
import hashlib
import json
import pathlib

ANNOTATIONS = {'status', 'reviewedBy', 'reviewedAt', 'reviewEvidence'}


def record_digest(record):
    payload = {key: value for key, value in record.items() if key not in ANNOTATIONS}
    return hashlib.sha256(json.dumps(payload, sort_keys=True, ensure_ascii=False,
                                    separators=(',', ':')).encode()).hexdigest()


def requirements(kind, guide_type):
    if kind == 'steps':
        return ('religious', 'source_rights') + (
            ('profile_temettu', 'profile_ifrad', 'profile_kiran') if guide_type == 'hajj' else ())
    if kind == 'prayerRecords':
        return ('religious', 'language', 'source_rights')
    return ('listening', 'audio_rights')


def audit_review_bindings(root, evidence_dir):
    blockers = []
    for name in ('umre', 'hac'):
        data = json.loads((root / f'assets/content/{name}_inventory.v1.json').read_text())
        for kind in ('steps', 'prayerRecords', 'audioRecords'):
            for record in data[kind]:
                if record.get('status') != 'approved':
                    continue
                refs = record.get('reviewEvidence', {})
                for decision in requirements(kind, data['guideType']):
                    try:
                        ref = refs[decision]
                        if not isinstance(ref, str) or pathlib.PurePosixPath(ref).name != ref or not ref.endswith('.json'):
                            raise ValueError('Evidence reference must be a local JSON filename')
                        receipt_path = evidence_dir / ref
                        receipt_path.resolve().relative_to(evidence_dir.resolve())
                        if receipt_path.is_symlink():
                            raise ValueError('Linked receipt')
                        receipt = json.loads(receipt_path.read_text())
                        expected = {'id': record['id'], 'textVersion': record['textVersion'],
                                    'recordSha256': record_digest(record), 'decisionKind': decision}
                        if any(receipt.get(key) != value for key, value in expected.items()):
                            raise ValueError('Record/version/digest/decision mismatch')
                        if receipt.get('result') != 'accepted':
                            raise ValueError('Decision not accepted')
                        for key in ('reviewedBy', 'reviewedAt', 'scope', 'document', 'documentSha256'):
                            if not isinstance(receipt.get(key), str) or not receipt[key].strip():
                                raise ValueError(f'Missing {key}')
                        if datetime.date.fromisoformat(receipt['reviewedAt']) > datetime.datetime.now(datetime.timezone.utc).date():
                            raise ValueError('Future decision date')
                        relative = pathlib.PurePosixPath(receipt['document'])
                        if relative.is_absolute() or '..' in relative.parts:
                            raise ValueError('Unsafe document path')
                        document = evidence_dir / relative
                        document.resolve().relative_to(evidence_dir.resolve())
                        current = evidence_dir
                        for part in relative.parts:
                            current = current / part
                            if current.is_symlink():
                                raise ValueError('Linked document')
                        if hashlib.sha256(document.read_bytes()).hexdigest() != receipt['documentSha256']:
                            raise ValueError('Document hash mismatch')
                    except (OSError, ValueError, KeyError, TypeError, AttributeError) as error:
                        blockers.append({'id': record.get('id'), 'type': 'record_review_evidence',
                                         'decision': decision, 'reason': str(error)})
    return blockers
