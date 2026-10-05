import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

/// Stores only technical prototype state. Journey records will use a separate
/// schema when the approved content identifiers are available.
class ProgressStore {
  Future<Database>? _opening;

  Future<Database> get _database => _opening ??= _open();

  Future<Database> _open() async {
    final databasePath = path.join(await getDatabasesPath(), 'sesli_rehber.db');
    return openDatabase(
      databasePath,
      version: 1,
      onCreate: (database, version) async {
        await database.execute(
          'CREATE TABLE app_state (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
        );
      },
    );
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
      await transaction.insert(
        'app_state',
        {'key': 'last_step_id', 'value': stepId},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  Future<void> close() async {
    if (_opening != null) {
      await (await _opening!).close();
      _opening = null;
    }
  }
}
