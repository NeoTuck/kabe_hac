import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hac_umre_sesli_rehber/group_repository.dart';
import 'package:hac_umre_sesli_rehber/group_sync.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const group = '10000000-0000-0000-0000-000000000001';
const user = '00000000-0000-0000-0000-000000000001';

class Adapter extends SupabaseGroupRepository {
  Adapter(super.client);
  String? uid = user;
  @override
  String? get userId => uid;
}

GroupOutboxMessage message({String owner = user}) => GroupOutboxMessage(
  clientId: '20000000-0000-0000-0000-000000000001',
  groupId: group,
  body: 'test',
  ownerUserId: owner,
  status: MessageOutboxStatus.pending,
  attemptCount: 0,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);
void main() {
  late SupabaseClient client;
  late Adapter adapter;
  late List<http.Request> requests;
  bool membership = true;
  bool mismatch = false;
  int membershipReads = 0;
  bool revokeOnRecheck = false;
  setUp(() {
    requests = [];
    membership = true;
    mismatch = false;
    membershipReads = 0;
    revokeOnRecheck = false;
    client = SupabaseClient(
      'https://example.supabase.co',
      'test-public-key',
      httpClient: MockClient((request) async {
        requests.add(request);
        final table = request.url.path.split('/').last;
        Object? response = [];
        if (request.method == 'POST') {
          if (table == 'create_personal_group' ||
              table == 'accept_group_invitation') {
            response = group;
          } else {
            return http.Response('', 201, request: request);
          }
        } else if (table == 'group_members') {
          final individual = request.url.queryParameters['select'] == 'user_id';
          if (individual) {
            membershipReads++;
            response = membership && !(revokeOnRecheck && membershipReads > 1)
                ? {'user_id': user}
                : [];
          } else if (request.url.queryParameters['select'] == 'group_id') {
            response = [
              {'group_id': group},
            ];
          } else {
            response = [
              {'user_id': user, 'role': 'group_admin', 'status': 'active'},
            ];
          }
        } else if (table == 'messages') {
          if (request.url.queryParameters.containsKey('client_id')) {
            response = {
              'group_id': group,
              'body': mismatch ? 'different' : 'test',
              'recipient_id': null,
            };
          } else {
            response = [
              {'body': 'new'},
              {'body': 'old'},
            ];
          }
        } else if (table == 'groups') {
          response = [
            {'id': group, 'name': 'Kafile'},
          ];
        }
        return http.Response(
          jsonEncode(response),
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    adapter = Adapter(client);
  });
  tearDown(() async {
    adapter.dispose();
    await client.dispose();
  });
  test(
    'send uses idempotent INSERT, then verifies the saved message',
    () async {
      await adapter.send(message());
      final insert = requests.singleWhere((r) => r.method == 'POST');
      expect(insert.url.queryParameters['on_conflict'], 'sender_id,client_id');
      expect(
        insert.headers['Prefer'],
        contains('resolution=ignore-duplicates'),
      );
      expect(jsonDecode(insert.body)['sender_id'], user);
      expect(requests.any((r) => r.method == 'PATCH'), false);
    },
  );
  test('another account and revoked membership never reach INSERT', () async {
    await expectLater(adapter.send(message(owner: 'other')), throwsStateError);
    expect(requests, isEmpty);
    membership = false;
    await expectLater(adapter.send(message()), throwsStateError);
    expect(requests.any((r) => r.method == 'POST'), false);
  });
  test(
    'server record with a reused client id cannot be acknowledged',
    () async {
      mismatch = true;
      await expectLater(adapter.send(message()), throwsStateError);
    },
  );
  test('snapshot is chronological and revalidates active membership', () async {
    final snapshot = await adapter.snapshot(group);
    expect(snapshot.messages.first['body'], 'old');
    expect(membershipReads, 2);
    expect(
      requests
          .where((r) => r.url.path.endsWith('/messages'))
          .single
          .url
          .queryParameters['limit'],
      '100',
    );
    membershipReads = 0;
    revokeOnRecheck = true;
    await expectLater(adapter.snapshot(group), throwsStateError);
  });
  test('group bootstrap and programs use the database contract', () async {
    expect((await adapter.createGroup('  Kafile  ')).id, group);
    expect(jsonDecode(requests.last.body), {'group_name': 'Kafile'});
    await adapter.publish(group, 'program', 'Ziyaret', 'Buluşma');
    final body = jsonDecode(requests.last.body);
    expect(body['created_by'], user);
    expect(body['document'], {'notes': 'Buluşma'});
    expect(body['version'], 1);
    await adapter.publish(group, 'announcement', 'Duyuru', 'Metin');
    expect(jsonDecode(requests.last.body)['author_id'], user);
  });
  test(
    'invitation stores only a digest and is single-use and time-limited',
    () async {
      final token = await adapter.createInvitation(group);
      final body = jsonDecode(requests.last.body);
      expect(token.length, 43);
      expect(
        body['token_digest'],
        sha256.convert(utf8.encode(token)).toString(),
      );
      expect(body['max_uses'], 1);
      expect(requests.last.body.contains(token), false);
      expect(
        DateTime.parse(body['expires_at'])
            .difference(DateTime.now().toUtc())
            .inHours,
        inInclusiveRange(23, 24),
      );
      expect(await adapter.acceptInvitation(token), group);
    },
  );
  test(
    'groups filter by this account; invalid ids do not send requests',
    () async {
      expect((await adapter.groups()).single.name, 'Kafile');
      expect(requests.first.url.queryParameters['user_id'], 'eq.$user');
      requests.clear();
      await expectLater(adapter.snapshot('invalid'), throwsFormatException);
      expect(requests, isEmpty);
    },
  );
}
