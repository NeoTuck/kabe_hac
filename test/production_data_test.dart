import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hac_umre_sesli_rehber/local_map_repository.dart';
import 'package:hac_umre_sesli_rehber/offline_package.dart';
import 'package:hac_umre_sesli_rehber/package_catalog.dart';
import 'package:hac_umre_sesli_rehber/safety_catalog.dart';
import 'package:hac_umre_sesli_rehber/travel_catalog.dart';

Map<String, Object?> jsonFile(String file) =>
    Map<String, Object?>.from(jsonDecode(File(file).readAsStringSync()) as Map);
const snapshot = 'offline_packages/osm-2026-10-08';

void main() {
  test(
    'actual city packages install, decompress and reject damaged geometry',
    () async {
      final root = await Directory.systemTemp.createTemp('actual-map-');
      addTearDown(() => root.delete(recursive: true));
      final config = OfflinePackageRuntimeConfig.fromJson(
        jsonFile('assets/content/package_defaults.v1.json'),
      );
      final manager = OfflinePackageManager(
        root: root,
        trustPolicy: PinnedManifestDigestPolicy(config.trustedManifestDigests),
      );
      final raw = jsonFile('$snapshot/catalog.v1.json');
      for (final item in (raw['packages'] as List).where(
        (v) => v['kind'] == 'map',
      )) {
        final manifest = OfflinePackageManifest.fromJson(
          Map<String, Object?>.from(item as Map),
        );
        final staging = await manager.createStagingDirectory(manifest);
        for (final entry in manifest.files) {
          final target = File('${staging.path}/${entry.relativePath}');
          await target.parent.create(recursive: true);
          await File('$snapshot/${manifest.packageId}/${entry.relativePath}')
              .copy(target.path);
        }
        await manager.activate(manifest, staging);
      }
      final repository = LocalMapRepository(manager);
      final maps = await repository.list();
      expect(maps.length, 2);
      for (final map in maps) {
        final geometry = await repository.load(map);
        final nearby = (geometry['features'] as List).where((feature) {
          final g = feature['geometry'];
          final coordinates = g['type'] == 'Polygon'
              ? g['coordinates'][0]
              : g['coordinates'];
          final first = coordinates[0] as List;
          return ((first[0] as num) - map.centerLongitude).abs() < 0.015 &&
              ((first[1] as num) - map.centerLatitude).abs() < 0.015;
        });
        expect(nearby.length, greaterThan(100));
        expect(
          (geometry['features'] as List).length,
          map.region == TravelRegion.mecca ? 40971 : 30291,
        );
      }
      final map = maps.first;
      final file = await manager.resolveActiveFile(
        map.packageId,
        map.featureFile,
        kind: OfflinePackageKind.map,
      );
      await file!.writeAsBytes([0, 1, 2]);
      await expectLater(repository.load(map), throwsA(isA<Exception>()));
    },
  );

  test('actual packages parse and match every bundled trust pin', () {
    final config = OfflinePackageRuntimeConfig.fromJson(
      jsonFile('assets/content/package_defaults.v1.json'),
    );
    final catalog = jsonFile('$snapshot/catalog.v1.json');
    final manifests = (catalog['packages'] as List)
        .map(
          (v) => OfflinePackageManifest.fromJson(
            Map<String, Object?>.from(v as Map),
          ),
        )
        .toList();
    expect(manifests.length, 3);
    expect(
      manifests.map(PinnedManifestDigestPolicy.digestFor).toSet(),
      config.trustedManifestDigests,
    );
    for (final manifest in manifests) {
      for (final file in manifest.files) {
        expect(
          file.downloadUri!.path,
          contains('/fed9f97861081f67cb5844598667347787f96502/'),
        );
      }
    }
  });

  test('untrusted catalog settings cannot enable downloads', () {
    final config = jsonFile('assets/content/package_defaults.v1.json');
    for (final change in [
      {'catalogUrl': 'http://raw.githubusercontent.com/catalog'},
      {
        'allowedHosts': ['other.test'],
      },
      {
        'trustedManifestDigests': ['not-a-digest'],
      },
    ]) {
      expect(
        () => OfflinePackageRuntimeConfig.fromJson({...config, ...change}),
        throwsA(isA<PackageCatalogException>()),
      );
    }
  });

  test('real OSM places remain source snapshots with unique IDs', () {
    final catalog = TravelCatalog.fromJsonText(
      File('$snapshot/travel/content/travel_catalog.v1.json')
          .readAsStringSync(),
    );
    expect(catalog.points.length, 2928);
    expect(catalog.points.map((p) => p.id).toSet().length, 2928);
    expect(
      catalog.points.every((p) => p.isSourceSnapshot && !p.isTestData),
      isTrue,
    );
    expect(catalog.routes, isEmpty);
  });

  test(
    'both actual map descriptors reject path escape and reversed bounds',
    () {
      for (final city in ['mecca', 'medina']) {
        final raw = jsonFile('$snapshot/map-$city/map/catalog.v1.json');
        final descriptor = LocalMapDescriptor.parse(
          'map-$city',
          jsonEncode(raw),
        );
        expect(descriptor.west, lessThan(descriptor.east));
        expect(
          () => LocalMapDescriptor.parse(
            'map-$city',
            jsonEncode({...raw, 'featureFile': '../features.geojson.gz'}),
          ),
          throwsFormatException,
        );
        expect(
          () => LocalMapDescriptor.parse(
            'map-$city',
            jsonEncode({
              ...raw,
              'bounds': {'west': 40, 'east': 39, 'south': 21, 'north': 22},
            }),
          ),
          throwsFormatException,
        );
      }
    },
  );

  test('native map style needs no tile, glyph, sprite or remote source', () {
    final style = localMapStyle({
      'type': 'FeatureCollection',
      'features': <Object>[],
    }, []);
    expect(style['glyphs'], isNull);
    expect(style['sprite'], isNull);
    for (final source in (style['sources'] as Map).values) {
      expect(source['type'], 'geojson');
      expect(source['data'], isA<Map>());
      expect(source['url'], isNull);
      expect(source['tiles'], isNull);
    }
    expect(
      (style['layers'] as List).any(
        (layer) => layer['type'] == 'fill-extrusion',
      ),
      isFalse,
    );
  });

  test(
    'official contact facts do not imply human religious or Arabic approval',
    () {
      final raw = jsonFile('assets/content/safety_catalog.v1.json');
      final catalog = SafetyCatalog.fromJsonText(jsonEncode(raw));
      expect(catalog.contacts.length, 6);
      expect(catalog.languageCards, isEmpty);
      final contact = Map<String, Object?>.from(
        (raw['contacts'] as List).first as Map,
      );
      for (final change in [
        {'sourceUrl': 'https://mfa.gov.tr.attacker.test/phone'},
        {'verifiedAt': '2099-01-01T00:00:00Z'},
        {'phone': '911;malformed'},
      ]) {
        expect(
          () => SafetyCatalog.fromJsonText(
            jsonEncode({
              ...raw,
              'contacts': [
                {...contact, ...change},
              ],
            }),
          ),
          throwsA(isA<SafetyCatalogFormatException>()),
        );
      }
    },
  );
}
