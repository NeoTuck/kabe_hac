#!/usr/bin/env python3
"""Run all native acceptance stages on the disposable GitHub Android emulator."""
from contextlib import contextmanager
import os
import json
import subprocess
import re
import pathlib
import sys

from native_qa_stages import NativeStages

ROOT = pathlib.Path(__file__).resolve().parent.parent
STAGES = {'full', 'optimized-ui', 'debug-audio'}


def verify_page_size(device, expected, evidence):
    if expected not in (4096, 16384):
        raise ValueError('Unsupported expected page size')
    command = ['adb', '-s', device, 'shell', 'getconf', 'PAGE_SIZE']
    try:
        actual = int(subprocess.check_output(command, text=True, timeout=30).strip())
    except subprocess.CalledProcessError as error:
        if error.returncode != 127:
            raise
        # API28 does not include getconf. Read measured kernel page sizes;
        # never substitute an expected constant or a device model assumption.
        command = ['adb', '-s', device, 'shell', 'cat', '/proc/self/smaps']
        output = subprocess.check_output(command, text=True, timeout=30)
        sizes = {int(x) * 1024 for x in re.findall(r'^KernelPageSize:\s+(\d+)\s+kB$', output, re.M)}
        if len(sizes) != 1:
            raise RuntimeError('Could not establish a single measured kernel page size')
        actual = sizes.pop()
    record = {'command': command, 'expected': expected, 'observed': actual,
              'passed': expected == actual, 'physical_device_tested': False}
    (evidence / 'page-size.json').write_text(json.dumps(record, indent=2) + '\n')
    if actual != expected:
        raise RuntimeError(f'Expected {expected}-byte pages, got {actual}')


@contextmanager
def capture_device_logcat(device, evidence):
    """Stream logs to disk so they survive a later ADB transport disconnect."""
    command = ['adb', '-s', device, 'logcat', '-v', 'threadtime', '-T', '1']
    record = {'command': command, 'started': False}
    with (evidence / 'device-logcat.log').open('wb') as output:
        try:
            process = subprocess.Popen(command, stdout=output, stderr=subprocess.STDOUT)
        except OSError as error:
            record['error'] = str(error)
            process = None
        else:
            record['started'] = True
        try:
            yield
        finally:
            if process is not None:
                record['exited_during_qa'] = process.poll() is not None
                if process.poll() is None:
                    process.terminate()
                    try:
                        process.wait(timeout=5)
                    except subprocess.TimeoutExpired:
                        process.kill()
                        process.wait(timeout=5)
                record['exit_code'] = process.returncode
            (evidence / 'device-logcat.json').write_text(json.dumps(record, indent=2) + '\n')


def main():
    if os.environ.get('GITHUB_ACTIONS') != 'true':
        raise RuntimeError('Restricted to disposable GitHub CI emulator')
    device = 'emulator-5554'
    stages = NativeStages(ROOT, ROOT / 'build/mobile-qa')
    expected_page_size = int(os.environ.get('EXPECTED_PAGE_SIZE', '4096'))
    qa_stage = os.environ.get('ANDROID_QA_STAGE', 'full')
    if qa_stage not in STAGES or (qa_stage == 'full') != (expected_page_size == 4096):
        raise ValueError('Unsupported Android QA stage/page-size combination')
    verify_page_size(device, expected_page_size, stages.evidence)
    if expected_page_size == 16384:
        if stages.run('configure-16kb-runtime', [sys.executable,
                      ROOT / 'tools/prepare_16kb_emulator.py', device], timeout=120):
            return stages.exit_code
    common = [sys.executable, ROOT / 'tools/run_mobile_qa.py', '--platform', 'android',
              '--device', device, '--test-device']
    with capture_device_logcat(device, stages.evidence):
        if qa_stage in ('full', 'optimized-ui'):
            apk = ROOT / ('build/app/outputs/flutter-apk/app-x86_64-release.apk'
                          if qa_stage == 'optimized-ui' else
                          'build/app/outputs/flutter-apk/app-debug.apk')
            if stages.run('production-install', ['adb', '-s', device, 'install', apk], timeout=120):
                return stages.exit_code
            stages.run('application-ui', [*common, '--flow', 'all', '--expected-apk', apk])
        if qa_stage in ('full', 'debug-audio'):
            if qa_stage == 'debug-audio':
                debug_apk = ROOT / 'build/app/outputs/flutter-apk/app-debug.apk'
                if stages.run('debug-install', ['adb', '-s', device, 'install', debug_apk], timeout=120):
                    return stages.exit_code
            stages.run('bundled-narration-native', ['flutter', 'test',
                       'integration_test/bundled_narration_test.dart', '-d', device,
                       '--reporter', 'expanded'], device=device, production_assets=True,
                       technical_probe=False, physical_device_tested=False)
            probe = ROOT / 'build/audio-qa/app-debug.apk'
            if not stages.run('probe-install', ['adb', '-s', device, 'install', '-r', probe], timeout=120):
                stages.run('technical-audio-probe', [*common, '--flow', 'audio', '--expected-apk', probe])
    return stages.exit_code


if __name__ == '__main__':
    sys.exit(main())
