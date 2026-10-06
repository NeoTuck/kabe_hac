import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hac_umre_sesli_rehber/travel_catalog.dart';
import 'package:hac_umre_sesli_rehber/travel_screen.dart';

import 'test_fakes.dart';

void main() {
  testWidgets('gezi ekranı test verisini etiketler, arar ve favoriler', (
    tester,
  ) async {
    final catalog = TravelCatalog.fromJsonText(
      jsonEncode({
        'schemaVersion': 1,
        'dataVersion': 'test-1',
        'points': [
          {
            'id': 'TEST-POI-1',
            'region': 'mecca',
            'nameTr': 'Teknik buluşma noktası',
            'latitude': 0.0,
            'longitude': 0.0,
            'category': 'meetingPoint',
            'sourceTitle': 'Otomatik test fixture',
            'sourceUrl': 'https://example.com/test-fixture',
            'verifiedAt': '2026-10-06T00:00:00Z',
            'isTestData': true,
          },
        ],
        'routes': [],
      }),
    );
    final store = MemoryGuideStore();
    await tester.pumpWidget(
      MaterialApp(
        home: TravelScreen(store: store, catalog: catalog),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('TEKNİK TEST VERİSİ'), findsOneWidget);
    await tester.tap(find.byTooltip('Favoriye ekle'));
    await tester.pumpAndSettle();
    expect(store.travelFavorites['poi'], {'TEST-POI-1'});
    expect(find.byTooltip('Favoriden çıkar'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'olmayan');
    await tester.pump();
    expect(find.text('Arama ölçütlerine uyan yer yok.'), findsOneWidget);
  });
}
