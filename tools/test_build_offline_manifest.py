"""Manifest creation must agree with the mobile client's trust contract."""

import hashlib
import json
import pathlib
import tempfile
import unittest

from build_offline_manifest import build


class ManifestBuilderTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = pathlib.Path(self.temp.name)
        self.source = self.root / 'source'
        (self.source / 'audio').mkdir(parents=True)
        (self.source / 'audio' / 'one.m4a').write_bytes(b'approved-fixture-only')

    def make(self, **changes):
        args = dict(source=self.source, base_url='https://packages.example.test/v1',
                    package_id='audio-pilot', kind='audio', version='1.0.0',
                    change_class='C0')
        args.update(changes)
        return build(**args)

    def test_manifest_bytes_urls_and_pin_match_client_order(self):
        manifest, digest = self.make()
        self.assertEqual(manifest['totalBytes'], 21)
        self.assertEqual(manifest['files'][0]['path'], 'audio/one.m4a')
        self.assertEqual(manifest['files'][0]['downloadUrl'],
                         'https://packages.example.test/v1/audio/one.m4a')
        self.assertEqual(manifest['files'][0]['sha256'],
                         hashlib.sha256(b'approved-fixture-only').hexdigest())
        self.assertEqual(digest, hashlib.sha256(json.dumps(
            manifest, ensure_ascii=False, separators=(',', ':')).encode()).hexdigest())

    def test_symlink_hidden_file_and_empty_package_rejected(self):
        link = self.source / 'audio' / 'shortcut'
        link.symlink_to(self.source / 'audio' / 'one.m4a')
        with self.assertRaisesRegex(ValueError, 'Sembolik'):
            self.make()
        link.unlink()
        (self.source / '.secret').write_text('secret')
        with self.assertRaisesRegex(ValueError, 'gizli'):
            self.make()
        (self.source / '.secret').unlink()
        (self.source / 'audio' / 'one.m4a').unlink()
        with self.assertRaisesRegex(ValueError, 'en az bir'):
            self.make()

    def test_invalid_host_identity_and_schema_rejected(self):
        for changes in ({'base_url': 'http://example.test'},
                        {'base_url': 'https://user:pw@example.test'},
                        {'base_url': 'https://example.test?token=x'},
                        {'package_id': '../escape'},
                        {'version': 'latest'},
                        {'min_schema': 2, 'max_schema': 1}):
            with self.subTest(changes=changes), self.assertRaises(ValueError):
                self.make(**changes)


if __name__ == '__main__':
    unittest.main()
