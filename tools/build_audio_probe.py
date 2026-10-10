#!/usr/bin/env python3
"""Build a separate debug audio probe; restore production manifest/artifact."""
import argparse
import pathlib
import shutil
import subprocess
import tempfile

ROOT = pathlib.Path(__file__).resolve().parent.parent


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--platform', choices=['android', 'ios-simulator'], required=True)
    args = parser.parse_args()
    manifest = ROOT / 'pubspec.yaml'
    original = manifest.read_bytes()
    marker = b'  assets:\n'
    asset = b'    - assets/audio/teknik_demo.m4a\n'
    if original.count(marker) != 1 or asset in original:
        raise RuntimeError('Production manifest must exclude technical audio')
    android = args.platform == 'android'
    artifact = ROOT / ('build/app/outputs/flutter-apk/app-debug.apk' if android
                       else 'build/ios/iphonesimulator/Runner.app')
    if not artifact.exists():
        raise RuntimeError('Build the production entry point before its separate QA probe')
    output = ROOT / 'build/audio-qa'
    output.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(dir=ROOT / 'build', prefix='audio-probe-') as tmp:
        backup = pathlib.Path(tmp) / artifact.name
        shutil.move(str(artifact), backup)
        try:
            manifest.write_bytes(original.replace(marker, marker + asset))
            command = ['flutter', 'build', 'apk' if android else 'ios', '--debug',
                       '--target=tools/audio_probe.dart', '--dart-define=KABE_AUDIO_QA=true']
            if not android:
                command.append('--simulator')
            subprocess.run(command, cwd=ROOT, check=True, timeout=900)
            target = output / artifact.name
            if target.exists():
                if target.is_dir():
                    shutil.rmtree(target)
                else:
                    target.unlink()
            shutil.move(str(artifact), target)
        finally:
            manifest.write_bytes(original)
            if artifact.exists():
                if artifact.is_dir():
                    shutil.rmtree(artifact)
                else:
                    artifact.unlink()
            shutil.move(str(backup), artifact)
    print('Separate debug audio probe built. Production artifact and manifest restored.')


if __name__ == '__main__':
    main()
