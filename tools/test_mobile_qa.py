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
        self.assertFalse(any('Demo' in str(command) or 'Teknik örnek' in str(command)
                             for command in flow))

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
