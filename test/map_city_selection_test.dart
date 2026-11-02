import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hac_umre_sesli_rehber/local_map_repository.dart';
import 'package:hac_umre_sesli_rehber/offline_city_map_screen.dart';
import 'package:hac_umre_sesli_rehber/offline_package.dart';
import 'package:hac_umre_sesli_rehber/travel_catalog.dart';

class _TwoCityMaps extends LocalMapRepository {
  _TwoCityMaps(super.packages);

  String? openedPackage;

  @override
  Future<List<LocalMapDescriptor>> list() async => [
    for (final region in [TravelRegion.mecca, TravelRegion.medina])
      LocalMapDescriptor(
        packageId: 'map-${region.name}',
        region: region,
        version: '1',
        attribution: 'Test',
        sourceUri: Uri.https('example.com'),
        licenseUri: Uri.https('example.com', '/license'),
        snapshotAt: DateTime.utc(2026, 10, 1),
        featureFile: 'map.geojson.gz',
        west: 39,
        south: 20,
        east: 41,
        north: 25,
      ),
  ];

  @override
  Future<String> loadStyle(
    LocalMapDescriptor map,
    List<TravelPoi> points,
  ) async {
    openedPackage = map.packageId;
    throw const FormatException('Widget test has no native map');
  }
}

void main() {
  testWidgets('iki harita kuruluysa şehir seçilmeden Mekke açılmaz', (
    tester,
  ) async {
    final packages = OfflinePackageManager(root: Directory('unused-map-test'));
    final maps = _TwoCityMaps(packages);
    await tester.pumpWidget(
      MaterialApp(
        home: OfflineCityMapScreen(
          packages: packages,
          mapRepository: maps,
          catalog: const TravelCatalog(
            dataVersion: 'empty',
            points: [],
            routes: [],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(maps.openedPackage, isNull);
    expect(
      find.text('Görüntülemek istediğin şehri yukarıdan seç.'),
      findsOneWidget,
    );

    await tester.tap(find.byType(DropdownButton<LocalMapDescriptor>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Medine').last);
    await tester.pumpAndSettle();
    expect(maps.openedPackage, 'map-medina');
  });
}
