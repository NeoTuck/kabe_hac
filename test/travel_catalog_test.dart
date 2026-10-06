import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hac_umre_sesli_rehber/offline_map_adapter.dart';
import 'package:hac_umre_sesli_rehber/travel_catalog.dart';

Map<String, Object?> testCatalog() => {
  'schemaVersion': 1,
  'dataVersion': 'test-1',
  'points': [
    {
      'id': 'TEST-POI-1',
      'region': 'mecca',
      'nameTr': 'Teknik test noktası',
      'localName': 'Test point',
      'latitude': 0.0,
      'longitude': 0.0,
      'category': 'meetingPoint',
      'sourceTitle': 'Otomatik test fixture',
      'sourceUrl': 'https://example.com/test-fixture',
      'verifiedAt': '2026-10-06T00:00:00Z',
      'isTestData': true,
    },
    {
      'id': 'TEST-POI-2',
      'region': 'mecca',
      'nameTr': 'İkinci teknik nokta',
      'latitude': 0.0,
      'longitude': 0.01,
      'category': 'transport',
      'sourceTitle': 'Otomatik test fixture',
      'sourceUrl': 'https://example.com/test-fixture',
      'verifiedAt': '2026-10-06T00:00:00Z',
      'isTestData': true,
    },
  ],
  'routes': [
    {
      'id': 'TEST-ROUTE-1',
      'region': 'mecca',
      'title': 'Teknik rota',
      'version': '1.0.0',
      'ownerType': 'user',
      'visibility': 'private',
      'moderationStatus': 'draft',
      'stops': [
        {'order': 1, 'title': 'Birinci', 'poiId': 'TEST-POI-1'},
        {'order': 2, 'title': 'İkinci', 'poiId': 'TEST-POI-2'},
      ],
      'geometry': [],
      'sourceTitle': 'Otomatik test fixture',
      'sourceUrl': 'https://example.com/test-fixture',
      'verifiedAt': '2026-10-06T00:00:00Z',
      'isTestData': true,
    },
  ],
};

void main() {
  test('POI ve rota kataloğu kaynaklı teknik fixture ile yüklenir', () {
    final catalog = TravelCatalog.fromJsonText(jsonEncode(testCatalog()));
    expect(catalog.points, hasLength(2));
    expect(catalog.routes.single.hasRouteGeometry, isFalse);
    expect(catalog.searchPoints(query: 'ikinci'), hasLength(1));
    expect(
      catalog.searchPoints(category: PoiCategory.meetingPoint).single.id,
      'TEST-POI-1',
    );
    final distance = straightLineDistanceMeters(
      catalog.points.first.point,
      catalog.points.last.point,
    );
    expect(distance, greaterThan(1000));
    expect(distance, lessThan(1200));
  });

  test('bozuk rota sırası, bilinmeyen POI ve aşırı geometri reddedilir', () {
    final badOrder = testCatalog();
    ((badOrder['routes'] as List).first['stops'] as List)[1]['order'] = 4;
    expect(
      () => TravelCatalog.fromJsonText(jsonEncode(badOrder)),
      throwsA(isA<TravelCatalogFormatException>()),
    );

    final unknownPoi = testCatalog();
    ((unknownPoi['routes'] as List).first['stops'] as List)[1]['poiId'] =
        'TEST-ABSENT';
    expect(
      () => TravelCatalog.fromJsonText(jsonEncode(unknownPoi)),
      throwsA(isA<TravelCatalogFormatException>()),
    );

    final hugeGeometry = testCatalog();
    (hugeGeometry['routes'] as List).first['geometry'] = List.generate(
      5001,
      (_) => {'latitude': 0.0, 'longitude': 0.0},
    );
    expect(
      () => TravelCatalog.fromJsonText(jsonEncode(hugeGeometry)),
      throwsA(isA<TravelCatalogFormatException>()),
    );
  });

  test('harita adaptörü izinsiz ve kamusal OSM offline kaynağını reddeder', () {
    OfflineMapRegionRequest build(Uri style, bool allowed) =>
        OfflineMapRegionRequest(
          regionId: 'test-region',
          styleUri: style,
          attribution: 'Test attribution',
          south: 0,
          west: 0,
          north: 1,
          east: 1,
          minZoom: 8,
          maxZoom: 14,
          providerAllowsOfflineDownload: allowed,
        );

    expect(
      () => build(Uri.parse('https://provider.example/style.json'), false),
      throwsArgumentError,
    );
    expect(
      () => build(Uri.parse('https://tile.openstreetmap.org/style.json'), true),
      throwsArgumentError,
    );
    expect(
      build(Uri.parse('https://provider.example/style.json'), true).regionId,
      'test-region',
    );
  });
}
