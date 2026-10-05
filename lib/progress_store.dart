import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import 'guide_catalog.dart';

class GuideSession {
  const GuideSession({
    required this.id,
    required this.mode,
    required this.currentStepId,
    required this.contentVersion,
    this.type = GuideType.umrah,
    this.profile,
    this.updatedAt = 0,
  });

  final int id;
  final GuideMode mode;
  final String currentStepId;
  final String contentVersion;
  final GuideType type;
  final HajjProfile? profile;
  final int updatedAt;

  GuideSession copyWith({String? currentStepId}) => GuideSession(
    id: id,
    mode: mode,
    currentStepId: currentStepId ?? this.currentStepId,
    contentVersion: contentVersion,
    type: type,
    profile: profile,
    updatedAt: updatedAt,
  );
}

class ProgressStore {
  ProgressStore({this.factory, this.databasePath});

  final DatabaseFactory? factory;
  final String? databasePath;
  Future<Database>? _opening;

  Future<Database> get _database => _opening ??= _open();

  Future<Database> _open() async {
    final dbFactory = factory ?? databaseFactory;
    final dbPath =
        databasePath ??
        path.join(await dbFactory.getDatabasesPath(), 'sesli_rehber.db');
    return dbFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 4,
        onConfigure: (database) async {
          await database.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (database, version) async {
          await database.execute(
            'CREATE TABLE app_state (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
          );
          await _createGuideTables(database);
          await _createCounterTables(database);
        },
        onUpgrade: (database, oldVersion, newVersion) async {
          if (oldVersion < 2) await _createGuideTables(database);
          if (oldVersion < 3) await _createCounterTables(database);
          if (oldVersion >= 2 && oldVersion < 4) {
            await _upgradeToV4(database);
          }
        },
      ),
    );
  }

  Future<void> _createGuideTables(Database database) async {
    await database.execute('''
      CREATE TABLE guide_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        guide_type TEXT NOT NULL,
        mode TEXT NOT NULL,
        profile TEXT NOT NULL DEFAULT '',
        current_step_id TEXT NOT NULL,
        content_version TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    await database.execute('''
      CREATE TABLE step_marks (
        session_id INTEGER NOT NULL,
        step_id TEXT NOT NULL,
        marked_at INTEGER NOT NULL,
        PRIMARY KEY (session_id, step_id),
        FOREIGN KEY (session_id) REFERENCES guide_sessions(id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _upgradeToV4(Database database) async {
    await database.execute(
      "ALTER TABLE guide_sessions ADD COLUMN profile TEXT NOT NULL DEFAULT ''",
    );
    const groupCounts = [2, 3, 1, 1, 1, 3, 2, 1, 2, 2];
    for (var groupIndex = 0; groupIndex < groupCounts.length; groupIndex++) {
      final groupNumber = (groupIndex + 1).toString().padLeft(2, '0');
      for (var number = 1; number <= groupCounts[groupIndex]; number++) {
        final oldId =
            'draft-u$groupNumber-${number.toString().padLeft(2, '0')}';
        final newId = 'U$groupNumber.$number';
        await database.update(
          'guide_sessions',
          {'current_step_id': newId},
          where: 'guide_type = ? AND current_step_id = ?',
          whereArgs: ['umrah', oldId],
        );
        await database.rawInsert(
          '''
          INSERT OR IGNORE INTO step_marks (session_id, step_id, marked_at)
          SELECT session_id, ?, marked_at FROM step_marks WHERE step_id = ?
        ''',
          [newId, oldId],
        );
        await database.delete(
          'step_marks',
          where: 'step_id = ?',
          whereArgs: [oldId],
        );
      }
    }
  }

  Future<void> _createCounterTables(Database database) async {
    await database.execute('''
      CREATE TABLE counter_state (
        session_id INTEGER NOT NULL,
        counter_key TEXT NOT NULL,
        count INTEGER NOT NULL CHECK (count BETWEEN 0 AND 7),
        updated_at INTEGER NOT NULL,
        PRIMARY KEY (session_id, counter_key),
        FOREIGN KEY (session_id) REFERENCES guide_sessions(id) ON DELETE CASCADE
      )
    ''');
    await database.execute('''
      CREATE TABLE counter_events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id INTEGER NOT NULL,
        counter_key TEXT NOT NULL,
        action_token TEXT NOT NULL UNIQUE,
        action TEXT NOT NULL,
        value_after INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (session_id) REFERENCES guide_sessions(id) ON DELETE CASCADE
      )
    ''');
  }

  Future<String?> readLastStepId() async {
    return readAppValue('last_step_id');
  }

  Future<String?> readAppValue(String key) async {
    final database = await _database;
    final rows = await database.query(
      'app_state',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  Future<void> saveLastStepId(String stepId) async {
    await saveAppValue('last_step_id', stepId);
  }

  Future<void> saveAppValue(String key, String value) async {
    final database = await _database;
    await database.transaction((transaction) async {
      await transaction.insert('app_state', {
        'key': key,
        'value': value,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  GuideSession _sessionFromRow(Map<String, Object?> row) => GuideSession(
    id: row['id'] as int,
    mode: GuideMode.values.byName(row['mode'] as String),
    currentStepId: row['current_step_id'] as String,
    contentVersion: row['content_version'] as String,
    type: GuideType.values.byName(row['guide_type'] as String),
    profile: (row['profile'] as String).isEmpty
        ? null
        : HajjProfile.values.byName(row['profile'] as String),
    updatedAt: row['updated_at'] as int,
  );

  Future<GuideSession?> readMostRecentSession() async {
    final database = await _database;
    final rows = await database.query(
      'guide_sessions',
      orderBy: 'updated_at DESC, id DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : _sessionFromRow(rows.first);
  }

  Future<GuideSession?> readSession(int id) async {
    final database = await _database;
    final rows = await database.query(
      'guide_sessions',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : _sessionFromRow(rows.first);
  }

  Future<GuideSession> openOrCreateSession({
    required GuideType type,
    required GuideMode mode,
    required HajjProfile? profile,
    required String firstStepId,
    required String contentVersion,
  }) async {
    _validateProfile(type, profile);
    final database = await _database;
    return database.transaction((transaction) async {
      final rows = await transaction.query(
        'guide_sessions',
        where: 'guide_type = ? AND mode = ? AND profile = ?',
        whereArgs: [type.name, mode.name, profile?.name ?? ''],
        orderBy: 'id DESC',
        limit: 1,
      );
      if (rows.isNotEmpty) return _sessionFromRow(rows.first);
      return _insertSession(
        transaction,
        type: type,
        mode: mode,
        profile: profile,
        firstStepId: firstStepId,
        contentVersion: contentVersion,
      );
    });
  }

  Future<GuideSession> startNewJourney({
    required GuideType type,
    required HajjProfile? profile,
    required String firstStepId,
    required String contentVersion,
  }) async {
    _validateProfile(type, profile);
    final database = await _database;
    return database.transaction(
      (transaction) => _insertSession(
        transaction,
        type: type,
        mode: GuideMode.journey,
        profile: profile,
        firstStepId: firstStepId,
        contentVersion: contentVersion,
      ),
    );
  }

  void _validateProfile(GuideType type, HajjProfile? profile) {
    if ((type == GuideType.hajj) != (profile != null)) {
      throw ArgumentError('Hac için tür seçilmeli; umrede hac türü olmamalı.');
    }
  }

  Future<GuideSession> openOrCreateUmrahSession({
    required GuideMode mode,
    required String firstStepId,
    required String contentVersion,
  }) => openOrCreateSession(
    type: GuideType.umrah,
    mode: mode,
    profile: null,
    firstStepId: firstStepId,
    contentVersion: contentVersion,
  );

  Future<GuideSession> startNewUmrahJourney({
    required String firstStepId,
    required String contentVersion,
  }) => startNewJourney(
    type: GuideType.umrah,
    profile: null,
    firstStepId: firstStepId,
    contentVersion: contentVersion,
  );

  Future<GuideSession> _insertSession(
    Transaction transaction, {
    required GuideType type,
    required GuideMode mode,
    required HajjProfile? profile,
    required String firstStepId,
    required String contentVersion,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = await transaction.insert('guide_sessions', {
      'guide_type': type.name,
      'mode': mode.name,
      'profile': profile?.name ?? '',
      'current_step_id': firstStepId,
      'content_version': contentVersion,
      'created_at': now,
      'updated_at': now,
    });
    return GuideSession(
      id: id,
      mode: mode,
      currentStepId: firstStepId,
      contentVersion: contentVersion,
      type: type,
      profile: profile,
      updatedAt: now,
    );
  }

  Future<void> saveCurrentStep(int sessionId, String stepId) async {
    final database = await _database;
    await database.transaction((transaction) async {
      final count = await transaction.update(
        'guide_sessions',
        {
          'current_step_id': stepId,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [sessionId],
      );
      if (count != 1) throw StateError('Guide session was not found.');
    });
  }

  Future<Set<String>> readMarkedStepIds(int sessionId) async {
    final database = await _database;
    final rows = await database.query(
      'step_marks',
      columns: ['step_id'],
      where: 'session_id = ?',
      whereArgs: [sessionId],
    );
    return rows.map((row) => row['step_id'] as String).toSet();
  }

  Future<void> setStepMarked(int sessionId, String stepId, bool marked) async {
    final database = await _database;
    await database.transaction((transaction) async {
      if (marked) {
        await transaction.insert('step_marks', {
          'session_id': sessionId,
          'step_id': stepId,
          'marked_at': DateTime.now().millisecondsSinceEpoch,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      } else {
        await transaction.delete(
          'step_marks',
          where: 'session_id = ? AND step_id = ?',
          whereArgs: [sessionId, stepId],
        );
      }
    });
  }

  void _validateCounterKey(String counterKey) {
    if (counterKey != 'tawaf' && counterKey != 'say') {
      throw ArgumentError.value(counterKey, 'counterKey');
    }
  }

  Future<int> readCounterCount(int sessionId, String counterKey) async {
    _validateCounterKey(counterKey);
    final database = await _database;
    final rows = await database.query(
      'counter_state',
      columns: ['count'],
      where: 'session_id = ? AND counter_key = ?',
      whereArgs: [sessionId, counterKey],
      limit: 1,
    );
    return rows.isEmpty ? 0 : rows.first['count'] as int;
  }

  Future<int> incrementCounter(
    int sessionId,
    String counterKey,
    String actionToken,
  ) => _applyCounterAction(sessionId, counterKey, actionToken, 'increment');

  Future<int> undoCounter(
    int sessionId,
    String counterKey,
    String actionToken,
  ) => _applyCounterAction(sessionId, counterKey, actionToken, 'undo');

  Future<int> resetCounter(
    int sessionId,
    String counterKey,
    String actionToken,
  ) => _applyCounterAction(sessionId, counterKey, actionToken, 'reset');

  Future<int> _applyCounterAction(
    int sessionId,
    String counterKey,
    String actionToken,
    String action,
  ) async {
    _validateCounterKey(counterKey);
    if (actionToken.isEmpty) {
      throw ArgumentError.value(actionToken, 'actionToken');
    }
    final database = await _database;
    return database.transaction((transaction) async {
      final rows = await transaction.query(
        'counter_state',
        columns: ['count'],
        where: 'session_id = ? AND counter_key = ?',
        whereArgs: [sessionId, counterKey],
        limit: 1,
      );
      final current = rows.isEmpty ? 0 : rows.first['count'] as int;
      final previousAction = await transaction.query(
        'counter_events',
        columns: ['session_id', 'counter_key', 'action'],
        where: 'action_token = ?',
        whereArgs: [actionToken],
        limit: 1,
      );
      if (previousAction.isNotEmpty) {
        final previous = previousAction.first;
        if (previous['session_id'] != sessionId ||
            previous['counter_key'] != counterKey ||
            previous['action'] != action) {
          throw StateError('Counter action token was reused.');
        }
        return current;
      }
      final next = switch (action) {
        'increment' => current < 7 ? current + 1 : 7,
        'undo' => current > 0 ? current - 1 : 0,
        'reset' => 0,
        _ => throw ArgumentError.value(action, 'action'),
      };
      final now = DateTime.now().millisecondsSinceEpoch;
      await transaction.insert('counter_state', {
        'session_id': sessionId,
        'counter_key': counterKey,
        'count': next,
        'updated_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await transaction.insert('counter_events', {
        'session_id': sessionId,
        'counter_key': counterKey,
        'action_token': actionToken,
        'action': action,
        'value_after': next,
        'created_at': now,
      });
      return next;
    });
  }

  Future<void> close() async {
    if (_opening != null) {
      await (await _opening!).close();
      _opening = null;
    }
  }
}
