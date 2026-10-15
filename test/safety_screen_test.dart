import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hac_umre_sesli_rehber/safety_catalog.dart';
import 'package:hac_umre_sesli_rehber/safety_screen.dart';

SafetyCatalog fixture({List<FieldInformation> fields = const []}) =>
    SafetyCatalog(
      dataVersion: 'technical-test',
      contacts: [
        SafetyContact(
          id: 'test',
          kind: ContactKind.company,
          name: 'Test kaydı',
          region: 'Test bölgesi',
          phone: 'TEST-NUMBER',
          languages: const ['Türkçe'],
          sourceTitle: 'Teknik fixture',
          sourceUri: Uri.parse('https://example.com/fixture'),
          verifiedAt: DateTime.utc(2026, 10, 8),
          status: SafetyReviewStatus.pendingReview,
        ),
      ],
      languageCards: const [],
      fieldInformation: fields,
    );

void main() {
  testWidgets('inceleme bekleyen numara kullanıcıya gösterilmez', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: SafetyScreen(catalog: fixture())),
    );
    expect(find.text('TEST-NUMBER'), findsNothing);
    expect(find.text('1 iletişim kaydı inceleme bekliyor.'), findsOneWidget);
  });

  testWidgets('eski kritik numara gösterilir ama doğrudan arama kapanır', (
    tester,
  ) async {
    var now = DateTime.utc(2026, 10, 11);
    final contact = SafetyContact(
      id: 'test-contact',
      kind: ContactKind.emergency,
      name: 'Teknik acil fixture',
      region: 'Fixture',
      phone: '000',
      languages: const ['Türkçe'],
      sourceTitle: 'Teknik kaynak',
      sourceUri: Uri.parse('https://example.com/fixture'),
      verifiedAt: now
          .subtract(const Duration(days: 180))
          .add(const Duration(seconds: 1)),
      status: SafetyReviewStatus.sourceVerified,
    );
    final catalog = SafetyCatalog(
      dataVersion: 'fixture',
      contacts: [contact],
      languageCards: const [],
      fieldInformation: const [],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: SafetyScreen(catalog: catalog, clock: () => now),
      ),
    );
    await tester.scrollUntilVisible(
      find.text('Arama ekranını aç'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Arama ekranını aç'),
          )
          .onPressed,
      isNotNull,
    );
    now = now.add(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Arama ekranını aç'),
          )
          .onPressed,
      isNull,
    );
    expect(find.textContaining('doğrudan arama kapalı'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('saha bilgisi ekrandayken geçerlilik sınırında güncellenir', (
    tester,
  ) async {
    var now = DateTime.utc(2026, 10, 8);
    final field = FieldInformation(
      id: 'test',
      title: 'Test saha bilgisi',
      value: 'Teknik değer',
      state: FieldInformationState.live,
      sourceKind: InformationSourceKind.official,
      sourceTitle: 'Teknik fixture',
      sourceUri: Uri.parse('https://example.com/fixture'),
      observedAt: now.add(const Duration(seconds: 1)),
      validUntil: now.add(const Duration(seconds: 2)),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: SafetyScreen(
          catalog: fixture(fields: [field]),
          clock: () => now,
        ),
      ),
    );
    await tester.scrollUntilVisible(
      find.text('Henüz geçerli olmayan bilgi'),
      200,
    );
    now = now.add(const Duration(milliseconds: 1001));
    await tester.pump(const Duration(milliseconds: 1001));
    expect(find.text('Güncel kaynak bilgisi'), findsOneWidget);
    now = now.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Süresi dolmuş bilgi'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
