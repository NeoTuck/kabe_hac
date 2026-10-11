#!/usr/bin/env python3
"""Run all native acceptance stages on the disposable GitHub Android emulator."""
import os
import pathlib
import sys

from native_qa_stages import NativeStages

ROOT = pathlib.Path(__file__).resolve().parent.parent


def main():
    if os.environ.get('GITHUB_ACTIONS') != 'true':
        raise RuntimeError('Restricted to disposable GitHub CI emulator')
    device = 'emulator-5554'
    stages = NativeStages(ROOT, ROOT / 'build/mobile-qa')
    apk = ROOT / 'build/app/outputs/flutter-apk/app-debug.apk'
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
