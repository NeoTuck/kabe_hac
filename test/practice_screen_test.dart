import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hac_umre_sesli_rehber/content_repository.dart';
import 'package:hac_umre_sesli_rehber/guide_catalog.dart';
import 'package:hac_umre_sesli_rehber/practice_screen.dart';
import 'package:hac_umre_sesli_rehber/progress_store.dart';

import 'test_fakes.dart';

class MemoryPracticeStore extends MemoryGuideStore {
  PracticeSession? practice;
  final Map<int, PracticeSession> practices = {};
  final Map<int, Set<String>> practiceMarks = {};
  int nextPracticeId = 100;

  @override
  Future<PracticeSession?> readLatestPracticeSession() async => practice;

  @override
  Future<PracticeSession?> readPracticeSession(int id) async => practices[id];

  @override
  Future<PracticeSession> startPracticeSession({
    required GuideType type,
    required HajjProfile? profile,
    required String contentVersion,
    required String firstStepId,
    String? sectionGroupId,
    bool audioEnabled = false,
    bool useOptionalPackage = false,
  }) async => practice = practices[nextPracticeId] = PracticeSession(
    id: nextPracticeId++,
    type: type,
    profile: profile,
    contentVersion: contentVersion,
    currentStepId: firstStepId,
    sectionGroupId: sectionGroupId,
    phase: PracticePhase.preparation,
    audioEnabled: audioEnabled,
    useOptionalPackage: useOptionalPackage,
    updatedAt: 1,
  );

  @override
  Future<PracticeSession> updatePracticeSession(
    int id, {
    String? currentStepId,
    PracticePhase? phase,
    bool? audioEnabled,
  }) async {
    final old = practices[id]!;
    return practice = practices[id] = PracticeSession(
      id: old.id,
      type: old.type,
      profile: old.profile,
      contentVersion: old.contentVersion,
      currentStepId: currentStepId ?? old.currentStepId,
      sectionGroupId: old.sectionGroupId,
      phase: phase ?? old.phase,
      audioEnabled: audioEnabled ?? old.audioEnabled,
      useOptionalPackage: old.useOptionalPackage,
      updatedAt: old.updatedAt + 1,
    );
  }

  @override
  Future<Set<String>> readPracticeMarkedStepIds(int sessionId) async =>
      Set.of(practiceMarks[sessionId] ?? {});

  @override
  Future<void> setPracticeStepMarked(
    int sessionId,
    String stepId,
    bool marked,
  ) async {
    final marks = practiceMarks.putIfAbsent(sessionId, () => {});
    if (marked) {
      marks.add(stepId);
    } else {
      marks.remove(stepId);
    }
  }

  @override
  Future<int> readPracticeCounter(int sessionId, String stepId) async => 0;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Map<GuideType, GuideCatalog> catalogs;
  setUpAll(() async => catalogs = await const LocalContentRepository().load());

