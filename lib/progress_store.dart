import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import 'group_sync.dart';
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

enum PracticePhase { preparation, practicing, paused, finished }

class PracticeSession {
  const PracticeSession({
    required this.id,
    required this.type,
    required this.profile,
    required this.contentVersion,
    required this.currentStepId,
    required this.sectionGroupId,
    required this.phase,
    required this.audioEnabled,
    required this.useOptionalPackage,
    required this.updatedAt,
  });

  final int id;
  final GuideType type;
  final HajjProfile? profile;
  final String contentVersion;
  final String currentStepId;
  final String? sectionGroupId;
  final PracticePhase phase;
  final bool audioEnabled;
  final bool useOptionalPackage;
  final int updatedAt;
}

class JamaratCounterContext {
  const JamaratCounterContext({
    required this.id,
    required this.sessionId,
    required this.dayLabel,
    required this.targetLabel,
    required this.count,
  });

  final int id;
  final int sessionId;
  final String dayLabel;
  final String targetLabel;
  final int count;

  String get counterKey => 'jamarat:$id';
  String get label => '$dayLabel · $targetLabel';
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
        version: 9,
        onConfigure: (database) async {
          await database.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (database, version) async {
          await database.execute(
            'CREATE TABLE app_state (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
          );
          await _createGuideTables(database);
          await _createCounterTables(database);
          await _createCounterContextTables(database);
          await _createTravelTables(database);
          await _createGroupSyncTables(database);
          await _upgradeOutboxOwner(database);
          await _createPracticeTables(database);
        },
        onUpgrade: (database, oldVersion, newVersion) async {
          if (oldVersion < 2) await _createGuideTables(database);
          if (oldVersion < 3) await _createCounterTables(database);
          if (oldVersion >= 2 && oldVersion < 4) {
            await _upgradeToV4(database);
          }
          if (oldVersion < 5) await _createCounterContextTables(database);
          if (oldVersion < 6) await _createTravelTables(database);
          if (oldVersion < 7) await _createGroupSyncTables(database);
          if (oldVersion < 8) await _upgradeOutboxOwner(database);
          if (oldVersion < 9) await _createPracticeTables(database);
        },
      ),
    );
  }

  Future<void> _upgradeOutboxOwner(Database database) => database.execute(
    'ALTER TABLE message_outbox ADD COLUMN owner_user_id TEXT',
  );

  Future<void> clearAccountOutbox(String userId) async {
    final database = await _database;
    await database.delete(
      'message_outbox',
      where: 'owner_user_id = ?',
      whereArgs: [userId],
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

  Future<void> _createCounterContextTables(Database database) async {
    await database.execute('''
      CREATE TABLE counter_contexts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id INTEGER NOT NULL,
        kind TEXT NOT NULL CHECK (kind IN ('jamarat')),
        day_label TEXT NOT NULL,
        target_label TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        UNIQUE (session_id, kind, day_label, target_label),
        FOREIGN KEY (session_id) REFERENCES guide_sessions(id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _createTravelTables(Database database) async {
    await database.execute('''
      CREATE TABLE travel_favorites (
        item_type TEXT NOT NULL CHECK (item_type IN ('poi', 'route')),
        item_id TEXT NOT NULL,
        saved_at INTEGER NOT NULL,
        PRIMARY KEY (item_type, item_id)
      )
    ''');
  }

  Future<void> _createGroupSyncTables(Database database) async {
    await database.execute('''
      CREATE TABLE message_outbox (
        client_id TEXT PRIMARY KEY,
        group_id TEXT NOT NULL,
        recipient_id TEXT,
        body TEXT NOT NULL CHECK (length(body) BETWEEN 1 AND 4000),
        status TEXT NOT NULL CHECK (status IN ('pending', 'sent', 'failed')),
        attempt_count INTEGER NOT NULL DEFAULT 0 CHECK (attempt_count >= 0),
        last_error TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    await database.execute('''
      CREATE TABLE location_share_state (
        group_id TEXT PRIMARY KEY,
        mode TEXT NOT NULL CHECK (mode IN ('oneTime', 'trip')),
        enabled INTEGER NOT NULL CHECK (enabled IN (0, 1)),
        started_at INTEGER NOT NULL,
        ends_at INTEGER NOT NULL,
        stopped_at INTEGER
      )
    ''');
  }

  Future<void> _createPracticeTables(Database database) async {
    await database.execute('''
      CREATE TABLE practice_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        guide_type TEXT NOT NULL CHECK (guide_type IN ('umrah', 'hajj')),
        profile TEXT NOT NULL DEFAULT '',
        section_group_id TEXT NOT NULL DEFAULT '',
        current_step_id TEXT NOT NULL,
        content_version TEXT NOT NULL,
        phase TEXT NOT NULL CHECK (phase IN ('preparation', 'practicing', 'paused', 'finished')),
        audio_enabled INTEGER NOT NULL CHECK (audio_enabled IN (0, 1)),
        use_optional_package INTEGER NOT NULL CHECK (use_optional_package IN (0, 1)),
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    await database.execute('''
      CREATE TABLE practice_step_marks (
        session_id INTEGER NOT NULL,
        step_id TEXT NOT NULL,
        marked_at INTEGER NOT NULL,
        PRIMARY KEY (session_id, step_id),
        FOREIGN KEY (session_id) REFERENCES practice_sessions(id) ON DELETE CASCADE
      )
    ''');
    await database.execute('''
      CREATE TABLE practice_counter_state (
        session_id INTEGER NOT NULL,
        step_id TEXT NOT NULL,
        count INTEGER NOT NULL CHECK (count >= 0),
        updated_at INTEGER NOT NULL,
        PRIMARY KEY (session_id, step_id),
        FOREIGN KEY (session_id) REFERENCES practice_sessions(id) ON DELETE CASCADE
      )
    ''');
    await database.execute('''
      CREATE TABLE practice_counter_events (
        action_token TEXT PRIMARY KEY,
        session_id INTEGER NOT NULL,
        step_id TEXT NOT NULL,
        action TEXT NOT NULL CHECK (action IN ('increment', 'undo', 'reset')),
        target INTEGER NOT NULL CHECK (target BETWEEN 1 AND 100),
        value_after INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (session_id) REFERENCES practice_sessions(id) ON DELETE CASCADE
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

  Future<Set<String>> readTravelFavoriteIds(String itemType) async {
    _validateTravelItemType(itemType);
    final database = await _database;
    final rows = await database.query(
      'travel_favorites',
      columns: ['item_id'],
      where: 'item_type = ?',
      whereArgs: [itemType],
      orderBy: 'saved_at, item_id',
    );
    return rows.map((row) => row['item_id'] as String).toSet();
  }

  Future<void> setTravelFavorite(
    String itemType,
    String itemId,
    bool favorite,
  ) async {
    _validateTravelItemType(itemType);
    final safeId = itemId.trim();
    if (safeId.isEmpty || safeId.length > 128) {
      throw ArgumentError.value(itemId, 'itemId');
    }
    final database = await _database;
    if (favorite) {
      await database.insert('travel_favorites', {
        'item_type': itemType,
        'item_id': safeId,
        'saved_at': DateTime.now().millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } else {
      await database.delete(
        'travel_favorites',
        where: 'item_type = ? AND item_id = ?',
        whereArgs: [itemType, safeId],
      );
    }
  }

  void _validateTravelItemType(String itemType) {
    if (itemType != 'poi' && itemType != 'route') {
      throw ArgumentError.value(itemType, 'itemType');
    }
  }

  String _requiredGroupValue(String value, String field, {int max = 128}) {
    final safeValue = value.trim();
    if (safeValue.isEmpty ||
        safeValue.length > max ||
        RegExp(r'[\u0000-\u001f]').hasMatch(safeValue)) {
      throw ArgumentError.value(value, field);
    }
    return safeValue;
  }

  GroupOutboxMessage _outboxMessageFromRow(Map<String, Object?> row) {
    return GroupOutboxMessage(
      ownerUserId: row['owner_user_id'] as String?,
      clientId: row['client_id'] as String,
      groupId: row['group_id'] as String,
      recipientId: row['recipient_id'] as String?,
      body: row['body'] as String,
      status: MessageOutboxStatus.values.byName(row['status'] as String),
      attemptCount: row['attempt_count'] as int,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row['updated_at'] as int),
      lastError: row['last_error'] as String?,
    );
  }

  Future<GroupOutboxMessage> enqueueGroupMessage({
    required String clientId,
    required String groupId,
    required String body,
    String? recipientId,
    String? ownerUserId,
  }) async {
    final safeClientId = _requiredGroupValue(clientId, 'clientId');
    final safeGroupId = _requiredGroupValue(groupId, 'groupId');
    final safeBody = _requiredGroupValue(body, 'body', max: 4000);
    final safeRecipientId = recipientId == null
        ? null
        : _requiredGroupValue(recipientId, 'recipientId');
    final database = await _database;
    return database.transaction((transaction) async {
      final existing = await transaction.query(
        'message_outbox',
        where: 'client_id = ?',
        whereArgs: [safeClientId],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        final message = _outboxMessageFromRow(existing.first);
        if (message.ownerUserId != ownerUserId ||
            message.groupId != safeGroupId ||
            message.recipientId != safeRecipientId ||
            message.body != safeBody) {
          throw StateError('Mesaj istemci kimliği farklı içerikle kullanıldı.');
        }
        return message;
      }
      final now = DateTime.now().millisecondsSinceEpoch;
      await transaction.insert('message_outbox', {
        'owner_user_id': ownerUserId,
        'client_id': safeClientId,
        'group_id': safeGroupId,
        'recipient_id': safeRecipientId,
        'body': safeBody,
        'status': MessageOutboxStatus.pending.name,
        'attempt_count': 0,
        'created_at': now,
        'updated_at': now,
      });
      final rows = await transaction.query(
        'message_outbox',
        where: 'client_id = ?',
        whereArgs: [safeClientId],
        limit: 1,
      );
      return _outboxMessageFromRow(rows.single);
    });
  }

  Future<List<GroupOutboxMessage>> readGroupOutbox({
    MessageOutboxStatus? status,
  }) async {
    final database = await _database;
    final rows = await database.query(
      'message_outbox',
      where: status == null ? null : 'status = ?',
      whereArgs: status == null ? null : [status.name],
      orderBy: 'created_at, client_id',
    );
    return rows.map(_outboxMessageFromRow).toList(growable: false);
  }

  Future<void> markGroupMessageAttempt({
    required String clientId,
    required MessageOutboxStatus status,
    String? error,
  }) async {
    final safeClientId = _requiredGroupValue(clientId, 'clientId');
    if (status == MessageOutboxStatus.pending) {
      throw ArgumentError.value(status, 'status');
    }
    final safeError = error?.trim();
    final database = await _database;
    final updated = await database.rawUpdate(
      '''
      UPDATE message_outbox
      SET status = ?, attempt_count = attempt_count + 1,
          last_error = ?, updated_at = ?
      WHERE client_id = ?
      ''',
      [
        status.name,
        status == MessageOutboxStatus.failed && safeError?.isNotEmpty == true
            ? safeError
            : null,
        DateTime.now().millisecondsSinceEpoch,
        safeClientId,
      ],
    );
    if (updated != 1) throw StateError('Gönderilecek mesaj bulunamadı.');
  }

  LocalLocationShare _locationShareFromRow(Map<String, Object?> row) {
    final stoppedAt = row['stopped_at'] as int?;
    return LocalLocationShare(
      groupId: row['group_id'] as String,
      mode: LocationShareMode.values.byName(row['mode'] as String),
      enabled: row['enabled'] == 1,
      startedAt: DateTime.fromMillisecondsSinceEpoch(row['started_at'] as int),
      endsAt: DateTime.fromMillisecondsSinceEpoch(row['ends_at'] as int),
      stoppedAt: stoppedAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(stoppedAt),
    );
  }

  Future<LocalLocationShare?> readLocationShare(String groupId) async {
    final safeGroupId = _requiredGroupValue(groupId, 'groupId');
    final database = await _database;
    final rows = await database.query(
      'location_share_state',
      where: 'group_id = ?',
      whereArgs: [safeGroupId],
      limit: 1,
    );
    return rows.isEmpty ? null : _locationShareFromRow(rows.single);
  }

  Future<LocalLocationShare> startLocationShare({
    required String groupId,
    required LocationShareMode mode,
    required Duration duration,
    DateTime? now,
  }) async {
    final safeGroupId = _requiredGroupValue(groupId, 'groupId');
    if (duration <= Duration.zero || duration > const Duration(days: 7)) {
      throw ArgumentError.value(duration, 'duration');
    }
    final startedAt = now ?? DateTime.now();
    final endsAt = startedAt.add(duration);
    final database = await _database;
    await database.insert('location_share_state', {
      'group_id': safeGroupId,
      'mode': mode.name,
      'enabled': 1,
      'started_at': startedAt.millisecondsSinceEpoch,
      'ends_at': endsAt.millisecondsSinceEpoch,
      'stopped_at': null,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    return LocalLocationShare(
      groupId: safeGroupId,
      mode: mode,
      enabled: true,
      startedAt: startedAt,
      endsAt: endsAt,
    );
  }

  Future<void> stopLocationShare(String groupId, {DateTime? now}) async {
    final safeGroupId = _requiredGroupValue(groupId, 'groupId');
    final database = await _database;
    await database.update(
      'location_share_state',
      {
        'enabled': 0,
        'stopped_at': (now ?? DateTime.now()).millisecondsSinceEpoch,
      },
      where: 'group_id = ?',
      whereArgs: [safeGroupId],
    );
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

  int? _jamaratContextId(String counterKey) {
    final match = RegExp(r'^jamarat:([1-9][0-9]*)$').firstMatch(counterKey);
    return match == null ? null : int.parse(match.group(1)!);
  }

  void _validateCounterKeyFormat(String counterKey) {
    if (counterKey != 'tawaf' &&
        counterKey != 'say' &&
        _jamaratContextId(counterKey) == null) {
      throw ArgumentError.value(counterKey, 'counterKey');
    }
  }

  Future<void> _validateCounterAccess(
    DatabaseExecutor executor,
    int sessionId,
    String counterKey,
  ) async {
    _validateCounterKeyFormat(counterKey);
    final contextId = _jamaratContextId(counterKey);
    if (contextId == null) return;
    final rows = await executor.query(
      'counter_contexts',
      columns: ['id'],
      where: 'id = ? AND session_id = ? AND kind = ?',
      whereArgs: [contextId, sessionId, 'jamarat'],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw StateError('Cemarat sayacı bu yolculuk kaydına ait değil.');
    }
  }

  String _counterLabel(String value, String field) {
    final label = value.trim();
    if (label.isEmpty ||
        label.length > 60 ||
        RegExp(r'[\u0000-\u001f]').hasMatch(label)) {
      throw ArgumentError.value(value, field);
    }
    return label;
  }

  Future<JamaratCounterContext> createJamaratCounter({
    required int sessionId,
    required String dayLabel,
    required String targetLabel,
  }) async {
    final safeDay = _counterLabel(dayLabel, 'dayLabel');
    final safeTarget = _counterLabel(targetLabel, 'targetLabel');
    final database = await _database;
    return database.transaction((transaction) async {
      final sessionRows = await transaction.query(
        'guide_sessions',
        columns: ['guide_type'],
        where: 'id = ?',
        whereArgs: [sessionId],
        limit: 1,
      );
      if (sessionRows.isEmpty) throw StateError('Guide session was not found.');
      if (sessionRows.first['guide_type'] != GuideType.hajj.name) {
        throw StateError('Cemarat sayacı yalnız hac kaydında açılabilir.');
      }
      final existing = await transaction.query(
        'counter_contexts',
        columns: ['id'],
        where: 'session_id = ? AND kind = ? AND day_label = ? AND target_label = ?',
        whereArgs: [sessionId, 'jamarat', safeDay, safeTarget],
        limit: 1,
      );
      final id = existing.isNotEmpty
          ? existing.first['id'] as int
          : await transaction.insert('counter_contexts', {
              'session_id': sessionId,
              'kind': 'jamarat',
              'day_label': safeDay,
              'target_label': safeTarget,
              'created_at': DateTime.now().millisecondsSinceEpoch,
            });
      final countRows = await transaction.query(
        'counter_state',
        columns: ['count'],
        where: 'session_id = ? AND counter_key = ?',
        whereArgs: [sessionId, 'jamarat:$id'],
        limit: 1,
      );
      return JamaratCounterContext(
        id: id,
        sessionId: sessionId,
        dayLabel: safeDay,
        targetLabel: safeTarget,
        count: countRows.isEmpty ? 0 : countRows.first['count'] as int,
      );
    });
  }

  Future<List<JamaratCounterContext>> readJamaratCounters(int sessionId) async {
    final database = await _database;
    final rows = await database.rawQuery(
      '''
      SELECT c.id, c.session_id, c.day_label, c.target_label,
             COALESCE(s.count, 0) AS count
      FROM counter_contexts c
      LEFT JOIN counter_state s
        ON s.session_id = c.session_id
       AND s.counter_key = 'jamarat:' || c.id
      WHERE c.session_id = ? AND c.kind = 'jamarat'
      ORDER BY c.id
      ''',
      [sessionId],
    );
    return [
      for (final row in rows)
        JamaratCounterContext(
          id: row['id'] as int,
          sessionId: row['session_id'] as int,
          dayLabel: row['day_label'] as String,
          targetLabel: row['target_label'] as String,
          count: row['count'] as int,
        ),
    ];
  }

  Future<int> readCounterCount(int sessionId, String counterKey) async {
    final database = await _database;
    await _validateCounterAccess(database, sessionId, counterKey);
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
    if (actionToken.isEmpty) {
      throw ArgumentError.value(actionToken, 'actionToken');
    }
    final database = await _database;
    return database.transaction((transaction) async {
      await _validateCounterAccess(transaction, sessionId, counterKey);
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

  PracticeSession _practiceFromRow(Map<String, Object?> row) => PracticeSession(
    id: row['id'] as int,
    type: GuideType.values.byName(row['guide_type'] as String),
    profile: (row['profile'] as String).isEmpty
        ? null
        : HajjProfile.values.byName(row['profile'] as String),
    contentVersion: row['content_version'] as String,
    currentStepId: row['current_step_id'] as String,
    sectionGroupId: (row['section_group_id'] as String).isEmpty
        ? null
        : row['section_group_id'] as String,
    phase: PracticePhase.values.byName(row['phase'] as String),
    audioEnabled: row['audio_enabled'] == 1,
    useOptionalPackage: row['use_optional_package'] == 1,
    updatedAt: row['updated_at'] as int,
  );

  Future<PracticeSession?> readLatestPracticeSession() async {
    final database = await _database;
    final rows = await database.query(
      'practice_sessions',
      orderBy: 'updated_at DESC, id DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : _practiceFromRow(rows.single);
  }

  Future<PracticeSession?> readPracticeSession(int id) async {
    final database = await _database;
    final rows = await database.query(
      'practice_sessions',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : _practiceFromRow(rows.single);
  }

  Future<PracticeSession> startPracticeSession({
    required GuideType type,
    required HajjProfile? profile,
    required String contentVersion,
    required String firstStepId,
    String? sectionGroupId,
    bool audioEnabled = false,
    bool useOptionalPackage = false,
  }) async {
    _validateProfile(type, profile);
    if (contentVersion.trim().isEmpty || firstStepId.trim().isEmpty) {
      throw ArgumentError('Prova içerik sürümü ve ilk adım gerekli.');
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final database = await _database;
    final id = await database.insert('practice_sessions', {
      'guide_type': type.name,
      'profile': profile?.name ?? '',
      'section_group_id': sectionGroupId ?? '',
      'current_step_id': firstStepId,
      'content_version': contentVersion,
      'phase': PracticePhase.preparation.name,
      'audio_enabled': audioEnabled ? 1 : 0,
      'use_optional_package': useOptionalPackage ? 1 : 0,
      'created_at': now,
      'updated_at': now,
    });
    return (await readPracticeSession(id))!;
  }

  Future<PracticeSession> updatePracticeSession(
    int id, {
    String? currentStepId,
    PracticePhase? phase,
    bool? audioEnabled,
  }) async {
    if (currentStepId != null && currentStepId.trim().isEmpty) {
      throw ArgumentError.value(currentStepId, 'currentStepId');
    }
    final values = <String, Object?>{
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    };
    if (currentStepId != null) values['current_step_id'] = currentStepId;
    if (phase != null) values['phase'] = phase.name;
    if (audioEnabled != null) values['audio_enabled'] = audioEnabled ? 1 : 0;
    final database = await _database;
    final updated = await database.update(
      'practice_sessions',
      values,
      where: 'id = ?',
      whereArgs: [id],
    );
    if (updated != 1) throw StateError('Prova kaydı bulunamadı.');
    return (await readPracticeSession(id))!;
  }

  Future<Set<String>> readPracticeMarkedStepIds(int sessionId) async {
    final database = await _database;
    final rows = await database.query(
      'practice_step_marks',
      columns: ['step_id'],
      where: 'session_id = ?',
      whereArgs: [sessionId],
    );
    return rows.map((row) => row['step_id'] as String).toSet();
  }

  Future<void> setPracticeStepMarked(
    int sessionId,
    String stepId,
    bool marked,
  ) async {
    if (stepId.trim().isEmpty) throw ArgumentError.value(stepId, 'stepId');
    final database = await _database;
    await database.transaction((transaction) async {
      if (marked) {
        await transaction.insert('practice_step_marks', {
          'session_id': sessionId,
          'step_id': stepId,
          'marked_at': DateTime.now().millisecondsSinceEpoch,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      } else {
        await transaction.delete(
          'practice_step_marks',
          where: 'session_id = ? AND step_id = ?',
          whereArgs: [sessionId, stepId],
        );
      }
    });
  }

  Future<int> readPracticeCounter(int sessionId, String stepId) async {
    final database = await _database;
    final rows = await database.query(
      'practice_counter_state',
      columns: ['count'],
      where: 'session_id = ? AND step_id = ?',
      whereArgs: [sessionId, stepId],
      limit: 1,
    );
    return rows.isEmpty ? 0 : rows.single['count'] as int;
  }

  Future<int> applyPracticeCounter({
    required int sessionId,
    required String stepId,
    required String actionToken,
    required String action,
    required int target,
  }) async {
    if (stepId.trim().isEmpty ||
        actionToken.trim().isEmpty ||
        !const {'increment', 'undo', 'reset'}.contains(action) ||
        target < 1 ||
        target > 100) {
      throw ArgumentError('Geçersiz prova sayacı isteği.');
    }
    final database = await _database;
    return database.transaction((transaction) async {
      final prior = await transaction.query(
        'practice_counter_events',
        where: 'action_token = ?',
        whereArgs: [actionToken],
        limit: 1,
      );
      if (prior.isNotEmpty) {
        final row = prior.single;
        if (row['session_id'] != sessionId ||
            row['step_id'] != stepId ||
            row['action'] != action ||
            row['target'] != target) {
          throw StateError('Prova işlem kimliği çakıştı.');
        }
        return row['value_after'] as int;
      }
      final rows = await transaction.query(
        'practice_counter_state',
        columns: ['count'],
        where: 'session_id = ? AND step_id = ?',
        whereArgs: [sessionId, stepId],
        limit: 1,
      );
      final current = rows.isEmpty ? 0 : rows.single['count'] as int;
      final next = switch (action) {
        'increment' => current < target ? current + 1 : current,
        'undo' => current > 0 ? current - 1 : 0,
        _ => 0,
      };
      final now = DateTime.now().millisecondsSinceEpoch;
      await transaction.insert('practice_counter_state', {
        'session_id': sessionId,
        'step_id': stepId,
        'count': next,
        'updated_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await transaction.insert('practice_counter_events', {
        'action_token': actionToken,
        'session_id': sessionId,
        'step_id': stepId,
        'action': action,
        'target': target,
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
