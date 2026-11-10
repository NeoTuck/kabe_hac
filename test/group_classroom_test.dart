import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hac_umre_sesli_rehber/app_theme.dart';
import 'package:hac_umre_sesli_rehber/group_repository.dart';
import 'package:hac_umre_sesli_rehber/group_screen.dart';

import 'test_fakes.dart';

Widget _app() => MaterialApp(
      theme: RehberTheme.build(Brightness.light),
      home: GroupScreen(
        repository: UnconfiguredGroupRepository(),
        store: MemoryGuideStore(),
      ),
    );

void main() {
  testWidgets('shows join & create buttons and Kafile hizmeti text',
      (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('Kafileye Katıl'), findsWidgets);
    expect(find.textContaining('Kafile Kur'), findsWidgets);
    expect(find.textContaining('Kafile hizmeti'), findsWidgets);
  });

  testWidgets('joining with code KAF-2026 shows kafile card', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    // Tap join button
    await tester.tap(find.text('Kafileye Katıl').first);
    await tester.pumpAndSettle();

    // Dialog should appear
    expect(find.text('Katılım Kodu'), findsOneWidget);

    // Enter code
    await tester.enterText(find.byType(TextField), 'KAF-2026');
    await tester.tap(find.text('Katıl'));
    await tester.pumpAndSettle();

    // Should show kafile name
    expect(find.text('Haremeyn 2026 Kafile No: 14'), findsOneWidget);
    expect(find.textContaining('Kafile hizmeti'), findsWidgets);
  });

  testWidgets('creating kafile without auth key shows authorization dialog',
      (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    // Tap create button
    await tester.tap(find.textContaining('Kafile Kur').first);
    await tester.pumpAndSettle();

    // Should show authorization dialog
    expect(find.textContaining('Kafile Başkanı Yetkisi'), findsOneWidget);
    expect(find.text('Yetki Anahtarı'), findsOneWidget);
  });

  testWidgets('entering valid auth key unlocks kafile creation',
      (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    // Tap create
    await tester.tap(find.textContaining('Kafile Kur').first);
    await tester.pumpAndSettle();

    // Enter valid key
    await tester.enterText(find.byType(TextField), 'HAC-REHBER-2026');
    await tester.tap(find.text('Yetkiyi Doğrula'));
    await tester.pumpAndSettle();

    // Should show create form
    expect(find.text('Yeni Kafile Kur 👑'), findsOneWidget);
    expect(find.text('Kafile Adı'), findsOneWidget);
  });

  testWidgets('entering invalid auth key shows error', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Kafile Kur').first);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'YANLIS-ANAHTAR');
    await tester.tap(find.text('Yetkiyi Doğrula'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Geçersiz yetki anahtarı'), findsOneWidget);
  });

  testWidgets('leaving kafile returns to empty state', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    // The default state has _hasJoinedKafile = true, showing the card
    // Find leave button by scrolling
    await tester.scrollUntilVisible(
      find.text('Kafileden Ayrıl'),
      180,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.text('Kafileden Ayrıl').last);
    await tester.pumpAndSettle();

    // Confirm dialog
    expect(find.text('Ayrıl'), findsOneWidget);
    await tester.tap(find.text('Ayrıl'));
    await tester.pumpAndSettle();

    // Should show empty state
    expect(
      find.textContaining('Herhangi Bir Kafileye Bağlı Değilsiniz'),
      findsOneWidget,
    );
  });
}
