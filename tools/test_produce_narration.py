import io
import json
import math
from pathlib import Path
import struct
import tempfile
import unittest
import wave

from produce_narration import (ROOT, TERMS, generate, matching_receipt, plan,
                               request_body, rights_input, sha)


def text(status='approved'):
    return {'id': 'U-TEST', 'summary': 'Teknik test.', 'details': 'Yayın içeriği değildir.',
            'status': status, 'textVersion': 'test-v1', 'reviewedBy': 'Unit-test fixture',
            'reviewedAt': '2026-01-01', 'sourceTitle': 'Test-only source',
            'sourceUrl': 'https://example.com/test', 'sourceLocation': 'Test',
            'sourceUsageRights': 'Test-owned string'}


def evidence():
    return {'provider': 'google-cloud-tts', 'termsUrl': TERMS,
            'usageScope': 'application-and-offline-distribution',
            'voice': 'tr-TR-Chirp3-HD-Charon', 'result': 'accepted',
            'reviewedBy': 'Test-only fixture', 'reviewedAt': '2026-01-01',
            'projectId': 'test-only-no-network', 'evidenceReference': 'Fixture'}


class NarrationProductionTests(unittest.TestCase):
    def test_actual_55_bindings_and_no_draft_is_eligible(self):
        catalogs = [json.loads((ROOT / f'assets/content/{name}_inventory.v1.json').read_text())
                    for name in ('umre', 'hac')]
        records = plan(catalogs)['records']
        self.assertEqual(len(records), 55)
        self.assertEqual(len({r['audioId'] for r in records}), 55)
        self.assertEqual(sum(r['language'] == 'tr-TR' for r in records), 54)
        self.assertFalse(any(r['eligibleForSynthesis'] for r in records))
        self.assertIn('A-P-U02.2-AR-01', {r['audioId'] for r in records})

    def test_draft_and_missing_or_future_review_block_before_request(self):
        for record in (text('draft'), dict(text(), reviewedBy=''),
                       dict(text(), reviewedAt='2999-01-01'),
                       dict(text(), sourceUsageRights='izin bekliyor')):
            row = plan([{'steps': [record]}])['records'][0]
            with self.assertRaises(ValueError):
                request_body(row, evidence()['voice'])

    def test_changed_script_or_wrong_voice_cannot_reuse_binding(self):
        row = plan([{'steps': [text()]}])['records'][0]
        with self.assertRaises(ValueError):
            request_body(dict(row, script='changed'), evidence()['voice'])
        with self.assertRaises(ValueError):
            request_body(row, 'en-US-voice')

    def test_arabic_is_separate_and_never_auto_synthesized(self):
        prayer = dict(text(), arabic='اختبار', meaningTr='Teknik anlam.')
        rows = plan([{'steps': [], 'prayerRecords': [prayer]}])['records']
        self.assertEqual(len(rows), 2)
        with self.assertRaises(ValueError):
            request_body(rows[0], evidence()['voice'])

    def test_provider_rights_need_exact_voice_scope_and_nonfuture_date(self):
        self.assertEqual(rights_input(evidence(), evidence()['voice']), evidence())
        for change in ({'result': 'pending'}, {'reviewedBy': ''},
                       {'voice': 'another-voice'}, {'reviewedAt': '2999-01-01'},
                       {'termsUrl': 'https://example.com'}, {'usageScope': 'streaming-only'}):
            with self.assertRaises(ValueError):
                rights_input(dict(evidence(), **change), evidence()['voice'])

    def test_real_encoder_decoder_receipt_and_idempotent_resume(self):
        # A test tone validates technical encoding only, never a human voice.
        buffer = io.BytesIO()
        with wave.open(buffer, 'wb') as out:
            out.setnchannels(1)
            out.setsampwidth(2)
            out.setframerate(22050)
            out.writeframes(b''.join(struct.pack('<h', int(6000 * math.sin(i * 2 * math.pi * 440 / 22050)))
                                     for i in range(44100)))
        row = plan([{'steps': [text()]}])['records'][0]
        calls = []
        def synth(body, token, project):
            calls.append(body)
            return buffer.getvalue()
        with tempfile.TemporaryDirectory() as temp:
            output = Path(temp)
            self.assertEqual(generate(row, output, evidence()['voice'], evidence(), 'test-token', synth), 'generated')
            self.assertEqual(generate(row, output, evidence()['voice'], evidence(), 'test-token', synth), 'reused')
            self.assertEqual(len(calls), 1)
            receipt = json.loads((output / 'receipts' / (row['audioId'] + '.json')).read_text())
            self.assertEqual(receipt['status'], 'pendingListeningReview')
            self.assertFalse(receipt['humanVoiceVerified'])
            self.assertFalse(receipt['technicalQA']['rightsVerified'])
            self.assertTrue(matching_receipt(row, receipt, output / row['file'], receipt['generationFingerprint']))
            (output / row['file']).write_bytes(b'changed')
            with self.assertRaises(ValueError):
                generate(row, output, evidence()['voice'], evidence(), 'test-token', synth)

