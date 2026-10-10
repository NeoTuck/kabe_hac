import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hac_umre_sesli_rehber/group_repository.dart';
import 'package:hac_umre_sesli_rehber/group_screen.dart';
import 'package:hac_umre_sesli_rehber/group_sync.dart';

import 'test_fakes.dart';

class QueuedStore extends MemoryGuideStore {
  MessageOutboxStatus status = MessageOutboxStatus.pending;
  @override
  Future<List<GroupOutboxMessage>> readGroupOutbox({
    MessageOutboxStatus? status,
  }) async => status != null && status != this.status
      ? []
      : [
          GroupOutboxMessage(
            clientId: 'queued',
            groupId: 'group-a',
            ownerUserId: 'user-a',
            body: 'Bekleyen mesaj',
            status: this.status,
            attemptCount: 0,
            createdAt: DateTime.utc(2026),
            updatedAt: DateTime.utc(2026),
          ),
        ];
  @override
  Future<void> markGroupMessageAttempt({
    required String clientId,
    required MessageOutboxStatus status,
    String? error,
  }) async {
    this.status = status;
  }
}

class RefreshRepository extends UnconfiguredGroupRepository {
  String? uid = 'user-a';
  bool failSend = false;
  final delivered = <Map<String, dynamic>>[];
  final oldGroups = Completer<List<GroupRecord>>();
  Completer<GroupSnapshot>? pendingSnapshot;
  @override
  bool get configured => true;
  @override
  String? get userId => uid;
  void changeAccount(String user) {
    uid = user;
    notifyListeners();
  }

  @override
  Future<List<GroupRecord>> groups() => uid == 'user-a'
      ? oldGroups.future
      : Future.value([const GroupRecord('group-b', 'Yeni kafile')]);
  @override
  Future<void> send(GroupOutboxMessage message) async {
    if (failSend) throw StateError('offline');
    delivered.add({
      'body': message.body,
      'sender_id': message.ownerUserId,
      'recipient_id': null,
      'created_at': '2026-10-07',
      'deleted_at': null,
    });
  }

  @override
  Future<GroupSnapshot> snapshot(String groupId) async {
    if (pendingSnapshot != null) return pendingSnapshot!.future;
    return GroupSnapshot(
      members: const [],
      messages: List.of(delivered),
      announcements: const [],
      programs: const [],
      routes: const [],
    );
  }
  // Deliberately no Realtime callback: refresh must stand on its own.
}

void main() {
  Future<void> openDetail(
    WidgetTester tester,
    RefreshRepository repo,
    QueuedStore store,
  ) => tester.pumpWidget(
    MaterialApp(
      home: GroupDetailScreen(
        group: const GroupRecord('group-a', 'Kafile A'),
        repository: repo,
        store: store,
      ),
    ),
  );

  testWidgets('delivered outbox appears without a Realtime notification', (
    tester,
  ) async {
    final repo = RefreshRepository();
    final store = QueuedStore();
    await openDetail(tester, repo, store);
    await tester.pumpAndSettle();
    expect(store.status, MessageOutboxStatus.sent);
    expect(find.text('Bekleyen mesaj'), findsOneWidget);
    expect(find.text('Sen'), findsOneWidget);
    expect(find.textContaining('Gönderim bekliyor'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    repo.dispose();
  });

  testWidgets('failed delivery remains visible as unsent', (tester) async {
    final repo = RefreshRepository()..failSend = true;
    final store = QueuedStore();
    await openDetail(tester, repo, store);
    await tester.pumpAndSettle();
    expect(store.status, MessageOutboxStatus.failed);
    final status = find.textContaining('Gönderilemedi');
    await tester.scrollUntilVisible(
      status,
      250,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(status, findsOneWidget);
    expect(repo.delivered, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    repo.dispose();
  });

  testWidgets('old account load failure preserves new account groups', (
    tester,
  ) async {
    final repo = RefreshRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: GroupScreen(repository: repo, store: MemoryGuideStore()),
      ),
    );
    repo.changeAccount('user-b');
    await tester.pumpAndSettle();
    repo.oldGroups.completeError(StateError('old request denied'));
    await tester.pumpAndSettle();
    expect(find.text('Yeni kafile'), findsOneWidget);
    expect(find.textContaining('Kafileler alınamadı'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    repo.dispose();
  });

  testWidgets('stale detail failure cannot overwrite session change warning', (
    tester,
  ) async {
    final repo = RefreshRepository()
      ..pendingSnapshot = Completer<GroupSnapshot>();
    await openDetail(tester, repo, QueuedStore());
    await tester.pump();
    repo.changeAccount('user-b');
    await tester.pump();
    repo.pendingSnapshot!.completeError(StateError('old membership denied'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Oturum değişti'), findsOneWidget);
    expect(find.textContaining('Kafileye erişilemedi'), findsNothing);
    expect(find.text('Bekleyen mesaj'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    repo.dispose();
  });
}
