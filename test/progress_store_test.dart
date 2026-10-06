import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hac_umre_sesli_rehber/group_sync.dart';
import 'package:hac_umre_sesli_rehber/guide_catalog.dart';
import 'package:hac_umre_sesli_rehber/progress_store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  test('v3 oturum, işaret ve sayaç verileri v4 kimliklerine taşınır', () async {
    final directory = await Directory.systemTemp.createTemp('umre_migrate_');
    final dbPath = '${directory.path}/sesli_rehber.db';
    final old = await databaseFactoryFfi.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 3,
        onCreate: (db, _) async {
          await db.execute(
            'CREATE TABLE app_state (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
          );
          await db.execute(
            'CREATE TABLE guide_sessions (id INTEGER PRIMARY KEY AUTOINCREMENT, guide_type TEXT NOT NULL, mode TEXT NOT NULL, current_step_id TEXT NOT NULL, content_version TEXT NOT NULL, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL)',
          );
          await db.execute(
            'CREATE TABLE step_marks (session_id INTEGER NOT NULL, step_id TEXT NOT NULL, marked_at INTEGER NOT NULL, PRIMARY KEY (session_id, step_id))',
          );
          await db.execute(
            'CREATE TABLE counter_state (session_id INTEGER NOT NULL, counter_key TEXT NOT NULL, count INTEGER NOT NULL, updated_at INTEGER NOT NULL, PRIMARY KEY (session_id, counter_key))',
          );
          await db.execute(
            'CREATE TABLE counter_events (id INTEGER PRIMARY KEY AUTOINCREMENT, session_id INTEGER NOT NULL, counter_key TEXT NOT NULL, action_token TEXT NOT NULL UNIQUE, action TEXT NOT NULL, value_after INTEGER NOT NULL, created_at INTEGER NOT NULL)',
          );
        },
      ),
    );
    final id = await old.insert('guide_sessions', {
      'guide_type': 'umrah',
      'mode': 'journey',
      'current_step_id': 'draft-u06-02',
      'content_version': 'draft-1',
      'created_at': 10,
      'updated_at': 20,
    });
    await old.insert('step_marks', {
      'session_id': id,
      'step_id': 'draft-u06-02',
      'marked_at': 11,
    });
    await old.insert('counter_state', {
      'session_id': id,
      'counter_key': 'tawaf',
      'count': 4,
      'updated_at': 12,
    });
    await old.close();
    final store = ProgressStore(
      factory: databaseFactoryFfi,
      databasePath: dbPath,
    );
    addTearDown(() async {
      await store.close();
      await directory.delete(recursive: true);
    });
    final session = await store.readSession(id);
    expect(session?.currentStepId, 'U06.2');
    expect(session?.profile, isNull);
    expect(await store.readMarkedStepIds(id), {'U06.2'});
    expect(await store.readCounterCount(id, 'tawaf'), 4);
  });

  test('hac profilleri ve kullanım biçimleri ayrı oturumdur', () async {
    final directory = await Directory.systemTemp.createTemp('hajj_store_');
    final store = ProgressStore(
      factory: databaseFactoryFfi,
      databasePath: '${directory.path}/sesli_rehber.db',
    );
    addTearDown(() async {
      await store.close();
      await directory.delete(recursive: true);
    });
    final ifrad = await store.openOrCreateSession(
      type: GuideType.hajj,
      mode: GuideMode.learning,
      profile: HajjProfile.ifrad,
      firstStepId: 'H01.1',
      contentVersion: 'v1',
    );
    final temettu = await store.openOrCreateSession(
      type: GuideType.hajj,
      mode: GuideMode.learning,
      profile: HajjProfile.temettu,
      firstStepId: 'H01.1',
      contentVersion: 'v1',
    );
    final journey = await store.openOrCreateSession(
      type: GuideType.hajj,
      mode: GuideMode.journey,
      profile: HajjProfile.ifrad,
      firstStepId: 'H01.1',
      contentVersion: 'v1',
    );
    expect({ifrad.id, temettu.id, journey.id}, hasLength(3));
    await store.saveCurrentStep(ifrad.id, 'H01.2');
    expect((await store.readSession(ifrad.id))?.currentStepId, 'H01.2');
    expect((await store.readSession(temettu.id))?.currentStepId, 'H01.1');
    expect((await store.readSession(journey.id))?.currentStepId, 'H01.1');
  });

  test('cemarat sayaçları yolculuk, gün ve hedef bazında ayrılır', () async {
    final directory = await Directory.systemTemp.createTemp('jamarat_store_');
    final dbPath = '${directory.path}/sesli_rehber.db';
    final store = ProgressStore(
      factory: databaseFactoryFfi,
      databasePath: dbPath,
    );
    ProgressStore? reopened;
    addTearDown(() async {
      await store.close();
      await reopened?.close();
      await directory.delete(recursive: true);
    });

    final firstJourney = await store.startNewJourney(
      type: GuideType.hajj,
      profile: HajjProfile.temettu,
      firstStepId: 'H01.1',
      contentVersion: 'draft-1',
    );
    final secondJourney = await store.startNewJourney(
      type: GuideType.hajj,
      profile: HajjProfile.temettu,
      firstStepId: 'H01.1',
      contentVersion: 'draft-1',
    );
    final firstTarget = await store.createJamaratCounter(
      sessionId: firstJourney.id,
      dayLabel: 'Gün notu A',
      targetLabel: 'Hedef 1',
    );
    final secondTarget = await store.createJamaratCounter(
      sessionId: firstJourney.id,
      dayLabel: 'Gün notu A',
      targetLabel: 'Hedef 2',
    );
    final otherJourneyTarget = await store.createJamaratCounter(
      sessionId: secondJourney.id,
      dayLabel: 'Gün notu A',
      targetLabel: 'Hedef 1',
    );
    final duplicate = await store.createJamaratCounter(
      sessionId: firstJourney.id,
      dayLabel: 'Gün notu A',
      targetLabel: 'Hedef 1',
    );
    expect(duplicate.id, firstTarget.id);

    expect(
      await store.incrementCounter(
        firstJourney.id,
        firstTarget.counterKey,
        'jamarat-1',
      ),
      1,
    );
    expect(
      await store.incrementCounter(
        firstJourney.id,
        firstTarget.counterKey,
        'jamarat-1',
      ),
      1,
    );
    expect(
      await store.readCounterCount(firstJourney.id, secondTarget.counterKey),
      0,
    );
    expect(
      await store.readCounterCount(
        secondJourney.id,
        otherJourneyTarget.counterKey,
      ),
      0,
    );
    await expectLater(
      store.readCounterCount(secondJourney.id, firstTarget.counterKey),
      throwsStateError,
    );

    await store.close();
    final reopenedStore = ProgressStore(
      factory: databaseFactoryFfi,
      databasePath: dbPath,
    );
    reopened = reopenedStore;
    final contexts = await reopenedStore.readJamaratCounters(firstJourney.id);
    expect(contexts.map((item) => item.label), [
      'Gün notu A · Hedef 1',
      'Gün notu A · Hedef 2',
    ]);
    expect(contexts.map((item) => item.count), [1, 0]);
  });

  test('gezi favorileri dinî ilerlemeden ayrı saklanır', () async {
    final directory = await Directory.systemTemp.createTemp('travel_store_');
    final store = ProgressStore(
      factory: databaseFactoryFfi,
      databasePath: '${directory.path}/sesli_rehber.db',
    );
    addTearDown(() async {
      await store.close();
      await directory.delete(recursive: true);
    });
    final session = await store.openOrCreateUmrahSession(
      mode: GuideMode.journey,
      firstStepId: 'U01.1',
      contentVersion: 'draft-1',
    );
    await store.setTravelFavorite('poi', 'TEST-POI-1', true);
    await store.setTravelFavorite('route', 'TEST-ROUTE-1', true);
    expect(await store.readTravelFavoriteIds('poi'), {'TEST-POI-1'});
    expect(await store.readTravelFavoriteIds('route'), {'TEST-ROUTE-1'});
    expect((await store.readSession(session.id))?.currentStepId, 'U01.1');
    expect(await store.readCounterCount(session.id, 'tawaf'), 0);
    await store.setTravelFavorite('poi', 'TEST-POI-1', false);
    expect(await store.readTravelFavoriteIds('poi'), isEmpty);
  });

  test('grup mesaj kuyruğu istemci kimliğiyle yinelenmeyi önler', () async {
    final directory = await Directory.systemTemp.createTemp('outbox_store_');
    final store = ProgressStore(
      factory: databaseFactoryFfi,
      databasePath: '${directory.path}/sesli_rehber.db',
    );
    addTearDown(() async {
      await store.close();
      await directory.delete(recursive: true);
    });

    final first = await store.enqueueGroupMessage(
      clientId: 'client-1',
      groupId: 'group-1',
      body: 'Teknik test mesajı',
    );
    final duplicate = await store.enqueueGroupMessage(
      clientId: 'client-1',
      groupId: 'group-1',
      body: 'Teknik test mesajı',
    );
    expect(duplicate.createdAt, first.createdAt);
    expect(await store.readGroupOutbox(), hasLength(1));
    await expectLater(
      store.enqueueGroupMessage(
        clientId: 'client-1',
        groupId: 'group-1',
        body: 'Farklı içerik',
      ),
      throwsStateError,
    );

    await store.markGroupMessageAttempt(
      clientId: 'client-1',
      status: MessageOutboxStatus.failed,
      error: 'Çevrimdışı',
    );
    final failed = (await store.readGroupOutbox(
      status: MessageOutboxStatus.failed,
    )).single;
    expect(failed.attemptCount, 1);
    expect(failed.lastError, 'Çevrimdışı');
    await store.markGroupMessageAttempt(
      clientId: 'client-1',
      status: MessageOutboxStatus.sent,
    );
    final sent = (await store.readGroupOutbox()).single;
    expect(sent.status, MessageOutboxStatus.sent);
    expect(sent.attemptCount, 2);
    expect(sent.lastError, isNull);
  });

  test(
    'konum paylaşımı varsayılan kapalıdır, sürelidir ve durdurulur',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'location_store_',
      );
      final store = ProgressStore(
        factory: databaseFactoryFfi,
        databasePath: '${directory.path}/sesli_rehber.db',
      );
      addTearDown(() async {
        await store.close();
        await directory.delete(recursive: true);
      });
      final startedAt = DateTime.utc(2026, 10, 6, 9);
      expect(await store.readLocationShare('group-1'), isNull);
      final share = await store.startLocationShare(
        groupId: 'group-1',
        mode: LocationShareMode.trip,
        duration: const Duration(hours: 2),
        now: startedAt,
      );
      expect(share.isActiveAt(startedAt.add(const Duration(hours: 1))), isTrue);
      expect(
        share.isActiveAt(startedAt.add(const Duration(hours: 3))),
        isFalse,
      );
      await store.stopLocationShare(
        'group-1',
        now: startedAt.add(const Duration(minutes: 30)),
      );
      final stopped = await store.readLocationShare('group-1');
      expect(stopped?.enabled, isFalse);
      expect(
        stopped?.isActiveAt(startedAt.add(const Duration(minutes: 31))),
        isFalse,
      );

      final update = SharedLocationUpdate(
        latitude: 21.4,
        longitude: 39.8,
        accuracyMeters: 12,
        measuredAt: startedAt,
        sentAt: startedAt.add(const Duration(seconds: 10)),
      );
      expect(
        update.isStaleAt(startedAt.add(const Duration(minutes: 6))),
        isTrue,
      );
    },
  );

  test('v1 kayıt korunur; öğrenme ve yolculuk ilerlemesi ayrılır', () async {
    final directory = await Directory.systemTemp.createTemp('umre_store_test_');
    final dbPath = '${directory.path}/sesli_rehber.db';

    final oldDatabase = await databaseFactoryFfi.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (database, version) async {
          await database.execute(
            'CREATE TABLE app_state (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
          );
        },
      ),
    );
    await oldDatabase.insert('app_state', {
      'key': 'last_step_id',
      'value': 'DEMO-001',
    });
    await oldDatabase.close();

    final store = ProgressStore(
      factory: databaseFactoryFfi,
      databasePath: dbPath,
    );
    ProgressStore? reopened;
    addTearDown(() async {
      await store.close();
      await reopened?.close();
      await directory.delete(recursive: true);
    });

    expect(await store.readLastStepId(), 'DEMO-001');
    final learning = await store.openOrCreateUmrahSession(
      mode: GuideMode.learning,
      firstStepId: 'U01.1',
      contentVersion: 'draft-1',
    );
    final journey = await store.openOrCreateUmrahSession(
      mode: GuideMode.journey,
      firstStepId: 'U01.1',
      contentVersion: 'draft-1',
    );
    expect(learning.id, isNot(journey.id));

    await store.saveCurrentStep(learning.id, 'U01.2');
    await store.setStepMarked(learning.id, 'U01.1', true);
    expect(await store.readMarkedStepIds(learning.id), {'U01.1'});
    expect(await store.readMarkedStepIds(journey.id), isEmpty);

    final resumedLearning = await store.openOrCreateUmrahSession(
      mode: GuideMode.learning,
      firstStepId: 'U01.1',
      contentVersion: 'draft-2',
    );
    expect(resumedLearning.id, learning.id);
    expect(resumedLearning.currentStepId, 'U01.2');
    expect(resumedLearning.contentVersion, 'draft-1');

    final newJourney = await store.startNewUmrahJourney(
      firstStepId: 'U01.1',
      contentVersion: 'draft-2',
    );
    expect(newJourney.id, isNot(journey.id));
    expect(await store.readMarkedStepIds(newJourney.id), isEmpty);
    await store.setStepMarked(learning.id, 'U01.1', false);
    expect(await store.readMarkedStepIds(learning.id), isEmpty);

    expect(await store.readCounterCount(journey.id, 'tawaf'), 0);
    expect(await store.incrementCounter(journey.id, 'tawaf', 'tap-1'), 1);
    expect(await store.incrementCounter(journey.id, 'tawaf', 'tap-1'), 1);
    expect(await store.incrementCounter(journey.id, 'tawaf', 'tap-2'), 2);
    expect(await store.undoCounter(journey.id, 'tawaf', 'undo-1'), 1);
    expect(await store.readCounterCount(journey.id, 'say'), 0);
    expect(await store.readCounterCount(newJourney.id, 'tawaf'), 0);
    expect(await store.resetCounter(journey.id, 'tawaf', 'reset-1'), 0);
    expect(await store.readCounterCount(journey.id, 'tawaf'), 0);
    for (var index = 0; index < 9; index++) {
      await store.incrementCounter(journey.id, 'tawaf', 'cap-$index');
    }
    expect(await store.readCounterCount(journey.id, 'tawaf'), 7);
    await expectLater(
      store.incrementCounter(journey.id, 'say', 'tap-1'),
      throwsStateError,
    );

    await store.close();
    final reopenedStore = ProgressStore(
      factory: databaseFactoryFfi,
      databasePath: dbPath,
    );
    reopened = reopenedStore;
    expect(await reopenedStore.readCounterCount(journey.id, 'tawaf'), 7);
    expect(await reopenedStore.readCounterCount(newJourney.id, 'tawaf'), 0);
    final afterRestart = await reopenedStore.openOrCreateUmrahSession(
      mode: GuideMode.learning,
      firstStepId: 'U01.1',
      contentVersion: 'draft-3',
    );
    expect(afterRestart.currentStepId, 'U01.2');
    expect(afterRestart.contentVersion, 'draft-1');
  });
}
