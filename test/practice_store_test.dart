import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hac_umre_sesli_rehber/guide_catalog.dart';
import 'package:hac_umre_sesli_rehber/progress_store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  test(
    'v8 yükseltmesi rehber kaydını korur ve ayrı prova tabloları ekler',
    () async {
      final directory = await Directory.systemTemp.createTemp('practice_v8_');
      final dbPath = '${directory.path}/sesli_rehber.db';
      final old = await databaseFactoryFfi.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 8,
          onCreate: (db, _) async {
            await db.execute('''CREATE TABLE guide_sessions (
            id INTEGER PRIMARY KEY AUTOINCREMENT, guide_type TEXT NOT NULL,
            mode TEXT NOT NULL, profile TEXT NOT NULL DEFAULT '',
            current_step_id TEXT NOT NULL, content_version TEXT NOT NULL,
            created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL)''');
            await db.insert('guide_sessions', {
              'guide_type': 'umrah',
              'mode': 'journey',
              'profile': '',
              'current_step_id': 'U06.2',
              'content_version': 'old-content',
              'created_at': 1,
              'updated_at': 2,
            });
          },
        ),
      );
      await old.close();
      final store = ProgressStore(
        factory: databaseFactoryFfi,
        databasePath: dbPath,
      );
      addTearDown(() async {
        await store.close();
        await directory.delete(recursive: true);
      });
      expect((await store.readSession(1))?.currentStepId, 'U06.2');
      final practice = await store.startPracticeSession(
        type: GuideType.umrah,
        profile: null,
        contentVersion: 'new-content',
        firstStepId: 'U01.1',
      );
      expect(practice.id, 1);
      expect((await store.readSession(1))?.contentVersion, 'old-content');
    },
  );

  test(
    'prova işaretleri ve sayaçları gerçek rehberden ayrı, kalıcı ve idempotent',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'practice_isolation_',
      );
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
      final journey = await store.startNewJourney(
        type: GuideType.umrah,
        profile: null,
        firstStepId: 'U01.1',
        contentVersion: 'v1',
      );
      final practice = await store.startPracticeSession(
        type: GuideType.umrah,
        profile: null,
        contentVersion: 'v1',
        firstStepId: 'U06.2',
        sectionGroupId: 'U06',
      );
      await store.setPracticeStepMarked(practice.id, 'U06.2', true);
      expect(await store.readMarkedStepIds(journey.id), isEmpty);
      expect(await store.readPracticeMarkedStepIds(practice.id), {'U06.2'});
      expect(
        await store.applyPracticeCounter(
          sessionId: practice.id,
          stepId: 'U06.2',
          actionToken: 'one',
          action: 'increment',
          target: 2,
        ),
        1,
      );
      expect(
        await store.applyPracticeCounter(
          sessionId: practice.id,
          stepId: 'U06.2',
          actionToken: 'one',
          action: 'increment',
          target: 2,
        ),
        1,
      );
      expect(
        await store.applyPracticeCounter(
          sessionId: practice.id,
          stepId: 'U06.2',
          actionToken: 'two',
          action: 'increment',
          target: 2,
        ),
        2,
      );
      expect(
        await store.applyPracticeCounter(
          sessionId: practice.id,
          stepId: 'U06.2',
          actionToken: 'three',
          action: 'increment',
          target: 2,
        ),
        2,
      );
      expect(await store.readCounterCount(journey.id, 'tawaf'), 0);
      await expectLater(
        store.applyPracticeCounter(
          sessionId: practice.id,
          stepId: 'U06.2',
          actionToken: 'one',
          action: 'undo',
          target: 2,
        ),
        throwsStateError,
      );
      await expectLater(
        store.applyPracticeCounter(
          sessionId: practice.id,
          stepId: 'U06.2',
          actionToken: 'one',
          action: 'increment',
          target: 3,
        ),
        throwsStateError,
      );
      expect(
        await store.applyPracticeCounter(
          sessionId: practice.id,
          stepId: 'U06.2',
          actionToken: 'undo-one',
          action: 'undo',
          target: 2,
        ),
        1,
      );
      expect(
        await store.applyPracticeCounter(
          sessionId: practice.id,
          stepId: 'U06.2',
          actionToken: 'reset-one',
          action: 'reset',
          target: 2,
        ),
        0,
      );
      expect(await store.readPracticeCounter(practice.id, 'U06.2'), 0);
      await store.updatePracticeSession(
        practice.id,
        currentStepId: 'U06.3',
        phase: PracticePhase.paused,
      );
      await store.close();
      reopened = ProgressStore(
        factory: databaseFactoryFfi,
        databasePath: dbPath,
      );
      expect(
        (await reopened.readLatestPracticeSession())?.currentStepId,
        'U06.3',
      );
      expect(
        (await reopened.readLatestPracticeSession())?.phase,
        PracticePhase.paused,
      );
      expect(await reopened.readPracticeCounter(practice.id, 'U06.2'), 0);
      expect(await reopened.readPracticeMarkedStepIds(practice.id), {'U06.2'});
    },
  );

  test('Hac profili zorunlu, Umre profili yasak', () async {
    final directory = await Directory.systemTemp.createTemp(
      'practice_profile_',
    );
    final store = ProgressStore(
      factory: databaseFactoryFfi,
      databasePath: '${directory.path}/sesli_rehber.db',
    );
    addTearDown(() async {
      await store.close();
      await directory.delete(recursive: true);
    });
    await expectLater(
      store.startPracticeSession(
        type: GuideType.hajj,
        profile: null,
        contentVersion: 'v1',
        firstStepId: 'H01.1',
      ),
      throwsArgumentError,
    );
    final hajj = await store.startPracticeSession(
      type: GuideType.hajj,
      profile: HajjProfile.ifrad,
      contentVersion: 'v1',
      firstStepId: 'H01.1',
    );
    expect(hajj.profile, HajjProfile.ifrad);
  });
}
