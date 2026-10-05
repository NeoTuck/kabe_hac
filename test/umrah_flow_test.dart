import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hac_umre_sesli_rehber/guide_catalog.dart';
import 'package:hac_umre_sesli_rehber/guide_screens.dart';
import 'package:hac_umre_sesli_rehber/main.dart';
import 'package:hac_umre_sesli_rehber/progress_store.dart';

class MemoryGuideStore extends ProgressStore {
  int _nextId = 1;
  final Map<GuideMode, GuideSession> _latest = {};
  final Map<int, Set<String>> _marks = {};

  @override
  Future<String?> readLastStepId() async => null;

  @override
  Future<GuideSession> openOrCreateUmrahSession({
    required GuideMode mode,
    required String firstStepId,
    required String contentVersion,
  }) async {
    return _latest.putIfAbsent(
      mode,
      () => GuideSession(
        id: _nextId++,
        mode: mode,
        currentStepId: firstStepId,
        contentVersion: contentVersion,
      ),
    );
  }

  @override
  Future<GuideSession> startNewUmrahJourney({
    required String firstStepId,
    required String contentVersion,
  }) async {
    final session = GuideSession(
      id: _nextId++,
      mode: GuideMode.journey,
      currentStepId: firstStepId,
      contentVersion: contentVersion,
    );
    _latest[GuideMode.journey] = session;
    return session;
  }

  @override
  Future<void> saveCurrentStep(int sessionId, String stepId) async {
    final mode = _latest.entries
        .firstWhere((entry) => entry.value.id == sessionId)
        .key;
    _latest[mode] = _latest[mode]!.copyWith(currentStepId: stepId);
  }

  @override
  Future<Set<String>> readMarkedStepIds(int sessionId) async =>
      Set.of(_marks[sessionId] ?? {});

  @override
  Future<void> setStepMarked(int sessionId, String stepId, bool marked) async {
    final marks = _marks.putIfAbsent(sessionId, () => {});
    if (marked) {
      marks.add(stepId);
    } else {
      marks.remove(stepId);
    }
  }
}

void main() {
  testWidgets('umre adımları gezinir ve iki modun işaretleri ayrıdır', (
    tester,
  ) async {
    final store = MemoryGuideStore();
    final catalog = await GuideCatalog.loadAsset();

    await tester.pumpWidget(SesliRehberApp(store: store, catalog: catalog));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Umreyi öğren'));
    await tester.pumpAndSettle();
    expect(find.text('Adımlar · 0/18 işaretli'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Kullanım biçimi seçimi'), 180);
    await tester.tap(find.text('Kullanım biçimi seçimi'));
    await tester.pumpAndSettle();
    expect(find.text('Kullanım biçimi seçimi'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Kişisel ilerleme olarak işaretle'),
      180,
    );
    await tester.tap(find.text('Kişisel ilerleme olarak işaretle'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sonraki başlığa geç'));
    await tester.pumpAndSettle();
    expect(find.text('Hazırlık'), findsOneWidget);

    Navigator.of(tester.element(find.byType(UmrahStepScreen))).pop();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Adımlar · 1/18 işaretli'), -180);
    expect(find.text('Adımlar · 1/18 işaretli'), findsOneWidget);

    Navigator.of(tester.element(find.byType(UmrahFlowScreen))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yolculukta rehber'));
    await tester.pumpAndSettle();
    expect(find.text('Adımlar · 0/18 işaretli'), findsOneWidget);
  });
}
