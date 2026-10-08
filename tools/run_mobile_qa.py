#!/usr/bin/env python3
"""Run explicit test-device flows and preserve evidence/status per execution."""
import argparse
import datetime
import json
import hashlib
import tempfile
import time
import pathlib
import re
import shutil
import subprocess
import sys
import uuid
import xml.etree.ElementTree as ET

ROOT = pathlib.Path(__file__).resolve().parent.parent
IDS = {'android': 'com.mustafasenoglu.hac_umre_sesli_rehber',
       'ios-simulator': 'com.mustafasenoglu.hacUmreSesliRehber'}


def probe(command):
    result = subprocess.run(command, capture_output=True, text=True, timeout=30)
    if result.returncode != 0:
        raise RuntimeError(f'Command failed: {command[0]} (exit {result.returncode})')
    return result.stdout.strip()


def file_hash(path):
    digest = hashlib.sha256()
    with pathlib.Path(path).open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            digest.update(chunk)
    return digest.hexdigest()


def wait_for_android(device, attempts=6, pause=2):
    """Require consecutive responsive boot probes; never retry UI assertions."""
    stable = 0
    for attempt in range(attempts):
        try:
            state = probe(['adb', '-s', device, 'get-state'])
            boot = probe(['adb', '-s', device, 'shell', 'getprop', 'sys.boot_completed'])
            stable = stable + 1 if state == 'device' and boot == '1' else 0
            if stable >= 2:
                return
        except (RuntimeError, subprocess.TimeoutExpired):
            stable = 0
        if attempt + 1 < attempts:
            time.sleep(pause)
    raise RuntimeError('Android transport/boot did not become stably ready')


def booted_ios_devices(attempts=3):
    """Retry only CoreSimulator startup queries, never application UI flows."""
    for attempt in range(attempts):
        try:
            return json.loads(probe(['xcrun', 'simctl', 'list', 'devices', 'booted', '-j']))
        except (RuntimeError, subprocess.TimeoutExpired):
            if attempt + 1 == attempts:
                raise
            time.sleep(2)


