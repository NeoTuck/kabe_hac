import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hac_umre_sesli_rehber/map_place_picker.dart';
import 'package:hac_umre_sesli_rehber/travel_catalog.dart';

import 'travel_catalog_test.dart' show testCatalog;

List<TravelPoi> points() {
  final json = testCatalog();
  final rows = json['points'] as List;
  rows.first['nameTr'] = 'Şifa Eczanesi';
  rows.first['localName'] = 'CITY Pharmacy';
  rows.first['category'] = 'pharmacy';
  rows.first['isTestData'] = false;
  rows.last['nameTr'] = 'İkinci Hastane';
  rows.last['category'] = 'hospital';
  rows.last['isTestData'] = false;
  return TravelCatalog.fromJsonText(jsonEncode(json)).points;
}

void main() {
  testWidgets('map search combines Turkish search, category and clear', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: MapPlacePicker(points: points())),
      ),
    );
    await tester.enterText(find.byType(TextField), '  SIFA  ');
    await tester.pump();
    expect(find.text('Şifa Eczanesi'), findsOneWidget);
    expect(find.text('İkinci Hastane'), findsNothing);
    await tester.tap(find.byTooltip('Aramayı temizle'));
    await tester.pump();
    await tester.tap(find.byType(DropdownButtonFormField<PoiCategory>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hastane / sağlık').last);
    await tester.pumpAndSettle();
    expect(find.text('İkinci Hastane'), findsOneWidget);
    expect(find.text('Şifa Eczanesi'), findsNothing);
    await tester.enterText(find.byType(TextField), 'city');
    await tester.pump();
    expect(find.textContaining('Eşleşen yer yok.'), findsOneWidget);
    await tester.tap(find.byTooltip('Aramayı temizle'));
    await tester.pump();
    await tester.tap(find.byType(DropdownButtonFormField<PoiCategory>));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Tüm yerler').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tüm yerler').last);
    await tester.pumpAndSettle();
    expect(find.text('Şifa Eczanesi'), findsOneWidget);
    expect(find.text('İkinci Hastane'), findsOneWidget);
  });

  testWidgets('selected place is returned and test data stays hidden', (
    tester,
  ) async {
    TravelPoi? selected;
    final values = [
      ...points(),
      TravelCatalog.fromJsonText(jsonEncode(testCatalog())).points.first,
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                selected = await showModalBottomSheet<TravelPoi>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => MapPlacePicker(points: values),
                );
              },
              child: const Text('Harita'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Harita'));
    await tester.pumpAndSettle();
    expect(find.text('Teknik test noktası'), findsNothing);
    await tester.tap(find.text('Şifa Eczanesi'));
    await tester.pumpAndSettle();
    expect(selected?.id, 'TEST-POI-1');
  });

  testWidgets('small screen with large text and keyboard remains scrollable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 640),
              viewInsets: EdgeInsets.only(bottom: 280),
              textScaler: TextScaler.linear(2),
            ),
            child: MapPlacePicker(points: points()),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.text('İkinci Hastane'),
      100,
      scrollable: find
          .descendant(
            of: find.byType(CustomScrollView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    expect(find.text('İkinci Hastane'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
