import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hac_umre_sesli_rehber/counter_screen.dart';
import 'package:hac_umre_sesli_rehber/progress_store.dart';

class MemoryCounterStore extends ProgressStore {
  int count = 0;

  @override
  Future<int> readCounterCount(int sessionId, String counterKey) async => count;

  @override
  Future<int> incrementCounter(
    int sessionId,
    String counterKey,
    String actionToken,
  ) async => count = count < 7 ? count + 1 : 7;

  @override
  Future<int> undoCounter(
    int sessionId,
    String counterKey,
    String actionToken,
  ) async => count = count > 0 ? count - 1 : 0;

  @override
  Future<int> resetCounter(
    int sessionId,
    String counterKey,
    String actionToken,
  ) async => count = 0;
}

class RecoveringJamaratStore extends MemoryCounterStore {
  bool fail = true;
  @override
  Future<List<JamaratCounterContext>> readJamaratCounters(int sessionId) async {
    if (fail) throw StateError('temporary read failure');
    return [];
  }
}

void main() {
  testWidgets('sayaç artar, geri alınır ve sıfırlama onay ister', (
    tester,
  ) async {
    final store = MemoryCounterStore();
    await tester.pumpWidget(
      MaterialApp(
        home: CounterScreen(store: store, sessionId: 1, counterKey: 'tawaf'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('0 / 7'), findsOneWidget);

    await tester.tap(find.text('+1 ekle'));
    await tester.pumpAndSettle();
    expect(find.text('1 / 7'), findsOneWidget);

    await tester.tap(find.text('Son sayımı geri al'));
    await tester.pumpAndSettle();
    expect(find.text('0 / 7'), findsOneWidget);

    await tester.tap(find.text('+1 ekle'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sayacı sıfırla'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();
    expect(find.text('1 / 7'), findsOneWidget);

    await tester.tap(find.text('Sayacı sıfırla'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sıfırla'));
    await tester.pumpAndSettle();
    expect(find.text('0 / 7'), findsOneWidget);
  });

  testWidgets('cemarat sayacı gün ve hedef bağlamını açıkça gösterir', (
    tester,
  ) async {
    final store = MemoryCounterStore();
    await tester.pumpWidget(
      MaterialApp(
        home: CounterScreen(
          store: store,
          sessionId: 12,
          counterKey: 'jamarat:3',
          title: 'Cemarat sayacı',
          contextLabel: 'Kişisel gün · Hedef A',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cemarat sayacı'), findsOneWidget);
    expect(find.text('Kişisel gün · Hedef A'), findsOneWidget);
    expect(find.textContaining('İbadetin yapıldığını'), findsOneWidget);
    await tester.tap(find.text('+1 ekle'));
    await tester.pumpAndSettle();
    expect(find.text('1 / 7'), findsOneWidget);
  });
  testWidgets(
    'rapid reset callbacks open one confirmation and cancel preserves count',
    (tester) async {
      final store = MemoryCounterStore()..count = 3;
      await tester.pumpWidget(
        MaterialApp(
          home: CounterScreen(store: store, sessionId: 1, counterKey: 'tawaf'),
        ),
      );
      await tester.pumpAndSettle();
      // Invoke the same callback twice before a rebuild. A second screen tap
      // would hit the first dialog's modal barrier instead of the reset action.
      final reset = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Sayacı sıfırla'),
      );
      reset.onPressed!();
      reset.onPressed!();
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.text('Vazgeç'));
      await tester.pumpAndSettle();
      expect(find.text('3 / 7'), findsOneWidget);
      await tester.tap(find.text('+1 ekle'));
      await tester.pumpAndSettle();
      expect(find.text('4 / 7'), findsOneWidget);
    },
  );

  testWidgets('cemarat read failure stops spinner and can recover', (
    tester,
  ) async {
    final store = RecoveringJamaratStore();
    await tester.pumpWidget(
      MaterialApp(home: JamaratCounterHubScreen(store: store, sessionId: 1)),
    );
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Sayaçları yeniden dene'), findsOneWidget);
    store.fail = false;
    await tester.tap(find.text('Sayaçları yeniden dene'));
    await tester.pumpAndSettle();
    expect(find.text('Henüz gün/hedef sayacı eklenmedi.'), findsOneWidget);
    await tester.tap(find.text('Yeni gün/hedef sayacı'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();
  });
}
