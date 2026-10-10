#!/usr/bin/env python3
"""Inventory bundled assets and locked Dart package license evidence.

This records local evidence, not a legal conclusion about native dependencies
or rights to external religious, map, audio or field content.
"""

import argparse
import hashlib
import json
import os
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent.parent
OUTPUT = ROOT / 'docs/qa/asset-license-inventory.json'
FONT_RIGHTS = {
    'NotoSans.ttf': ('Noto Sans', 'assets/fonts/NotoSans-OFL.txt',
                     'https://github.com/notofonts/latin-greek-cyrillic'),
    'NotoNaskhArabic.ttf': ('Noto Naskh Arabic',
                            'assets/fonts/NotoNaskhArabic-OFL.txt',
                            'https://github.com/notofonts/arabic'),
}
REVIEW_AUDIO_DIR = 'assets/audio/draft-v2/'
REVIEW_AUDIO_MODEL_REVISION = '7a6ba1ad216bb2f1da9863f80ac8770a6a807632'
REVIEW_AUDIO_MODEL_CARD = (
    'https://huggingface.co/canberkkkkkk/ema-lightning/blob/'
    f'{REVIEW_AUDIO_MODEL_REVISION}/README.md'
)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def asset_entry(path):
    rel = path.relative_to(ROOT).as_posix()
    entry = {'path': rel, 'sha256': digest(path), 'bytes': path.stat().st_size}
    if path.name in FONT_RIGHTS and rel.startswith('assets/fonts/'):
        family, license_path, source = FONT_RIGHTS[path.name]
        entry.update({'kind': 'font', 'name': family,
                      'owner': 'The Noto Project Authors', 'license': 'OFL-1.1',
                      'licenseFile': license_path, 'source': source,
                      'releaseStatus': 'bundled'})
    elif rel.startswith('assets/fonts/'):
        entry.update({'kind': 'font_license', 'license': 'OFL-1.1',
                      'releaseStatus': 'bundled'})
    elif rel == 'assets/licenses/ODbL-1.0.txt':
        entry.update({'kind': 'data_license', 'license': 'ODbL-1.0',
                      'source': 'https://opendatacommons.org/licenses/odbl/1-0/', 'releaseStatus': 'bundled'})
    elif rel == 'assets/content/safety_catalog.v1.json':
        entry.update({'kind': 'official_contact_facts',
                      'owner': 'project original labels; cited official contact facts',
                      'license': 'factual directory; original UI labels',
                      'source': 'docs/qa/source-registry.v1.json',
                      'releaseStatus': 'source_checked_not_human_reviewed'})
    elif rel == 'assets/content/package_defaults.v1.json':
        entry.update({'kind': 'package_trust_configuration', 'owner': 'project',
                      'license': 'original project configuration', 'releaseStatus': 'bundled'})
    elif rel.startswith('assets/content/'):
        entry.update({'kind': 'religious_content_draft',
                      'owner': 'project original summaries',
                      'license': 'source reuse and expert review pending',
                      'releaseStatus': 'draft_guarded'})
    elif '/AppIcon.appiconset/' in rel or '/mipmap-' in rel:
        entry.update({'kind': 'app_icon', 'owner': 'project generated geometry',
                      'license': 'original project asset',
                      'source': 'tools/build_app_icons.py',
                      'releaseStatus': 'bundled'})
    elif rel.startswith(REVIEW_AUDIO_DIR) and path.suffix == '.m4a':
        entry.update({
            'kind': 'synthetic_turkish_review_audio',
            'audioId': path.stem,
            'declaredOrigin': 'synthetic',
            'engine': 'EMA Lightning 1.0.4',
            'model': 'canberkkkkkk/ema-lightning',
            'modelRevision': REVIEW_AUDIO_MODEL_REVISION,
            'normalizer': 'normalizer-tr 0.4.0',
            'source': REVIEW_AUDIO_MODEL_CARD,
            'provenanceReceipt': (
                'release-inputs/local-review-audio-v2/receipts/'
                f'{path.stem}.json'
            ),
            'license': 'Apache-2.0 (model author declaration)',
            'rightsStatus': 'training_corpus_consent_and_output_distribution_unverified',
            'listeningReview': 'pending',
            'religiousContentReview': 'pending',
            'releaseStatus': 'draft_guarded',
        })
    elif rel == 'assets/audio/teknik_demo.m4a':
        entry.update({'kind': 'technical_audio', 'license': 'QA fixture only',
                      'releaseStatus': 'excluded_from_user_build'})
    else:
        entry.update({'kind': 'template_asset',
                      'releaseStatus': 'bundled'})
    return entry


def collect_assets():
    paths = list((ROOT / 'assets/fonts').glob('*'))
    paths += list((ROOT / 'assets/content').glob('*.json'))
    paths += list((ROOT / 'assets/licenses').glob('*.txt'))
    paths += list((ROOT / 'android/app/src/main/res').glob('mipmap-*/ic_launcher.png'))
    paths += list((ROOT / 'ios/Runner/Assets.xcassets/AppIcon.appiconset').glob('*.png'))
    paths += list((ROOT / 'ios/Runner/Assets.xcassets/LaunchImage.imageset').glob('*.png'))
    paths.append(ROOT / 'assets/audio/teknik_demo.m4a')
    review_audio = sorted((ROOT / REVIEW_AUDIO_DIR).glob('*.m4a'))
    if len(review_audio) != 54:
        raise SystemExit(f'Expected 54 bundled draft review audio files, found {len(review_audio)}.')
    paths += review_audio
    return [asset_entry(p) for p in sorted(paths) if p.is_file()]


def collect_packages():
    lock = yaml.safe_load((ROOT / 'pubspec.lock').read_text())['packages']
    cache = Path(os.environ.get('PUB_CACHE', Path.home() / '.pub-cache'))
    result = []
    for name, package in sorted(lock.items()):
        version = str(package['version'])
        entry = {'name': name, 'version': version,
                 'dependency': package['dependency'],
                 'source': package['source']}
        if package['source'] == 'hosted':
            entry['licenseUrl'] = (
                f'https://pub.dev/packages/{name}/versions/{version}/license')
            base = cache / 'hosted/pub.dev' / f'{name}-{version}'
            licenses = sorted(p for p in base.glob('LICEN[CS]E*') if p.is_file())
            entry['licenseFiles'] = [
                {'name': p.name, 'sha256': digest(p)} for p in licenses]
            entry['localEvidence'] = 'found' if licenses else 'missing'
        else:
            entry['localEvidence'] = 'SDK or non-hosted; inspect build notices'
        result.append(entry)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    report = {
        'scope': 'checked-in user assets including 54 guarded synthetic draft audio files, excluded QA audio, pubspec.lock Dart packages',
        'limits': 'Audio model license is an author declaration; training corpus consent, output distribution rights, listening and religious review remain unverified. Native Gradle/Apple transitive packages and future downloaded packs require separate review.',
        'assets': collect_assets(),
        'dartPackages': collect_packages(),
    }
    content = json.dumps(report, ensure_ascii=False, indent=2) + '\n'
    if args.check:
        if not OUTPUT.is_file() or OUTPUT.read_text() != content:
            raise SystemExit('Asset/license inventory is stale; regenerate it.')
    else:
        OUTPUT.write_text(content)
    print(json.dumps({'assets': len(report['assets']),
                      'dart_packages': len(report['dartPackages']),
                      'missing_local_license_files': sum(
                          e['localEvidence'] == 'missing'
                          for e in report['dartPackages'])}))


if __name__ == '__main__':
    main()
