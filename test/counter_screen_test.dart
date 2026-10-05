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
}
