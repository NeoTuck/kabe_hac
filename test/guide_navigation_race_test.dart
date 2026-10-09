import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hac_umre_sesli_rehber/content_repository.dart';
import 'package:hac_umre_sesli_rehber/guide_catalog.dart';
import 'package:hac_umre_sesli_rehber/guide_screens.dart';

import 'test_fakes.dart';

class DelayedStop extends FakeNarration {
  final gate = Completer<void>();
  bool fail = false;
  @override
  Future<void> stop() async {
    stopCount++;
    await gate.future;
    if (fail) throw StateError('stop');
  }
}

class PopObserver extends NavigatorObserver {
  int pops = 0;
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pops++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late GuideCatalog catalog;
  setUpAll(() async {
    catalog = (await const LocalContentRepository().load())[GuideType.umrah]!;
  });
  Future<void> open(
    WidgetTester tester,
    MemoryGuideStore store,
    DelayedStop audio,
    PopObserver observer,
  ) async {
    final session = await store.openOrCreateSession(
      type: GuideType.umrah,
      mode: GuideMode.learning,
      profile: null,
      firstStepId: catalog.steps.first.id,
      contentVersion: catalog.contentVersion,
    );
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [observer],
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => GuideStepScreen(
                    store: store,
                    catalog: catalog,
                    narration: audio,
                    session: session,
                    step: catalog.steps.first,
                    initiallyMarked: false,
                  ),
                ),
              ),
              child: const Text('Aç'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Aç'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Sonraki başlık'), 250);
    await tester.pumpAndSettle();
  }

  testWidgets('rapid next taps close one route while audio stop is pending', (
    tester,
  ) async {
    final store = MemoryGuideStore();
    final audio = DelayedStop();
    final observer = PopObserver();
    await open(tester, store, audio, observer);
    final button = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('Sonraki başlık'),
        matching: find.byType(FilledButton),
      ),
    );
    button.onPressed!();
    button.onPressed!();
    await tester.pump();
    expect(audio.stopCount, 1);
    expect(observer.pops, 0);
    audio.gate.complete();
    await tester.pumpAndSettle();
    expect(observer.pops, 1);
    expect(find.text('Aç'), findsOneWidget);
    expect(store.marks, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    audio.dispose();
  });
  testWidgets('failed audio stop keeps step open and allows retry', (
    tester,
  ) async {
    final store = MemoryGuideStore();
    final audio = DelayedStop()..fail = true;
    final observer = PopObserver();
    await open(tester, store, audio, observer);
    tester
        .widget<FilledButton>(
          find.ancestor(
            of: find.text('Sonraki başlık'),
            matching: find.byType(FilledButton),
          ),
        )
        .onPressed!();
    audio.gate.complete();
    await tester.pumpAndSettle();
    expect(observer.pops, 0);
    expect(find.textContaining('Başlık değiştirilemedi'), findsOneWidget);
    audio.fail = false;
    tester
        .widget<FilledButton>(
          find.ancestor(
            of: find.text('Sonraki başlık'),
            matching: find.byType(FilledButton),
          ),
        )
        .onPressed!();
    await tester.pumpAndSettle();
    expect(observer.pops, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    audio.dispose();
  });
}
