import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hac_umre_sesli_rehber/app_theme.dart';
import 'package:hac_umre_sesli_rehber/group_repository.dart';
import 'package:hac_umre_sesli_rehber/group_screen.dart';

import 'test_fakes.dart';

class LoginRepository extends UnconfiguredGroupRepository {
  String? uid;
  String? requestedEmail;
  bool denied = false;
  bool deletionRequested = false;
  @override
  bool get configured => true;
  @override
  String? get userId => uid;
  @override
  Future<void> requestCode(String email) async {
    requestedEmail = email;
  }

  @override
  Future<void> verifyCode(String email, String code) async {
    if (denied) throw StateError('invalid code');
    uid = 'account';
    notifyListeners();
  }

  @override
  Future<List<GroupRecord>> groups() async => [];

  @override
  Future<bool> accountDeletionRequested() async => deletionRequested;

  @override
  Future<void> requestAccountDeletion() async {
    deletionRequested = true;
  }
}

void main() {
  testWidgets(
    'invalid email is local; OTP failure retries without blocking guide',
    (tester) async {
      final repo = LoginRepository();
      await tester.pumpWidget(
        MaterialApp(
          theme: RehberTheme.build(Brightness.light),
          home: GroupScreen(repository: repo, store: MemoryGuideStore()),
        ),
      );
      await tester.tap(find.text('Giriş kodu gönder'));
      await tester.pumpAndSettle();
      expect(repo.requestedEmail, isNull);
      await tester.enterText(
        find.byType(TextField).first,
        'member@example.test',
      );
      await tester.tap(find.text('Giriş kodu gönder'));
      await tester.pumpAndSettle();
      expect(repo.requestedEmail, 'member@example.test');
      await tester.scrollUntilVisible(
        find.text('Giriş yap'),
        180,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.enterText(find.byType(TextField).last, '123456');
      repo.denied = true;
      await tester.tap(find.text('Giriş yap'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.textContaining('İşlem tamamlanamadı'),
        180,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.textContaining('İşlem tamamlanamadı'), findsOneWidget);
      repo.denied = false;
      await tester.scrollUntilVisible(
        find.text('Giriş yap'),
        -180,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(find.text('Giriş yap'));
      await tester.pumpAndSettle();
      expect(repo.userId, 'account');
      expect(find.text('Birlikte, adım adım'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      repo.dispose();
    },
  );

  testWidgets('account deletion request needs confirmation and shows receipt', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = LoginRepository()..uid = 'account';
    await tester.pumpWidget(
      MaterialApp(
        theme: RehberTheme.build(Brightness.light),
        home: GroupScreen(repository: repo, store: MemoryGuideStore()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Hesap silme isteği gönder'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Hesap silme isteği gönder'));
    await tester.pumpAndSettle();
    expect(repo.deletionRequested, isFalse);
    expect(find.textContaining('hesabını hemen silmez'), findsOneWidget);
    await tester.tap(find.text('İsteği gönder'));
    await tester.pumpAndSettle();
    expect(repo.deletionRequested, isTrue);
    expect(find.text('Hesap silme isteği alındı'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    repo.dispose();
  });
}
