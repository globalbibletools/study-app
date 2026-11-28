import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart' show rootBundle;
import 'package:gbt/common/bible_navigation.dart';
import 'package:gbt/services/logging/log.dart';
import 'package:gbt/reading_plan/data_access/day_summary_repository.dart';
import 'package:gbt/reading_plan/data_access/reading_plan_queries.dart'
    hide VerseInventoryProvider;
import 'package:gbt/reading_plan/data_access/reading_plan_repository.dart';
import 'package:gbt/reading_plan/data_access/session_log_repository.dart';
import 'package:gbt/reading_plan/data_access/session_repository.dart';
import 'package:gbt/reading_plan/data_access/unit_of_work.dart';
import 'package:gbt/reading_plan/data_access/verse_state_repository.dart';
import 'package:gbt/reading_plan/model.dart' show GoalType;
import 'package:gbt/services/service_locator.dart';
import 'package:gbt/services/settings/user_settings.dart';
import 'package:sqflite/sqflite.dart';

class ReadingSessionDatabase {
  final _settings = getIt<UserSettings>();
  final _bibleNavigation = getIt<BibleNavigation>();

  ReadingSessionDatabase() : _databasePath = null;

  @visibleForTesting
  ReadingSessionDatabase.inMemory() : _databasePath = inMemoryDatabasePath;

  static const _defaultDatabaseName = 'reading_session.db';
  static const _databaseVersion = 9;

  final String? _databasePath;

  late final ReadingPlanRepository readingPlans = ReadingPlanRepository(
    _database,
  );

  late Database _database;
  Future<void>? _initFuture;

  late final SessionLogRepository sessionLog = SessionLogRepository(_database);
  late final SessionRepository session = SessionRepository(_database);
  late final VerseStateRepository verseState = VerseStateRepository(
    _database,
    verseInventoryProvider: _verseInventory,
  );
  late final DaySummaryRepository daySummary = DaySummaryRepository(_database);
  late final ReadingPlanQueries queries = ReadingPlanQueries(
    _database,
    verseInventoryProvider: _verseInventory,
  );

  Future<void> init() async {
    if (_initFuture != null) {
      return _initFuture;
    }

    _initFuture = _initDatabase(_databasePath ?? _defaultDatabaseName);
    try {
      await _initFuture;
    } catch (_) {
      _initFuture = null;
      rethrow;
    }
    return _initFuture;
  }

  Future<T> unitOfWork<T>(Future<T> Function(UnitOfWork uow) action) {
    return _database.transaction((txn) async {
      final uow = UnitOfWork(txn, verseInventoryProvider: _verseInventory);
      return action(uow);
    });
  }

  Future<void> resetDatabase() async {
    final path = await getDatabasesPath();
    final dbPath = _databasePath ?? '$path/$_defaultDatabaseName';

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
          verseInventoryProvider: _verseInventory,
        );
        // We have to materialize here because there is a default reading plan that needs verse state setup correctly.
        await verseStateRepository.materializeAll();
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        info(
          "Upgrading reading session database from $oldVersion to $newVersion",
        );
        for (int v = oldVersion + 1; v <= newVersion; v++) {
          final file = 'assets/schemas/reading_session_$v.sql';
          final sql = await rootBundle.loadString(file);
          await _executeSqlBatch(db, sql);
          if (v == 3) {
            await _applyLegacyDailyGoal(db);
          }
          if (v == 4) {
            final verseStateRepository = VerseStateRepository(
              db,
              verseInventoryProvider: _verseInventory,
            );
            await verseStateRepository.materializeAll();
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

  Future<Map<(int, int), List<int>>> _verseInventory(Set<int> bookIds) async {
    final inventory = <(int, int), List<int>>{};
    for (final bookId in bookIds) {
      for (
        var chapter = 1;
        chapter <= _bibleNavigation.getChapterCount(bookId);
        chapter++
      ) {
        final verses = _bibleNavigation.getVerseNumbers(bookId, chapter);
        if (verses.isEmpty) continue;
        inventory[(bookId, chapter)] = verses;
      }
    }
    return inventory;
  }

  // Legacy goals were user preferences that we have to now inject into the database.
  Future<void> _applyLegacyDailyGoal(DatabaseExecutor db) async {
    final goal = _parseLegacyDailyGoal(_settings.legacyDailyGoal);
    if (goal == null) return;

    await db.update('reading_plan', {
      'goal_type': goal.type.storageValue,
      'goal_value': goal.value,
    }, where: 'id = 1');
    info(
      'Restored legacy reading goal: ${goal.type.storageValue}-${goal.value}',
    );
  }

  static ({GoalType type, int value})? _parseLegacyDailyGoal(String? raw) {
    if (raw == null) return null;

    final parts = raw.split('-');
    final typeName = parts.isNotEmpty ? parts[0] : GoalType.minutes.name;
    final valueText = parts.length > 1 ? parts[1] : '10';
    final type = typeName == GoalType.verses.name
        ? GoalType.verses
        : GoalType.minutes;
    final value = int.tryParse(valueText) ?? 10;
    if (value <= 0) return null;

    return (type: type, value: value);
  }

  void dispose() {
    _database.close();
    _initFuture = null;
  }
}
