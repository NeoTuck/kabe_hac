import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hac_umre_sesli_rehber/guide_catalog.dart';
import 'package:hac_umre_sesli_rehber/main.dart';
import 'package:hac_umre_sesli_rehber/reader_settings.dart';
import 'package:hac_umre_sesli_rehber/prayer_times_widget.dart';
import 'package:hac_umre_sesli_rehber/safety_repository.dart';
import 'package:hac_umre_sesli_rehber/safety_screen.dart';
import 'package:hac_umre_sesli_rehber/travel_catalog.dart';
import 'package:hac_umre_sesli_rehber/route_studio_screen.dart';

import 'test_fakes.dart';

void main() {
  testWidgets('boş rehberde kullanılabilir araçlar doğrudan açılır', (
    tester,
  ) async {
    final store = MemoryGuideStore();
    final narration = FakeNarration();
    final settings = ReaderSettings(store, narration);
    addTearDown(() {
      settings.dispose();
      narration.dispose();
    });
    await tester.pumpWidget(
      SesliRehberApp(
        initialEnteredMainScreen: true,
        store: store,
        catalogs: {
          for (final type in GuideType.values)
            type: GuideCatalog.unavailable(type),
        },
        narration: narration,
        settings: settings,
        safetyCatalog: await const LocalSafetyRepository().load(),
        travelCatalog: const TravelCatalog(
          dataVersion: 'empty',
          points: [],
          routes: [],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(PrayerTimesCard), findsOneWidget);
    expect(find.text('Mekke-i Mükerreme'), findsOneWidget);
    expect(find.text('Umre Eğitimi'), findsOneWidget);
    expect(find.text('Yardım ve önemli numaralar'), findsOneWidget);
    expect(find.text('Kıble pusulası'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Umre duaları'), 200);
    expect(find.text('Umre duaları'), findsOneWidget);

    await tester.tap(find.text('Yardım ve önemli numaralar'));
    await tester.pumpAndSettle();
    expect(find.byType(SafetyScreen), findsOneWidget);

    Navigator.of(tester.element(find.byType(SafetyScreen))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rota, Harita'));
    await tester.pumpAndSettle();
    expect(find.byType(RouteStudioScreen), findsOneWidget);
  });
}
