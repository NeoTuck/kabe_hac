import hashlib
import json
import pathlib
import tempfile
import unittest

from review_evidence import audit_review_bindings, record_digest
from build_review_handoff import build
from release_preflight import audit_audio_integrity


class ReviewBindingTests(unittest.TestCase):
    def test_audio_bytes_must_match_catalog_even_if_review_digest_is_unchanged(self):
        with tempfile.TemporaryDirectory() as temp:
            root = pathlib.Path(temp)
            (root / 'assets/content').mkdir(parents=True)
            (root / 'assets/audio').mkdir()
            (root / 'pubspec.yaml').write_text('flutter:\n  assets:\n    - assets/audio/\n')
            audio = root / 'assets/audio/fixture.aac'
            audio.write_bytes(b'unit test only')
            record = {'id': 'fixture', 'asset': 'assets/audio/fixture.aac',
                      'assetSha256': hashlib.sha256(audio.read_bytes()).hexdigest()}
            (root / 'assets/content/umre_inventory.v1.json').write_text(json.dumps({'audioRecords': [record]}))
            (root / 'assets/content/hac_inventory.v1.json').write_text(json.dumps({'audioRecords': []}))
            self.assertEqual(audit_audio_integrity(root), [])
            audio.write_bytes(b'changed recording')
            self.assertEqual(len(audit_audio_integrity(root)), 1)
            audio.write_bytes(b'unit test only')
            (root / 'assets/audio/unreviewed.aac').write_bytes(b'orphan')
            self.assertEqual(audit_audio_integrity(root)[0]['type'], 'bundled_audio_scope_mismatch')

    def test_export_preserves_unsigned_status_and_never_overwrites(self):
        with tempfile.TemporaryDirectory() as temp:
            output = pathlib.Path(temp) / 'handoff'
            self.assertEqual(build(output), 324)
            inventory = json.loads((output / 'inventory.json').read_text())
            self.assertEqual(inventory['status'], 'awaiting_real_decisions')
            with self.assertRaises(FileExistsError):
                build(output)

    def test_exact_record_and_document_required(self):
        with tempfile.TemporaryDirectory() as temp:
            root = pathlib.Path(temp)
            content = root / 'assets/content'
            content.mkdir(parents=True)
            evidence = root / 'proof'
            evidence.mkdir()
            record = {'id': 'technical-fixture', 'status': 'approved', 'textVersion': 'fixture-v1',
                      'summary': 'Unit-test text, not real religious approval', 'reviewEvidence': {}}
            data = {'guideType': 'umrah', 'steps': [record], 'prayerRecords': [], 'audioRecords': []}
            (content / 'hac_inventory.v1.json').write_text(json.dumps({'guideType': 'hajj', 'steps': [], 'prayerRecords': [], 'audioRecords': []}))
            document = evidence / 'unit-test.txt'
            document.write_text('Technical fixture only. This is not a real signature.')
            for kind in ('religious', 'source_rights'):
                ref = f'fixture-{kind}.json'
                record['reviewEvidence'][kind] = ref
                (evidence / ref).write_text(json.dumps({
                    'id': record['id'], 'textVersion': 'fixture-v1', 'recordSha256': record_digest(record),
                    'decisionKind': kind, 'result': 'accepted', 'reviewedBy': 'Unit-test fixture',
                    'reviewedAt': '2026-10-10', 'scope': 'unit test only', 'document': document.name,
                    'documentSha256': hashlib.sha256(document.read_bytes()).hexdigest()}))
            catalog = content / 'umre_inventory.v1.json'
            catalog.write_text(json.dumps(data))
            self.assertEqual(audit_review_bindings(root, evidence), [])
            record['textVersion'] = 'fixture-v2'
            catalog.write_text(json.dumps(data))
            self.assertEqual(len(audit_review_bindings(root, evidence)), 2)
            record['textVersion'] = 'fixture-v1'
            catalog.write_text(json.dumps(data))
            document.write_text('changed')
            self.assertEqual(len(audit_review_bindings(root, evidence)), 2)

    def test_annotations_do_not_change_signed_payload_but_profile_and_audio_do(self):
        record = {'id': 'fixture', 'textVersion': 'v1', 'status': 'draft', 'assetSha256': 'a' * 64,
                  'profileApplicability': {'kiran': 'unverified'}}
        digest = record_digest(record)
        record.update(status='approved', reviewedBy='Unit test', reviewedAt='2026-10-10')
        self.assertEqual(record_digest(record), digest)
        record['profileApplicability']['kiran'] = 'applicable'
        self.assertNotEqual(record_digest(record), digest)
