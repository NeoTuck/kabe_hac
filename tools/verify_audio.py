#!/usr/bin/env python3
"""QA-only: decode bundled audio and reject silence, clipping and invalid media."""
import array
import json
import math
import pathlib
import subprocess

root = pathlib.Path(__file__).resolve().parent.parent
files = sorted((root / 'assets/audio').glob('*.m4a'))
if not files:
    raise SystemExit('FAIL: no audio files')
for file in files:
    result = subprocess.run(['ffprobe', '-v', 'error', '-show_streams', '-show_format', '-of', 'json', str(file)], check=True, capture_output=True)
    metadata = json.loads(result.stdout)
    streams = [s for s in metadata['streams'] if s['codec_type'] == 'audio']
    if len(streams) != 1 or float(metadata['format']['duration']) <= 0:
        raise SystemExit(f'FAIL: invalid stream {file.name}')
    decoded = subprocess.run(['ffmpeg', '-v', 'error', '-i', str(file), '-f', 'f32le', '-ac', '1', '-ar', '22050', '-'], check=True, capture_output=True)
    samples = array.array('f', decoded.stdout)
    if not samples or any(not math.isfinite(s) for s in samples):
        raise SystemExit(f'FAIL: invalid PCM {file.name}')
    peak = max(abs(s) for s in samples)
    rms = math.sqrt(sum(s*s for s in samples)/len(samples))
    if peak >= 1 or rms < 0.0001:
        raise SystemExit(f'FAIL: clipping or silence {file.name}')
    print(f'PASS {file.name}: {metadata["format"]["duration"]}s, {streams[0]["codec_name"]}, {len(samples)} samples, RMS {20*math.log10(rms):.1f} dBFS, peak {20*math.log10(peak):.1f} dBFS')
print('File integrity only; human narration and device playback still require review.')
