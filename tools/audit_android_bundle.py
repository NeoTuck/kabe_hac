"""Build and inspect technical AAB-derived APKs; never grant store/signing acceptance."""
import argparse
import hashlib
import json
import pathlib
import subprocess
import zipfile

from audit_android_native import audit
from verify_production_assets import audit as exclude_qa

BUNDLETOOL_SHA256 = 'a099cfa1543f55593bc2ed16a70a7c67fe54b1747bb7301f37fdfd6d91028e29'


def validate_config(config):
    native = config.get('optimizations', {}).get('uncompressNativeLibraries', {})
    if native.get('enabled') is not True or native.get('alignment') != 'PAGE_ALIGNMENT_16K':
        raise ValueError('Actual BundleConfig must enable native libraries with PAGE_ALIGNMENT_16K')


def inspect(bundle, jar, java, output):
    if hashlib.sha256(jar.read_bytes()).hexdigest() != BUNDLETOOL_SHA256:
        raise ValueError('Pinned official bundletool digest mismatch')
    output.mkdir(parents=True, exist_ok=True)
    command = [java, '-jar', str(jar)]
    config = json.loads(subprocess.check_output(
        [*command, 'dump', 'config', '--bundle=' + str(bundle)], text=True, timeout=120))
    validate_config(config)
    apks = output / 'technical.apks'
    # Supply no upload credentials. Bundletool's environment-dependent default
    # signing behavior is not accepted as production signing evidence.
    subprocess.run([*command, 'build-apks', '--bundle=' + str(bundle),
                    '--output=' + str(apks), '--mode=universal', '--overwrite'],
                   check=True, timeout=600)
    derived = output / 'universal.apk'
    with zipfile.ZipFile(apks) as archive:
        if archive.namelist().count('universal.apk') != 1:
            raise ValueError('Expected exactly one real universal APK')
        derived.write_bytes(archive.read('universal.apk'))
    exclude_qa(derived)
    native = audit(derived)
    if not native['libraries'] or native['blockers']:
        raise ValueError('AAB-derived native ELF/ZIP validation failed')
    result = {'bundle_sha256': hashlib.sha256(bundle.read_bytes()).hexdigest(),
              'bundletool_version': '1.18.3', 'bundletool_sha256': BUNDLETOOL_SHA256,
              'bundle_config': config, 'derived_apk': native,
              'production_assets_fixture_exclusion_checked': True,
              'signing_inputs': 'no_explicit_keystore',
              'store_signing_accepted': False, 'store_ready': False,
              'note': 'Actual derived APK ELF LOAD/ZIP and static RELRO-end report; 16 KB runtime behavior, final production signatures and store-generated split APKs require separate acceptance.'}
    (output / 'bundle-audit.json').write_text(json.dumps(result, indent=2) + '\n')
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--bundle', type=pathlib.Path, required=True)
    parser.add_argument('--bundletool', type=pathlib.Path, required=True)
    parser.add_argument('--java', default='java')
    parser.add_argument('--output', type=pathlib.Path, required=True)
    args = parser.parse_args()
    result = inspect(args.bundle, args.bundletool, args.java, args.output)
    print(json.dumps({'bundle_sha256': result['bundle_sha256'],
                      'derived_apk_sha256': result['derived_apk']['sha256'], 'store_ready': False}))
