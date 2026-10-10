#!/usr/bin/env python3
"""Build a pinned offline package manifest from owned, reviewed files.

The tool prepares metadata only. It does not grant distribution rights or upload
files. Publish the files at the exact HTTPS URLs in the manifest after review.
"""

import argparse
import hashlib
import json
import pathlib
import re
import sys
from urllib.parse import quote, urlsplit

PACKAGE_ID = re.compile(r'^[a-z0-9][a-z0-9._-]{2,63}$')
VERSION = re.compile(r'^[0-9]+\.[0-9]+\.[0-9]+(?:[-+][a-zA-Z0-9.-]+)?$')
MAX_FILE_BYTES = 512 * 1024 * 1024


def build(source, base_url, package_id, kind, version, change_class,
          min_schema=1, max_schema=1):
    source = pathlib.Path(source)
    if source.is_symlink() or not source.is_dir():
        raise ValueError('Kaynak gerçek bir klasör olmalı; sembolik bağ reddedildi.')
    if not PACKAGE_ID.fullmatch(package_id):
        raise ValueError('Geçersiz paket kimliği.')
    if not VERSION.fullmatch(version):
        raise ValueError('Geçersiz paket sürümü.')
    if kind not in ('audio', 'map', 'travel', 'language'):
        raise ValueError('Geçersiz paket türü.')
    if change_class not in ('C0', 'C1', 'C2'):
        raise ValueError('Geçersiz içerik değişiklik sınıfı.')
    if not 1 <= min_schema <= max_schema:
        raise ValueError('Geçersiz içerik şema aralığı.')
    parsed = urlsplit(base_url)
    if (parsed.scheme != 'https' or not parsed.hostname or parsed.username or
            parsed.password or parsed.query or parsed.fragment or
            base_url.endswith('/package-manifest.json')):
        raise ValueError('Dosya tabanı temiz bir HTTPS bağlantısı olmalı.')
    files = []
    for item in sorted(source.rglob('*')):
        if item.is_symlink():
            raise ValueError(f'Sembolik bağ reddedildi: {item}')
        if item.is_dir():
            continue
        if not item.is_file():
            raise ValueError(f'Desteklenmeyen dosya türü: {item}')
        relative = item.relative_to(source).as_posix()
        if (relative == 'package-manifest.json' or
                any(part.startswith('.') for part in pathlib.PurePosixPath(relative).parts)):
            raise ValueError(f'Paket dışı veya gizli dosya: {relative}')
        size = item.stat().st_size
        if size > MAX_FILE_BYTES:
            raise ValueError(f'Dosya boyut sınırını aşıyor: {relative}')
        digest = hashlib.sha256()
        with item.open('rb') as handle:
            for block in iter(lambda: handle.read(1024 * 1024), b''):
                digest.update(block)
        files.append({
            'path': relative,
            'sha256': digest.hexdigest(),
            'sizeBytes': size,
            'downloadUrl': base_url.rstrip('/') + '/' + quote(relative, safe='/'),
        })
    if not files:
        raise ValueError('Paket en az bir dosya içermeli.')
    manifest = {
        'schemaVersion': 1,
        'packageId': package_id,
        'kind': kind,
        'version': version,
        'changeClass': change_class,
        'minContentSchema': min_schema,
        'maxContentSchema': max_schema,
        'totalBytes': sum(file['sizeBytes'] for file in files),
        'files': files,
    }
    # Dart jsonEncode(manifest.toJson()) uses this field and insertion order.
    canonical = json.dumps(manifest, ensure_ascii=False, separators=(',', ':'))
    return manifest, hashlib.sha256(canonical.encode('utf-8')).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source-dir', required=True, type=pathlib.Path)
    parser.add_argument('--base-url', required=True)
    parser.add_argument('--package-id', required=True)
    parser.add_argument('--kind', required=True, choices=('audio', 'map', 'travel', 'language'))
    parser.add_argument('--version', required=True)
    parser.add_argument('--change-class', default='C0', choices=('C0', 'C1', 'C2'))
    parser.add_argument('--min-content-schema', type=int, default=1)
    parser.add_argument('--max-content-schema', type=int, default=1)
    parser.add_argument('--output', required=True, type=pathlib.Path)
    args = parser.parse_args()
    try:
        source = args.source_dir.resolve(strict=True)
        output = args.output.resolve()
        if output == source or source in output.parents or output.exists():
            raise ValueError('Çıktı kaynak klasöründe veya mevcut dosya üzerinde olamaz.')
        manifest, digest = build(
            args.source_dir, args.base_url, args.package_id, args.kind,
            args.version, args.change_class, args.min_content_schema,
            args.max_content_schema,
        )
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n')
        print(json.dumps({'manifest': str(output), 'sha256': digest,
                          'totalBytes': manifest['totalBytes'],
                          'files': len(manifest['files'])}))
    except (OSError, ValueError) as error:
        parser.exit(2, f'blocked: {error}\n')


if __name__ == '__main__':
    sys.exit(main())
