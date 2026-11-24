import 'package:flutter/services.dart';
import 'package:gbt/services/hebrew_greek/database.dart';
import 'package:gbt/services/logging/log.dart';
import 'package:gbt/reading_plan/data_access/day_summary_repository.dart';
import 'package:gbt/reading_plan/model.dart' show GoalType;
import 'package:gbt/reading_plan/data_access/reading_plan_queries.dart';
import 'package:gbt/reading_plan/data_access/reading_plan_repository.dart'
    show ReadingPlanRepository;
import 'package:gbt/reading_plan/data_access/session_log_repository.dart';
import 'package:gbt/reading_plan/data_access/session_repository.dart';
import 'package:gbt/reading_plan/data_access/verse_state_repository.dart';
import 'package:gbt/services/service_locator.dart';
import 'package:sqflite/sqflite.dart';

typedef VerseInventoryProvider =
    Future<Map<(int, int), List<int>>> Function(Set<int> bookIds);

class ReadingSessionDatabase {
  ReadingSessionDatabase({String databaseName = _defaultDatabaseName})
    : this.withDependencies(
        databaseName: databaseName,
        verseInventoryProvider: (bookIds) async {
          final database = await getIt.getAsync<HebrewGreekDatabase>();
          return database.getVerseInventory(bookIds: bookIds);
        },
      );

  ReadingSessionDatabase.withDependencies({
    String databaseName = _defaultDatabaseName,
    String? databasePath,
    required VerseInventoryProvider verseInventoryProvider,
  }) : _databaseName = databaseName,
       _databasePath = databasePath,
       _verseInventoryProvider = verseInventoryProvider;

  static const _defaultDatabaseName = 'reading_session.db';
  static const _databaseVersion = 9;

  final String _databaseName;
  final String? _databasePath;
  final VerseInventoryProvider _verseInventoryProvider;

  late final ReadingPlanRepository readingPlans = ReadingPlanRepository(
    _database,
  );

  late Database _database;
  Future<void>? _initFuture;

  late final SessionLogRepository sessionLog = SessionLogRepository(_database);
  late final SessionRepository session = SessionRepository(_database);
  late final VerseStateRepository verseState = VerseStateRepository(_database);
  late final DaySummaryRepository daySummary = DaySummaryRepository(_database);
  late final ReadingPlanQueries queries = ReadingPlanQueries(
    _database,
    verseInventoryProvider: _verseInventoryProvider,
  );

  Future<void> init() async {
    if (_initFuture != null) {
      return _initFuture;
    }

    _initFuture = _initDatabase(_databasePath ?? _databaseName);
    try {
      await _initFuture;
    } catch (_) {
      _initFuture = null;
      rethrow;
    }
    return _initFuture;
  }

  Future<void> resetDatabase() async {
    final path = await getDatabasesPath();
    final dbPath = _databasePath ?? '$path/$_databaseName';

    _initFuture = null;
    await deleteDatabase(dbPath);
  }

  Future<void> _initDatabase(String path) async {
    _database = await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: (db, version) async {
        info("Creating reading session database");
        String sql = await rootBundle.loadString(
          'assets/schemas/reading_session.sql',
        );
        await _executeSqlBatch(db, sql);
        // We have to materialize here because there is a default reading plan that needs verse state setup correctly.
        await _materializeAllVerseState(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        info(
          "Upgrading reading session database from $oldVersion to $newVersion",
        );
        for (int v = oldVersion + 1; v <= newVersion; v++) {
          final file = 'assets/schemas/reading_session_$v.sql';
          final sql = await rootBundle.loadString(file);
          await _executeSqlBatch(db, sql);
          if (v == 4) {
            await _materializeAllVerseState(db);
          }
        }
      },
    );
  }

  Future<void> _executeSqlBatch(Database db, String sql) async {
    final statements = sql
        .split(RegExp(r';\s*\n'))
        .where((s) => s.trim().isNotEmpty);

    final batch = db.batch();

    for (final statement in statements) {
      batch.execute(statement);
    }

    await batch.commit(noResult: true);
  }

  Future<void> __executeSqlBatch(Batch batch, String sql) async {
    final statements = sql
        .split(RegExp(r';\s*\n'))
        .where((s) => s.trim().isNotEmpty);

    for (final statement in statements) {
      batch.execute(statement);
    }
  }

  Future<void> _materializeAllVerseState(Database db) async {
    final plans = await db.query('reading_plan', columns: ['id']);
    for (final plan in plans) {
      await _materializeVerseState(db, plan['id'] as int);
    }
  }

