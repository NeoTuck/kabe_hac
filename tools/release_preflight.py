#!/usr/bin/env python3
"""Fail-closed release-input audit. This is not store approval or religious review."""
import argparse
import datetime
import hashlib
import json
import pathlib
import sys
from urllib.parse import urlparse

ROOT = pathlib.Path(__file__).resolve().parent.parent
EVIDENCE = ('religious_expert_review', 'human_audio_rights', 'offline_map_license',
            'verified_travel_safety_language_data', 'live_supabase_acceptance',
            'push_location_acceptance', 'physical_android_acceptance',
            'physical_iphone_acceptance', 'ios_distribution_signing',
            'privacy_store_declarations', 'chat_safety_acceptance',
            'account_deletion_acceptance', 'signed_android_artifact')
SCOPE_PATH = ROOT / 'docs/qa/mvp-release-scope.v1.json'


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


def audit_mvp_scope(root, manifest_path, evidence_dir):
    """Check the declared scope against what this build actually exposes and bundles.

    A smaller manifest cannot hide a bundled draft. Future partial releases need a
    build-time content filter before this exact-set check may be changed.
    """
    blockers = []
    try:
        scope = json.loads(manifest_path.read_text())
        if not isinstance(scope, dict):
            raise ValueError('scope must be a JSON object')
        if scope.get('schemaVersion') != 1 or scope.get('releaseTarget') != 'android_ios':
            blockers.append({'type': 'scope_schema_or_target'})
        actual_steps, actual_prayers, actual_audio = {}, {}, {}
        for name in ('umre', 'hac'):
            path = root / f'assets/content/{name}_inventory.v1.json'
            raw = path.read_bytes()
            data = json.loads(raw)
            blockers.extend(audit_catalog(data))
            if scope.get('catalogSha256', {}).get(name) != hashlib.sha256(raw).hexdigest():
                blockers.append({'id': name, 'type': 'scope_catalog_hash'})
            for key, destination in (('steps', actual_steps),
                                     ('prayerRecords', actual_prayers),
                                     ('audioRecords', actual_audio)):
                for record in data.get(key, []):
                    identifier = record.get('id')
                    if not isinstance(identifier, str) or identifier in destination:
                        blockers.append({'id': identifier, 'type': 'duplicate_catalog_id'})
                    destination[identifier] = record

        for key, records, version_key in (
            ('visibleSteps', actual_steps, 'textVersion'),
            ('visiblePrayers', actual_prayers, 'textVersion'),
            ('audioRecords', actual_audio, 'textVersion'),
        ):
            declared = scope.get(key)
            if not isinstance(declared, list) or not all(isinstance(x, dict) for x in declared):
                blockers.append({'id': key, 'type': 'scope_list'})
                continue
            indexed = {x.get('id'): x for x in declared}
            if len(indexed) != len(declared) or set(indexed) != set(records):
                blockers.append({'id': key, 'type': 'scope_ids_mismatch',
                                 'declared': len(declared), 'actual': len(records)})
            for identifier, record in records.items():
                entry = indexed.get(identifier, {})
                if entry.get(version_key) != record.get(version_key):
                    blockers.append({'id': identifier, 'type': 'scope_version'})
                if key == 'audioRecords':
                    if entry.get('asset') != record.get('asset') or entry.get('sha256') != record.get('assetSha256'):
                        blockers.append({'id': identifier, 'type': 'scope_audio_binding'})
                if record.get('status') != 'approved':
                    blockers.append({'id': identifier, 'type': 'scope_unapproved_content'})

        # pubspec declares the whole draft-v2 directory. Check every such file,
        # including an orphan that is absent from the catalog or manifest.
        pubspec = (root / 'pubspec.yaml').read_text()
        bundled = set()
        for line in pubspec.splitlines():
            value = line.strip().removeprefix('- ').strip()
            if not value.startswith('assets/audio/'):
                continue
            asset_path = root / value
            if value.endswith('/'):
                bundled.update(p.relative_to(root).as_posix()
                               for p in asset_path.rglob('*') if p.is_file())
            elif asset_path.is_file():
                bundled.add(value)
        declared_assets = {r.get('asset') for r in actual_audio.values() if r.get('asset')}
        if bundled != declared_assets:
            blockers.append({'type': 'bundled_audio_scope_mismatch',
                             'bundled': len(bundled), 'catalog': len(declared_assets)})
        for identifier, record in actual_audio.items():
            asset = record.get('asset')
            if not isinstance(asset, str) or not asset.startswith('assets/audio/'):
                blockers.append({'id': identifier, 'type': 'audio_asset_path'})
                continue
            path = root / asset
            try:
                path.resolve().relative_to((root / 'assets/audio').resolve())
                if path.is_symlink() or not path.is_file():
                    raise ValueError('missing or linked asset')
                if hashlib.sha256(path.read_bytes()).hexdigest() != record.get('assetSha256'):
                    raise ValueError('hash mismatch')
            except (OSError, ValueError) as error:
                blockers.append({'id': identifier, 'type': 'audio_asset_integrity',
                                 'reason': str(error)})
            for field in ('recordingOwner', 'rights', 'reviewedBy', 'reviewedAt'):
                if not isinstance(record.get(field), str) or not record[field].strip():
                    blockers.append({'id': identifier, 'type': 'audio_rights_or_review'})
            if any(marker in str(record.get('rights', '')).lower()
                   for marker in ('pending', 'bekliyor', 'bilinmiyor', 'teyit edilmedi')):
                blockers.append({'id': identifier, 'type': 'audio_rights_unverified'})
            if record.get('reviewOnly') is True:
                blockers.append({'id': identifier, 'type': 'review_only_audio'})

        service = scope.get('liveService', {})
        if not isinstance(service, dict):
            service = {}
        if service.get('enabled') is not True:
            blockers.append({'type': 'live_service_not_accepted'})
        for key in ('privacyUrl', 'supportUrl', 'accountDeletionUrl',
                    'termsOfUseUrl'):
            value = service.get(key, '')
            parsed = urlparse(value) if isinstance(value, str) else None
            if not parsed or parsed.scheme != 'https' or not parsed.netloc or parsed.username:
                blockers.append({'id': key, 'type': 'service_url'})
        maps = scope.get('mapPackages')
        package_path = root / 'offline_packages/osm-2026-10-08/catalog.v1.json'
        package_raw = package_path.read_bytes()
        packages = json.loads(package_raw).get('packages', [])
        if scope.get('packageCatalogSha256') != hashlib.sha256(package_raw).hexdigest():
            blockers.append({'type': 'package_catalog_hash'})
        actual_maps = {p.get('packageId'): p for p in packages
                       if p.get('kind') in ('map', 'travel')}
        if not isinstance(maps, list) or not maps:
            blockers.append({'type': 'map_scope_missing'})
        else:
            indexed_maps = {p.get('id'): p for p in maps if isinstance(p, dict)}
            if len(indexed_maps) != len(maps) or set(indexed_maps) != set(actual_maps):
                blockers.append({'type': 'map_scope_ids_mismatch'})
            for entry in maps:
                if not isinstance(entry, dict) or not all(
                    isinstance(entry.get(k), str) and entry[k].strip()
                    for k in ('id', 'version', 'rightsEvidence')):
                    blockers.append({'type': 'map_scope_incomplete'})
                    continue
                actual = actual_maps.get(entry['id'], {})
                if entry['version'] != actual.get('version'):
                    blockers.append({'id': entry['id'], 'type': 'map_scope_version'})
                if any(marker in entry['rightsEvidence'].lower()
                       for marker in ('pending', 'bekliyor', 'bilinmiyor', 'teyit edilmedi')):
                    blockers.append({'id': entry['id'], 'type': 'map_rights_unverified'})
        blockers.extend(audit_evidence(evidence_dir))
    except (OSError, ValueError, TypeError, AttributeError, KeyError) as error:
        blockers.append({'type': 'scope_manifest_invalid', 'reason': str(error)})
    return blockers


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--evidence-dir', type=pathlib.Path, default=ROOT / 'release-inputs')
    parser.add_argument('--output', type=pathlib.Path)
    parser.add_argument('--mvp-scope', type=pathlib.Path,
                        help='Audit the versioned MVP scope; the default full audit is unchanged')
    args = parser.parse_args()
    output = args.output or ROOT / ('build/mvp-release-preflight.json' if args.mvp_scope
                                   else 'build/release-preflight.json')
    if args.mvp_scope:
        blockers = audit_mvp_scope(ROOT, args.mvp_scope, args.evidence_dir)
    else:
        blockers = []
        for name in ('umre', 'hac'):
            data = json.loads((ROOT / f'assets/content/{name}_inventory.v1.json').read_text())
            blockers.extend(audit_catalog(data))
        blockers.extend(audit_evidence(args.evidence_dir))
    report = {'status': 'blocked' if blockers else 'inputs_checked',
              'note': 'Declared review fields and evidence hashes checked; independent human release acceptance still required.',
              'audit': 'mvp_scope' if args.mvp_scope else 'full',
              'blockers': blockers}
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({'status': report['status'], 'blocker_count': len(blockers),
                      'report': str(output)}, ensure_ascii=False))
    return 2 if blockers else 0


if __name__ == '__main__':
    sys.exit(main())
