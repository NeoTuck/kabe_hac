import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hac_umre_sesli_rehber/main.dart';
import 'package:hac_umre_sesli_rehber/progress_store.dart';

class MemoryProgressStore extends ProgressStore {
  String? lastId;

  @override
  Future<String?> readLastStepId() async => lastId;

  @override
  Future<void> saveLastStepId(String stepId) async {
    lastId = stepId;
  }
}

void main() {
  testWidgets('son açılan kart yeniden girişte devam eylemine dönüşür',
      (tester) async {
    final store = MemoryProgressStore();

    await tester.pumpWidget(SesliRehberApp(store: store));
    await tester.pumpAndSettle();
    expect(find.text('Örnek kartı aç'), findsOneWidget);

    await tester.tap(find.text('Örnek kartı aç'));
    await tester.pumpAndSettle();
    expect(find.text('Bir adım kartı nasıl görünür?'), findsOneWidget);
    expect(store.lastId, DemoStepScreen.stepId);

    Navigator.of(tester.element(find.byType(DemoStepScreen))).pop();
    await tester.pumpAndSettle();
    expect(find.text('Kaldığım yerden devam'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(SesliRehberApp(store: store));
    await tester.pumpAndSettle();
    expect(find.text('Kaldığım yerden devam'), findsOneWidget);
  });
}