  Future<void> _backfillVerseStateFromLog(DatabaseExecutor db) async {
    await db.rawInsert(
      'INSERT OR REPLACE INTO rs_verse_state '
      '(reading_plan_id, book_id, chapter, verse, read_count, last_read) '
      'SELECT reading_plan_id, book_id, chapter, verse, '
      '       COUNT(*), MAX(date_time) '
      'FROM rs_log '
      'GROUP BY reading_plan_id, book_id, chapter, verse',
    );
  }

  Future<void> _materializeVerseState(
    Database db,
    int planId, {
    Set<int>? bookIds,
  }) async {
    final rows = await db.query(
      'reading_plan_book',
      columns: ['book_id'],
      where: 'reading_plan_id = ?',
      whereArgs: [planId],
    );
    final planBookIds = rows.map((row) => row['book_id'] as int).toSet();
    final targetBookIds = bookIds == null
        ? planBookIds
        : planBookIds.intersection(bookIds);
    if (targetBookIds.isEmpty) return;

    final inventory = await _verseInventoryProvider(targetBookIds);
    if (inventory.isEmpty) return;

    await VerseStateRepository(db).bulkInsert(planId, inventory);
  }

  Future<void> materializeVerseStateForPlan(
    int planId, {
    Set<int>? bookIds,
  }) async {
    await init();
    await _materializeVerseState(_database, planId, bookIds: bookIds);
  }

  Future<Map<String, List<Map<String, Object?>>>> exportBackupTables() async {
    await init();
    return {
      'reading_plan': await _database.query('reading_plan', orderBy: 'id'),
      'reading_plan_book': await _database.query(
        'reading_plan_book',
        orderBy: 'reading_plan_id, ord',
      ),
      'rs_session': await _database.query('rs_session', orderBy: 'id'),
      'rs_log': await _database.query('rs_log', orderBy: 'id'),
      'rs_day_summary': await _database.query(
        'rs_day_summary',
        orderBy: 'reading_plan_id, rs_date',
      ),
    };
  }

  Future<void> restoreBackupTables(
    Map<String, dynamic> tables, {
    required int formatVersion,
  }) async {
    await init();
    if (formatVersion == 1) {
      await _restoreBackupTablesV1(tables);
    } else {
      await _restoreBackupTablesV2(tables);
    }
  }

  Future<void> _restoreBackupTablesV1(Map<String, dynamic> tables) async {
    // v1 payloads predate the rs_session rename: sessions were exported
    // under the 'rs_daily_log' key and rs_log rows carry 'rs_daily_log_id'.
    final sessionRows = _parseBackupRows(
      tables['rs_daily_log'],
      'rs_daily_log',
    );
    final logRows = _parseBackupRows(tables['rs_log'], 'rs_log');
    final statsRows = _parseBackupRows(tables['rs_stats'], 'rs_stats');

    final file = 'assets/schemas/reading_session_data.sql';
    final sql = await rootBundle.loadString(file);

    await _database.transaction((txn) async {
      final batch = txn.batch();

      batch.delete('rs_log');
      batch.delete('rs_session');
      batch.delete('rs_day_summary');
      batch.delete('rs_verse_state');
      batch.delete('reading_plan_book');
      batch.delete('reading_plan');

      await __executeSqlBatch(batch, sql);

      for (final row in sessionRows) {
        row['reading_plan_id'] = 1;
        row['read_seconds'] = _readSecondsForSessionRow(row);
        row['is_manual'] = 0;
        batch.insert('rs_session', row);
      }
      for (final row in logRows) {
        row['reading_plan_id'] = 1;
        row['rs_session_id'] = row.remove('rs_daily_log_id');
        batch.insert('rs_log', row);
      }

      await batch.commit(noResult: true);

      await _rebuildDaySummariesFromV1Stats(txn, statsRows);
    });

    await _backfillVerseStateFromLog(_database);
    await _materializeAllVerseState(_database);
  }