def prepare_android_driver(device, output):
    """Install/connect Maestro before measured flows; preserve both attempts."""
    command = ['maestro', '--device', device, 'hierarchy']
    with (output / 'driver-preflight.log').open('w') as log:
        for attempt in range(2):
            wait_for_android(device)
            log.write(f'Driver preparation attempt {attempt + 1}\n')
            try:
                result = subprocess.run(command, capture_output=True, text=True, timeout=120)
                log.write(result.stdout + result.stderr)
                log.flush()
                if result.returncode == 0:
                    wait_for_android(device)
                    return
            except subprocess.TimeoutExpired:
                log.write('Driver preparation timed out\n')
                log.flush()
        raise RuntimeError('Maestro driver preparation failed; UI flows were not started')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--platform', required=True, choices=list(IDS))
    parser.add_argument('--device', required=True)
    parser.add_argument('--app-id')
    parser.add_argument('--expected-apk', type=pathlib.Path, help='Android APK whose SHA-256 must match the installed base APK')
    parser.add_argument('--test-device', action='store_true', help='Dedicated test device; flow creates/resumes guide records')
    parser.add_argument('--dry-run', action='store_true', help='Print command only; no device checks or tests')
    parser.add_argument('--preflight', action='store_true', help='Check tools/device/app only; do not run UI tests')
    parser.add_argument('--flow', choices=['all', 'core', '01', '02', '03', '04'], default='core')
    args = parser.parse_args()
    app_id = args.app_id or IDS[args.platform]
    if not re.fullmatch(r'[A-Za-z][A-Za-z0-9_.-]+', app_id) or args.device.startswith('-'):
        parser.error('Invalid app or device identifier')
    if args.expected_apk and args.platform != 'android':
        parser.error('--expected-apk is Android-only')
    if not args.test_device:
        parser.error('--test-device is required; personal guide progress must be preserved')
    stamp = datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%SZ')
    output = ROOT / 'build/mobile-qa' / (stamp + '-' + uuid.uuid4().hex[:8])
    flows = sorted((ROOT / '.maestro/flows').glob('*.yaml'))
    if args.flow == 'core':
        flows = [p for p in flows if not p.name.startswith('04')]
    elif args.flow != 'all':
        flows = [p for p in flows if p.name.startswith(args.flow)]
    command = ['maestro', '--device', args.device, 'test', '--env', f'APP_ID={app_id}',
               '--format', 'junit', '--output', str(output / 'report.xml'),
               '--test-output-dir', str(output / 'artifacts'), *map(str, flows)]
    evidence = {'platform': args.platform, 'device': args.device, 'app_id': app_id,
                'flows': [p.name for p in flows], 'command': command,
                'workspace_commit': probe(['git', '-C', str(ROOT), 'rev-parse', 'HEAD']),
                'installed_build_hash': None,
                'status': 'prepared', 'device_tests_run': False}
    if args.dry_run:
        print(json.dumps(evidence, ensure_ascii=False, indent=2))
        return 0
    output.mkdir(parents=True)
    try:
        required = ['maestro', 'java', 'adb' if args.platform == 'android' else 'xcrun']
        missing = [tool for tool in required if shutil.which(tool) is None]
        if missing:
            raise RuntimeError('Missing tools: ' + ', '.join(missing))
        if args.platform == 'android':
            wait_for_android(args.device)
            installed_paths = probe(['adb', '-s', args.device, 'shell', 'pm', 'path', app_id]).splitlines()
            if not installed_paths or not all(line.startswith('package:') for line in installed_paths):
                raise RuntimeError('Application is not installed on this device')
            if args.expected_apk:
                if len(installed_paths) != 1:
                    raise RuntimeError('Expected a single APK installation; split installs need a separate hash contract')
                evidence['expected_build_hash'] = file_hash(args.expected_apk)
                with tempfile.TemporaryDirectory(prefix='kabe-apk-proof-') as temporary:
                    installed_apk = pathlib.Path(temporary) / 'installed.apk'
                    probe(['adb', '-s', args.device, 'pull', installed_paths[0][len('package:'):], str(installed_apk)])
                    evidence['installed_build_hash'] = file_hash(installed_apk)
                if evidence['installed_build_hash'] != evidence['expected_build_hash']:
                    raise RuntimeError('Installed APK hash does not match the expected build')
            package = probe(['adb', '-s', args.device, 'shell', 'dumpsys', 'package', app_id])
            evidence['installed_version_lines'] = [line.strip() for line in package.splitlines()
                                                   if 'versionName=' in line or 'versionCode=' in line]
        else:
            devices = booted_ios_devices()
            if not any(d['udid'] == args.device and d['state'] == 'Booted'
                       for group in devices['devices'].values() for d in group):
                raise RuntimeError('Requested iOS simulator is not booted; physical iPhone is not supported here')
            probe(['xcrun', 'simctl', 'get_app_container', args.device, app_id, 'app'])
        evidence['maestro_version'] = probe(['maestro', '--version'])
        if args.preflight:
            evidence['status'] = 'preflight_ready'
        else:
            if args.platform == 'android':
                prepare_android_driver(args.device, output)
                evidence['driver_prepared'] = True
            evidence['device_tests_run'] = True
            with (output / 'maestro.log').open('w') as log:
                result = subprocess.run(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, timeout=600)
            evidence['exit_code'] = result.returncode
            evidence['status'] = 'passed' if result.returncode == 0 else 'failed'
            if result.returncode == 0:
                report = ET.parse(output / 'report.xml').getroot()
                cases = report.findall('.//testcase')
                if len(cases) < len(flows) or any(case.find(tag) is not None
                        for case in cases for tag in ('failure', 'error', 'skipped')):
                    raise RuntimeError('JUnit report has missing, failed or skipped flow cases')
                evidence['reported_cases'] = len(cases)
    except (RuntimeError, subprocess.TimeoutExpired, OSError, ValueError, KeyError, ET.ParseError) as error:
        evidence['status'] = 'blocked'
        evidence['reason'] = str(error)
    (output / 'session.json').write_text(json.dumps(evidence, ensure_ascii=False, indent=2))
    print(json.dumps({'status': evidence['status'], 'device_tests_run': evidence['device_tests_run'],
                      'evidence': str(output), 'reason': evidence.get('reason')}, ensure_ascii=False))
    return 0 if evidence['status'] in ('passed', 'preflight_ready') else 2


if __name__ == '__main__':
    sys.exit(main())
