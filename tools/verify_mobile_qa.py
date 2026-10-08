#!/usr/bin/env python3
"""Validate pilot flow structure; this is not a device execution result."""
import pathlib
import sys

import yaml

ROOT = pathlib.Path(__file__).resolve().parent.parent
ALLOWED = {'launchApp', 'assertVisible', 'tapOn', 'scrollUntilVisible', 'takeScreenshot'}
files = sorted((ROOT / '.maestro/flows').glob('*.yaml'))
if len(files) != 5:
    sys.exit('FAIL: expected five pilot flows')
for path in files:
    documents = list(yaml.safe_load_all(path.read_text()))
    if len(documents) != 2:
        sys.exit(f'FAIL: header/commands missing: {path.name}')
    header, commands = documents
    if not isinstance(header, dict) or header.get('appId') != '${APP_ID}':
        sys.exit(f'FAIL: configurable appId required: {path.name}')
    if not isinstance(commands, list) or not commands:
        sys.exit(f'FAIL: commands missing: {path.name}')
    for command in commands:
        name = command if isinstance(command, str) else next(iter(command), None) if isinstance(command, dict) and len(command) == 1 else None
        if name not in ALLOWED:
            sys.exit(f'FAIL: unexpected command in {path.name}: {name}')
        if name == 'launchApp' and command != 'launchApp':
            sys.exit(f'FAIL: pilot flows must not clear state/permissions: {path.name}')
    if not any(isinstance(c, dict) and 'assertVisible' in c for c in commands):
        sys.exit(f'FAIL: no assertions: {path.name}')
    print(f'VALID YAML {path.name}: {len(commands)} commands')
print('Syntax and pilot command policy only. No device, audio output or UI behavior verified.')
