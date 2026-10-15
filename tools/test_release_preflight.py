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

    def test_unknown_source_rights_block_approved_label(self):
        record = {'id': 'U01.1', 'status': 'approved',
                  'sourceUsageRights': 'Yeniden dağıtım izni teyit edilmedi'}
        self.assertTrue(any(b['type'] == 'source_rights_unverified'
                            for b in audit_catalog({'steps': [record]})))

    def test_hajj_profile_review_is_separate(self):
        self.assertTrue(any(b['type'] == 'hajj_profile_review' for b in
            audit_catalog({'guideType': 'hajj', 'steps': [{'id': 'H01.1'}]})))

    def test_approved_counter_requires_catalog_target(self):
        data = {'guideType': 'umrah', 'steps': [
            {'id': 'U06.2', 'status': 'approved', 'counterKey': 'tawaf'}]}
        self.assertTrue(any(b['type'] == 'practice_counter_target'
                            for b in audit_catalog(data)))
        data['steps'][0]['counterTarget'] = 7
        self.assertFalse(any(b['type'] == 'practice_counter_target'
                             for b in audit_catalog(data)))

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

    def test_installed_apk_shell_fallback_keeps_sync_failure_and_exact_bytes(self):
        from run_mobile_qa import read_installed_apk, file_hash
        import subprocess
        evidence = {}
        payload = b'installed APK fixture bytes'
        def shell_read(command, **kwargs):
            self.assertEqual(command[3:5], ['exec-out', 'cat'])
            kwargs['stdout'].write(payload)
            return subprocess.CompletedProcess(command, 0, None, b'')
        with tempfile.TemporaryDirectory() as temp, patch('run_mobile_qa.probe', side_effect=RuntimeError('sync denied')), patch('run_mobile_qa.subprocess.run', side_effect=shell_read):
            target = pathlib.Path(temp) / 'installed.apk'
            read_installed_apk('emulator-5554', '/data/app/fixture/base.apk', target, evidence)
            self.assertEqual(file_hash(target), hashlib.sha256(payload).hexdigest())
        self.assertEqual(evidence, {'apk_sync_error': 'sync denied', 'apk_read_transport': 'adb-shell'})

    def test_failed_installed_apk_read_blocks_and_reports_transport_error(self):
        from run_mobile_qa import read_installed_apk
        import subprocess
        with tempfile.TemporaryDirectory() as temp, patch('run_mobile_qa.probe', side_effect=RuntimeError('sync denied')), patch('run_mobile_qa.subprocess.run', return_value=subprocess.CompletedProcess([], 1, None, b'Permission denied')):
            with self.assertRaisesRegex(RuntimeError, 'Permission denied'):
                read_installed_apk('emulator-5554', '/data/app/fixture/base.apk', pathlib.Path(temp) / 'installed.apk', {})

    def test_probe_failure_preserves_command_and_bounded_diagnostic(self):
        from run_mobile_qa import probe
        import subprocess
        with patch('run_mobile_qa.subprocess.run', return_value=subprocess.CompletedProcess([], 1, '', 'Permission denied')):
            with self.assertRaisesRegex(RuntimeError, 'adb pull.*Permission denied'):
                probe(['adb', 'pull', '/data/app/fixture/base.apk'])

    def test_ios_startup_query_timeout_can_recover(self):
        from run_mobile_qa import booted_ios_devices
        import subprocess
        with patch('run_mobile_qa.probe', side_effect=[subprocess.TimeoutExpired('simctl', 30), '{"devices": {}}']), patch('run_mobile_qa.time.sleep'):
            self.assertEqual(booted_ios_devices(), {'devices': {}})

    def test_android_driver_preparation_is_separate_from_flows(self):
        from run_mobile_qa import prepare_android_driver
        import subprocess
        with tempfile.TemporaryDirectory() as temp, patch('run_mobile_qa.wait_for_android'), patch('run_mobile_qa.subprocess.run', side_effect=[subprocess.CompletedProcess([], 1, '', 'device offline'), subprocess.CompletedProcess([], 0, 'hierarchy', '')]) as run:
            prepare_android_driver('emulator-5554', pathlib.Path(temp))
            self.assertEqual(run.call_count, 2)
            self.assertEqual(run.call_args.args[0], ['maestro', '--device', 'emulator-5554', 'hierarchy'])
            self.assertIn('device offline', (pathlib.Path(temp) / 'driver-preflight.log').read_text())

    def test_failed_driver_preparation_never_returns_success(self):
        from run_mobile_qa import prepare_android_driver
        import subprocess
        with tempfile.TemporaryDirectory() as temp, patch('run_mobile_qa.wait_for_android'), patch('run_mobile_qa.subprocess.run', return_value=subprocess.CompletedProcess([], 1, '', 'offline')):
            with self.assertRaisesRegex(RuntimeError, 'UI flows were not started'):
                prepare_android_driver('emulator-5554', pathlib.Path(temp))
