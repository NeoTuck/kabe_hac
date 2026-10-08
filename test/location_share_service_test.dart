import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hac_umre_sesli_rehber/group_sync.dart';
import 'package:hac_umre_sesli_rehber/location_share_service.dart';
import 'package:hac_umre_sesli_rehber/progress_store.dart';

const groupId = '11111111-1111-4111-8111-111111111111';
const userId = '22222222-2222-4222-8222-222222222222';

class FakeLocationStore extends ProgressStore {
  LocalLocationShare? value;

  @override
  Future<LocalLocationShare?> readLocationShare(String groupId) async => value;

  @override
  Future<LocalLocationShare> startLocationShare({
    required String groupId,
    required LocationShareMode mode,
    required Duration duration,
    DateTime? now,
  }) async {
    final start = now ?? DateTime.now();
    return value = LocalLocationShare(
      groupId: groupId,
      mode: mode,
      enabled: true,
      startedAt: start,
      endsAt: start.add(duration),
    );
  }

  @override
  Future<void> stopLocationShare(String groupId, {DateTime? now}) async {
    final old = value;
    if (old == null) return;
    value = LocalLocationShare(
      groupId: old.groupId,
      mode: old.mode,
      enabled: false,
      startedAt: old.startedAt,
      endsAt: old.endsAt,
      stoppedAt: now ?? DateTime.now(),
    );
  }
}

class FakeLocationReader extends DeviceLocationReader {
  FakeLocationReader(this.result);
  Future<SharedLocationUpdate> Function() result;
  @override
  Future<SharedLocationUpdate> measure() => result();
}

class FakeLocationRemote extends LocationShareRemote {
  int opens = 0;
  int sends = 0;
  int stops = 0;
  bool failStop = false;
  Completer<void>? sendGate;
  List<RecentSharedLocation> recent = [];

  @override
  Future<String> open(String groupId, String userId, DateTime endsAt) async {
    opens++;
    return '33333333-3333-4333-8333-333333333333';
  }

  @override
  Future<void> send(
    String shareId,
    String userId,
    SharedLocationUpdate update,
  ) async {
    sends++;
    await sendGate?.future;
  }

  @override
  Future<void> stop(String groupId, String userId) async {
    stops++;
    if (failStop) throw StateError('offline');
  }

  @override
  Future<DateTime?> activeUntil(String groupId, String userId) async => null;

  @override
  Future<List<RecentSharedLocation>> recentForGroup(
    String groupId,
    String userId,
  ) async => recent;
}

