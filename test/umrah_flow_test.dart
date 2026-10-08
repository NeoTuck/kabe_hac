import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hac_umre_sesli_rehber/content_repository.dart';
import 'package:hac_umre_sesli_rehber/guide_catalog.dart';
import 'package:hac_umre_sesli_rehber/guide_screens.dart';

import 'test_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Map<GuideType, GuideCatalog> catalogs;
  late String umrahJson;
  setUpAll(() async {
    catalogs = await const LocalContentRepository().load();
    umrahJson = await rootBundle.loadString(
      'assets/content/umre_inventory.v1.json',
    );
  });

  testWidgets('işaretleme elle yapılır, ses bitişi kaydı değiştirmez', (
    tester,
  ) async {
    final store = MemoryGuideStore();
    final narration = FakeNarration();
    final catalog = catalogs[GuideType.umrah]!;
    final session = await store.openOrCreateSession(
      type: GuideType.umrah,
      mode: GuideMode.learning,
      profile: null,
      firstStepId: 'U01.1',
      contentVersion: catalog.contentVersion,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: GuideStepScreen(
          store: store,
          catalog: catalog,
          narration: narration,
          session: session,
          step: catalog.steps.first,
          initiallyMarked: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await narration.playAsset('technical-test');
    narration.finish();
    await tester.pump();
    expect(await store.readMarkedStepIds(session.id), isEmpty);
    await tester.ensureVisible(find.text('Kişisel ilerleme olarak işaretle'));
    await tester.tap(find.text('Kişisel ilerleme olarak işaretle'));
    await tester.pumpAndSettle();
    expect(await store.readMarkedStepIds(session.id), {'U01.1'});
  });

  testWidgets('geçersiz eski kimlikte listeyle kurtarma', (tester) async {
    final store = MemoryGuideStore();
    final narration = FakeNarration();
    final catalog = catalogs[GuideType.umrah]!;
    final session = await store.openOrCreateSession(
      type: GuideType.umrah,
      mode: GuideMode.journey,
      profile: null,
      firstStepId: 'OLD-STEP',
      contentVersion: 'old',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: GuideFlowScreen(
          store: store,
          catalog: catalog,
          narration: narration,
          mode: GuideMode.journey,
          profile: null,
          existingSession: session,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('bu içerik sürümünde bulunamadı'),
      findsOneWidget,
    );
    expect(store.sessions[session.id]!.currentStepId, 'OLD-STEP');
    await tester.tap(find.text('Kullanım biçimi seçimi').first);
    await tester.pumpAndSettle();
    expect(store.sessions[session.id]!.currentStepId, 'U01.1');
  });

  testWidgets('U02.2 taslağı onaylı içerik gibi sunulmaz', (tester) async {
    final store = MemoryGuideStore();
    final narration = FakeNarration();
    final catalog = catalogs[GuideType.umrah]!;
    final session = await store.openOrCreateSession(
      type: GuideType.umrah,
      mode: GuideMode.learning,
      profile: null,
      firstStepId: 'U02.2',
      contentVersion: catalog.contentVersion,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: GuideStepScreen(
          store: store,
          catalog: catalog,
          narration: narration,
          session: session,
          step: catalog.stepById('U02.2')!,
          initiallyMarked: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('İçerik durumu: Taslak'), findsWidgets);
    expect(find.textContaining('onaylı içerik değildir'), findsOneWidget);
    expect(
      find.text('Arapça metin, okunuş ve Türkçe anlam henüz sağlanmadı.'),
      findsOneWidget,
    );
    expect(find.text('Kaynak bilgisi henüz sağlanmadı.'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.textContaining('Türkçe anlatım: Taslak'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.text('Türkçe anlatım: Taslak. Ses dosyası henüz sağlanmadı.'),
      findsOneWidget,
    );
  });

  testWidgets('taslak dua metni onay gelmeden gösterilmez', (tester) async {
    final source = jsonDecode(umrahJson) as Map<String, dynamic>;
    final prayer =
        (source['prayerRecords'] as List).first as Map<String, dynamic>;
    prayer.addAll({
      'arabic': 'نص اختبار',
      'transliteration': 'Taslak okunuş',
      'meaningTr': 'Taslak anlam',
    });
    final catalog = GuideCatalog.fromJsonText(jsonEncode(source));
    final store = MemoryGuideStore();
    final narration = FakeNarration();
    final session = await store.openOrCreateSession(
      type: GuideType.umrah,
      mode: GuideMode.learning,
      profile: null,
      firstStepId: 'U02.2',
      contentVersion: catalog.contentVersion,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: GuideStepScreen(
          store: store,
          catalog: catalog,
          narration: narration,
          session: session,
          step: catalog.stepById('U02.2')!,
          initiallyMarked: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Bu dua hazırlama kaydıdır'), findsOneWidget);
    expect(find.text('نص اختبار'), findsNothing);
    expect(find.text('Taslak okunuş'), findsNothing);
    expect(find.text('Taslak anlam'), findsNothing);
  });

  testWidgets(
    'onaylı örnek veride dua kartı doğru metin ve ses türlerini açar',
    (tester) async {
      final source = jsonDecode(umrahJson) as Map<String, dynamic>;
      final step = (source['steps'] as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((item) => item['id'] == 'U02.2');
      step.addAll({
        'status': 'approved',
        'summary': 'Test özeti',
        'details': 'Test ayrıntısı',
        'sourceTitle': 'Test kaynağı',
        'sourceUrl': 'https://example.com/source',
        'sourceLocation': 'Bölüm 2',
        'sourceUsageRights': 'Yalnız test verisi',
        'reviewedBy': 'Test inceleyicisi',
        'reviewedAt': '2026-10-05',
      });
      final prayer =
          (source['prayerRecords'] as List).first as Map<String, dynamic>;
      prayer.addAll({
        'status': 'approved',
        'arabic': 'نص اختبار',
        'transliteration': 'Test okunuşu',
        'meaningTr': 'Test anlamı',
        'sourceTitle': 'Dua test kaynağı',
        'sourceUrl': 'https://example.com/prayer',
        'sourceLocation': 'Sayfa 10',
        'sourceUsageRights': 'Yalnız test verisi',
        'reviewedBy': 'Test inceleyicisi',
        'reviewedAt': '2026-10-05',
      });
      final catalog = GuideCatalog.fromJsonText(jsonEncode(source));
      final store = MemoryGuideStore();
      final narration = FakeNarration();
      final session = await store.openOrCreateSession(
        type: GuideType.umrah,
        mode: GuideMode.learning,
        profile: null,
        firstStepId: 'U02.2',
        contentVersion: catalog.contentVersion,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: GuideStepScreen(
            store: store,
            catalog: catalog,
            narration: narration,
            session: session,
            step: catalog.stepById('U02.2')!,
            initiallyMarked: false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('نص اختبار'), findsOneWidget);
      expect(find.text('Test okunuşu'), findsOneWidget);
      expect(find.text('Test anlamı'), findsOneWidget);
      expect(find.text('Kaynak: Dua test kaynağı · Sayfa 10'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.textContaining('Türkçe anlam: Taslak'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('Arapça okuma: Taslak'), findsOneWidget);
      expect(find.textContaining('Türkçe anlam: Taslak'), findsOneWidget);
      final rtl = tester.widget<Directionality>(
        find
            .ancestor(
              of: find.text('نص اختبار'),
              matching: find.byType(Directionality),
            )
            .first,
      );
      expect(rtl.textDirection, TextDirection.rtl);
      expect(await store.readMarkedStepIds(session.id), isEmpty);
    },
  );
}
