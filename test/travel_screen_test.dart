import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hac_umre_sesli_rehber/travel_catalog.dart';
import 'package:hac_umre_sesli_rehber/travel_screen.dart';
import 'package:hac_umre_sesli_rehber/travel_details.dart';

import 'test_fakes.dart';

TravelCatalog fixture() => TravelCatalog.fromJsonText(
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

class SlowFavoritesStore extends MemoryGuideStore {
  final gate = Completer<void>();
  int calls = 0;
  @override
  Future<void> setTravelFavorite(String type, String id, bool favorite) async {
    calls++;
    await gate.future;
    await super.setTravelFavorite(type, id, favorite);
  }
}

void main() {
  testWidgets('gezi ekranı test verisini etiketler, arar ve favoriler', (
    tester,
  ) async {
    final catalog = fixture();
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
  testWidgets(
    'favorite save is single flight and filter reflects saved state',
    (tester) async {
      final store = SlowFavoritesStore();
      await tester.pumpWidget(
        MaterialApp(
          home: TravelScreen(store: store, catalog: fixture()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Favoriye ekle'));
      await tester.pump();
      await tester.tap(find.byTooltip('Favoriye ekle'));
      expect(store.calls, 1);
      store.gate.complete();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Yalnız favoriler'));
      await tester.pumpAndSettle();
      expect(find.text('Teknik buluşma noktası'), findsOneWidget);
      await tester.tap(find.byTooltip('Favoriden çıkar'));
      await tester.pumpAndSettle();
      expect(find.text('Arama ölçütlerine uyan yer yok.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  test('Türkçe arama işaret ve büyük harf farklarını tolere eder', () {
    final catalog = fixture();
    expect(catalog.searchPoints(query: 'BULUSMA').length, 1);
    expect(catalog.searchPoints(query: 'buluşma').length, 1);
    expect(catalog.searchPoints(query: 'noktasI').length, 1);
  });

  testWidgets('yer ayrıntısı kayıt ve kaynak bilgisini çevrimdışı gösterir', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TravelScreen(store: MemoryGuideStore(), catalog: fixture()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Teknik buluşma noktası'));
    await tester.pumpAndSettle();
    expect(find.byType(TravelPoiScreen), findsOneWidget);
    expect(find.text('0.000000, 0.000000'), findsOneWidget);
    await tester.tap(find.text('Kaynak ve güncellik'));
    await tester.pumpAndSettle();
    expect(find.text('https://example.com/test-fixture'), findsOneWidget);
  });

  testWidgets('rota durakları sırayla açılır ve POI ayrıntısına gider', (
    tester,
  ) async {
    final catalog = fixture();
    final route = TravelRoute(
      id: 'TEST-ROUTE',
      region: TravelRegion.mecca,
      title: 'Teknik test rotası',
      version: '1.0.0',
      ownerType: RouteOwnerType.user,
      visibility: RouteVisibility.private,
      moderationStatus: RouteModerationStatus.draft,
      stops: const [
        RouteStop(
          order: 1,
          title: 'Birinci test durağı',
          poiId: 'TEST-POI-1',
          point: null,
        ),
        RouteStop(
          order: 2,
          title: 'İkinci test durağı',
          poiId: null,
          point: GeoPoint(1, 2),
        ),
      ],
      geometry: const [],
      sourceTitle: 'Teknik fixture',
      sourceUri: Uri.parse('https://example.com/test'),
      verifiedAt: DateTime.utc(2026, 10, 8),
      isTestData: true,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: TravelRouteScreen(route: route, catalog: catalog),
      ),
    );
    expect(find.text('Birinci test durağı'), findsOneWidget);
    expect(find.text('İkinci test durağı'), findsOneWidget);
    expect(find.text('Bu rota yayın onayından geçmemiştir.'), findsOneWidget);
    await tester.tap(find.text('Birinci test durağı'));
    await tester.pumpAndSettle();
    expect(find.byType(TravelPoiScreen), findsOneWidget);
  });

  testWidgets('yer ayrıntısı küçük ekranda yüzde 200 yazıyı taşırmaz', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: TravelPoiScreen(point: fixture().points.single),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Kaynak ve güncellik'), 200);
    await tester.tap(find.text('Kaynak ve güncellik'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
