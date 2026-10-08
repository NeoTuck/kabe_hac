import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hac_umre_sesli_rehber/group_repository.dart';
import 'package:hac_umre_sesli_rehber/group_screen.dart';

import 'test_fakes.dart';

class ManagementRepository extends UnconfiguredGroupRepository {
  String? uid = 'user-a';
  final invitation = Completer<String>();
  int invites = 0;
  int publications = 0;
  @override
  bool get configured => true;
  @override
  String? get userId => uid;
  void changeAccount() {
    uid = 'user-b';
    notifyListeners();
  }

  @override
  Future<GroupSnapshot> snapshot(String id) async => const GroupSnapshot(
    members: [
      {'user_id': 'user-a', 'role': 'group_admin'},
    ],
    messages: [],
    announcements: [],
    programs: [],
    routes: [],
  );
  @override
  Future<String> createInvitation(String id) {
    invites++;
    return invitation.future;
  }

  @override
  Future<void> publish(
    String id,
    String kind,
    String title,
    String body,
  ) async {
    publications++;
  }
}

void main() {
  Future<void> open(WidgetTester tester, ManagementRepository repo) async {
    await tester.pumpWidget(
      MaterialApp(
        home: GroupDetailScreen(
          group: const GroupRecord('group-a', 'Kafile'),
          repository: repo,
          store: MemoryGuideStore(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> close(WidgetTester tester, ManagementRepository repo) async {
    await tester.pumpWidget(const SizedBox.shrink());
    repo.dispose();
  }

  testWidgets('late invitation from previous account is never displayed', (
    tester,
  ) async {
    final repo = ManagementRepository();
    await open(tester, repo);
    await tester.tap(find.text('Davet oluştur'));
    await tester.tap(find.text('Davet oluştur'));
    expect(repo.invites, 1);
    repo.changeAccount();
    repo.invitation.complete('SECRET-TEST-TOKEN');
    await tester.pumpAndSettle();
    expect(find.textContaining('SECRET-TEST-TOKEN'), findsNothing);
    expect(find.byType(AlertDialog), findsNothing);
    await close(tester, repo);
  });
  testWidgets('visible invitation is hidden immediately after account change', (
    tester,
  ) async {
    final repo = ManagementRepository();
    await open(tester, repo);
    repo.invitation.complete('SECRET-TEST-TOKEN');
    await tester.tap(find.text('Davet oluştur'));
    await tester.pumpAndSettle();
    expect(find.textContaining('SECRET-TEST-TOKEN'), findsOneWidget);
    repo.changeAccount();
    await tester.pumpAndSettle();
    expect(find.textContaining('SECRET-TEST-TOKEN'), findsNothing);
    expect(find.text('Oturum değişti. Davet kodu gizlendi.'), findsOneWidget);
    await tester.tap(find.text('Kapat'));
    await tester.pumpAndSettle();
    await close(tester, repo);
  });
  testWidgets('publication dialog cannot publish under a changed account', (
    tester,
  ) async {
    final repo = ManagementRepository();
    await open(tester, repo);
    await tester.tap(find.text('Duyuru ekle'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Test başlık');
    await tester.enterText(find.byType(TextField).last, 'Test açıklama');
    repo.changeAccount();
    await tester.tap(find.text('Yayınla'));
    await tester.pumpAndSettle();
    expect(repo.publications, 0);
    expect(
      find.text('Oturum değişti. Kafile ekranından geri dön.'),
      findsOneWidget,
    );
    await close(tester, repo);
  });
}