  Future<void> _rebuildDaySummariesFromV1Stats(
    DatabaseExecutor txn,
    List<Map<String, Object?>> statsRows,
  ) async {
    final dailyGoalReached = <String, int>{};
    for (final row in statsRows) {
      if (row['type'] != 'D') continue;
      final statsDate = row['stats_date'];
      if (statsDate is! String || statsDate.length < 10) continue;
      dailyGoalReached[statsDate.substring(0, 10)] = row['goal_reached'] == 1
          ? 1
          : 0;
    }

    final plan = await txn.query(
      'reading_plan',
      columns: ['goal_type', 'goal_value'],
      where: 'id = ?',
      whereArgs: [1],
      limit: 1,
    );
    final goalType = plan.isEmpty ? null : plan.first['goal_type'] as String?;
    final goalValue = plan.isEmpty ? null : plan.first['goal_value'] as int?;

    final dayTotals = await txn.rawQuery(
      'SELECT date(rs_date) AS rs_date, '
      'coalesce(sum(read_seconds), 0) AS rs_seconds, '
      'coalesce(sum(verses), 0) AS rs_verses '
      'FROM rs_session '
      'WHERE reading_plan_id = 1 '
      'GROUP BY date(rs_date)',
    );

    for (final totals in dayTotals) {
      final day = totals['rs_date'] as String;
      final rsSeconds = totals['rs_seconds'] as int? ?? 0;
      final rsVerses = totals['rs_verses'] as int? ?? 0;

      final storedFlag = dailyGoalReached[day];
      final int goalReached;
      if (storedFlag != null) {
        goalReached = storedFlag;
      } else {
        final reached = GoalType.fromStorage(goalType) == GoalType.minutes
            ? rsSeconds >= (goalValue ?? 0) * 60
            : rsVerses >= (goalValue ?? 0);
        goalReached = reached ? 1 : 0;
      }

      await txn.insert('rs_day_summary', {
        'reading_plan_id': 1,
        'rs_date': day,
        'rs_seconds': rsSeconds,
        'rs_verses': rsVerses,
        'goal_type': goalType,
        'goal_value': goalValue,
        'goal_reached': goalReached,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<void> _restoreBackupTablesV2(Map<String, dynamic> tables) async {
    if (tables.containsKey('rs_daily_log') || tables.containsKey('rs_stats')) {
      throw const FormatException(
        'Backup contains the unsupported rs_daily_log or rs_stats table.',
      );
    }

    final readingPlanRows = _parseBackupRows(
      tables['reading_plan'],
      'reading_plan',
    );
    final readingPlanBookRows = _parseBackupRows(
      tables['reading_plan_book'],
      'reading_plan_book',
    );
    final sessionRows = _parseBackupRows(tables['rs_session'], 'rs_session');
    final logRows = _parseBackupRows(tables['rs_log'], 'rs_log');
    final daySummaryRows = _parseBackupRows(
      tables['rs_day_summary'],
      'rs_day_summary',
    );

    await _database.transaction((txn) async {
      final batch = txn.batch();

      batch.delete('rs_log');
      batch.delete('rs_session');
      batch.delete('rs_day_summary');
      batch.delete('rs_verse_state');
      batch.delete('reading_plan_book');
      batch.delete('reading_plan');

      for (final row in readingPlanRows) {
        // Older backups persist the denormalized collection id, which the
        // current schema no longer has. The ordered book list is authoritative.
        row.remove('collection_id');
        // Older backups also persist reading_plan.last_read, which the current
        // schema dropped.
        row.remove('last_read');
        batch.insert('reading_plan', row);
      }
      for (final row in readingPlanBookRows) {
        // Older backups persist a surrogate id for reading_plan_book; the
        // current schema keys rows by (reading_plan_id, book_id).
        row.remove('id');
        batch.insert('reading_plan_book', row);
      }
      for (final row in sessionRows) {
        row['read_seconds'] = _readSecondsForSessionRow(row);
        row['is_manual'] ??= 0;
        batch.insert('rs_session', row);
      }
      for (final row in logRows) {
        batch.insert('rs_log', row);
      }
      for (final row in daySummaryRows) {
        batch.insert('rs_day_summary', row);
      }

      await batch.commit(noResult: true);
    });

    await _backfillVerseStateFromLog(_database);
    await _materializeAllVerseState(_database);
  }

  List<Map<String, Object?>> _parseBackupRows(Object? rows, String table) {
    if (rows is! List) {
      throw FormatException('Backup table payload for $table is invalid.');
    }

    return rows.map((row) {
      if (row is! Map) {
        throw FormatException('Backup row payload for $table is invalid.');
      }
      return Map<String, Object?>.from(row);
    }).toList();
  }

  int _readSecondsForSessionRow(Map<String, Object?> row) {
    final stored = row['read_seconds'];
    if (stored is num) return stored.toInt();

    final start = _parseTimestamp(row['start_time']);
    final end = _parseTimestamp(row['end_time']);
    if (start == null || end == null) return 0;

    final seconds = end.difference(start).inSeconds;
    return seconds < 0 ? 0 : seconds;
  }

  DateTime? _parseTimestamp(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  Future<T> transaction<T>(Future<T> Function(DatabaseExecutor txn) action) {
    return _database.transaction(action);
  }

  void dispose() {
    _database.close();
    _initFuture = null;
  }
}
