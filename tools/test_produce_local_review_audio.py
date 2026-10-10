import json
from pathlib import Path
import tempfile
import unittest

from produce_local_review_audio import matching, safe_output, selected_records
from produce_narration import ROOT, sha


class LocalReviewAudioTests(unittest.TestCase):
    def test_all_actual_turkish_bindings_and_arabic_exclusion(self):
        catalogs = [json.loads((ROOT / f'assets/content/{name}_inventory.v1.json').read_text())
                    for name in ('umre', 'hac')]
        records = selected_records(catalogs)
        self.assertEqual(len(records), 54)
        self.assertEqual(len({r['audioId'] for r in records}), 54)
        self.assertTrue(all(r['language'] == 'tr-TR' for r in records))
        with self.assertRaises(ValueError):
            selected_records(catalogs, ['A-P-U02.2-AR-01'])

    def test_output_cannot_escape_ignored_review_directory(self):
        with self.assertRaises(ValueError):
            safe_output(ROOT / 'assets/audio/review')
        with self.assertRaises(ValueError):
            safe_output(ROOT / 'release-inputs/../assets/audio')
        self.assertEqual(safe_output(ROOT / 'release-inputs/review'),
                         ROOT / 'release-inputs/review')

    def test_reuse_requires_same_binding_and_actual_audio_hash(self):
        record = {'file': 'recordings/A-T-TR-01.m4a', 'textVersion': 'v1',
                  'scriptSha256': 'a' * 64}
        with tempfile.TemporaryDirectory() as temp:
            output = Path(temp)
            audio = output / record['file']
            audio.parent.mkdir()
            audio.write_bytes(b'review-only')
            receipt = {'generationFingerprint': 'f' * 64, 'textVersion': 'v1',
                       'scriptSha256': 'a' * 64, 'reviewOnly': True,
                       'sha256': sha(audio.read_bytes())}
            self.assertTrue(matching(record, receipt, output, 'f' * 64))
            self.assertFalse(matching(record, dict(receipt, reviewOnly=False), output, 'f' * 64))
            audio.write_bytes(b'changed')
            self.assertFalse(matching(record, receipt, output, 'f' * 64))