void main() {
  SharedLocationUpdate fresh() {
    final now = DateTime.now().toUtc();
    return SharedLocationUpdate(
      latitude: 21.4,
      longitude: 39.8,
      accuracyMeters: 12,
      measuredAt: now.subtract(const Duration(seconds: 1)),
      sentAt: now,
    );
  }

  test(
    'one-time measurement sends only after local consent; stop revokes',
    () async {
      final store = FakeLocationStore();
      final remote = FakeLocationRemote();
      final coordinator = LocationShareCoordinator(
        store: store,
        reader: FakeLocationReader(() async => fresh()),
        remote: remote,
        currentUserId: () => userId,
      );
      final measured = await coordinator.shareOnce(groupId);
      expect(measured.accuracyMeters, 12);
      expect(remote.opens, 1);
      expect(remote.sends, 1);
      expect(store.value!.isActiveAt(DateTime.now()), isTrue);
      await coordinator.stop(groupId);
      expect(store.value!.enabled, isFalse);
      expect(remote.stops, 1);
    },
  );

  test('denied permission or stale fix never opens a remote share', () async {
    final remote = FakeLocationRemote();
    final store = FakeLocationStore();
    final denied = LocationShareCoordinator(
      store: store,
      reader: FakeLocationReader(
        () async => throw const LocationShareException('denied'),
      ),
      remote: remote,
      currentUserId: () => userId,
    );
    await expectLater(
      denied.shareOnce(groupId),
      throwsA(isA<LocationShareException>()),
    );
    final stale = LocationShareCoordinator(
      store: store,
      reader: FakeLocationReader(() async {
        final update = fresh();
        return SharedLocationUpdate(
          latitude: update.latitude,
          longitude: update.longitude,
          accuracyMeters: update.accuracyMeters,
          measuredAt: update.measuredAt.subtract(const Duration(minutes: 10)),
          sentAt: update.sentAt,
        );
      }),
      remote: remote,
      currentUserId: () => userId,
    );
    await expectLater(
      stale.shareOnce(groupId),
      throwsA(isA<LocationShareException>()),
    );
    expect(remote.opens, 0);
    expect(store.value, isNull);
  });

  test(
    'leaving screen during GPS request cancels before network write',
    () async {
      final gate = Completer<SharedLocationUpdate>();
      final remote = FakeLocationRemote();
      final coordinator = LocationShareCoordinator(
        store: FakeLocationStore(),
        reader: FakeLocationReader(() => gate.future),
        remote: remote,
        currentUserId: () => userId,
      );
      final pending = coordinator.shareOnce(groupId);
      coordinator.cancelPending();
      gate.complete(fresh());
      await expectLater(pending, throwsA(isA<LocationShareException>()));
      expect(remote.opens, 0);
    },
  );

  test('server revocation failure still disables local consent', () async {
    final store = FakeLocationStore();
    final remote = FakeLocationRemote()..failStop = true;
    final coordinator = LocationShareCoordinator(
      store: store,
      reader: FakeLocationReader(() async => fresh()),
      remote: remote,
      currentUserId: () => userId,
    );
    await coordinator.shareOnce(groupId);
    await expectLater(coordinator.stop(groupId), throwsStateError);
    expect(store.value!.enabled, isFalse);
  });

  test(
    'cancelling while send is pending never reports successful sharing',
    () async {
      final store = FakeLocationStore();
      final gate = Completer<void>();
      final remote = FakeLocationRemote()..sendGate = gate;
      final coordinator = LocationShareCoordinator(
        store: store,
        reader: FakeLocationReader(() async => fresh()),
        remote: remote,
        currentUserId: () => userId,
      );
      final pending = coordinator.shareOnce(groupId);
      while (remote.sends == 0) {
        await Future<void>.delayed(Duration.zero);
      }
      coordinator.cancelPending();
      gate.complete();
      await expectLater(pending, throwsA(isA<LocationShareException>()));
      expect(store.value!.enabled, isFalse);
      expect(remote.stops, 1);
    },
  );

  test('manager view hides expired, stale and own locations', () async {
    final now = DateTime.now().toUtc();
    final remote = FakeLocationRemote()
      ..recent = [
        RecentSharedLocation(
          userId: '33333333-3333-4333-8333-333333333333',
          update: fresh(),
          endsAt: now.add(const Duration(minutes: 1)),
        ),
        RecentSharedLocation(
          userId: userId,
          update: fresh(),
          endsAt: now.add(const Duration(minutes: 1)),
        ),
        RecentSharedLocation(
          userId: '44444444-4444-4444-8444-444444444444',
          update: fresh(),
          endsAt: now.subtract(const Duration(seconds: 1)),
        ),
        RecentSharedLocation(
          userId: '55555555-5555-4555-8555-555555555555',
          update: SharedLocationUpdate(
            latitude: 21.4,
            longitude: 39.8,
            accuracyMeters: 12,
            measuredAt: now.subtract(const Duration(minutes: 6)),
            sentAt: now.subtract(const Duration(minutes: 6)),
          ),
          endsAt: now.add(const Duration(minutes: 1)),
        ),
      ];
    final coordinator = LocationShareCoordinator(
      store: FakeLocationStore(),
      reader: FakeLocationReader(() async => fresh()),
      remote: remote,
      currentUserId: () => userId,
    );

    final visible = await coordinator.recentForGroup(groupId);

    expect(visible.map((item) => item.userId), [
      '33333333-3333-4333-8333-333333333333',
    ]);
  });
}
