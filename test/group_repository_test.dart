import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hac_umre_sesli_rehber/group_repository.dart';
import 'package:hac_umre_sesli_rehber/group_sync.dart';
import 'package:hac_umre_sesli_rehber/progress_store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SendingRepository extends UnconfiguredGroupRepository {
  String? uid = 'user-a';
  bool fail = false;
  Object? sendError;
  Completer<void>? gate;
  final sent = <String>[];
  @override
  bool get configured => true;
  @override
  String? get userId => uid;
  @override
  Future<void> send(GroupOutboxMessage message) async {
    sent.add(message.clientId);
    await gate?.future;
    if (sendError != null) throw sendError!;
    if (fail) throw StateError('server denied');
  }
}

void main() {
  sqfliteFfiInit();
  late Directory directory;
  late ProgressStore store;
  late SendingRepository repository;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('mvp_outbox_');
    store = ProgressStore(
      factory: databaseFactoryFfi,
      databasePath: '${directory.path}/app.db',
    );
    repository = SendingRepository();
  });
  tearDown(() async {
    await store.close();
    repository.dispose();
    await directory.delete(recursive: true);
  });
  Future<GroupOutboxMessage> enqueue(String id, String? owner) =>
      store.enqueueGroupMessage(
        clientId: id,
        groupId: 'group-a',
        ownerUserId: owner,
        body: id,
      );
  test(
    'v7 upgrade preserves old records without assigning an account',
    () async {
      await store.close();
      final legacy = await databaseFactoryFfi.openDatabase(
        '${directory.path}/app.db',
        options: OpenDatabaseOptions(
          version: 7,
          onCreate: (db, _) async {
            await db.execute(
              'CREATE TABLE app_state (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
            );
            await db.execute(
              'CREATE TABLE message_outbox (client_id TEXT PRIMARY KEY, group_id TEXT NOT NULL, recipient_id TEXT, body TEXT NOT NULL, status TEXT NOT NULL, attempt_count INTEGER NOT NULL, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, last_error TEXT)',
            );
            await db.insert('app_state', {
              'key': 'last_step_id',
              'value': 'U02.2',
            });
            await db.insert('message_outbox', {
              'client_id': 'legacy',
              'group_id': 'group-a',
              'body': 'old message',
              'status': 'pending',
              'attempt_count': 0,
              'created_at': 1,
              'updated_at': 1,
            });
          },
        ),
      );
      await legacy.close();
      store = ProgressStore(
        factory: databaseFactoryFfi,
        databasePath: '${directory.path}/app.db',
      );
      expect(await store.readAppValue('last_step_id'), 'U02.2');
      expect((await store.readGroupOutbox()).single.ownerUserId, isNull);
      await GroupOutboxSynchronizer(store, repository).sync('group-a');
      expect(repository.sent, isEmpty);
    },
  );
  test('no credentials means no backend initialization', () async {
    expect(GroupRuntimeConfig.parse('', ''), isNull);
    final unavailable = UnconfiguredGroupRepository();
    expect(unavailable.configured, false);
    expect(unavailable.userId, isNull);
    await expectLater(unavailable.groups(), throwsStateError);
    unavailable.dispose();
  });
  test('configuration rejects service secrets and insecure origins', () {
    const key = 'sb_publishable_1234567890123456';
    expect(
      GroupRuntimeConfig.parse('https://example.supabase.co', key),
      isNotNull,
    );
    for (final url in [
      'http://example.test',
      'https://example.test/path',
      'https://user:pass@example.test',
      'https://example.test?q=1',
    ]) {
      expect(() => GroupRuntimeConfig.parse(url, key), throwsFormatException);
    }
    expect(
      () => GroupRuntimeConfig.parse(
        'https://example.test',
        'sb_secret_1234567890123456',
      ),
      throwsFormatException,
    );
  });
  test(
    'account-bound queue never sends other or legacy unowned messages',
    () async {
      await enqueue('a', 'user-a');
      await enqueue('b', 'user-b');
      await enqueue('legacy', null);
      final sync = GroupOutboxSynchronizer(store, repository);
      await sync.sync('group-a');
      expect(repository.sent, ['a']);
      repository.uid = 'user-b';
      await sync.sync('group-a');
      expect(repository.sent, ['a', 'b']);
      final rows = await store.readGroupOutbox();
      expect(
        rows.singleWhere((r) => r.clientId == 'legacy').status,
        MessageOutboxStatus.pending,
      );
    },
  );
  test('retry keeps client id and sent message is not sent twice', () async {
    await enqueue('retry', 'user-a');
    final sync = GroupOutboxSynchronizer(store, repository);
    repository.fail = true;
    await sync.sync('group-a');
    expect(
      (await store.readGroupOutbox()).single.status,
      MessageOutboxStatus.failed,
    );
    repository.fail = false;
    await sync.sync('group-a');
    await sync.sync('group-a');
    expect(repository.sent, ['retry', 'retry']);
    expect(
      (await store.readGroupOutbox()).single.status,
      MessageOutboxStatus.sent,
    );
  });
  test(
    'content rejection persists after reopen and never auto retries',
    () async {
      await enqueue('rejected', 'user-a');
      repository.sendError = const PostgrestException(
        message: 'message content rejected',
        code: '42501',
      );
      await GroupOutboxSynchronizer(store, repository).sync('group-a');
      var row = (await store.readGroupOutbox()).single;
      expect(row.status, MessageOutboxStatus.rejected);
      expect(row.lastError, contains('Metni değiştirip'));
      await store.close();
      store = ProgressStore(
        factory: databaseFactoryFfi,
        databasePath: '${directory.path}/app.db',
      );
      repository.sendError = null;
      await GroupOutboxSynchronizer(store, repository).sync('group-a');
      row = (await store.readGroupOutbox()).single;
      expect(repository.sent, ['rejected']);
      expect(row.attemptCount, 1);
      expect(row.status, MessageOutboxStatus.rejected);
      await expectLater(
        store.discardRejectedGroupMessage(
          clientId: row.clientId,
          ownerUserId: 'user-b',
        ),
        throwsStateError,
      );
      expect(await store.readGroupOutbox(), hasLength(1));
      await store.discardRejectedGroupMessage(
        clientId: row.clientId,
        ownerUserId: 'user-a',
      );
      await store.discardRejectedGroupMessage(
        clientId: row.clientId,
        ownerUserId: 'user-a',
      );
      expect(await store.readGroupOutbox(), isEmpty);
    },
  );
  test('policy outage remains retryable and explains the next step', () async {
    await enqueue('outage', 'user-a');
    repository.sendError = const PostgrestException(
      message: 'content moderation unavailable',
      code: '42501',
    );
    final sync = GroupOutboxSynchronizer(store, repository);
    await sync.sync('group-a');
    final row = (await store.readGroupOutbox()).single;
    expect(row.status, MessageOutboxStatus.failed);
    expect(row.lastError, contains('destekle'));
    repository.sendError = null;
    await sync.sync('group-a');
    expect(
      (await store.readGroupOutbox()).single.status,
      MessageOutboxStatus.sent,
    );
  });
  test('v9 migration retains bound pending failed and sent rows', () async {
    final db = await databaseFactoryFfi.openDatabase(
      '${directory.path}/app.db',
      options: OpenDatabaseOptions(
        version: 9,
        onCreate: (db, _) async {
          await db.execute(
            "CREATE TABLE message_outbox (client_id TEXT PRIMARY KEY,group_id TEXT NOT NULL,recipient_id TEXT,body TEXT NOT NULL,status TEXT CHECK(status IN ('pending','failed','sent')),attempt_count INTEGER NOT NULL,last_error TEXT,created_at INTEGER NOT NULL,updated_at INTEGER NOT NULL,owner_user_id TEXT)",
          );
          for (final status in ['pending', 'failed', 'sent']) {
            await db.insert('message_outbox', {
              'client_id': status,
              'group_id': 'group-a',
              'recipient_id': 'guide',
              'body': 'preserved $status',
              'status': status,
              'attempt_count': 3,
              'last_error': 'previous reason',
              'created_at': 1,
              'updated_at': 2,
              'owner_user_id': 'user-a',
            });
          }
        },
      ),
    );
    await db.close();
    final rows = await store.readGroupOutbox();
    expect(rows.map((r) => r.status).toSet(), {
      MessageOutboxStatus.pending,
      MessageOutboxStatus.failed,
      MessageOutboxStatus.sent,
    });
    for (final row in rows) {
      expect(row.body, 'preserved ${row.clientId}');
      expect(row.ownerUserId, 'user-a');
      expect(row.recipientId, 'guide');
      expect(row.attemptCount, 3);
      expect(row.lastError, 'previous reason');
    }
    await store.markGroupMessageAttempt(
      clientId: 'failed',
      status: MessageOutboxStatus.rejected,
      error: 'rejected',
    );
    expect(
      (await store.readGroupOutbox())
          .singleWhere((r) => r.clientId == 'failed')
          .status,
      MessageOutboxStatus.rejected,
    );
  });
  test('concurrent refresh shares one send attempt', () async {
    await enqueue('single', 'user-a');
    repository.gate = Completer<void>();
    final sync = GroupOutboxSynchronizer(store, repository);
    final first = sync.sync('group-a');
    final second = sync.sync('group-a');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    repository.gate!.complete();
    await Future.wait([first, second]);
    expect(repository.sent, ['single']);
  });
  test('sign out clears only that account queue', () async {
    await enqueue('a', 'user-a');
    await enqueue('b', 'user-b');
    await store.clearAccountOutbox('user-a');
    expect((await store.readGroupOutbox()).single.ownerUserId, 'user-b');
  });
  test(
    'auth change during send does not acknowledge another account',
    () async {
      await enqueue('a', 'user-a');
      repository.gate = Completer<void>();
      final sync = GroupOutboxSynchronizer(store, repository);
      final running = sync.sync('group-a');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      repository.uid = 'user-b';
      repository.gate!.complete();
      await running;
      expect(
        (await store.readGroupOutbox()).single.status,
        MessageOutboxStatus.pending,
      );
    },
  );
}
