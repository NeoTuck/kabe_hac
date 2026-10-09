"""Regression checks for observed native semantics and simulator selection.

These checks validate test configuration, not execution on a device.
"""
import pathlib
import re
import unittest

import yaml

from run_ci_ios_qa import select_runtime

ROOT = pathlib.Path(__file__).resolve().parent.parent


def commands(name):
    return list(yaml.safe_load_all((ROOT / '.maestro/flows' / name).read_text()))[1]


class MobileConfigurationTests(unittest.TestCase):
    def test_guide_pending_heading_matches_native_merged_card(self):
        flow = commands('01-umre-girisleri.yaml')
        selector = next(c['assertVisible'] for c in flow if isinstance(c, dict)
                        and 'assertVisible' in c and 'İçerik hazırlanıyor' in c['assertVisible'])
        self.assertIsNotNone(re.fullmatch(selector, 'İçerik hazırlanıyor\nBu başlığın kaynaklı açıklaması ve dinî incelemesi henüz tamamlanmadı.'))
        self.assertIsNone(re.fullmatch(selector, 'İçerik onaylandı'))

    def test_group_pending_heading_matches_native_merged_card(self):
        flow = commands('04-kapali-servisler.yaml')
        selector = next(c['assertVisible'] for c in flow if isinstance(c, dict)
                        and 'assertVisible' in c and 'Kafile hizmeti hazırlanıyor' in c['assertVisible'])
        self.assertIsNotNone(re.fullmatch(selector, 'Kafile hizmeti hazırlanıyor\nDavet, sohbet ve gezi programı bağlantı kurulunca açılacak.'))
        self.assertIsNone(re.fullmatch(selector, 'Kafilem'))

    def test_guide_flow_shows_honest_missing_audio_state(self):
        flow = commands('03-rehber-ses-durumu.yaml')
        self.assertIn({'assertVisible': 'Bu başlık için onaylı ses kaydı henüz yok.'}, flow)
        self.assertIn({'scrollUntilVisible': {
            'element': '(?s)Umreye hazırlanıyorum.*', 'direction': 'UP'}}, flow)
        self.assertFalse(any('Demo' in str(command) or 'Teknik örnek' in str(command)
                             for command in flow))

    def test_bundled_font_license_has_native_route(self):
        flow = commands('06-lisans-kaynak.yaml')
        self.assertIn({'assertVisible': 'Uygulamaya gömülü yazı tipleri'}, flow)
        self.assertIn({'assertVisible': 'Noto Sans lisansı'}, flow)

    def test_real_catalog_card_matches_native_merged_metadata(self):
        flow = commands('04-kapali-servisler.yaml')
        selector = next(c['assertVisible'] for c in flow if isinstance(c, dict) and 'assertVisible' in c and 'Mekke ve Medine yerleri' in c['assertVisible'])
        self.assertIsNotNone(re.fullmatch(selector, 'Mekke ve Medine yerleri\nGezi ve rotalar · 1.0.0 · 1.1 MB'))
        self.assertIsNone(re.fullmatch(selector, 'Başka bir paket'))

    def test_sdk_match_does_not_choose_newer_incompatible_runtime(self):
        def runtime(version, available=True):
            return {'version': version, 'isAvailable': available,
                    'identifier': 'com.apple.CoreSimulator.SimRuntime.iOS-' + version.replace('.', '-')}
        selected = select_runtime([runtime('26.2'), runtime('18.5'), runtime('18.5.1', False)], '18.5')
        self.assertEqual(selected['version'], '18.5')

    def test_missing_matching_runtime_is_explicit_failure(self):
        with self.assertRaisesRegex(RuntimeError, 'matching selected simulator SDK 18.5'):
            select_runtime([{'version': '26.2', 'isAvailable': True,
                             'identifier': 'com.apple.CoreSimulator.SimRuntime.iOS-26-2'}], '18.5')


if __name__ == '__main__':
    unittest.main()

class ExtendedCoverageTests(unittest.TestCase):
    def test_optional_practice_is_in_the_measured_suite(self):
        flow = commands('05-prova.yaml')
        self.assertIn({'tapOn': 'Kaldığım provadan devam et'}, flow)
        selector = next(c['assertVisible'] for c in flow if isinstance(c, dict)
                        and 'assertVisible' in c and 'Kullanım biçimi seçimi' in c['assertVisible'])
        self.assertIsNotNone(re.fullmatch(selector, 'Kullanım biçimi seçimi'))
        self.assertIsNotNone(re.fullmatch(selector, '1 / 18 · U01\nKullanım biçimi seçimi\nBu aşama için görsel şema bulunmuyor.'))
        self.assertIsNone(re.fullmatch(selector, 'Başka bir başlık'))

    def test_audio_suite_requires_position_pause_completion_and_stop(self):
        docs = list(yaml.safe_load_all((ROOT / '.maestro/audio-probe.yaml').read_text()))
        flow = docs[1]
        for label in ('Konum ilerledi', 'Süre alındı', 'Ses duraklatıldı',
                      'Ses tamamlandı', 'Ses durdu'):
            self.assertIn({'assertVisible': label}, flow)


class NativeEnvironmentRegressionTests(unittest.TestCase):
    def test_android_matrix_avoids_observed_api35_pixel_launcher_anr(self):
        workflow = yaml.safe_load((ROOT / '.github/workflows/mvp-checks.yml').read_text())
        job = workflow['jobs']['android-ui']
        self.assertEqual(job['strategy']['matrix']['include'], [
            {'api': 28, 'target': 'google_apis'},
            {'api': 35, 'target': 'default'},
        ])
        runner = next(step for step in job['steps']
                      if step.get('uses') == 'reactivecircus/android-emulator-runner@v2')
        self.assertEqual(runner['with']['target'], '${{ matrix.target }}')

    def test_practice_relaunch_waits_for_restored_home_records(self):
        flow = commands('05-prova.yaml')
        for index, command in enumerate(flow):
            if command == 'launchApp':
                wait = flow[index + 1]['extendedWaitUntil']
                self.assertIsNotNone(re.fullmatch(wait['visible'], 'Nasıl devam etmek istersin?'))
                self.assertIsNone(re.fullmatch(wait['visible'], 'Nasıl devam etmek istersin? Kayıtlar yükleniyor.'))
                self.assertEqual(wait['timeout'], 30000)
