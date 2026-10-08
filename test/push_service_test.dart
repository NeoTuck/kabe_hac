import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hac_umre_sesli_rehber/push_service.dart';

import 'test_fakes.dart';

const userId = '22222222-2222-4222-8222-222222222222';
const groupId = '11111111-1111-4111-8111-111111111111';

class FakePushSource extends PushTokenSource {
  final refreshes = StreamController<String>.broadcast();
  String? token = 'first-token';
  int requests = 0;
  int deletes = 0;
  @override
  Future<String?> requestToken() async {
    requests++;
    return token;
  }

  @override
  Future<String?> currentToken() async => token;

  @override
  Stream<String> get tokenRefreshes => refreshes.stream;

  @override
  Future<void> deleteToken() async {
    deletes++;
  }
}

class FakePushRemote extends PushTokenRemote {
  final registrations = <String>[];
  final revocations = <String>[];
  final secondRegistration = Completer<void>();
  bool failRevoke = false;

  @override
  Future<void> register(String userId, String platform, String token) async {
    registrations.add('$userId:$platform:$token');
    if (registrations.length == 2) secondRegistration.complete();
  }

  @override
  Future<void> revoke(String userId, String token) async {
    if (failRevoke) throw StateError('offline');
    revocations.add(token);
  }
}

void main() {
  test('missing runtime setup stays disabled', () {
    expect(PushRuntimeConfig.fromCompileTime(), isNull);
  });

  test(
    'opt-in, token refresh and logout revoke only this device token',
    () async {
      final source = FakePushSource();
      final remote = FakePushRemote();
      final store = MemoryGuideStore();
      final coordinator = PushTokenCoordinator(
        source: source,
        remote: remote,
        currentUserId: () => userId,
        platform: 'android',
        store: store,
      );
      addTearDown(() async {
        coordinator.dispose();
        await source.refreshes.close();
      });
      expect(source.requests, 0);
      await coordinator.enable();
      expect(coordinator.enabled, isTrue);
      expect(await store.readAppValue('push_opt_in_user'), userId);
      expect(remote.registrations, ['$userId:android:first-token']);
      source.refreshes.add('second-token');
      await remote.secondRegistration.future;
      await Future<void>.delayed(Duration.zero);
      expect(remote.revocations, ['first-token']);
      await coordinator.disable();
      expect(remote.revocations, ['first-token', 'second-token']);
      expect(source.deletes, 1);
      expect(coordinator.enabled, isFalse);
      expect(await store.readAppValue('push_opt_in_user'), '');
    },
  );

  test(
    'denied permission and remote revocation failure do not claim disabled',
    () async {
      final source = FakePushSource()..token = null;
      final remote = FakePushRemote();
      final coordinator = PushTokenCoordinator(
        source: source,
        remote: remote,
        currentUserId: () => userId,
        platform: 'ios',
        store: MemoryGuideStore(),
      );
      addTearDown(() async {
        coordinator.dispose();
        await source.refreshes.close();
      });
      await expectLater(coordinator.enable(), throwsA(isA<PushException>()));
      expect(remote.registrations, isEmpty);
      source.token = 'later-token';
      await coordinator.enable();
      remote.failRevoke = true;
      await expectLater(coordinator.disable(), throwsStateError);
      expect(coordinator.enabled, isTrue);
      expect(source.deletes, 0);
    },
  );

  test('previous opt-in resumes without another permission prompt', () async {
    final store = MemoryGuideStore();
    await store.saveAppValue('push_opt_in_user', userId);
    final source = FakePushSource();
    final remote = FakePushRemote();
    final coordinator = PushTokenCoordinator(
      source: source,
      remote: remote,
      currentUserId: () => userId,
      platform: 'android',
      store: store,
    );
    addTearDown(() async {
      coordinator.dispose();
      await source.refreshes.close();
    });
    await coordinator.resumeIfEnabled();
    expect(source.requests, 0);
    expect(coordinator.enabled, isTrue);
    expect(remote.registrations, ['$userId:android:first-token']);
  });

  test('saved opt-in is cleared when a different account is active', () async {
    final store = MemoryGuideStore();
    await store.saveAppValue('push_opt_in_user', userId);
    final source = FakePushSource();
    final remote = FakePushRemote();
    final coordinator = PushTokenCoordinator(
      source: source,
      remote: remote,
      currentUserId: () => '33333333-3333-4333-8333-333333333333',
      platform: 'android',
      store: store,
    );
    addTearDown(() async {
      coordinator.dispose();
      await source.refreshes.close();
    });

    await coordinator.resumeIfEnabled();

    expect(coordinator.enabled, isFalse);
    expect(source.deletes, 1);
    expect(remote.registrations, isEmpty);
    expect(await store.readAppValue('push_opt_in_user'), '');
  });

  test(
    'route accepts only known group event without trusting message text',
    () {
      final target = PushRouteTarget.parse({
        'group_id': groupId,
        'kind': 'message',
        'body': 'untrusted',
      });
      expect(target?.groupId, groupId);
      expect(target?.kind, 'message');
      expect(
        PushRouteTarget.parse({'group_id': '../../bad', 'kind': 'message'}),
        isNull,
      );
      expect(
        PushRouteTarget.parse({'group_id': groupId, 'kind': 'location'}),
        isNull,
      );
    },
  );
}
