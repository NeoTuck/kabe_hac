import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import 'guide_catalog.dart';

class GuideSession {
  const GuideSession({
    required this.id,
    required this.mode,
    required this.currentStepId,
    required this.contentVersion,
  });

  final int id;
  final GuideMode mode;
  final String currentStepId;
  final String contentVersion;

  GuideSession copyWith({String? currentStepId}) => GuideSession(
    id: id,
    mode: mode,
    currentStepId: currentStepId ?? this.currentStepId,
    contentVersion: contentVersion,
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
        version: 3,
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
    final database = await _database;
    final rows = await database.query(
      'app_state',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: ['last_step_id'],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  Future<void> saveLastStepId(String stepId) async {
    final database = await _database;
    await database.transaction((transaction) async {
      await transaction.insert('app_state', {
        'key': 'last_step_id',
        'value': stepId,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  GuideSession _sessionFromRow(Map<String, Object?> row) => GuideSession(
    id: row['id'] as int,
    mode: GuideMode.values.byName(row['mode'] as String),
    currentStepId: row['current_step_id'] as String,
    contentVersion: row['content_version'] as String,
  );

  Future<GuideSession> openOrCreateUmrahSession({
    required GuideMode mode,
    required String firstStepId,
    required String contentVersion,
  }) async {
    final database = await _database;
    return database.transaction((transaction) async {
      final rows = await transaction.query(
        'guide_sessions',
        where: 'guide_type = ? AND mode = ?',
        whereArgs: ['umrah', mode.databaseValue],
        orderBy: 'id DESC',
        limit: 1,
      );
      if (rows.isNotEmpty) return _sessionFromRow(rows.first);
      return _insertUmrahSession(
        transaction,
        mode: mode,
        firstStepId: firstStepId,
        contentVersion: contentVersion,
      );
    });
  }

  Future<GuideSession> startNewUmrahJourney({
    required String firstStepId,
    required String contentVersion,
  }) async {
    final database = await _database;
    return database.transaction(
      (transaction) => _insertUmrahSession(
        transaction,
        mode: GuideMode.journey,
        firstStepId: firstStepId,
        contentVersion: contentVersion,
      ),
    );
  }

  Future<GuideSession> _insertUmrahSession(
    Transaction transaction, {
    required GuideMode mode,
    required String firstStepId,
    required String contentVersion,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = await transaction.insert('guide_sessions', {
      'guide_type': 'umrah',
      'mode': mode.databaseValue,
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
