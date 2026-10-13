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

class FailingHomeStore extends MemoryGuideStore {
  bool fail = true;
  @override
  Future<GuideSession?> readMostRecentSession() async {
    if (fail) throw StateError('technical read failure');
    return super.readMostRecentSession();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Map<GuideType, GuideCatalog> catalogs;
  setUpAll(() async {
    catalogs = await const LocalContentRepository().load();
  });

  testWidgets('ilk açılışta Umre öğrenmeye doğrudan başlanır', (tester) async {
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

    expect(find.text('Umreyi öğrenmeye başla'), findsOneWidget);
    await tester.tap(find.text('Umreyi öğrenmeye başla'));
    await tester.pumpAndSettle();
    expect(find.byType(GuideFlowScreen), findsOneWidget);
    expect(find.text('Adımlar · 0/18 işaretli'), findsOneWidget);
    expect(store.sessions.values.single.mode, GuideMode.learning);
    expect(store.sessions.values.single.type, GuideType.umrah);
  });

  testWidgets('Hac devamı profil, adım ve eski kişisel işaretleri korur', (
    tester,
  ) async {
    final store = MemoryGuideStore();
    final catalog = catalogs[GuideType.hajj]!;
    final session = await store.startNewJourney(
      type: GuideType.hajj,
      profile: HajjProfile.kiran,
      firstStepId: 'H02.1',
      contentVersion: catalog.contentVersion,
    );
    await store.setStepMarked(session.id, 'H01.1', true);
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
    expect(find.textContaining('Yolculukta rehber ·'), findsOneWidget);
    expect(
      find.textContaining(catalog.stepById('H02.1')!.title),
      findsOneWidget,
    );
    await tester.tap(find.textContaining('Kaldığım yerden devam'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<GuideFlowScreen>(find.byType(GuideFlowScreen)).profile,
      HajjProfile.kiran,
    );
    expect(store.sessions.length, 1);
    expect(store.sessions[session.id]!.currentStepId, 'H02.1');
    expect(await store.readMarkedStepIds(session.id), {'H01.1'});
  });

  testWidgets('kayıt okuma hatası yeni kullanıcı sayılmaz; kurtarma sunulur', (
    tester,
  ) async {
    final store = FailingHomeStore();
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
    expect(find.text('Umreyi öğrenmeye başla'), findsNothing);
    await tester.scrollUntilVisible(find.text('Kayıtları yeniden oku'), 300);
    store.fail = false;
    await tester.tap(find.text('Kayıtları yeniden oku'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Umreyi öğrenmeye başla'), -300);
    expect(find.text('Umreyi öğrenmeye başla'), findsOneWidget);
    expect(store.sessions, isEmpty);
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
    expect(find.text('Rehber seç'), findsOneWidget);
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
    await tester.scrollUntilVisible(find.text('Sonraki başlık'), 250);
    await tester.ensureVisible(
      find.widgetWithText(FilledButton, 'Sonraki başlık'),
    );
    await tester.pumpAndSettle();
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
      find.bySemanticsLabel('Rehbere başla. Kayıtlar yükleniyor.'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Rehbere başla'), findsNothing);
    expect(find.text('Umreyi öğrenmeye başla'), findsNothing);
    store.pending.complete(null);
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Rehbere başla'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Rehbere başla. Kayıtlar yükleniyor.'),
      findsNothing,
    );
    expect(find.text('Umreyi öğrenmeye başla'), findsOneWidget);
    semantics.dispose();
  });
}
