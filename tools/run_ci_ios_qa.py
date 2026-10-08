#!/usr/bin/env python3
"""Create one disposable GitHub CI simulator, test the built app, clean it up."""
import json
import os
import pathlib
import plistlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
APP = ROOT / 'build/ios/iphonesimulator/Runner.app'


def run(*command, timeout=60):
    return subprocess.check_output(command, text=True, timeout=timeout).strip()


def main():
    if os.environ.get('GITHUB_ACTIONS') != 'true':
        raise RuntimeError('This runner is restricted to disposable GitHub CI; use run_mobile_qa.py on your explicit test simulator')
    with (APP / 'Info.plist').open('rb') as stream:
        app_id = plistlib.load(stream)['CFBundleIdentifier']
    runtimes = json.loads(run('xcrun', 'simctl', 'list', 'runtimes', '-j'))['runtimes']
    available = [r for r in runtimes if r.get('isAvailable') and r['identifier'].startswith('com.apple.CoreSimulator.SimRuntime.iOS-')]
    if not available:
        raise RuntimeError('No available iOS runtime')
    runtime = max(available, key=lambda r: tuple(int(p) for p in r['version'].split('.')))
    types = json.loads(run('xcrun', 'simctl', 'list', 'devicetypes', '-j'))['devicetypes']
    phone = next((t for t in types if t['name'] == 'iPhone 16'), None)
    if phone is None:
        raise RuntimeError('iPhone 16 simulator type is unavailable')
    device = run('xcrun', 'simctl', 'create', 'Kabe MVP disposable QA', phone['identifier'], runtime['identifier'])
    evidence = ROOT / 'build/mobile-qa'
    evidence.mkdir(parents=True, exist_ok=True)
    (evidence / 'ci-simulator.json').write_text(json.dumps({
        'device': device, 'runtime': runtime['identifier'], 'device_type': phone['identifier'],
        'app_id': app_id, 'physical_iphone_tested': False,
    }, indent=2) + '\n')
    try:
        run('xcrun', 'simctl', 'boot', device)
        run('xcrun', 'simctl', 'bootstatus', device, '-b', timeout=180)
        run('xcrun', 'simctl', 'install', device, str(APP), timeout=120)
        return subprocess.run([sys.executable, str(ROOT / 'tools/run_mobile_qa.py'),
            '--platform', 'ios-simulator', '--device', device, '--app-id', app_id,
            '--test-device', '--flow', 'all'], cwd=ROOT, timeout=900).returncode
    finally:
        subprocess.run(['xcrun', 'simctl', 'shutdown', device], timeout=60)
        subprocess.run(['xcrun', 'simctl', 'delete', device], timeout=60)


if __name__ == '__main__':
    sys.exit(main())
