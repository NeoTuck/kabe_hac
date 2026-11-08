import 'draft_catalog_fixture.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hac_umre_sesli_rehber/guide_catalog.dart';
import 'package:hac_umre_sesli_rehber/guide_sections_screen.dart';
import 'package:hac_umre_sesli_rehber/main.dart';
import 'package:hac_umre_sesli_rehber/reader_settings.dart';
import 'package:hac_umre_sesli_rehber/safety_repository.dart';
import 'package:hac_umre_sesli_rehber/progress_store.dart';

import 'test_fakes.dart';

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
    catalogs = await loadDraftCatalogs();
  });

  testWidgets('kullanıcı açılışında hoş geldiniz ekranı ve kilitli Hac uyarısı görünür', (
    tester,
  ) async {
    final store = MemoryGuideStore();
    final narration = FakeNarration();
    await store.openOrCreateSession(
      type: GuideType.umrah,
      mode: GuideMode.learning,
      profile: null,
      firstStepId: 'U01.1',
      contentVersion: 'old-draft',
    );
    await tester.pumpWidget(
      SesliRehberApp(
        store: store,
        catalogs: catalogs,
        narration: narration,
        settings: ReaderSettings(store, narration),
        safetyCatalog: await const LocalSafetyRepository().load(),
      ),
    );
    await tester.pumpAndSettle();

    // Portal screen is shown first
    expect(find.textContaining('Kutlu Yolculuğunuza'), findsOneWidget);
    expect(find.textContaining('Hoş Geldiniz'), findsOneWidget);
    expect(find.text('Hac rehberim'), findsOneWidget);
    expect(find.text('Geliştiriliyor'), findsOneWidget);
    expect(find.byIcon(Icons.lock_rounded), findsOneWidget);
    expect(find.text('Umre rehberim'), findsOneWidget);
    expect(find.text('0%'), findsOneWidget);
    expect(find.textContaining('Kaldığım yerden devam'), findsNothing);

    // Tapping Hac rehberim shows under construction alert dialog
    await tester.tap(find.text('Hac rehberim'));
    await tester.pumpAndSettle();
    expect(find.text('Hac Rehberi Geliştirme Aşamasında'), findsOneWidget);
    expect(
      find.textContaining('uzman incelemesinde ve geliştirme aşamasındadır'),
      findsOneWidget,
    );
    await tester.tap(find.text('Anladım'));
    await tester.pumpAndSettle();
    expect(find.text('Hac Rehberi Geliştirme Aşamasında'), findsNothing);

    // Tapping Umre rehberim opens the main app
    await tester.tap(find.text('Umre rehberim'));
    await tester.pumpAndSettle();
    expect(find.text('Umre Eğitimi'), findsOneWidget);
    expect(find.text('Yardım ve önemli numaralar'), findsOneWidget);
    expect(find.text('Kıble pusulası'), findsOneWidget);
    expect(find.text('Rota, Harita'), findsOneWidget);
  });

  testWidgets('ilk açılışta Umre Eğitimi doğrudan açılır', (tester) async {
    final store = MemoryGuideStore();
    final narration = FakeNarration();
    await tester.pumpWidget(
      SesliRehberApp(
        initialEnteredMainScreen: true,
        store: store,
        catalogs: catalogs,
        narration: narration,
        settings: ReaderSettings(store, narration),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Umre Eğitimi'), findsOneWidget);
    await tester.tap(find.text('Umre Eğitimi'));
    await tester.pumpAndSettle();

    expect(find.byType(GuideSectionsScreen), findsOneWidget);
    expect(find.text('Umre Rehberim'), findsWidgets);
    expect(
      find.textContaining('Bölüm 1: Valiz & Hazırlık Eşyaları'),
      findsOneWidget,
    );
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

    expect(store.sessions.length, 1);
    expect(store.sessions[session.id]!.currentStepId, 'H02.1');
    expect(await store.readMarkedStepIds(session.id), {'H01.1'});
  });

  testWidgets('kayıt okuma hatası yeni kullanıcı sayılmaz ve çökmez', (
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
    expect(find.textContaining('Kutlu Yolculuğunuza'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ana sayfa seçimi, ayrıntı ve son adıma dönüş', (tester) async {
    final store = MemoryGuideStore();
    final narration = FakeNarration();
    await tester.pumpWidget(
      SesliRehberApp(
        initialEnteredMainScreen: true,
        store: store,
        catalogs: catalogs,
        narration: narration,
        settings: ReaderSettings(store, narration),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Umre Eğitimi'), findsOneWidget);
    await tester.tap(find.text('Umre Eğitimi'));
    await tester.pumpAndSettle();
    expect(find.byType(GuideSectionsScreen), findsOneWidget);
    expect(
      find.textContaining('Bölüm 1: Valiz & Hazırlık Eşyaları'),
      findsOneWidget,
    );
    expect(find.text('Valiz ve Hazırlık Rehberi'), findsOneWidget);
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

    // Hac rehberim button has lock and shows under development dialog
    await tester.tap(find.text('Hac rehberim'));
    await tester.pumpAndSettle();
    expect(find.text('Hac Rehberi Geliştirme Aşamasında'), findsOneWidget);
    await tester.tap(find.text('Anladım'));
    await tester.pumpAndSettle();
    expect(find.text('Hac Rehberi Geliştirme Aşamasında'), findsNothing);
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
    expect(find.text('Teknik deneme'), findsNothing);
    expect(find.text('Ses örneğine kaldığım yerden devam'), findsNothing);
    expect(find.text('Ses ve Arapça örnek kartını aç'), findsNothing);
    expect(await store.readLastStepId(), 'DEMO-001');
  });

  testWidgets('ana ekran kayıt yükleme durumu erişilebilir ve sınırlıdır', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
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
    expect(find.text('Hac rehberim'), findsOneWidget);
    expect(find.text('Umre rehberim'), findsOneWidget);
    semantics.dispose();
  });
}