  testWidgets(
    'prova isteğe bağlı açılır, taslağı saklar ve gerçek ilerlemeyi değiştirmez',
    (tester) async {
      final store = MemoryPracticeStore();
      final narration = FakeNarration();
      await tester.pumpWidget(
        MaterialApp(
          home: PracticeScreen(
            store: store,
            catalogs: catalogs,
            narration: narration,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('gerçek ibadetin yerine geçmez'),
        findsOneWidget,
      );
      await tester.tap(find.text('Yeni prova'));
      await tester.pumpAndSettle();
      expect(find.text('Hac'), findsOneWidget);
      await tester.tap(find.text('Paket seçimine geç'));
      await tester.pumpAndSettle();
      expect(find.textContaining('İndirme gerekmez'), findsOneWidget);
      await tester.tap(find.text('Hazırlığa geç'));
      await tester.pumpAndSettle();
      expect(store.practice?.phase, PracticePhase.preparation);
      await tester.tap(find.text('Provaya başla'));
      await tester.pumpAndSettle();
      expect(find.text('Kullanım biçimi seçimi'), findsOneWidget);
      expect(find.textContaining('uzman incelemesinde'), findsWidgets);
      expect(find.text('Bu başlığı prova ettim'), findsOneWidget);
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bu başlığı prova ettim'));
      await tester.pumpAndSettle();
      expect(store.practiceMarks[store.practice!.id], {'U01.1'});
      expect(store.sessions, isEmpty);
      await tester.tap(find.text('Sonraki'));
      await tester.pumpAndSettle();
      expect(store.practice?.currentStepId, 'U01.2');
      await tester.scrollUntilVisible(find.text('Provayı duraklat'), 150);
      await tester.tap(find.text('Provayı duraklat'));
      await tester.pumpAndSettle();
      expect(store.practice?.phase, PracticePhase.paused);
      expect(narration.stopCount, greaterThan(0));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        MaterialApp(
          home: PracticeScreen(
            store: store,
            catalogs: catalogs,
            narration: narration,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kaldığım provadan devam et'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Prova duraklatıldı'), findsOneWidget);
      expect(store.sessions, isEmpty);
    },
  );

  testWidgets('adım listesi yalnız prova konumunu değiştirir', (tester) async {
    final store = MemoryPracticeStore();
    await tester.pumpWidget(
      MaterialApp(
        home: PracticeScreen(
          store: store,
          catalogs: catalogs,
          narration: FakeNarration(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yeni prova'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Paket seçimine geç'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hazırlığa geç'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Provaya başla'));
    await tester.pumpAndSettle();

    expect(find.text('Bu aşama için görsel şema bulunmuyor.'), findsOneWidget);
    await tester.tap(find.text('Adım sırasını gör (0 işaretli)'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Bir başlığa geçmek'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('practice-step-U01.2')));
    await tester.pumpAndSettle();

    expect(store.practice?.currentStepId, 'U01.2');
    expect(store.practiceMarks, isEmpty);
    expect(store.sessions, isEmpty);
  });

  testWidgets('ürün durumu kartları veri değiştirmeden yardım gösterir', (
    tester,
  ) async {
    final store = MemoryPracticeStore();
    final narration = FakeNarration();
    await tester.pumpWidget(
      MaterialApp(
        home: PracticeScreen(
          store: store,
          catalogs: catalogs,
          narration: narration,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ses kesildi'));
    await tester.pumpAndSettle();
    expect(find.textContaining('kulaklık bağlantısını'), findsOneWidget);
    await tester.tap(find.text('Destek bağlantılarını gör'));
    await tester.pumpAndSettle();
    expect(find.text('Gizlilik ve destek'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Paket çevrimdışı değil'));
    await tester.tap(find.text('Paket çevrimdışı değil'));
    await tester.pumpAndSettle();
    expect(find.textContaining('temel içerikle devam et'), findsOneWidget);
    await tester.tap(find.text('Provaya dön'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Kafileden ayrıldım'));
    await tester.tap(find.text('Kafileden ayrıldım'));
    await tester.pumpAndSettle();
    expect(find.textContaining('yeni davet iste'), findsOneWidget);
    await tester.tap(find.text('Provaya dön'));
    await tester.pumpAndSettle();

    expect(store.practice, isNull);
    expect(store.sessions, isEmpty);
    expect(store.practiceMarks, isEmpty);
    expect(narration.stopCount, 0);
  });

  testWidgets('özet işaretli başlık ve taslak durumunu gösterir', (
    tester,
  ) async {
    final store = MemoryPracticeStore();
    final first = catalogs[GuideType.umrah]!.steps.first;
    final finished = PracticeSession(
      id: 44,
      type: GuideType.umrah,
      profile: null,
      contentVersion: catalogs[GuideType.umrah]!.contentVersion,
      currentStepId: first.id,
      sectionGroupId: null,
      phase: PracticePhase.finished,
      audioEnabled: false,
      useOptionalPackage: false,
      updatedAt: 1,
    );
    store.practice = finished;
    store.practices[finished.id] = finished;
    store.practiceMarks[finished.id] = {first.id};
    await tester.pumpWidget(
      MaterialApp(
        home: PracticeScreen(
          store: store,
          catalogs: catalogs,
          narration: FakeNarration(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Son prova özetini aç'));
    await tester.pumpAndSettle();
    expect(find.text('Prova edilen başlıklar'), findsOneWidget);
    expect(find.text(first.title), findsOneWidget);
    expect(
      find.text('${first.groupId} · ${first.status.label}'),
      findsOneWidget,
    );
    expect(store.sessions, isEmpty);

    await tester.tap(find.text('Yeni prova'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Bu akışta uzman incelemesi bekleyen başlıklar var'),
      findsOneWidget,
    );
  });

  testWidgets('katalog değişince eski prova ve işaretleri korunur', (
    tester,
  ) async {
    final store = MemoryPracticeStore();
    final old = PracticeSession(
      id: 42,
      type: GuideType.umrah,
      profile: null,
      contentVersion: 'onceki-surum',
      currentStepId: 'U01.1',
      sectionGroupId: 'U01',
      phase: PracticePhase.practicing,
      audioEnabled: false,
      useOptionalPackage: false,
      updatedAt: 1,
    );
    store.practice = old;
    store.practices[old.id] = old;
    store.practiceMarks[old.id] = {'U01.1'};
    await tester.pumpWidget(
      MaterialApp(
        home: PracticeScreen(
          store: store,
          catalogs: catalogs,
          narration: FakeNarration(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kaldığım provadan devam et'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Eski prova kaydı korunuyor'), findsOneWidget);
    await tester.tap(find.text('Yeni katalogla prova aç'));
    await tester.pumpAndSettle();
    expect(store.practices[old.id], old);
    expect(store.practiceMarks[old.id], {'U01.1'});
    expect(store.practice?.id, isNot(old.id));
    expect(
      store.practice?.contentVersion,
      catalogs[GuideType.umrah]!.contentVersion,
    );
    expect(store.practice?.phase, PracticePhase.preparation);
    expect(store.practiceMarks[store.practice!.id], isNull);
  });

  testWidgets('eski sürüm özeti yeni katalogla sayısal kıyas yapmaz', (
    tester,
  ) async {
    final store = MemoryPracticeStore();
    final old = PracticeSession(
      id: 43,
      type: GuideType.umrah,
      profile: null,
      contentVersion: 'onceki-surum',
      currentStepId: 'U01.1',
      sectionGroupId: null,
      phase: PracticePhase.finished,
      audioEnabled: false,
      useOptionalPackage: false,
      updatedAt: 1,
    );
    store.practice = old;
    store.practices[old.id] = old;
    store.practiceMarks[old.id] = {'U01.1'};
    await tester.pumpWidget(
      MaterialApp(
        home: PracticeScreen(
          store: store,
          catalogs: catalogs,
          narration: FakeNarration(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Son prova özetini aç'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('sayısal karşılaştırma yapılmaz'),
      findsOneWidget,
    );
    expect(find.textContaining('/ 18 başlık prova edildi'), findsNothing);
    await tester.tap(find.text('Baştan tekrar gözden geçir'));
    await tester.pumpAndSettle();
    expect(store.practices[old.id], old);
    expect(store.practice?.id, isNot(old.id));
  });
}
