#!/usr/bin/env python3
"""Make Turkish draft listening copies with pinned, offline EMA Lightning weights.

Outputs live only in ignored release-inputs. They never become catalog assets or
religious, pronunciation, training-data-rights, or publication approvals.
Run with Python 3.11-3.13 and ema-lightning==1.0.4 installed separately.
"""
import argparse
import datetime
import hashlib
import importlib.metadata
import json
import os
from pathlib import Path
import subprocess
import tempfile
import wave

from produce_narration import ROOT, plan, sha
from verify_recording import verify

MODEL_REPO = 'canberkkkkkk/ema-lightning'
MODEL_REVISION = '7a6ba1ad216bb2f1da9863f80ac8770a6a807632'
MODEL_CARD = 'https://huggingface.co/canberkkkkkk/ema-lightning/blob/' + MODEL_REVISION + '/README.md'
MODEL_LICENSE = 'Apache-2.0 (author declaration; training corpus terms need separate review)'
FILES = ('config.json', 'ema.pt', 'decoder.pt', 'README.md')


def selected_records(catalogs, wanted=None):
    records = plan(catalogs)['records']
    choices = [r for r in records if r['language'] == 'tr-TR']
    if wanted:
        choices = [r for r in choices if r['audioId'] in wanted]
        if {r['audioId'] for r in choices} != set(wanted):
            raise ValueError('Unknown or non-Turkish audio ID')
    for record in choices:
        if not record['script'].strip() or sha(record['script'].encode()) != record['scriptSha256']:
            raise ValueError('Empty or changed script: ' + record['audioId'])
    return choices


def model_files():
    from huggingface_hub import hf_hub_download
    files = {name: Path(hf_hub_download(MODEL_REPO, name, revision=MODEL_REVISION))
             for name in FILES}
    return files, {name: sha(path.read_bytes()) for name, path in files.items()}


def model_instance(files):
    # The installed library otherwise downloads mutable main. This pins all
    # inference inputs and makes any unexpected model request fail closed.
    import ema_lightning.api as api
    original = api.hf_hub_download
    def pinned(repo, filename):
        if repo != MODEL_REPO or filename not in files:
            raise ValueError('Unexpected model request')
        return str(files[filename])
    try:
        api.hf_hub_download = pinned
        return api.EMA(device='cpu')
    finally:
        api.hf_hub_download = original


def safe_output(output):
    output = Path(os.path.abspath(output))
    root = (ROOT / 'release-inputs').resolve()
    if not output.is_relative_to(root):
        raise ValueError('Draft audio output must stay under ignored release-inputs')
    cursor = root
    for component in output.relative_to(root).parts:
        if cursor.is_symlink():
            raise ValueError('Linked output directory')
        cursor = cursor / component
    if cursor.is_symlink():
        raise ValueError('Linked output directory')
    return output


def matching(record, receipt, output, fingerprint):
    audio = output / record['file']
    return (receipt.get('generationFingerprint') == fingerprint and
            receipt.get('textVersion') == record['textVersion'] and
            receipt.get('scriptSha256') == record['scriptSha256'] and
            receipt.get('reviewOnly') is True and audio.is_file() and
            not audio.is_symlink() and sha(audio.read_bytes()) == receipt.get('sha256'))


def generate(record, output, tts, model_hashes):
    import numpy as np
    fingerprint = sha(json.dumps({
        'scriptSha256': record['scriptSha256'], 'textVersion': record['textVersion'],
        'modelRevision': MODEL_REVISION, 'modelSha256': model_hashes,
        'seed': 0, 'encoder': 'AAC 64k mono', 'boundaryPaddingMs': 250,
        'peakCeiling': 0.7,
    }, sort_keys=True).encode())
    destination = output / record['file']
    receipt_path = output / 'receipts' / (record['audioId'] + '.json')
    if destination.exists() or receipt_path.exists():
        if receipt_path.is_file() and matching(record, json.loads(receipt_path.read_text()), output, fingerprint):
            return 'reused'
        raise ValueError('Existing recording or receipt does not match pinned text/model: ' + record['audioId'])
    speech = tts.say(record['script'], seed=0)
    if speech.sample_rate != 48000 or not speech.words or speech.duration <= 0:
        raise ValueError('Unexpected TTS result: ' + record['audioId'])
    audio = np.asarray(speech.audio, dtype=np.float32)
    if audio.ndim != 1 or not np.all(np.isfinite(audio)):
        raise ValueError('Invalid TTS samples')
    peak = float(np.max(np.abs(audio)))
    rms = float(np.sqrt(np.mean(audio * audio)))
    if peak <= 0 or rms < 1e-5:
        raise ValueError('Silent TTS result')
    # AAC may overshoot the PCM peak. Leave headroom for codec reconstruction.
    gain = min(4.0, 0.7 / peak, 0.1 / rms)
    padded = np.concatenate((np.zeros(12000, np.float32), audio * gain,
                             np.zeros(12000, np.float32)))
    pcm = (np.clip(padded, -1, 1) * 32767).astype('<i2').tobytes()
    destination.parent.mkdir(parents=True, exist_ok=True)
    receipt_path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(dir=output) as temp:
        master, encoded = Path(temp) / 'master.wav', Path(temp) / 'audio.m4a'
        with wave.open(str(master), 'wb') as stream:
            stream.setnchannels(1)
            stream.setsampwidth(2)
            stream.setframerate(48000)
            stream.writeframes(pcm)
        subprocess.run(['ffmpeg', '-nostdin', '-v', 'error', '-i', str(master), '-ac', '1',
                        '-c:a', 'aac', '-b:a', '64k', '-movflags', '+faststart', str(encoded)],
                       capture_output=True, check=True, timeout=120)
        probe = subprocess.run(['ffprobe', '-v', 'error', '-show_format', '-of', 'json', str(encoded)],
                               capture_output=True, check=True, timeout=30)
        duration = float(json.loads(probe.stdout)['format']['duration'])
        payload = encoded.read_bytes()
        receipt = {key: record[key] for key in ('audioId', 'textId', 'textVersion', 'scriptSha256')}
        receipt.update({
            'file': record['file'], 'sha256': sha(payload), 'sizeBytes': len(payload),
            'durationSeconds': duration, 'durationToleranceSeconds': 0.05,
            'boundarySilenceRequired': True, 'declaredOrigin': 'synthetic',
            'model': MODEL_REPO, 'modelRevision': MODEL_REVISION, 'modelSha256': model_hashes,
            'modelCard': MODEL_CARD, 'engineVersion': importlib.metadata.version('ema-lightning'),
            'normalizerVersion': importlib.metadata.version('normalizer-tr'),
            'softwareLicense': 'Apache-2.0', 'modelLicense': MODEL_LICENSE,
            'distributionRights': 'pending-training-corpus-and-content-review',
            'attribution': 'EMA Lightning © Canberk Aslan; normalizer-tr © Erdem Tuna',
            'reviewOnly': True, 'status': 'pendingListeningReview', 'humanVoiceVerified': False,
            'generationFingerprint': fingerprint, 'seed': speech.seed, 'gain': gain,
            'firstWord': speech.words[0].text, 'lastWord': speech.words[-1].text,
            'lastWordEndSeconds': speech.words[-1].end,
            'generatedAt': datetime.datetime.now(datetime.timezone.utc).isoformat(),
        })
        catalog = {'steps': [{'id': record['textId'], 'textVersion': record['textVersion']}],
                   'audioRecords': [{'id': record['audioId'], 'textId': record['textId'],
                                     'textVersion': record['textVersion']}]}
        receipt['technicalQA'] = verify(catalog, dict(receipt, file=encoded.name), Path(temp))
        os.replace(encoded, destination)
        receipt_path.write_text(json.dumps(receipt, ensure_ascii=False, indent=2) + '\n')
    return 'generated'


