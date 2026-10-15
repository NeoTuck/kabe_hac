import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hac_umre_sesli_rehber/local_data_screen.dart';
import 'package:hac_umre_sesli_rehber/push_service.dart';

import 'test_fakes.dart';

const _userId = '22222222-2222-4222-8222-222222222222';

class _LocalStore extends MemoryGuideStore {
  int clearCount = 0;

  @override
  Future<void> clearLocalRecords() async {
    clearCount++;
    appValues.remove('push_opt_in_user');
  }
}

class _PushSource extends PushTokenSource {
  int deleteCount = 0;
  String? token = 'test-token';
  final _refreshes = StreamController<String>.broadcast();

  @override
  Future<String?> requestToken() async => 'test-token';

  @override
  Future<String?> currentToken() async => token;

  @override
  Stream<String> get tokenRefreshes => _refreshes.stream;

  Future<void> close() => _refreshes.close();

  @override
  Future<void> deleteToken() async {
    deleteCount++;
  }
}

class _PushRemote extends PushTokenRemote {
  bool failRevoke = false;
  final revoked = <String>[];

  @override
  Future<void> register(String userId, String platform, String token) async {}

  @override
  Future<void> revoke(String userId, String token) async {
    if (failRevoke) throw StateError('offline');
    revoked.add(token);
  }
}

Future<void> _confirmClear(WidgetTester tester) async {
  await tester.tap(find.text('Yerel kayıtları sil').first);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Yerel kayıtları sil').last);
  await tester.pump();
  // Subscription cancellation runs outside the fake frame clock. Wait for the
  // operation to finish before asserting its remote and local side effects.
  for (var attempt = 0; attempt < 20; attempt++) {
    await tester.runAsync(() async {
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pump();
    if (find.text('Siliniyor').evaluate().isEmpty) break;
  }
  expect(find.text('Siliniyor'), findsNothing);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('yerel silmeden önce push tokenı geri alınır', (tester) async {
    final store = _LocalStore();
    final source = _PushSource();
    final remote = _PushRemote();
    final push = PushTokenCoordinator(
      source: source,
      remote: remote,
      currentUserId: () => _userId,
      platform: 'android',
      store: store,
    );
    addTearDown(() async {
      push.dispose();
      await source.close();
    });
    await push.enable();

    await tester.pumpWidget(
      MaterialApp(
        home: LocalDataScreen(store: store, push: push),
      ),
    );
    await _confirmClear(tester);

    expect(remote.revoked, ['test-token']);
    expect(source.deleteCount, 1);
    expect(store.clearCount, 1);
    expect(store.appValues.containsKey('push_opt_in_user'), isFalse);
    expect(find.text('Cihazdaki kayıtlar silindi.'), findsOneWidget);
  });

  testWidgets('token geri alınamazsa kayıtlar yerinde kalır', (tester) async {
    final store = _LocalStore();
    final remote = _PushRemote()..failRevoke = true;
    final source = _PushSource();
    final push = PushTokenCoordinator(
      source: source,
      remote: remote,
      currentUserId: () => _userId,
      platform: 'android',
      store: store,
    );
    addTearDown(() async {
      push.dispose();
      await source.close();
    });
    await push.enable();

    await tester.pumpWidget(
      MaterialApp(
        home: LocalDataScreen(store: store, push: push),
      ),
    );
    await _confirmClear(tester);

    expect(store.clearCount, 0);
    expect(store.appValues['push_opt_in_user'], _userId);
    expect(push.enabled, isTrue);
    expect(find.textContaining('Kayıtlar silinemedi'), findsOneWidget);
  });

  testWidgets('push servisi yoksa kayıtlı opt-in sessizce unutulmaz', (
    tester,
  ) async {
    final store = _LocalStore();
    await store.saveAppValue('push_opt_in_user', _userId);

    await tester.pumpWidget(MaterialApp(home: LocalDataScreen(store: store)));
    await _confirmClear(tester);

    expect(store.clearCount, 0);
    expect(store.appValues['push_opt_in_user'], _userId);
    expect(find.textContaining('Bildirim kaydı kapatılamıyor'), findsOneWidget);
  });

  testWidgets('token bulunamazsa uzak kayıt unutulmadan silme durur', (
    tester,
  ) async {
    final store = _LocalStore();
    await store.saveAppValue('push_opt_in_user', _userId);
    final source = _PushSource()..token = null;
    final push = PushTokenCoordinator(
      source: source,
      remote: _PushRemote(),
      currentUserId: () => _userId,
      platform: 'android',
      store: store,
    );
    addTearDown(() async {
      push.dispose();
      await source.close();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: LocalDataScreen(store: store, push: push),
      ),
    );
    await _confirmClear(tester);

    expect(store.clearCount, 0);
    expect(store.appValues['push_opt_in_user'], _userId);
    expect(source.deleteCount, 0);
  });

  testWidgets('başka hesaba ait push kaydı silme sırasında korunur', (
    tester,
  ) async {
    final store = _LocalStore();
    await store.saveAppValue('push_opt_in_user', _userId);
    final source = _PushSource();
    final push = PushTokenCoordinator(
      source: source,
      remote: _PushRemote(),
      currentUserId: () => '33333333-3333-4333-8333-333333333333',
      platform: 'android',
      store: store,
    );
    addTearDown(() async {
      push.dispose();
      await source.close();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: LocalDataScreen(store: store, push: push),
      ),
    );
    await _confirmClear(tester);

    expect(store.clearCount, 0);
    expect(store.appValues['push_opt_in_user'], _userId);
    expect(find.textContaining('Bildirim kaydı kapatılamıyor'), findsOneWidget);
  });
}
