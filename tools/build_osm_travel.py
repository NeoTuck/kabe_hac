#!/usr/bin/env python3
"""Extract actual OSM snapshots into optional, self-contained city packages.

Requires osmium==4.2.0 for PBF input. Does not scrape public tile servers,
translate names, verify opening hours, or create religious boundaries/routes.
"""
import argparse
import datetime
import gzip
import hashlib
import json
import math
from pathlib import Path

REGIONS = {
    'mecca': (39.65, 21.25, 40.05, 21.55),
    'medina': (39.45, 24.25, 39.80, 24.65),
}
LICENSE_URL = 'https://opendatacommons.org/licenses/odbl/1-0/'
SOURCE_URL = 'https://download.geofabrik.de/asia/gcc-states.html'
ATTRIBUTION = '© OpenStreetMap contributors · ODbL 1.0'


def region_at(lon, lat):
    if not all(math.isfinite(v) for v in (lon, lat)):
        return None
    for region, (west, south, east, north) in REGIONS.items():
        if west <= lon <= east and south <= lat <= north:
            return region
    return None


def category(tags):
    amenity = tags.get('amenity')
    if amenity in ('restaurant', 'cafe', 'fast_food', 'food_court'):
        return 'food'
    if amenity == 'pharmacy':
        return 'pharmacy'
    if amenity in ('hospital', 'clinic', 'doctors'):
        return 'hospital'
    if amenity == 'toilets':
        return 'toilet'
    if amenity == 'police':
        return 'police'
    if amenity in ('bus_station', 'taxi') or tags.get('railway') == 'station':
        return 'transport'
    if tags.get('tourism') in ('hotel', 'hostel', 'guest_house'):
        return 'accommodation'
    if amenity == 'place_of_worship' or tags.get('historic'):
        return 'religiousSite'
    return None


def poi(osm_type, osm_id, tags, lon, lat, snapshot_at):
    region = region_at(lon, lat)
    kind = category(tags)
    # Do not invent a Turkish name or show anonymous amenities as named places.
    name = tags.get('name:tr') or tags.get('name:en') or tags.get('name') or tags.get('name:ar')
    if not region or not kind or not name or len(name) > 200:
        return None
    item = {
        'id': f'OSM-{osm_type.upper()}-{osm_id}', 'region': region,
        'nameTr': name, 'localName': tags.get('name:ar') or tags.get('name'),
        'latitude': round(lat, 6), 'longitude': round(lon, 6),
        'category': kind, 'sourceTitle': 'OpenStreetMap / Geofabrik — kaynak kaydı',
        'sourceUrl': f'https://www.openstreetmap.org/{osm_type}/{osm_id}',
        'verifiedAt': snapshot_at, 'isTestData': False,
        'isSourceSnapshot': True,
    }
    # OSM phone/hours are not independently verified safety data; preserve them
    # only in the attribution/source, not in an actionable contact directory.
    return item


def simplified(points, tolerance=0.000025):
    """Iterative Douglas–Peucker, ~few metres; drawing only, never navigation."""
    if len(points) < 3:
        return points
    keep = {0, len(points) - 1}
    pending = [(0, len(points) - 1)]
    while pending:
        first, last = pending.pop()
        ax, ay = points[first]
        bx, by = points[last]
        dx, dy = bx - ax, by - ay
        length = dx * dx + dy * dy
        maximum, chosen = tolerance * tolerance, None
        for index in range(first + 1, last):
            px, py = points[index]
            t = min(1, max(0, ((px - ax) * dx + (py - ay) * dy) / length)) if length else 0
            distance = (px - ax - t * dx) ** 2 + (py - ay - t * dy) ** 2
            if distance > maximum:
                maximum, chosen = distance, index
        if chosen is not None:
            keep.add(chosen)
            pending.extend(((first, chosen), (chosen, last)))
    return [points[i] for i in sorted(keep)]


def write_json(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, separators=(',', ':')) + '\n')


