"""Verify root and compatibility properties on a disposable CI emulator only."""
import json
import os
import subprocess
import sys


def prepare(device):
    if os.environ.get('GITHUB_ACTIONS') != 'true' or not device.startswith('emulator-'):
        raise RuntimeError('Disposable CI emulator required')
    base = ['adb', '-s', device]
    uid = subprocess.check_output([*base, 'shell', 'id', '-u'], text=True, timeout=30).strip()
    record = {'device': device, 'initial_uid': uid, 'root_attempts': [], 'properties': {},
              'physical_device_tested': False}
    if uid != '0':
        # Restarting adbd can close the transport before adb root receives its
        # response. A bounded setup retry still requires actual UID0 afterwards.
        for _ in range(2):
            root = subprocess.run([*base, 'root'], capture_output=True, text=True, timeout=30)
            record['root_attempts'].append({'exit_code': root.returncode,
                                           'stdout': root.stdout, 'stderr': root.stderr})
            if root.returncode and 'closed' not in root.stderr:
                raise RuntimeError('Emulator root request failed')
            subprocess.run([*base, 'wait-for-device'], check=True, timeout=30)
            uid = subprocess.check_output([*base, 'shell', 'id', '-u'], text=True, timeout=30).strip()
            if uid == '0':
                break
    record['verified_uid'] = uid
    if uid != '0':
        raise RuntimeError('Emulator UID0 not established')
    for prop, value in [('bionic.linker.16kb.app_compat.enabled', 'false'),
                        ('pm.16kb.app_compat.disabled', 'true')]:
        subprocess.run([*base, 'shell', 'setprop', prop, value], check=True, timeout=30)
        observed = subprocess.check_output([*base, 'shell', 'getprop', prop], text=True, timeout=30).strip()
        record['properties'][prop] = observed
        if observed != value:
            raise RuntimeError('16KB compatibility property was not applied')
    print(json.dumps(record), flush=True)
    return record


if __name__ == '__main__':
    prepare(sys.argv[1])
