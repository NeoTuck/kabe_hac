"""Reject wrong bundle configuration and unverified emulator setup."""
import pathlib
import subprocess
import tempfile
import unittest
from unittest.mock import patch

from audit_android_bundle import inspect, validate_config
from prepare_16kb_emulator import prepare
from run_ci_android_qa import verify_page_size


class BundleRuntimeTests(unittest.TestCase):
    def test_four_k_missing_or_disabled_bundle_config_is_rejected(self):
        for config in [{}, {'optimizations': {'uncompressNativeLibraries': {
                'enabled': True, 'alignment': 'PAGE_ALIGNMENT_4K'}}},
                {'optimizations': {'uncompressNativeLibraries': {
                'enabled': False, 'alignment': 'PAGE_ALIGNMENT_16K'}}}]:
            with self.subTest(config=config), self.assertRaises(ValueError):
                validate_config(config)
        validate_config({'optimizations': {'uncompressNativeLibraries': {
            'enabled': True, 'alignment': 'PAGE_ALIGNMENT_16K'}}})

    def test_unverified_jar_never_executes(self):
        with tempfile.TemporaryDirectory() as directory, patch('audit_android_bundle.subprocess.check_output') as run:
            jar = pathlib.Path(directory) / 'tool.jar'
            jar.write_bytes(b'untrusted')
            with self.assertRaisesRegex(ValueError, 'digest mismatch'):
                inspect(jar, jar, 'java', pathlib.Path(directory))
            run.assert_not_called()

    def test_api28_missing_getconf_uses_measured_kernel_pages(self):
        with tempfile.TemporaryDirectory() as directory, patch('run_ci_android_qa.subprocess.check_output', side_effect=[
                subprocess.CalledProcessError(127, ['getconf']),
                'KernelPageSize:        4 kB\nKernelPageSize:        4 kB\n']):
            verify_page_size('emulator', 4096, pathlib.Path(directory))
            self.assertIn('/proc/self/smaps', (pathlib.Path(directory) / 'page-size.json').read_text())

    def test_api28_fallback_never_invents_page_size(self):
        for output in ['', 'KernelPageSize: 16 kB\n']:
            with tempfile.TemporaryDirectory() as directory, patch('run_ci_android_qa.subprocess.check_output', side_effect=[
                    subprocess.CalledProcessError(127, ['getconf']), output]):
                with self.assertRaises(RuntimeError):
                    verify_page_size('emulator', 4096, pathlib.Path(directory))

    def test_closed_root_transport_requires_observed_uid_zero(self):
        closed = subprocess.CompletedProcess(['adb'], 1, '', 'adb: unable to connect for root: closed')
        good = subprocess.CompletedProcess(['adb'], 0, '', '')
        with patch.dict('os.environ', {'GITHUB_ACTIONS': 'true'}), \
             patch('prepare_16kb_emulator.subprocess.check_output', side_effect=['2000\n', '0\n', 'false\n', 'true\n']), \
             patch('prepare_16kb_emulator.subprocess.run', side_effect=[closed, good, good, good]):
            record = prepare('emulator-5554')
            self.assertEqual(record['root_attempts'][0]['exit_code'], 1)
            self.assertEqual(record['verified_uid'], '0')
            self.assertEqual(len(record['properties']), 2)

    def test_root_retry_never_accepts_shell_uid_or_false_property(self):
        good = subprocess.CompletedProcess(['adb'], 0, '', '')
        for outputs in [['2000', '2000', '2000'], ['0', 'true']]:
            with patch.dict('os.environ', {'GITHUB_ACTIONS': 'true'}), \
                 patch('prepare_16kb_emulator.subprocess.check_output', side_effect=outputs), \
                 patch('prepare_16kb_emulator.subprocess.run', return_value=good):
                with self.assertRaises(RuntimeError):
                    prepare('emulator-5554')

    def test_non_ci_or_physical_device_is_never_modified(self):
        with patch.dict('os.environ', {'GITHUB_ACTIONS': 'true'}), patch('prepare_16kb_emulator.subprocess.check_output') as run:
            with self.assertRaises(RuntimeError):
                prepare('physical-serial')
            run.assert_not_called()
