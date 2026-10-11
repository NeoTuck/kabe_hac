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

    def test_guide_flow_shows_honest_draft_audio_state(self):
        flow = commands('03-rehber-ses-durumu.yaml')
        self.assertIn({'assertVisible':
                       'Sentetik taslak kayıt. Dinî, dil ve kullanım hakkı incelemesi tamamlanmadı.'}, flow)
        self.assertIn({'scrollUntilVisible': {
            'element': '(?s)Umre.*18 başlık.*', 'direction': 'DOWN'}}, flow)
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
            {'api': 28, 'target': 'google_apis', 'page_size': 4096,
             'qa_stage': 'full', 'ram_size': '2048M',
             'artifact_name': 'android-ui-api-28'},
            {'api': 35, 'target': 'default', 'page_size': 4096,
             'qa_stage': 'full', 'ram_size': '2048M',
             'artifact_name': 'android-ui-api-35'},
            {'api': 36, 'target': 'google_apis_ps16k', 'page_size': 16384,
             'qa_stage': 'optimized-ui', 'ram_size': '4096M',
             'artifact_name': 'android-ui-api-36-optimized-ui'},
            {'api': 36, 'target': 'google_apis_ps16k', 'page_size': 16384,
             'qa_stage': 'debug-audio', 'ram_size': '4096M',
             'artifact_name': 'android-ui-api-36-debug-audio'},
        ])
        runner = next(step for step in job['steps']
                      if step.get('uses') == 'reactivecircus/android-emulator-runner@v2')
        self.assertEqual(runner['with']['target'], '${{ matrix.target }}')
        self.assertEqual(runner['with']['ram-size'], '${{ matrix.ram_size }}')

    def test_practice_relaunch_waits_for_restored_home_records(self):
        flow = commands('05-prova.yaml')
        self.assertEqual(flow.count('launchApp'), 2)
        for index, command in enumerate(flow):
            if command == 'launchApp':
                wait = flow[index + 1]['extendedWaitUntil']
                self.assertIsNotNone(re.fullmatch(wait['visible'], 'Rehbere başla'))
                self.assertIsNone(re.fullmatch(wait['visible'], 'Rehbere başla. Kayıtlar yükleniyor.'))
                self.assertEqual(wait['timeout'], 30000)


class StoreSdkCoverageTests(unittest.TestCase):
    def test_ios_keeps_older_runtime_and_adds_store_eligible_sdk(self):
        workflow = yaml.safe_load((ROOT / '.github/workflows/mvp-checks.yml').read_text())
        job = workflow['jobs']['ios']
        self.assertEqual(job['strategy']['matrix']['xcode'], ['16.4', '26.2'])
        steps = job['steps']
        selector = next(step for step in steps
                        if step.get('uses') == 'maxim-lobanov/setup-xcode@v1')
        self.assertEqual(selector['with']['xcode-version'], '${{ matrix.xcode }}')
        builds = [step.get('run') for step in steps]
        self.assertIn('flutter build ios --debug --no-codesign', builds)
        self.assertIn('flutter build ios --simulator --debug', builds)
        release = next(step for step in steps if step.get('run') == 'flutter build ios --release --no-codesign')
        self.assertEqual(release['if'], "matrix.xcode == '26.2'")
        self.assertIn('python3 tools/run_ci_ios_qa.py', builds)
        artifact = next(step for step in steps if step.get('uses') == 'actions/upload-artifact@v4')
        self.assertEqual(artifact['with']['name'], 'ios-simulator-ui-${{ matrix.xcode }}')


class NativeFailureEvidenceTests(unittest.TestCase):
    def test_real_place_package_follows_sorted_map_packages(self):
        flow = commands('07-gercek-offline-harita.yaml')
        scroll = next(c['scrollUntilVisible'] for c in flow
                      if isinstance(c, dict) and
                      c.get('scrollUntilVisible', {}).get('element') == 'Yer kayıtlarını indir')
        self.assertEqual(scroll['direction'], 'DOWN')
        self.assertIn({'assertVisible': '(?s)[1-9][0-9]* yer · Eczane.*'}, flow)

    def test_audio_driver_does_not_wait_out_short_recording_before_pause(self):
        flow = commands('03-rehber-ses-durumu.yaml')
        for label in ('Anlatımı dinle', 'Duraklat', 'Devam et', '10 sn ileri', '10 sn geri'):
            taps = [c['tapOn'] for c in flow if isinstance(c, dict) and 'tapOn' in c
                    and (c['tapOn'] == label or isinstance(c['tapOn'], dict)
                         and c['tapOn'].get('text') == label)]
            self.assertTrue(taps)
            for tap in taps:
                self.assertIsInstance(tap, dict)
                self.assertLessEqual(tap['waitToSettleTimeoutMs'], 500)
        paused = flow.index({'assertVisible': 'Ses duraklatıldı'})
        self.assertEqual(flow[paused - 1], {'scrollUntilVisible': {
            'element': 'Ses duraklatıldı', 'direction': 'DOWN'}})

    def test_preparation_and_profile_wait_for_home_without_tapping_guide_selector(self):
        for name in ('08-hazirlik.yaml', '09-hac-profil-kaydi.yaml'):
            flow = commands(name)
            self.assertNotIn({'tapOn': '(?s)Rehber.*'}, flow)
            for index, command in enumerate(flow):
                if command == 'launchApp':
                    self.assertEqual(flow[index + 1], {'extendedWaitUntil': {
                        'visible': 'Rehbere başla', 'timeout': 30000}})
        profile = commands('09-hac-profil-kaydi.yaml')
        self.assertIn({'assertNotVisible': 'Kişisel ilerleme olarak işaretle'}, profile)
        self.assertIn({'assertVisible': '(?s).*Kıran.*'}, profile)


class ShortNarrationResumeTests(unittest.TestCase):
    def test_resume_restores_full_remaining_duration_without_extending_audio(self):
        flow = commands('03-rehber-ses-durumu.yaml')
        paused = flow.index({'assertVisible': 'Ses duraklatıldı'})
        resumed = next(i for i, c in enumerate(flow) if isinstance(c, dict)
                       and isinstance(c.get('tapOn'), dict) and c['tapOn'].get('text') == 'Devam et')
        rewinds = [c for c in flow[paused:resumed] if isinstance(c, dict)
                   and isinstance(c.get('tapOn'), dict) and c['tapOn'].get('text') == '10 sn geri']
        self.assertEqual(len(rewinds), 2)
        self.assertIn({'assertVisible': '(?s).*0:00 / [0-9]+:[0-9]{2}.*'}, flow[paused:resumed])
        self.assertIn({'assertVisible': 'Duraklat'}, flow[resumed:])
