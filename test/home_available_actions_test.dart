import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hac_umre_sesli_rehber/guide_catalog.dart';
import 'package:hac_umre_sesli_rehber/main.dart';
import 'package:hac_umre_sesli_rehber/reader_settings.dart';
import 'package:hac_umre_sesli_rehber/safety_repository.dart';
import 'package:hac_umre_sesli_rehber/safety_screen.dart';
import 'package:hac_umre_sesli_rehber/travel_catalog.dart';
import 'package:hac_umre_sesli_rehber/travel_screen.dart';

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

    expect(find.text('Yolculuk araçları'), findsOneWidget);
    expect(find.text('Rehber seç'), findsNothing);
    expect(find.text('Şu an kullanabileceklerin'), findsOneWidget);
    expect(find.text('Harita, yerler ve rotalar'), findsNothing);

    await tester.ensureVisible(find.text('Yardım ve önemli numaralar'));
    await tester.tap(find.text('Yardım ve önemli numaralar'));
    await tester.pumpAndSettle();
    expect(find.byType(SafetyScreen), findsOneWidget);

    Navigator.of(tester.element(find.byType(SafetyScreen))).pop();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Yerleri ve favorileri aç'));
    await tester.tap(find.text('Yerleri ve favorileri aç'));
    await tester.pumpAndSettle();
    expect(find.byType(TravelScreen), findsOneWidget);
  });
}
