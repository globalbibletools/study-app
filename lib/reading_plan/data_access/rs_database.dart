import 'package:flutter/services.dart' show rootBundle;
import 'package:gbt/services/hebrew_greek/database.dart';
import 'package:gbt/services/logging/log.dart';
import 'package:gbt/reading_plan/data_access/day_summary_repository.dart';
import 'package:gbt/reading_plan/data_access/reading_plan_queries.dart'
    hide VerseInventoryProvider;
import 'package:gbt/reading_plan/data_access/reading_plan_repository.dart';
import 'package:gbt/reading_plan/data_access/session_log_repository.dart';
import 'package:gbt/reading_plan/data_access/session_repository.dart';
import 'package:gbt/reading_plan/data_access/verse_state_repository.dart';
import 'package:gbt/services/service_locator.dart';
import 'package:sqflite/sqflite.dart';

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
  late final VerseStateRepository verseState = VerseStateRepository(
    _database,
    verseInventoryProvider: _verseInventoryProvider,
  );
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
        final verseStateRepository = VerseStateRepository(
          db,
          verseInventoryProvider: _verseInventoryProvider,
        );
        // We have to materialize here because there is a default reading plan that needs verse state setup correctly.
        await verseStateRepository.materializeAll(executor: db);
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
            final verseStateRepository = VerseStateRepository(
              db,
              verseInventoryProvider: _verseInventoryProvider,
            );
            await verseStateRepository.materializeAll(executor: db);
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

  Future<T> transaction<T>(Future<T> Function(DatabaseExecutor txn) action) {
    return _database.transaction(action);
  }

  void dispose() {
    _database.close();
    _initFuture = null;
  }
}
