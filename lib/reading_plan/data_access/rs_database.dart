import 'package:flutter/services.dart' show rootBundle;
import 'package:gbt/services/hebrew_greek/database.dart';
import 'package:gbt/services/logging/log.dart';
import 'package:gbt/reading_plan/data_access/day_summary_repository.dart';
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
        await materializeAllVerseState(db);
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
            await materializeAllVerseState(db);
          }
        }
      },
    );
  }

  Future<void> _executeSqlBatch(DatabaseExecutor db, String sql) async {
    final statements = sql
        .split(RegExp(r';\s*\n'))
        .where((s) => s.trim().isNotEmpty);

    final batch = db.batch();

    for (final statement in statements) {
      batch.execute(statement);
    }

    await batch.commit(noResult: true);
  }

  Future<void> backfillVerseStateFromLog(DatabaseExecutor db) async {
    await db.rawInsert(
      'INSERT OR REPLACE INTO rs_verse_state '
      '(reading_plan_id, book_id, chapter, verse, read_count, last_read) '
      'SELECT reading_plan_id, book_id, chapter, verse, '
      '       COUNT(*), MAX(date_time) '
      'FROM rs_log '
      'GROUP BY reading_plan_id, book_id, chapter, verse',
    );
  }

  Future<void> materializeAllVerseState(DatabaseExecutor db) async {
    final plans = await db.query('reading_plan', columns: ['id']);
    for (final plan in plans) {
      await _materializeVerseState(db, plan['id'] as int);
    }
  }

  Future<void> _materializeVerseState(
    DatabaseExecutor db,
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

  Future<T> transaction<T>(Future<T> Function(DatabaseExecutor txn) action) {
    return _database.transaction(action);
  }

  void dispose() {
    _database.close();
    _initFuture = null;
  }
}
