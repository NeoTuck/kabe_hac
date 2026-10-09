#!/usr/bin/env python3
"""Verify a supplied recording receipt, never grant human/rights approval.

Receipt fields: audioId, textId, textVersion, file, sha256, sizeBytes,
durationSeconds, durationToleranceSeconds, declaredOrigin (human/synthetic).
Keep receipts/recordings in ignored release-inputs until their rights are reviewed.
"""
import argparse
import array
import hashlib
import json
import math
import pathlib
import subprocess


def binding(catalog, receipt, directory):
    audios = [a for a in catalog.get('audioRecords', []) if a.get('id') == receipt.get('audioId')]
    if len(audios) != 1:
        raise ValueError('Unknown or duplicate audio ID')
    audio = audios[0]
    texts = [r for r in catalog.get('steps', []) + catalog.get('prayerRecords', [])
             if r.get('id') == receipt.get('textId')]
    if (len(texts) != 1 or audio.get('textId') != receipt.get('textId') or
            audio.get('textVersion') != receipt.get('textVersion') or
            texts[0].get('textVersion') != receipt.get('textVersion')):
        raise ValueError('Recording/text version mismatch')
    if receipt.get('declaredOrigin') not in ('human', 'synthetic'):
        raise ValueError('Recording origin declaration required')
    directory = pathlib.Path(directory)
    relative = pathlib.PurePosixPath(receipt['file'])
    if relative.is_absolute() or any(p in ('..', '.') for p in relative.parts) or not relative.parts:
        raise ValueError('Unsafe recording path')
    path = directory
    if path.is_symlink():
        raise ValueError('Linked recording directory rejected')
    for part in relative.parts:
        path = path / part
        if path.is_symlink():
            raise ValueError('Linked recording rejected')
    if not path.is_file() or path.stat().st_size > 64 * 1024 * 1024:
        raise ValueError('Missing or oversized recording')
    if type(receipt.get('sizeBytes')) is not int or path.stat().st_size != receipt['sizeBytes']:
        raise ValueError('Recording byte size mismatch')
    with path.open('rb') as handle:
        digest = hashlib.file_digest(handle, 'sha256').hexdigest()
    if digest != receipt.get('sha256'):
        raise ValueError('Recording hash mismatch')
    for field in ('durationSeconds', 'durationToleranceSeconds'):
        value = receipt.get(field)
        if type(value) not in (int, float) or not math.isfinite(value) or value < 0:
            raise ValueError('Explicit duration and tolerance required')
    if not 0 < receipt['durationSeconds'] <= 7200:
        raise ValueError('Duration outside technical decode limit')
    return path


def verify(catalog, receipt, directory):
    path = binding(catalog, receipt, directory)
    probe = subprocess.run(['ffprobe', '-v', 'error', '-show_streams', '-show_format', '-of', 'json', str(path)],
                           capture_output=True, check=True, timeout=30)
    metadata = json.loads(probe.stdout)
    streams = metadata['streams']
    if len(streams) != 1 or streams[0].get('codec_type') != 'audio' or streams[0].get('codec_name') != 'aac':
        raise ValueError('Expected one AAC audio stream without video')
    duration = float(metadata['format']['duration'])
    if abs(duration - receipt['durationSeconds']) > receipt['durationToleranceSeconds']:
        raise ValueError('Duration mismatch: truncation or wrong recording')
    # Decode to disk, then scan in bounded memory. ffmpeg failure rejects corruption.
    import tempfile
    with tempfile.TemporaryFile() as pcm:
        subprocess.run(['ffmpeg', '-v', 'error', '-xerror', '-err_detect', 'explode', '-i', str(path),
                        '-f', 'f32le', '-ac', '1', '-ar', '22050', '-'], stdout=pcm, stderr=subprocess.PIPE,
                       check=True, timeout=120)
        pcm.seek(0)
        count = 0
        energy = 0.0
        peak = 0.0
        while block := pcm.read(65536):
            samples = array.array('f', block)
            if any(not math.isfinite(s) for s in samples):
                raise ValueError('Invalid decoded PCM')
            count += len(samples)
            energy += sum(s * s for s in samples)
            peak = max(peak, max((abs(s) for s in samples), default=0))
        rms = math.sqrt(energy / count) if count else 0
        if peak >= 0.999 or rms < 0.0001:
            raise ValueError('Clipping or silence detected')
    return {'audioId': receipt['audioId'], 'textId': receipt['textId'], 'textVersion': receipt['textVersion'],
            'sha256': receipt['sha256'], 'durationSeconds': duration, 'codec': 'aac',
            'peakDbFS': 20 * math.log10(peak), 'rmsDbFS': 20 * math.log10(rms),
            'declaredOrigin': receipt['declaredOrigin'], 'technicalIntegrity': 'passed',
            'humanVoiceVerified': False, 'rightsVerified': False,
            'listeningReview': 'required: pronunciation, missing words, clipped start/end and device playback'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--catalog', required=True, type=pathlib.Path)
    parser.add_argument('--receipt', required=True, type=pathlib.Path)
    parser.add_argument('--recording-dir', required=True, type=pathlib.Path)
    args = parser.parse_args()
    try:
        print(json.dumps(verify(json.loads(args.catalog.read_text()), json.loads(args.receipt.read_text()),
                                args.recording_dir), ensure_ascii=False, indent=2))
    except (ValueError, OSError, KeyError, subprocess.SubprocessError) as error:
        parser.exit(2, f'blocked: {error}\n')


if __name__ == '__main__':
    main()
