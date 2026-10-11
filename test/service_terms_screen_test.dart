import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hac_umre_sesli_rehber/group_repository.dart';
import 'package:hac_umre_sesli_rehber/group_screen.dart';

import 'test_fakes.dart';

class TermsScreenRepository extends UnconfiguredGroupRepository {
  String uid = 'fixture-a';
  String version = 'fixture-v1';
  bool offline = false;
  bool offlineOnRejection = false;
  final accepted = <String>{};
  @override
  Future<String> acceptInvitation(String token) async {
    version = 'fixture-v2';
    offline = offlineOnRejection;
    throw const PostgrestException(
      message: 'current service terms acceptance required',
      code: '42501',
    );
  }

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
    'terms rejection followed by offline refresh never reuses old acceptance',
    (tester) async {
      final repo = TermsScreenRepository()
        ..accepted.add('fixture-a/fixture-v1')
        ..offlineOnRejection = true;
      await tester.pumpWidget(
        MaterialApp(
          home: GroupScreen(repository: repo, store: MemoryGuideStore()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Kafile davet kodu'),
        'kept-invite',
      );
      await tester.ensureVisible(find.text('Davetle katıl'));
      await tester.tap(find.text('Davetle katıl'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Davetle katıl'),
            )
            .onPressed,
        isNull,
      );
      expect(
        find.text('Bu sürüm için kabulün sunucuda kayıtlı.'),
        findsNothing,
      );
      expect(find.text('kept-invite'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text(
          'Güncel koşullar alınamadı. Bağlantını kontrol edip Kafileleri yenile; işlemin gönderilmedi.',
        ),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.text(
          'Güncel koşullar alınamadı. Bağlantını kontrol edip Kafileleri yenile; işlemin gönderilmedi.',
        ),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      repo.dispose();
    },
  );

  testWidgets(
    'open terms document keeps its displayed version across account and theme changes',
    (tester) async {
      final repo = TermsScreenRepository();
      final store = MemoryGuideStore();
      await tester.pumpWidget(
        MaterialApp(
          home: GroupScreen(repository: repo, store: store),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Koşulları oku'));
      await tester.pumpAndSettle();
      repo.version = 'fixture-v2';
      repo.changeAccount();
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: GroupScreen(repository: repo, store: store),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Kullanım koşulları · fixture-v1'),
        ),
        findsOneWidget,
      );
      expect(find.text('Kullanım koşulları · fixture-v2'), findsOneWidget);
      await tester.tap(find.text('Kapat'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Davetle katıl'),
            )
            .onPressed,
        isNull,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      repo.dispose();
    },
  );

  testWidgets(
    'server terms rejection reloads current version and preserves invitation',
    (tester) async {
      final repo = TermsScreenRepository()
        ..accepted.add('fixture-a/fixture-v1');
      await tester.pumpWidget(
        MaterialApp(
          home: GroupScreen(repository: repo, store: MemoryGuideStore()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Kafile davet kodu'),
        'fixture-invite',
      );
      await tester.ensureVisible(find.text('Davetle katıl'));
      await tester.tap(find.text('Davetle katıl'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Kullanım koşulları · fixture-v2'),
        -300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Okudum, bu sürümü kabul ediyorum'), findsOneWidget);
      final join = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Davetle katıl'),
      );
      expect(join.onPressed, isNull);
      expect(find.text('fixture-invite'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text(
          'Kullanım koşulları değişti. Güncel sürümü okuyup kabul et, sonra işlemini yeniden dene.',
        ),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.text(
          'Kullanım koşulları değişti. Güncel sürümü okuyup kabul et, sonra işlemini yeniden dene.',
        ),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      repo.dispose();
    },
  );

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
