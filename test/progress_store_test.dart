import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hac_umre_sesli_rehber/guide_catalog.dart';
import 'package:hac_umre_sesli_rehber/progress_store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

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
      firstStepId: 'draft-u01-01',
      contentVersion: 'draft-1',
    );
    final journey = await store.openOrCreateUmrahSession(
      mode: GuideMode.journey,
      firstStepId: 'draft-u01-01',
      contentVersion: 'draft-1',
    );
    expect(learning.id, isNot(journey.id));

    await store.saveCurrentStep(learning.id, 'draft-u01-02');
    await store.setStepMarked(learning.id, 'draft-u01-01', true);
    expect(await store.readMarkedStepIds(learning.id), {'draft-u01-01'});
    expect(await store.readMarkedStepIds(journey.id), isEmpty);

    final resumedLearning = await store.openOrCreateUmrahSession(
      mode: GuideMode.learning,
      firstStepId: 'draft-u01-01',
      contentVersion: 'draft-2',
    );
    expect(resumedLearning.id, learning.id);
    expect(resumedLearning.currentStepId, 'draft-u01-02');
    expect(resumedLearning.contentVersion, 'draft-1');

    final newJourney = await store.startNewUmrahJourney(
      firstStepId: 'draft-u01-01',
      contentVersion: 'draft-2',
    );
    expect(newJourney.id, isNot(journey.id));
    expect(await store.readMarkedStepIds(newJourney.id), isEmpty);
    await store.setStepMarked(learning.id, 'draft-u01-01', false);
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
      firstStepId: 'draft-u01-01',
      contentVersion: 'draft-3',
    );
    expect(afterRestart.currentStepId, 'draft-u01-02');
    expect(afterRestart.contentVersion, 'draft-1');
  });
}
