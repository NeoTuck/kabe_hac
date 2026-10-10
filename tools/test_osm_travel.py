import gzip
import json
import math
from pathlib import Path
import unittest

from build_osm_travel import poi, region_at, simplified

ROOT = Path(__file__).resolve().parent.parent


class OsmTravelTests(unittest.TestCase):
    def test_outside_invalid_and_unnamed_points_are_not_invented(self):
        self.assertIsNone(region_at(math.nan, 21.4))
        self.assertIsNone(poi('node', 1, {'amenity': 'pharmacy'}, 39.8, 21.4, '2026-10-08T20:21:06Z'))
        self.assertIsNone(poi('node', 1, {'amenity': 'pharmacy', 'name': 'source'}, 1, 1, '2026-10-08T20:21:06Z'))

    def test_source_name_is_retained_and_unverified_phone_hours_not_imported(self):
        value = poi('node', 12, {'amenity': 'pharmacy', 'name': 'اسم', 'phone': 'unverified',
                              'opening_hours': '24/7'}, 39.8, 21.4, '2026-10-08T20:21:06Z')
        self.assertEqual(value['nameTr'], 'اسم')
        self.assertTrue(value['isSourceSnapshot'])
        self.assertNotIn('phone', value)
        self.assertNotIn('hours', value)

    def test_simplification_retains_endpoints_and_turn(self):
        points = [[0, 0], [1, 0], [2, 0], [2, 1], [2, 2]]
        self.assertEqual(simplified(points, 0.01), [[0, 0], [2, 0], [2, 2]])

    def test_published_real_dataset_identity_limits_and_licenses(self):
        root = ROOT / 'offline_packages/osm-2026-10-08'
        data = json.loads((root / 'travel/content/travel_catalog.v1.json').read_text())
        self.assertEqual(len(data['points']), 2928)
        self.assertEqual(len({p['id'] for p in data['points']}), 2928)
        self.assertTrue(all(p['isSourceSnapshot'] and not p['isTestData'] for p in data['points']))
        self.assertEqual(data['routes'], [])
        for name, count in (('mecca', 40971), ('medina', 30291)):
            folder = root / ('map-' + name)
            archive = (folder / 'features.geojson.gz').read_bytes()
            raw = gzip.decompress(archive)
            self.assertLess(len(archive), 6 * 1024 * 1024)
            self.assertLess(len(raw), 24 * 1024 * 1024)
            geometry = json.loads(raw)
            self.assertEqual(len(geometry['features']), count)
            self.assertIn('OpenStreetMap', json.loads((folder / 'source-license.json').read_text())['attribution'])
            self.assertGreater((folder / 'LICENSE-ODbL-1.0.txt').stat().st_size, 20000)

