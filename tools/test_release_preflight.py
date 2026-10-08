import hashlib
import json
import pathlib
import tempfile
import unittest
from unittest.mock import patch

from release_preflight import audit_catalog, audit_evidence
from run_mobile_qa import wait_for_android


class ReleaseAuditTests(unittest.TestCase):
    def test_approved_label_without_metadata_is_blocked(self):
        result = audit_catalog({'steps': [{'id': 'U01.1', 'status': 'approved'}]})
        record = next(b for b in result if b['type'] == 'steps')
        self.assertEqual(record['id'], 'U01.1')
        self.assertIn('reviewedBy', record['missing'])

    def test_draft_never_becomes_approved_from_complete_text(self):
        self.assertTrue(audit_catalog({'steps': [{'id': 'U01.1', 'status': 'draft'}]}))

    def test_hajj_profile_review_is_separate(self):
        self.assertTrue(any(b['type'] == 'hajj_profile_review' for b in
            audit_catalog({'guideType': 'hajj', 'steps': [{'id': 'H01.1'}]})))

    def test_missing_changed_and_outside_evidence_rejected(self):
        with tempfile.TemporaryDirectory() as temp:
            root = pathlib.Path(temp)
            self.assertTrue(audit_evidence(root))
            file = root / 'proof.txt'
            file.write_text('Technical fixture, not real acceptance')
            metadata = {'file': 'proof.txt', 'sha256': hashlib.sha256(file.read_bytes()).hexdigest(),
                        'result': 'accepted', 'reviewedBy': 'Technical fixture',
                        'scope': 'unit test only', 'reviewedAt': '2026-10-08'}
            with patch('release_preflight.EVIDENCE', ('fixture',)):
                manifest = root / 'fixture.json'
                manifest.write_text(json.dumps(metadata))
                self.assertEqual(audit_evidence(root), [])
                file.write_text('changed')
                self.assertTrue(audit_evidence(root))
                metadata['file'] = '../outside.txt'
                manifest.write_text(json.dumps(metadata))
                self.assertTrue(audit_evidence(root))

    def test_android_requires_two_consecutive_boot_responses(self):
        with patch('run_mobile_qa.probe', side_effect=['device', '0', 'device', '1', 'device', '1']), patch('run_mobile_qa.time.sleep'):
            wait_for_android('emulator-5554')

    def test_android_unstable_transport_fails_without_running_ui(self):
        with patch('run_mobile_qa.probe', side_effect=RuntimeError('offline')), patch('run_mobile_qa.time.sleep'):
            with self.assertRaisesRegex(RuntimeError, 'stably ready'):
                wait_for_android('emulator-5554')
