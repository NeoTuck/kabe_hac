import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hac_umre_sesli_rehber/app_startup.dart';

void main() {
  testWidgets('first frame is visible while local initialization is pending', (
    tester,
  ) async {
    final local = Completer<Widget>();
    await tester.pumpWidget(AppStartup(load: () => local.future));
    expect(find.text('Rehber hazırlanıyor…'), findsOneWidget);
    local.complete(const MaterialApp(home: Text('Yerel rehber')));
    await tester.pumpAndSettle();
    expect(find.text('Yerel rehber'), findsOneWidget);
  });

  testWidgets('failed local startup retries without relaunch or data reset', (
    tester,
  ) async {
    var attempts = 0;
    await tester.pumpWidget(
      AppStartup(
        load: () async {
          if (++attempts == 1) throw StateError('temporary storage error');
          return const MaterialApp(home: Text('Kayıtlar korundu'));
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Rehber açılamadı.'), findsOneWidget);
    await tester.tap(find.text('Tekrar dene'));
    await tester.pumpAndSettle();
    expect(find.text('Kayıtlar korundu'), findsOneWidget);
    expect(attempts, 2);
  });

  testWidgets('pending or failed online setup never blocks offline actions', (
    tester,
  ) async {
    final online = Completer<bool>();
    var taps = 0;
    await tester.pumpWidget(
      DeferredValue<bool>(
        initialValue: false,
        load: () => online.future,
        builder: (ready) => MaterialApp(
          home: Scaffold(
            body: TextButton(
              onPressed: () => taps++,
              child: Text(ready ? 'Kafile hazır' : 'Yerel rehber'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Yerel rehber'));
    expect(taps, 1);
    online.completeError(StateError('offline'));
    await tester.pumpAndSettle();
    expect(find.text('Yerel rehber'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
