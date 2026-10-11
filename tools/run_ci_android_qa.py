#!/usr/bin/env python3
"""Run all native acceptance stages on the disposable GitHub Android emulator."""
import os
import json
import subprocess
import pathlib
import sys

from native_qa_stages import NativeStages

ROOT = pathlib.Path(__file__).resolve().parent.parent


def verify_page_size(device, expected, evidence):
    if expected not in (4096, 16384):
        raise ValueError('Unsupported expected page size')
    command = ['adb', '-s', device, 'shell', 'getconf', 'PAGE_SIZE']
    actual = int(subprocess.check_output(command, text=True, timeout=30).strip())
    record = {'command': command, 'expected': expected, 'observed': actual,
              'passed': expected == actual, 'physical_device_tested': False}
    (evidence / 'page-size.json').write_text(json.dumps(record, indent=2) + '\n')
    if actual != expected:
        raise RuntimeError(f'Expected {expected}-byte pages, got {actual}')


def main():
    if os.environ.get('GITHUB_ACTIONS') != 'true':
        raise RuntimeError('Restricted to disposable GitHub CI emulator')
    device = 'emulator-5554'
    stages = NativeStages(ROOT, ROOT / 'build/mobile-qa')
    expected_page_size = int(os.environ.get('EXPECTED_PAGE_SIZE', '4096'))
    verify_page_size(device, expected_page_size, stages.evidence)
    apk = ROOT / ('build/app/outputs/flutter-apk/app-x86_64-release.apk'
                  if expected_page_size == 16384 else 'build/app/outputs/flutter-apk/app-debug.apk')
    if expected_page_size == 16384:
        if stages.run('disposable-emulator-root', ['adb', '-s', device, 'root'], timeout=30):
            return stages.exit_code
        if stages.run('wait-rooted-emulator', ['adb', '-s', device, 'wait-for-device'], timeout=60):
            return stages.exit_code
        for prop, value in [('bionic.linker.16kb.app_compat.enabled', 'false'),
                            ('pm.16kb.app_compat.disabled', 'true')]:
            if stages.run('disable-' + prop, ['adb', '-s', device, 'shell', 'setprop', prop, value], timeout=30):
                return stages.exit_code
            observed = subprocess.check_output(
                ['adb', '-s', device, 'shell', 'getprop', prop], text=True, timeout=30).strip()
            if observed != value:
                raise RuntimeError(f'16KB compatibility property {prop} was not applied')
    probe = ROOT / 'build/audio-qa/app-debug.apk'
    if stages.run('production-install', ['adb', '-s', device, 'install', apk], timeout=120):
        return stages.exit_code
    common = [sys.executable, ROOT / 'tools/run_mobile_qa.py', '--platform', 'android',
              '--device', device, '--test-device']
    stages.run('application-ui', [*common, '--flow', 'all', '--expected-apk', apk])
    stages.run('bundled-narration-native', ['flutter', 'test',
               'integration_test/bundled_narration_test.dart', '-d', device,
               '--reporter', 'expanded'], device=device, production_assets=True,
               technical_probe=False, physical_device_tested=False)
    if not stages.run('probe-install', ['adb', '-s', device, 'install', '-r', probe], timeout=120):
        stages.run('technical-audio-probe', [*common, '--flow', 'audio', '--expected-apk', probe])
    return stages.exit_code


if __name__ == '__main__':
    sys.exit(main())
