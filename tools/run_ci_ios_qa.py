#!/usr/bin/env python3
"""Create one disposable GitHub CI simulator, test the built app, clean it up."""
import json
import os
import pathlib
import plistlib
import subprocess
import sys
import time

from native_qa_stages import NativeStages

ROOT = pathlib.Path(__file__).resolve().parent.parent
APP = ROOT / 'build/ios/iphonesimulator/Runner.app'


def run(*command, timeout=60):
    return subprocess.check_output(command, text=True, timeout=timeout).strip()


def select_runtime(runtimes, sdk_version):
    sdk_parts = tuple(int(p) for p in sdk_version.split('.')[:2])
    compatible = [r for r in runtimes if r.get('isAvailable')
                  and r['identifier'].startswith('com.apple.CoreSimulator.SimRuntime.iOS-')
                  and tuple(int(p) for p in r['version'].split('.')[:2]) == sdk_parts]
    if not compatible:
        raise RuntimeError(f'No available runtime matching selected simulator SDK {sdk_version}')
    return max(compatible, key=lambda r: tuple(int(p) for p in r['version'].split('.')))


def main():
    if os.environ.get('GITHUB_ACTIONS') != 'true':
        raise RuntimeError('This runner is restricted to disposable GitHub CI; use run_mobile_qa.py on your explicit test simulator')
    with (APP / 'Info.plist').open('rb') as stream:
        app_id = plistlib.load(stream)['CFBundleIdentifier']
    runtimes = json.loads(run('xcrun', 'simctl', 'list', 'runtimes', '-j'))['runtimes']
    # The newest installed runtime can belong to a different Xcode toolchain.
    # Match the selected SDK instead of launching an incompatible XCTest driver.
    sdk_version = run('xcrun', '--sdk', 'iphonesimulator', '--show-sdk-version')
    runtime = select_runtime(runtimes, sdk_version)
    types = json.loads(run('xcrun', 'simctl', 'list', 'devicetypes', '-j'))['devicetypes']
    phone = next((t for t in types if t['name'] == 'iPhone 16'), None)
    if phone is None:
        raise RuntimeError('iPhone 16 simulator type is unavailable')
    device = run('xcrun', 'simctl', 'create', 'Kabe MVP disposable QA', phone['identifier'], runtime['identifier'])
    evidence = ROOT / 'build/mobile-qa'
    evidence.mkdir(parents=True, exist_ok=True)
    (evidence / 'ci-simulator.json').write_text(json.dumps({
        'device': device, 'runtime': runtime['identifier'], 'device_type': phone['identifier'],
        'app_id': app_id, 'sdk_version': sdk_version, 'physical_iphone_tested': False,
    }, indent=2) + '\n')
    console = None
    console_stream = None
    try:
        run('xcrun', 'simctl', 'boot', device)
        run('xcrun', 'simctl', 'bootstatus', device, '-b', timeout=180)
        # A fresh iOS 26 simulator can report boot completion before its app
        # installation service is ready. Keep this pre-test setup bounded and
        # record a timeout distinctly from a failed UI or audio assertion.
        install_started = time.monotonic()
        try:
            run('xcrun', 'simctl', 'install', device, str(APP), timeout=300)
        except (subprocess.CalledProcessError, subprocess.TimeoutExpired) as error:
            (evidence / 'ci-install-error.json').write_text(json.dumps({
                'phase': 'simctl install', 'device': device,
                'elapsed_seconds': round(time.monotonic() - install_started, 2),
                'error_type': type(error).__name__,
            }, indent=2) + '\n')
            raise
        console_stream = (evidence / 'ios-console.log').open('w')
        console = subprocess.Popen(['xcrun', 'simctl', 'spawn', device, 'log', 'stream',
            '--level', 'info', '--predicate', 'process == \"Runner\"'], stdout=console_stream, stderr=subprocess.STDOUT)
        stages = NativeStages(ROOT, evidence)
        common = [sys.executable, str(ROOT / 'tools/run_mobile_qa.py'),
                  '--platform', 'ios-simulator', '--device', device,
                  '--app-id', app_id, '--test-device']
        stages.run('application-ui', [*common, '--flow', 'all'])
        # Independent production assets check runs even when a UI assertion fails.
        stages.run('bundled-narration-native', ['flutter', 'test',
                   'integration_test/bundled_narration_test.dart', '-d', device,
                   '--reporter', 'expanded'], device=device, production_assets=True,
                   technical_probe=False, physical_iphone_tested=False)
        audio_app = ROOT / 'build/audio-qa/Runner.app'
        subprocess.run(['xcrun', 'simctl', 'terminate', device, app_id], timeout=30)
        if not stages.run('probe-install', ['xcrun', 'simctl', 'install', device, str(audio_app)], timeout=120):
            stages.run('technical-audio-probe', [*common, '--flow', 'audio'])
        return stages.exit_code
    finally:
        if console is not None:
            console.terminate()
            try:
                console.wait(timeout=10)
            except subprocess.TimeoutExpired:
                console.kill()
        if console_stream is not None:
            console_stream.close()
        subprocess.run(['xcrun', 'simctl', 'shutdown', device], timeout=60)
        subprocess.run(['xcrun', 'simctl', 'delete', device], timeout=60)


if __name__ == '__main__':
    sys.exit(main())
