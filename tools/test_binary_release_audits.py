"""Malformed/unaligned binaries and manifests must never acquire release acceptance."""
import pathlib
import plistlib
import struct
import tempfile
import unittest
import warnings
import zipfile
from unittest.mock import patch

import audit_android_native as android
import audit_ios_privacy as ios
from run_ci_android_qa import verify_page_size


def elf(alignment=16384, address=0, kind=1, memory=120):
    data = bytearray(120)
    data[:6] = b'\x7fELF\x02\x01'
    struct.pack_into('<Q', data, 32, 64)
    struct.pack_into('<HH', data, 54, 56, 1)
    struct.pack_into('<IIQQQQQQ', data, 64, kind, 5, 0, address, 0, 120, memory, alignment)
    return data


class AndroidBinaryTests(unittest.TestCase):
    def test_rejects_four_k_load_and_incongruent_load(self):
        for data in (elf(4096), elf(address=1), elf(memory=119), elf(kind=4), elf()[:100]):
            with self.subTest(data=data[:6]), self.assertRaises(ValueError):
                android.elf_segments(data)
        self.assertEqual(android.elf_segments(elf())[0]['alignment'], 16384)

    def test_checks_actual_zip_offset_not_only_elf_alignment(self):
        with tempfile.TemporaryDirectory() as directory:
            apk = pathlib.Path(directory) / 'app.apk'
            name = 'lib/arm64-v8a/libtest.so'
            with zipfile.ZipFile(apk, 'w') as archive:
                archive.writestr(name, elf())
            self.assertEqual(android.audit(apk)['status'], 'blocked')
            info = zipfile.ZipInfo(name)
            padding = android.PAGE - 30 - len(name.encode())
            info.extra = struct.pack('<HH', 0xCAFE, padding - 4) + bytes(padding - 4)
            with zipfile.ZipFile(apk, 'w') as archive:
                archive.writestr(info, elf())
            result = android.audit(apk)
            self.assertEqual(result['status'], 'static_load_zip_checked')
            self.assertEqual(result['libraries'][0]['zip_data_offset'], 16384)
            self.assertFalse(result['runtime_16kb_tested'])
            self.assertFalse(result['store_ready'])

    def test_duplicate_entries_fail_and_32bit_is_not_64bit_acceptance(self):
        with tempfile.TemporaryDirectory() as directory:
            apk = pathlib.Path(directory) / 'app.apk'
            with zipfile.ZipFile(apk, 'w') as archive:
                archive.writestr('lib/armeabi-v7a/libtest.so', b'32-bit')
            self.assertEqual(android.audit(apk)['status'], 'not_applicable_no_64bit_libraries')
            with warnings.catch_warnings(), zipfile.ZipFile(apk, 'a') as archive:
                warnings.simplefilter('ignore', UserWarning)
                archive.writestr('lib/armeabi-v7a/libtest.so', b'other')
            with self.assertRaisesRegex(ValueError, 'Duplicate'):
                android.audit(apk)

    def test_wrong_runtime_page_size_is_recorded_and_rejected(self):
        with tempfile.TemporaryDirectory() as directory, patch(
                'run_ci_android_qa.subprocess.check_output', return_value='4096\n'):
            path = pathlib.Path(directory)
            with self.assertRaisesRegex(RuntimeError, 'got 4096'):
                verify_page_size('emulator', 16384, path)
            self.assertIn('"passed": false', (path / 'page-size.json').read_text())


class IosPrivacyTests(unittest.TestCase):
    def test_invalid_flags_reasons_and_collected_purposes_rejected(self):
        invalid = [
            {'NSPrivacyTracking': 'false'},
            {'NSPrivacyAccessedAPITypes': [{'NSPrivacyAccessedAPIType': 'unknown'}]},
            {'NSPrivacyAccessedAPITypes': [{'NSPrivacyAccessedAPIType':
                'NSPrivacyAccessedAPICategoryUserDefaults', 'NSPrivacyAccessedAPITypeReasons': []}]},
            {'NSPrivacyCollectedDataTypes': [{'NSPrivacyCollectedDataType': 'email'}]},
            {'NSPrivacyTrackingDomains': ['']},
        ]
        for data in invalid:
            with self.subTest(data=data), self.assertRaises(ValueError):
                ios.validate(data)
        ios.validate({'NSPrivacyTracking': False, 'NSPrivacyAccessedAPITypes': []})

    def test_actual_packaged_flutter_manifest_required_not_just_app_manifest(self):
        with tempfile.TemporaryDirectory() as directory:
            app = pathlib.Path(directory) / 'Runner.app'
            app.mkdir()
            (app / 'Info.plist').write_bytes(plistlib.dumps({'CFBundleIdentifier': 'test.app'}))
            (app / 'PrivacyInfo.xcprivacy').write_bytes(plistlib.dumps({'NSPrivacyTracking': False}))
            self.assertEqual(ios.audit(app)['status'], 'blocked')
            framework = app / 'Frameworks/Flutter.framework'
            framework.mkdir(parents=True)
            (framework / 'PrivacyInfo.xcprivacy').write_bytes(plistlib.dumps({'NSPrivacyTracking': False}))
            result = ios.audit(app)
            self.assertEqual(result['status'], 'packaged_manifest_inventory_checked')
            self.assertEqual(len(result['manifests']), 2)
            self.assertFalse(result['sdk_coverage_accepted'])
            self.assertFalse(result['store_ready'])

    def test_manifest_symlink_outside_package_cannot_supply_acceptance(self):
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            app = root / 'Runner.app'
            app.mkdir()
            (app / 'Info.plist').write_bytes(plistlib.dumps({}))
            outside = root / 'external.plist'
            outside.write_bytes(plistlib.dumps({}))
            (app / 'PrivacyInfo.xcprivacy').symlink_to(outside)
            result = ios.audit(app)
            self.assertEqual(result['status'], 'blocked')
            self.assertEqual(result['manifests'], [])
