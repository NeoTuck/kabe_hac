import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hac_umre_sesli_rehber/content_repository.dart';
import 'package:hac_umre_sesli_rehber/guide_catalog.dart';
import 'package:hac_umre_sesli_rehber/guide_screens.dart';
import 'package:hac_umre_sesli_rehber/main.dart';
import 'package:hac_umre_sesli_rehber/reader_settings.dart';
import 'package:hac_umre_sesli_rehber/progress_store.dart';

import 'test_fakes.dart';

class DelayedHomeStore extends MemoryGuideStore {
  final pending = Completer<GuideSession?>();

  @override
  Future<GuideSession?> readMostRecentSession() => pending.future;
}

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
    expect(
      find.textContaining('Umre içeriği henüz incelemede'),
      findsOneWidget,
    );
    expect(
      find.text('Taslak başlıkları ve sayaçları kişisel olarak takip et'),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(find.text('Umre'), 200);
    await tester.ensureVisible(find.text('Umre'));
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
    await tester.scrollUntilVisible(
      find.textContaining('Kaldığım yerden devam'),
      -200,
    );
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
    await tester.scrollUntilVisible(find.text('Hac'), 180);
    await tester.ensureVisible(find.text('Hac'));
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

  testWidgets('eski demo kaydı ana ekranda giriş oluşturmaz', (tester) async {
    final store = MemoryGuideStore();
    await store.saveLastStepId('DEMO-001');
    final narration = FakeNarration();
    final app = SesliRehberApp(
      store: store,
      catalogs: catalogs,
      narration: narration,
      settings: ReaderSettings(store, narration),
    );
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, -1500));
    await tester.pumpAndSettle();
    expect(find.text('Teknik deneme'), findsNothing);
    expect(find.text('Ses örneğine kaldığım yerden devam'), findsNothing);
    expect(find.text('Ses ve Arapça örnek kartını aç'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
    expect(await store.readLastStepId(), 'DEMO-001');
    await tester.drag(find.byType(ListView).first, const Offset(0, -1500));
    await tester.pumpAndSettle();
    expect(find.text('Teknik deneme'), findsNothing);
  });
  testWidgets('ana ekran kayıt yükleme durumu erişilebilir ve sınırlıdır', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final store = DelayedHomeStore();
    final narration = FakeNarration();
    await tester.pumpWidget(
      SesliRehberApp(
        store: store,
        catalogs: catalogs,
        narration: narration,
        settings: ReaderSettings(store, narration),
      ),
    );
    await tester.pump();
    expect(
      find.bySemanticsLabel('Nasıl devam etmek istersin? Kayıtlar yükleniyor.'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Nasıl devam etmek istersin?'), findsNothing);
    store.pending.complete(null);
    await tester.pumpAndSettle();
    expect(
      find.bySemanticsLabel('Nasıl devam etmek istersin?'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Nasıl devam etmek istersin? Kayıtlar yükleniyor.'),
      findsNothing,
    );
    semantics.dispose();
  });
}
