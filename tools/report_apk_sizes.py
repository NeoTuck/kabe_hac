#!/usr/bin/env python3
"""Record per-ABI release APK sizes and hashes; signing remains technical pilot."""
import hashlib
import json
import pathlib
import subprocess

root = pathlib.Path(__file__).resolve().parent.parent
apks = sorted((root / 'build/app/outputs/flutter-apk').glob('app-*-release.apk'))
expected = {'app-armeabi-v7a-release.apk', 'app-arm64-v8a-release.apk', 'app-x86_64-release.apk'}
if {p.name for p in apks} != expected:
    raise SystemExit('Expected three ABI-specific release APKs')
report = {
    'commit': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root, text=True).strip(),
    'build_mode': 'release', 'signing': 'debug-key-technical-pilot',
    'store_ready': False, 'device_performance_measured': False,
    'files': [],
}
for apk in apks:
    digest = hashlib.sha256()
    with apk.open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            digest.update(chunk)
    report['files'].append({'name': apk.name, 'bytes': apk.stat().st_size,
                            'sha256': digest.hexdigest()})
(root / 'build/apk-size-report.json').write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps(report, indent=2))
