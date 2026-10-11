import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hac_umre_sesli_rehber/group_repository.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TermsAdapter extends SupabaseGroupRepository {
  TermsAdapter(super.client);
  String? uid = 'account-a';
  @override
  String? get userId => uid;
}

void main() {
  final row = <String, dynamic>{
    'version': 'fixture-v1',
    'body': 'TEST ONLY',
    'document_url': 'https://example.test/terms',
    'document_sha256': 'a' * 64,
    'accepted_at': null,
  };
  test(
    'terms parser fails closed on invalid timestamp or insecure document',
    () {
      expect(ServiceTerms.fromRow(row).accepted, isFalse);
      expect(
        () => ServiceTerms.fromRow({...row, 'accepted_at': 'bad'}),
        throwsFormatException,
      );
      expect(
        () => ServiceTerms.fromRow({
          ...row,
          'document_url': 'http://example.test',
        }),
        throwsFormatException,
      );
    },
  );
  test('acceptance sends only displayed version and account switches reject response', () async {
    late TermsAdapter adapter;
    var switchAccount = false;
    var offline = false;
    final client = SupabaseClient(
      'https://example.supabase.co',
      'public-test',
      httpClient: MockClient((request) async {
        if (offline) throw StateError('offline');
        if (request.url.path.endsWith('accept_service_terms')) {
          expect(jsonDecode(request.body), {'displayed_version': 'fixture-v1'});
          if (switchAccount) adapter.uid = 'account-b';
          return http.Response(
            jsonEncode('2026-10-11T08:00:00Z'),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }
        if (switchAccount) adapter.uid = 'account-b';
        return http.Response(
          jsonEncode([row]),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    adapter = TermsAdapter(client);
    expect((await adapter.currentTerms())!.accepted, isFalse);
    await adapter.acceptTerms('fixture-v1');
    // No optimistic or persisted local acceptance after a successful RPC.
    expect((await adapter.currentTerms())!.accepted, isFalse);
    switchAccount = true;
    await expectLater(
      adapter.acceptTerms('fixture-v1'),
      throwsA(isA<GroupAccessError>()),
    );
    adapter.uid = 'account-a';
    await expectLater(adapter.currentTerms(), throwsA(isA<GroupAccessError>()));
    switchAccount = false;
    offline = true;
    await expectLater(adapter.currentTerms(), throwsStateError);
    adapter.dispose();
    await client.dispose();
  });
}
