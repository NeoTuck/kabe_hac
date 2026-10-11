#!/usr/bin/env python3
"""Inspect actual APK ELF/ZIP alignment; never grant runtime/store acceptance."""
import argparse
import hashlib
import json
import pathlib
import struct
import sys
import zipfile

PAGE = 16384


def elf_segments(data):
    if len(data) < 64 or data[:4] != b'\x7fELF' or data[4] != 2 or data[5] not in (1, 2):
        raise ValueError('Expected a complete ELF64 library')
    order = '<' if data[5] == 1 else '>'
    offset = struct.unpack_from(order + 'Q', data, 32)[0]
    size, count = struct.unpack_from(order + 'HH', data, 54)
    if size != 56 or not count or offset + size * count > len(data):
        raise ValueError('Truncated/unsupported program headers')
    result = []
    for index in range(count):
        kind, flags, file_offset, address, _, file_size, memory_size, alignment = struct.unpack_from(
            order + 'IIQQQQQQ', data, offset + index * size)
        if file_offset + file_size > len(data) or file_size > memory_size:
            raise ValueError('Invalid segment bounds')
        if kind == 1:
            if alignment < PAGE or alignment & (alignment - 1) or (address - file_offset) % alignment:
                raise ValueError('PT_LOAD is not 16KB aligned/congruent')
        result.append({'type': kind, 'flags': flags, 'offset': file_offset,
                       'virtual_address': address, 'memory_bytes': memory_size,
                       'alignment': alignment})
    if not any(s['type'] == 1 for s in result):
        raise ValueError('No load segments')
    return result


def audit(apk):
    apk = pathlib.Path(apk)
    report = {'file': apk.name, 'sha256': hashlib.sha256(apk.read_bytes()).hexdigest(),
              'libraries': [], 'blockers': [], 'relro_blockers': [],
              'runtime_16kb_tested': False,
              'signing_verified': False, 'store_ready': False}
    with zipfile.ZipFile(apk) as archive, apk.open('rb') as raw:
        if len(archive.namelist()) != len(set(archive.namelist())):
            raise ValueError('Duplicate ZIP entries')
        for entry in archive.infolist():
            parts = pathlib.PurePosixPath(entry.filename).parts
            if len(parts) != 3 or parts[0] != 'lib' or not parts[2].endswith('.so'):
                continue
            if parts[1] not in ('arm64-v8a', 'x86_64'):
                continue  # The 16KB environment requires 64-bit ABI libraries.
            item = {'name': entry.filename, 'compressed': entry.compress_type != zipfile.ZIP_STORED}
            try:
                item['segments'] = elf_segments(archive.read(entry))
                raw.seek(entry.header_offset)
                header = raw.read(30)
                if len(header) != 30 or header[:4] != b'PK\x03\x04':
                    raise ValueError('Invalid ZIP local header')
                name_size, extra_size = struct.unpack_from('<HH', header, 26)
                offset = entry.header_offset + 30 + name_size + extra_size
                item['zip_data_offset'] = offset
                if not item['compressed'] and offset % PAGE:
                    raise ValueError('Uncompressed library is not ZIP-aligned to 16KB')
                # Record the official RELRO-end check separately. Static LOAD/ZIP
                # success cannot settle linker behavior; real 16KB QA remains required.
                item['relro_end_remainders'] = [
                    (s['virtual_address'] + s['memory_bytes']) % PAGE
                    for s in item['segments'] if s['type'] == 0x6474E552]
                item['relro_needs_runtime_review'] = any(item['relro_end_remainders'])
                if item['relro_needs_runtime_review']:
                    report['relro_blockers'].append({
                        'file': entry.filename,
                        'end_remainders': item['relro_end_remainders'],
                    })
            except (ValueError, struct.error) as error:
                report['blockers'].append({'file': entry.filename, 'reason': str(error)})
            report['libraries'].append(item)
    report['status'] = ('blocked' if report['blockers'] else
                        'static_load_zip_checked' if report['libraries'] else
                        'not_applicable_no_64bit_libraries')
    report['relro_status'] = ('not_checked' if report['blockers'] else
                              'unaligned' if report['relro_blockers'] else
                              'aligned_or_absent')
    report['note'] = 'ELF LOAD/ZIP and RELRO end alignment are separate; runtime, signing and store review still require acceptance.'
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('apks', nargs='+', type=pathlib.Path)
    parser.add_argument('--output', required=True, type=pathlib.Path)
    args = parser.parse_args()
    reports = [audit(path) for path in args.apks]
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(reports, indent=2) + '\n')
    print(json.dumps([{'file': r['file'], 'status': r['status'],
                       'relro_status': r['relro_status'],
                       'libraries': len(r['libraries']), 'blockers': len(r['blockers']),
                       'relro_blockers': len(r['relro_blockers'])} for r in reports]))
    return int(any(r['blockers'] for r in reports))


if __name__ == '__main__':
    sys.exit(main())
