import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hac_umre_sesli_rehber/licenses_and_sources_screen.dart';

void main() {
  testWidgets('bundled font notice opens its complete license', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: LicensesAndSourcesScreen()),
    );

    expect(find.text('Noto Sans'), findsOneWidget);
    await tester.tap(find.text('Noto Sans'));
    await tester.pumpAndSettle();

    expect(find.text('Noto Sans lisansı'), findsOneWidget);
    expect(
      find.textContaining('SIL OPEN FONT LICENSE Version 1.1'),
      findsOneWidget,
    );
  });
}
