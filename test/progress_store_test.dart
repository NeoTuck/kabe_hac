import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
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
