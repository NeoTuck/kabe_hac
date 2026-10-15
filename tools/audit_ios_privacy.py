#!/usr/bin/env python3
"""Inventory actual packaged privacy manifests; do not invent app/SDK declarations."""
import argparse
import hashlib
import json
import pathlib
import plistlib
import sys

API_CATEGORIES = {
    'NSPrivacyAccessedAPICategoryFileTimestamp', 'NSPrivacyAccessedAPICategorySystemBootTime',
    'NSPrivacyAccessedAPICategoryDiskSpace', 'NSPrivacyAccessedAPICategoryUserDefaults',
    'NSPrivacyAccessedAPICategoryActiveKeyboards',
}


def validate(data):
    if not isinstance(data, dict):
        raise ValueError('Privacy manifest root must be a dictionary')
    if 'NSPrivacyTracking' in data and type(data['NSPrivacyTracking']) is not bool:
        raise ValueError('NSPrivacyTracking must be boolean')
    domains = data.get('NSPrivacyTrackingDomains', [])
    if not isinstance(domains, list) or any(not isinstance(d, str) or not d.strip() for d in domains):
        raise ValueError('Invalid tracking domain list')
    apis = data.get('NSPrivacyAccessedAPITypes', [])
    if not isinstance(apis, list):
        raise ValueError('Invalid required-reason API list')
    for api in apis:
        if not isinstance(api, dict) or api.get('NSPrivacyAccessedAPIType') not in API_CATEGORIES:
            raise ValueError('Unknown or missing API category; review current Apple schema')
        reasons = api.get('NSPrivacyAccessedAPITypeReasons')
        if not isinstance(reasons, list) or not reasons or any(not isinstance(r, str) or not r.strip() for r in reasons):
            raise ValueError('Each accessed API requires nonempty declared reasons')
    collected = data.get('NSPrivacyCollectedDataTypes', [])
    if not isinstance(collected, list):
        raise ValueError('Invalid collected data list')
    for item in collected:
        if not isinstance(item, dict) or not isinstance(item.get('NSPrivacyCollectedDataType'), str):
            raise ValueError('Missing collected data type')
        for flag in ('NSPrivacyCollectedDataTypeLinked', 'NSPrivacyCollectedDataTypeTracking'):
            if type(item.get(flag)) is not bool:
                raise ValueError('Collected data flags must be boolean')
        purposes = item.get('NSPrivacyCollectedDataTypePurposes')
        if not isinstance(purposes, list) or not purposes or any(not isinstance(p, str) or not p.strip() for p in purposes):
            raise ValueError('Collected data needs declared purposes')


def audit(app):
    app = pathlib.Path(app)
    if not app.is_dir() or app.suffix != '.app':
        raise ValueError('Pass the actual built .app directory')
    info = plistlib.loads((app / 'Info.plist').read_bytes())
    result = {'bundle_id': info.get('CFBundleIdentifier'), 'version': info.get('CFBundleShortVersionString'),
              'build': info.get('CFBundleVersion'), 'sdk_name': info.get('DTSDKName'),
              'manifests': [], 'blockers': [], 'sdk_coverage_accepted': False,
              'app_privacy_declaration_accepted': False, 'sdk_signatures_verified': False,
              'store_ready': False}
    for path in sorted(app.rglob('PrivacyInfo.xcprivacy')):
        relative = path.relative_to(app).as_posix()
        try:
            path.resolve().relative_to(app.resolve())
            raw = path.read_bytes()
            data = plistlib.loads(raw)
            validate(data)
            result['manifests'].append({'path': relative, 'sha256': hashlib.sha256(raw).hexdigest(),
                                        'declarations': data})
        except (OSError, ValueError, plistlib.InvalidFileException) as error:
            result['blockers'].append({'path': relative, 'reason': str(error)})
    if not result['manifests']:
        result['blockers'].append({'reason': 'No valid packaged SDK privacy manifests found'})
    result['app_manifest_present'] = any(m['path'] == 'PrivacyInfo.xcprivacy' for m in result['manifests'])
    # The app includes Flutter; its own SDK manifest must survive packaging.
    if not any('flutter' in m['path'].lower() for m in result['manifests']):
        result['blockers'].append({'reason': 'Packaged Flutter SDK privacy manifest missing'})
    result['status'] = 'blocked' if result['blockers'] else 'packaged_manifest_inventory_checked'
    result['note'] = 'Structure/hash inventory only. Match every SDK and reason to actual APIs/data use; App Store declarations and SDK signatures require separate review.'
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('app', type=pathlib.Path)
    parser.add_argument('--output', required=True, type=pathlib.Path)
    args = parser.parse_args()
    result = audit(args.app)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({'status': result['status'], 'manifests': len(result['manifests']),
                       'blockers': len(result['blockers'])}))
    return int(bool(result['blockers']))


if __name__ == '__main__':
    sys.exit(main())
