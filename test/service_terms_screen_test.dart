import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hac_umre_sesli_rehber/group_repository.dart';
import 'package:hac_umre_sesli_rehber/group_screen.dart';

import 'test_fakes.dart';

class TermsScreenRepository extends UnconfiguredGroupRepository {
  String uid = 'fixture-a';
  String version = 'fixture-v1';
  bool offline = false;
  final accepted = <String>{};
  @override
  bool get configured => true;
  @override
  String? get userId => uid;
  @override
  Future<List<GroupRecord>> groups() async => [];
  @override
  Future<ServiceTerms?> currentTerms() async {
    if (offline) throw StateError('offline');
    return ServiceTerms(
      version: version,
      body: 'TEST ONLY terms',
      documentUrl: Uri.parse('https://example.test/terms'),
      documentSha256: 'a' * 64,
      acceptedAt: accepted.contains('$uid/$version')
          ? DateTime.utc(2026)
          : null,
    );
  }

  @override
  Future<void> acceptTerms(String displayedVersion) async {
    if (offline || displayedVersion != version) throw StateError('changed');
    accepted.add('$uid/$version');
  }

  void changeAccount() {
    uid = 'fixture-b';
    notifyListeners();
  }
}

void main() {
  testWidgets(
    'writes need server acceptance, reaccept on account/version and fail closed offline',
    (tester) async {
      final repo = TermsScreenRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: GroupScreen(repository: repo, store: MemoryGuideStore()),
        ),
      );
      await tester.pumpAndSettle();
      FilledButton join() => tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Davetle katıl'),
      );
      expect(join().onPressed, isNull);
      await tester.tap(find.text('Okudum, bu sürümü kabul ediyorum'));
      await tester.pumpAndSettle();
      expect(join().onPressed, isNotNull);
      repo.changeAccount();
      await tester.pumpAndSettle();
      expect(join().onPressed, isNull);
      expect(find.text('Okudum, bu sürümü kabul ediyorum'), findsOneWidget);
      repo.version = 'fixture-v2';
      await tester.scrollUntilVisible(
        find.text('Kafileleri yenile'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Kafileleri yenile'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Kullanım koşulları · fixture-v2'),
        -300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(join().onPressed, isNull);
      repo.offline = true;
      await tester.scrollUntilVisible(
        find.text('Kafileleri yenile'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Kafileleri yenile'));
      await tester.pumpAndSettle();
      expect(join().onPressed, isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      repo.dispose();
    },
  );
}
