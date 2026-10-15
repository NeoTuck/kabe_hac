import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hac_umre_sesli_rehber/group_message_composer.dart';
import 'package:hac_umre_sesli_rehber/group_repository.dart';

class ComposerAccount extends UnconfiguredGroupRepository {
  String? uid = 'account-a';
  @override
  String? get userId => uid;
  void change() {
    uid = 'account-b';
    notifyListeners();
  }
}

void main() {
  Future<void> open(
    WidgetTester tester,
    ComposerAccount repo,
    TextEditingController draft,
    Future<bool> Function(String?) send, {
    bool small = false,
  }) async {
    if (small) {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 568);
      tester.view.viewInsets = const FakeViewPadding(bottom: 240);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    }
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                builder: (_) => GroupMessageComposer(
                  repository: repo,
                  controller: draft,
                  guides: const [],
                  onSend: send,
                ),
              ),
              child: const Text('Aç'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Aç'));
    await tester.pumpAndSettle();
  }

  Future<void> finish(
    WidgetTester tester,
    ComposerAccount repo,
    TextEditingController draft,
  ) async {
    await tester.pumpWidget(const SizedBox.shrink());
    repo.dispose();
    draft.dispose();
  }

  testWidgets('closing and reopening preserves draft without sending', (
    tester,
  ) async {
    final repo = ComposerAccount();
    final draft = TextEditingController();
    var calls = 0;
    await open(tester, repo, draft, (_) async {
      calls++;
      return true;
    });
    await tester.enterText(find.byType(TextField), 'Kafile taslağı');
    await tester.tap(find.text('Kapat'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aç'));
    await tester.pumpAndSettle();
    expect(find.text('Kafile taslağı'), findsOneWidget);
    expect(calls, 0);
    await finish(tester, repo, draft);
  });
  testWidgets('saving is single flight and failure keeps the draft', (
    tester,
  ) async {
    final repo = ComposerAccount();
    final draft = TextEditingController(text: 'Mesaj');
    final gate = Completer<bool>();
    var calls = 0;
    await open(tester, repo, draft, (_) {
      calls++;
      return gate.future;
    });
    await tester.tap(find.text('Mesajı gönder'));
    await tester.pump();
    await tester.tap(find.text('Kaydediliyor'));
    expect(calls, 1);
    gate.complete(false);
    await tester.pumpAndSettle();
    expect(draft.text, 'Mesaj');
    expect(find.textContaining('Mesaj kaydedilemedi'), findsOneWidget);
    await finish(tester, repo, draft);
  });
  testWidgets('account change clears draft and disables send during save', (
    tester,
  ) async {
    final repo = ComposerAccount();
    final draft = TextEditingController(text: 'Özel taslak');
    final gate = Completer<bool>();
    await open(tester, repo, draft, (_) => gate.future);
    await tester.tap(find.text('Mesajı gönder'));
    await tester.pump();
    repo.change();
    gate.complete(true);
    await tester.pumpAndSettle();
    expect(draft.text, isEmpty);
    expect(find.textContaining('Oturum değişti'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    await finish(tester, repo, draft);
  });
  testWidgets('keyboard and 200 percent text remain scrollable at 320 pixels', (
    tester,
  ) async {
    final repo = ComposerAccount();
    final draft = TextEditingController();
    var calls = 0;
    await open(tester, repo, draft, (_) async {
      calls++;
      return true;
    }, small: true);
    await tester.ensureVisible(find.byType(TextField));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Küçük ekran');
    await tester.ensureVisible(find.text('Mesajı gönder'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mesajı gönder'));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.byType(GroupMessageComposer), findsNothing);
    expect(tester.takeException(), isNull);
    await finish(tester, repo, draft);
  });
  testWidgets('removed private recipient cannot silently become a group send', (
    tester,
  ) async {
    final repo = ComposerAccount();
    final draft = TextEditingController(text: 'Özel mesaj');
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GroupMessageComposer(
            repository: repo,
            controller: draft,
            guides: const [],
            recipient: 'removed-guide',
            onSend: (_) async {
              calls++;
              return true;
            },
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.textContaining('Mesaj alıcısını yeniden seç'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(calls, 0);
    expect(draft.text, 'Özel mesaj');
    await finish(tester, repo, draft);
  });
}
