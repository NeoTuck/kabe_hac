import pathlib
import tempfile
import unittest
import zipfile

from verify_production_assets import audit


class ProductionAssetsTests(unittest.TestCase):
    def test_probe_fixture_is_rejected_from_user_apk(self):
        with tempfile.TemporaryDirectory() as tmp:
            apk = pathlib.Path(tmp) / 'app.apk'
            with zipfile.ZipFile(apk, 'w') as out:
                out.writestr('assets/flutter_assets/assets/content/umre_inventory.v1.json', '{}')
            audit(apk)
            with zipfile.ZipFile(apk, 'a') as out:
                out.writestr('assets/flutter_assets/assets/audio/teknik_demo.m4a', b'fixture')
            with self.assertRaisesRegex(RuntimeError, 'QA fixture packaged'):
                audit(apk)

    def test_probe_is_not_reachable_from_production_entrypoint(self):
        root = pathlib.Path(__file__).resolve().parent.parent
        self.assertNotIn('audio_probe', (root / 'lib/main.dart').read_text())
        self.assertNotIn('assets/audio/', (root / 'pubspec.yaml').read_text())