def write_review_index(output, records, model_hashes):
    entries = []
    for record in records:
        receipt_path = output / 'receipts' / (record['audioId'] + '.json')
        if not receipt_path.exists():
            continue
        receipt = json.loads(receipt_path.read_text())
        if (receipt.get('modelSha256') != model_hashes or
                receipt.get('modelRevision') != MODEL_REVISION or
                not matching(record, receipt, output, receipt.get('generationFingerprint'))):
            raise ValueError('Review index input changed: ' + record['audioId'])
        entries.append({key: record[key] for key in
                        ('audioId', 'textId', 'textVersion', 'kind', 'script',
                         'scriptSha256', 'textReview', 'sourceUrl', 'file')})
        entries[-1]['receiptSha256'] = sha(receipt_path.read_bytes())
    index = {'schemaVersion': 1, 'reviewOnly': True,
             'publicationStatus': 'blocked: religious, listening and training-corpus-rights review',
             'model': MODEL_REPO, 'modelRevision': MODEL_REVISION,
             'modelSha256': model_hashes, 'records': entries}
    (output / 'review-index.json').write_text(json.dumps(index, ensure_ascii=False, indent=2) + '\n')
    (output / 'README.txt').write_text(
        'TASLAK TÜRKÇE SES İNCELEME PAKETİ\n'
        f'{len(entries)} sentetik kayıt: tamamlanan Türkçe adım anlatımları ve dua anlamı.\n'
        'Arapça telbiye kaydı yoktur. Hiçbir kayıt uygulamanın yayın varlığı değildir.\n'
        'Metin, telaffuz, işitsel kalite ve model eğitim verisi hak zinciri incelemesi bekler.\n'
        'Teknik decoder/hash/seviye ve sınır sessizliği kabulü insan dinlemesi değildir.\n'
        'Model ve motor: EMA Lightning 1.0.4, Apache-2.0 yazar beyanı.\n'
        'Atıf: EMA Lightning © Canberk Aslan; normalizer-tr © Erdem Tuna.\n'
        'Model kartı: ' + MODEL_CARD + '\n'
        'Dosya bağları ve taslak metinler review-index.json içindedir.\n'
    )


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=ROOT / 'release-inputs/local-review-audio')
    parser.add_argument('--audio-id', action='append')
    args = parser.parse_args()
    try:
        output = safe_output(args.output)
        catalogs = [json.loads((ROOT / f'assets/content/{name}_inventory.v1.json').read_text())
                    for name in ('umre', 'hac')]
        records = selected_records(catalogs, args.audio_id)
        files, hashes = model_files()
        tts = model_instance(files)
        output.mkdir(parents=True, exist_ok=True)
        counts = {'generated': 0, 'reused': 0}
        for record in records:
            state = generate(record, output, tts, hashes)
            counts[state] += 1
            print(record['audioId'] + ': ' + state, flush=True)
        write_review_index(output, selected_records(catalogs), hashes)
        print(json.dumps({'selected': len(records), **counts, 'reviewOnly': True,
                          'output': str(output)}, ensure_ascii=False))
    except (OSError, ValueError, KeyError, subprocess.SubprocessError) as error:
        parser.exit(2, 'blocked: ' + str(error) + '\n')


if __name__ == '__main__':
    main()
