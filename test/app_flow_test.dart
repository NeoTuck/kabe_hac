import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hac_umre_sesli_rehber/content_repository.dart';
import 'package:hac_umre_sesli_rehber/guide_catalog.dart';
import 'package:hac_umre_sesli_rehber/guide_screens.dart';
import 'package:hac_umre_sesli_rehber/main.dart';
import 'package:hac_umre_sesli_rehber/reader_settings.dart';

import 'test_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Map<GuideType, GuideCatalog> catalogs;
  setUpAll(() async {
    catalogs = await const LocalContentRepository().load();
  });

  testWidgets('ana sayfa seçimi, ayrıntı ve son adıma dönüş', (tester) async {
    final store = MemoryGuideStore();
    final narration = FakeNarration();
    await tester.pumpWidget(
      SesliRehberApp(
        store: store,
        catalogs: catalogs,
        narration: narration,
        settings: ReaderSettings(store, narration),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Umre'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Öğrenme'));
    await tester.pumpAndSettle();
    expect(find.text('Adımlar · 0/18 işaretli'), findsOneWidget);
    await tester.tap(find.text('Kullanım biçimi seçimi').first);
    await tester.pumpAndSettle();
    expect(find.byType(GuideStepScreen), findsOneWidget);
    expect(find.text('U01 · 1 / 18'), findsOneWidget);
    await tester.ensureVisible(find.text('Sonraki başlık'));
    await tester.tap(find.text('Sonraki başlık'));
    await tester.pumpAndSettle();
    expect(find.text('U01 · 2 / 18'), findsOneWidget);
    expect(store.sessions.values.single.currentStepId, 'U01.2');
    Navigator.of(tester.element(find.byType(GuideStepScreen))).pop();
    await tester.pumpAndSettle();
    expect(find.text('Kaldığım başlığa git'), findsOneWidget);
    await tester.tap(find.text('Kaldığım başlığa git'));
    await tester.pumpAndSettle();
    expect(find.text('U01 · 2 / 18'), findsOneWidget);
    Navigator.of(tester.element(find.byType(GuideStepScreen))).pop();
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.byType(GuideFlowScreen))).pop();
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.text('Öğrenme'))).pop();
    await tester.pumpAndSettle();
    expect(find.textContaining('Kaldığım yerden devam'), findsOneWidget);
  });

  testWidgets('Hac türü doğrulanmamış önizleme açar', (tester) async {
    final store = MemoryGuideStore();
    final narration = FakeNarration();
    await tester.pumpWidget(
      SesliRehberApp(
        store: store,
        catalogs: catalogs,
        narration: narration,
        settings: ReaderSettings(store, narration),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hac'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Öğrenme'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('İfrad'));
    await tester.pumpAndSettle();
    expect(find.text('Başlık envanteri · 35'), findsOneWidget);
    await tester.tap(find.text('Hac türü ve profil seçimi').first);
    await tester.pumpAndSettle();
    expect(
      find.textContaining('uygulanabilirliği ve açıklaması henüz doğrulanmadı'),
      findsOneWidget,
    );
    expect(find.text('Kişisel ilerleme olarak işaretle'), findsNothing);
    expect(store.sessions.values.single.profile, HajjProfile.ifrad);
  });

  testWidgets('teknik örnek son kart kaydı yeniden okunur', (tester) async {
    final store = MemoryGuideStore();
    final narration = FakeNarration();
    final app = SesliRehberApp(
      store: store,
      catalogs: catalogs,
      narration: narration,
      settings: ReaderSettings(store, narration),
    );
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Ses ve Arapça örnek kartını aç'));
    await tester.tap(find.text('Ses ve Arapça örnek kartını aç'));
    await tester.pumpAndSettle();
    expect(await store.readLastStepId(), 'DEMO-001');
    Navigator.of(tester.element(find.text('Teknik örnek kart'))).pop();
    await tester.pumpAndSettle();
    expect(find.text('Ses örneğine kaldığım yerden devam'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
    expect(find.text('Ses örneğine kaldığım yerden devam'), findsOneWidget);
  });
}