def extract(source, output, snapshot_at):
    import osmium

    points = []
    features = {name: [] for name in REGIONS}

    class Handler(osmium.SimpleHandler):
        def node(self, node):
            if not node.location.valid():
                return
            item = poi('node', node.id, dict(node.tags), node.location.lon,
                       node.location.lat, snapshot_at)
            if item:
                points.append(item)

        def way(self, way):
            tags = dict(way.tags)
            road = tags.get('highway')
            building = tags.get('building') not in (None, 'no')
            water = tags.get('natural') == 'water'
            if not road and not building and not water and not category(tags):
                return
            coordinates = []
            for node in way.nodes:
                if not node.location.valid():
                    return
                coordinates.append([round(node.location.lon, 6), round(node.location.lat, 6)])
            if len(coordinates) < 2 or len(coordinates) > 10000:
                return
            regions = {region_at(*point) for point in coordinates} - {None}
            if not regions:
                return
            lon = sum(p[0] for p in coordinates) / len(coordinates)
            lat = sum(p[1] for p in coordinates) / len(coordinates)
            item = poi('way', way.id, tags, lon, lat, snapshot_at)
            if item:
                points.append(item)
            if not road and not building and not water:
                return
            closed = coordinates[0] == coordinates[-1] and len(coordinates) >= 4
            if (building or water) and not closed:
                return
            # Small buildings add size and clutter; retain larger outlines.
            if building:
                xs, ys = zip(*coordinates)
                if (max(xs) - min(xs)) * (max(ys) - min(ys)) < 0.00000001:
                    return
            geometry = simplified(coordinates)
            if closed and len(geometry) < 4:
                geometry = coordinates
            feature = {'type': 'Feature', 'id': way.id,
                       'properties': {'kind': 'road' if road else 'water' if water else 'building',
                                      'roadClass': road or ''},
                       'geometry': {'type': 'LineString' if road else 'Polygon',
                                    'coordinates': geometry if road else [geometry]}}
            for region in regions:
                features[region].append(feature)

    Handler().apply_file(str(source), locations=True, idx='flex_mem')
    points.sort(key=lambda item: item['id'])
    with source.open('rb') as handle:
        digest = hashlib.file_digest(handle, 'sha256').hexdigest()
    provenance = {
        'schemaVersion': 1, 'sourceUrl': SOURCE_URL, 'sourceSha256': digest,
        'snapshotAt': snapshot_at, 'license': 'ODbL-1.0', 'licenseUrl': LICENSE_URL,
        'attribution': ATTRIBUTION,
        'limits': 'Community snapshot, not live opening hours, safe navigation or sacred boundaries.',
    }
    travel = output / 'travel'
    write_json(travel / 'content/travel_catalog.v1.json',
               {'schemaVersion': 1, 'dataVersion': 'osm-' + snapshot_at[:10],
                'points': points, 'routes': []})
    write_json(travel / 'source-license.json', provenance)
    for region, values in features.items():
        folder = output / f'map-{region}'
        raw = json.dumps({'type': 'FeatureCollection', 'features': values},
                         ensure_ascii=False, separators=(',', ':')).encode()
        folder.mkdir(parents=True, exist_ok=True)
        (folder / 'features.geojson.gz').write_bytes(gzip.compress(raw, mtime=0))
        west, south, east, north = REGIONS[region]
        write_json(folder / 'map/catalog.v1.json', {
            'schemaVersion': 1, 'region': region, 'dataVersion': 'osm-' + snapshot_at[:10],
            'attribution': ATTRIBUTION, 'licenseUrl': LICENSE_URL,
            'sourceUrl': SOURCE_URL, 'snapshotAt': snapshot_at,
            'featureFile': 'features.geojson.gz', 'featureCount': len(values),
            'bounds': {'west': west, 'south': south, 'east': east, 'north': north},
        })
        write_json(folder / 'source-license.json', provenance)
    return {'points': len(points), 'mapFeatures': {k: len(v) for k, v in features.items()},
            'sourceSha256': digest}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--pbf', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--snapshot-at', required=True)
    args = parser.parse_args()
    date = datetime.datetime.fromisoformat(args.snapshot_at.replace('Z', '+00:00'))
    if date.utcoffset() != datetime.timedelta(0) or date > datetime.datetime.now(datetime.timezone.utc):
        parser.error('Explicit, non-future UTC source snapshot time required')
    if args.output.exists():
        parser.error('Output already exists; never overwrite a published package')
    print(json.dumps(extract(args.pbf, args.output, args.snapshot_at)))


if __name__ == '__main__':
    main()
