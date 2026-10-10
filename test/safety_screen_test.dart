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
