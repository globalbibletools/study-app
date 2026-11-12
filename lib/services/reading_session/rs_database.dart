import 'package:flutter/services.dart';
import 'package:gbt/common/reference.dart';
import 'package:gbt/services/hebrew_greek/database.dart';
import 'package:gbt/services/logging/log.dart';
import 'package:gbt/services/reading_session/rs_model.dart';
import 'package:gbt/services/service_locator.dart';
import 'package:sqflite/sqflite.dart';

typedef VerseInventoryProvider =
    Future<Map<(int, int), List<int>>> Function(Set<int> bookIds);

class ReadingSessionDatabase {
  ReadingSessionDatabase({
    String databaseName = _defaultDatabaseName,
    VerseInventoryProvider? verseInventoryProvider,
  }) : _databaseName = databaseName,
       _verseInventoryProvider =
           verseInventoryProvider ??
           ((bookIds) async {
             final database = await getIt.getAsync<HebrewGreekDatabase>();
             return database.getVerseInventory(bookIds: bookIds);
           });

  static const _defaultDatabaseName = 'reading_session.db';
  static const _databaseVersion = 5;

  final String _databaseName;
  final VerseInventoryProvider _verseInventoryProvider;

  late Database _database;
  Future<void>? _initFuture;

  Future<void> init() async {
    if (_initFuture != null) {
      return _initFuture;
    }

    _initFuture = _initDatabase(_databaseName);
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
    final dbPath = '$path/$_databaseName';

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

  Future<void> _materializeAllVerseState(DatabaseExecutor db) async {
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

    final batch = db.batch();
    for (final entry in inventory.entries) {
      final (bookId, chapter) = entry.key;
      for (final verse in entry.value) {
        batch.rawInsert(
          'INSERT OR IGNORE INTO rs_verse_state '
          '(reading_plan_id, book_id, chapter, verse, read_count, last_read) '
          'VALUES (?, ?, ?, ?, 0, NULL)',
          [planId, bookId, chapter, verse],
        );
      }
    }
    await batch.commit(noResult: true);
  }

  Future<Map<String, List<Map<String, Object?>>>> exportBackupTables() async {
    await init();
    return {
      'reading_plan': await _database.query('reading_plan', orderBy: 'id'),
      'reading_plan_book': await _database.query(
        'reading_plan_book',
        orderBy: 'id',
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
      "SELECT date(rs_date) AS rs_date, "
      "coalesce(sum(strftime('%s', end_time) - strftime('%s', start_time)), 0) AS rs_seconds, "
      'coalesce(sum(verses), 0) AS rs_verses '
      'FROM rs_session '
      'WHERE reading_plan_id = 1 AND end_time IS NOT NULL '
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
        final reached = _isMinutesGoal(goalType)
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
        batch.insert('reading_plan', row);
      }
      for (final row in readingPlanBookRows) {
        batch.insert('reading_plan_book', row);
      }
      for (final row in sessionRows) {
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

  /* READING PLAN */
  Future<List<ReadingPlan>> _getReadingPlans() async {
    final result = await _database.query(
      'reading_plan',
      orderBy: "is_bookmarked desc, created_at desc",
    );

    return result.map((e) => ReadingPlan.fromMap(e)).toList();
  }

  Future<void> updateReadingPlan(ReadingPlan readingPlan) async {
    await _database.update(
      'reading_plan',
      readingPlan.toMap(),
      where: 'id = ?',
      whereArgs: [readingPlan.id],
    );
  }

  Future<List<ReadingPlanDetails>> getReadingPlans() async {
    List<ReadingPlan> plans = await _getReadingPlans();

    List<ReadingPlanDetails> planDetails = [];
    for (ReadingPlan p in plans) {
      List<ReadingPlanBook> books = await getReadingPlanBooks(p.id!);
      planDetails.add(ReadingPlanDetails(p, books));
    }

    return planDetails;
  }

  Future<List<ReadingPlanBook>> getReadingPlanBooks(int readingPlanId) async {
    final result = await _database.query(
      'reading_plan_book',
      where: 'reading_plan_id = ?',
      whereArgs: [readingPlanId],
      orderBy: "ord",
    );

    return result.map((e) => ReadingPlanBook.fromMap(e)).toList();
  }

  Future<ReadingPlanDetails?> getReadingPlanById(int planId) async {
    final result = await _database.query(
      'reading_plan',
      where: 'id = ?',
      whereArgs: [planId],
    );
    if (result.isEmpty) return null;

    final plan = ReadingPlan.fromMap(result.first);
    final books = await getReadingPlanBooks(planId);
    return ReadingPlanDetails(plan, books);
  }

  Future<ReadingPlan> saveReadingPlan({
    ReadingPlan? existingPlan,
    required String planName,
    required int collectionId,
    required String goalType,
    required int goalValue,
    required List<int> orderedBookIds,
  }) async {
    final previousBookIds = existingPlan == null
        ? <int>{}
        : (await _database.query(
            'reading_plan_book',
            columns: ['book_id'],
            where: 'reading_plan_id = ?',
            whereArgs: [existingPlan.id],
          )).map((row) => row['book_id'] as int).toSet();

    final plan = await _database.transaction((txn) async {
      final int planId;
      final ReadingPlan plan;
      if (existingPlan != null) {
        planId = existingPlan.id!;
        plan = existingPlan.copyWith(
          planName: planName,
          collectionId: collectionId,
          goalType: goalType,
          goalValue: goalValue,
        );
        await txn.update(
          'reading_plan',
          plan.toMap(),
          where: 'id = ?',
          whereArgs: [planId],
        );
      } else {
        final newPlan = ReadingPlan(
          planName: planName,
          createdAt: DateTime.now(),
          collectionId: collectionId,
          goalType: goalType,
          goalValue: goalValue,
          isBookmarked: false,
        );
        planId = await txn.insert(
          'reading_plan',
          newPlan.toMap()..remove('id'),
        );
        plan = newPlan.copyWith(id: planId);
      }

      await txn.delete(
        'reading_plan_book',
        where: 'reading_plan_id = ?',
        whereArgs: [planId],
      );

      final batch = txn.batch();
      for (int i = 0; i < orderedBookIds.length; i++) {
        final book = ReadingPlanBook(
          readingPlanId: planId,
          bookId: orderedBookIds[i],
          ord: i + 1,
        );
        batch.insert('reading_plan_book', book.toMap()..remove('id'));
      }

      await batch.commit(noResult: true);
      return plan;
    });

    final newlyAddedBookIds = orderedBookIds.toSet().difference(
      previousBookIds,
    );
    await _materializeVerseState(
      _database,
      plan.id!,
      bookIds: newlyAddedBookIds,
    );

    return plan;
  }

  Future<void> updateReadingPlanBooks(List<ReadingPlanBook> books) async {
    await _database.transaction((txn) async {
      final batch = txn.batch();
      for (ReadingPlanBook b in books) {
        batch.update(
          'reading_plan_book',
          b.toMap(),
          where: 'id = ?',
          whereArgs: [b.id],
        );
      }
      await batch.commit(noResult: true);
    });
  }

  Future<void> deleteReadingPlan(int planId) async {
    await _database.transaction((txn) async {
      final batch = txn.batch();
      batch.delete('rs_log', where: 'reading_plan_id = ?', whereArgs: [planId]);
      batch.delete(
        'rs_session',
        where: 'reading_plan_id = ?',
        whereArgs: [planId],
      );
      batch.delete(
        'rs_day_summary',
        where: 'reading_plan_id = ?',
        whereArgs: [planId],
      );
      batch.delete(
        'rs_verse_state',
        where: 'reading_plan_id = ?',
        whereArgs: [planId],
      );
      batch.delete(
        'reading_plan_book',
        where: 'reading_plan_id = ?',
        whereArgs: [planId],
      );
      batch.delete('reading_plan', where: 'id = ?', whereArgs: [planId]);
      await batch.commit(noResult: true);
    });
  }

  Future<T> transaction<T>(Future<T> Function(DatabaseExecutor txn) action) {
    return _database.transaction(action);
  }

  Future<RsSession?> getSessionById(int id) async {
    final rows = await _database.query(
      'rs_session',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    return rows.isEmpty ? null : RsSession.fromMap(rows.first);
  }

  Future<RsSession> insertSession(
    RsSession log, {
    DatabaseExecutor? executor,
  }) async {
    final db = executor ?? _database;
    final id = await db.insert('rs_session', log.toMap()..remove('id'));
    return log.copyWith(id: id);
  }

  Future<int> updateSession(RsSession log, {DatabaseExecutor? executor}) async {
    final db = executor ?? _database;
    return await db.update(
      'rs_session',
      log.toMap(),
      where: 'id = ?',
      whereArgs: [log.id],
    );
  }

  Future<int> deleteSession(int id) async {
    return await _database.delete(
      'rs_session',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /* RS LOG */
  Future<RsLog> insertLog(RsLog log, {DatabaseExecutor? executor}) async {
    final db = executor ?? _database;
    final id = await db.insert('rs_log', log.toMap()..remove('id'));
    return log.copyWith(id: id);
  }

  Future<Reference?> getResumeReference(
    int readingPlanId, {
    Reference? after,
    DatabaseExecutor? executor,
  }) async {
    final db = executor ?? _database;
    final List<Map<String, Object?>> rows;

    if (after == null) {
      rows = await db.rawQuery(
        'WITH last_read AS ('
        '  SELECT l.book_id AS book_id, '
        '         l.chapter AS chapter, '
        '         l.verse AS verse '
        '  FROM rs_log l '
        '  JOIN reading_plan_book b '
        '    ON b.reading_plan_id = l.reading_plan_id '
        '   AND b.book_id = l.book_id '
        '  WHERE l.reading_plan_id = ? '
        '  ORDER BY l.date_time DESC, l.id DESC '
        '  LIMIT 1'
        '),'
        'current_book AS ('
        '  SELECT b.ord AS ord '
        '  FROM reading_plan_book b '
        '  JOIN last_read l ON l.book_id = b.book_id '
        '  WHERE b.reading_plan_id = ?'
        '),'
        'resume AS ('
        '  SELECT v.book_id AS book_id, '
        '         v.chapter AS chapter, '
        '         v.verse AS verse '
        '  FROM rs_verse_state v '
        '  JOIN reading_plan_book b '
        '    ON b.reading_plan_id = v.reading_plan_id '
        '   AND b.book_id = v.book_id '
        '  WHERE v.reading_plan_id = ? '
        '    AND v.read_count = 0 '
        '    AND ('
        '      NOT EXISTS (SELECT 1 FROM last_read) '
        '      OR ('
        '        b.ord >= (SELECT ord FROM current_book) '
        '        AND ('
        '          v.book_id <> (SELECT book_id FROM last_read) '
        '          OR v.chapter > (SELECT chapter FROM last_read) '
        '          OR ('
        '            v.chapter = (SELECT chapter FROM last_read) '
        '            AND v.verse > (SELECT verse FROM last_read)'
        '          )'
        '        )'
        '      )'
        '    )'
        '  ORDER BY b.ord, v.chapter, v.verse '
        '  LIMIT 1'
        ')'
        'SELECT book_id, chapter, verse FROM resume '
        'UNION ALL '
        'SELECT book_id, chapter, verse FROM last_read '
        'WHERE NOT EXISTS (SELECT 1 FROM resume) '
        'LIMIT 1',
        [readingPlanId, readingPlanId, readingPlanId],
      );
    } else {
      rows = await db.rawQuery(
        'WITH current_book AS ('
        '  SELECT b.ord AS ord '
        '  FROM reading_plan_book b '
        '  WHERE b.reading_plan_id = ? AND b.book_id = ?'
        ') '
        'SELECT v.book_id AS book_id, '
        '       v.chapter AS chapter, '
        '       v.verse AS verse '
        'FROM rs_verse_state v '
        'JOIN reading_plan_book b '
        '  ON b.reading_plan_id = v.reading_plan_id '
        ' AND b.book_id = v.book_id '
        'WHERE v.reading_plan_id = ? '
        '  AND v.read_count = 0 '
        '  AND b.ord >= (SELECT ord FROM current_book) '
        '  AND ('
        '    v.book_id <> ? '
        '    OR v.chapter > ? '
        '    OR (v.chapter = ? AND v.verse > ?)'
        '  ) '
        'ORDER BY b.ord, v.chapter, v.verse '
        'LIMIT 1',
        [
          readingPlanId,
          after.bookId,
          readingPlanId,
          after.bookId,
          after.chapter,
          after.chapter,
          after.verse,
        ],
      );
    }

    if (rows.isEmpty) return null;

    final row = rows.first;
    return Reference(
      bookId: row['book_id'] as int,
      chapter: row['chapter'] as int,
      verse: row['verse'] as int,
    );
  }

  Future<void> upsertDaySummary(
    int readingPlanId,
    DateTime date, {
    bool preserveStoredGoalSnapshot = false,
    DatabaseExecutor? executor,
  }) async {
    Future<void> upsert(DatabaseExecutor txn) async {
      final totals = await txn.rawQuery(
        "SELECT coalesce(sum(strftime('%s', end_time) - strftime('%s', start_time)), 0) AS rs_seconds, "
        'coalesce(sum(verses), 0) AS rs_verses '
        'FROM rs_session '
        'WHERE reading_plan_id = ? AND date(rs_date) = date(?)',
        [readingPlanId, date.toIso8601String()],
      );

      final rsSeconds = totals.first['rs_seconds'] as int? ?? 0;
      final rsVerses = totals.first['rs_verses'] as int? ?? 0;

      String? goalType;
      int? goalValue;
      if (preserveStoredGoalSnapshot) {
        final stored = await txn.query(
          'rs_day_summary',
          columns: ['goal_type', 'goal_value'],
          where: 'reading_plan_id = ? AND rs_date = ?',
          whereArgs: [readingPlanId, RsDaySummary.dayString(date)],
          limit: 1,
        );
        if (stored.isNotEmpty) {
          goalType = stored.first['goal_type'] as String?;
          goalValue = stored.first['goal_value'] as int?;
        }
      }
      if (goalType == null || goalValue == null) {
        final plan = await txn.query(
          'reading_plan',
          columns: ['goal_type', 'goal_value'],
          where: 'id = ?',
          whereArgs: [readingPlanId],
          limit: 1,
        );
        goalType = plan.isEmpty ? null : plan.first['goal_type'] as String?;
        goalValue = plan.isEmpty ? null : plan.first['goal_value'] as int?;
      }

      final goalReached = _isMinutesGoal(goalType)
          ? rsSeconds >= (goalValue ?? 0) * 60
          : rsVerses >= (goalValue ?? 0);

      await txn.insert(
        'rs_day_summary',
        RsDaySummary(
          readingPlanId: readingPlanId,
          rsDate: DateTime(date.year, date.month, date.day),
          rsSeconds: rsSeconds,
          rsVerses: rsVerses,
          goalType: goalType,
          goalValue: goalValue,
          goalReached: goalReached,
        ).toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    if (executor != null) {
      await upsert(executor);
    } else {
      await _database.transaction(upsert);
    }
  }

  Future<RsDaySummary?> getDaySummary(
    int readingPlanId,
    DateTime date, {
    DatabaseExecutor? executor,
  }) async {
    final db = executor ?? _database;
    final rows = await db.query(
      'rs_day_summary',
      where: 'reading_plan_id = ? AND rs_date = ?',
      whereArgs: [readingPlanId, RsDaySummary.dayString(date)],
      limit: 1,
    );

    return rows.isEmpty ? null : RsDaySummary.fromMap(rows.first);
  }

  Future<List<RsDaySummary>> getDaySummariesBetween(
    int readingPlanId,
    DateTime start,
    DateTime end,
  ) async {
    final result = await _database.query(
      'rs_day_summary',
      where: 'reading_plan_id = ? AND rs_date BETWEEN ? AND ?',
      whereArgs: [
        readingPlanId,
        RsDaySummary.dayString(start),
        RsDaySummary.dayString(end),
      ],
      orderBy: 'rs_date asc',
    );

    return result.map((e) => RsDaySummary.fromMap(e)).toList();
  }

  static bool _isMinutesGoal(String? goalType) {
    return goalType != null && goalType.toLowerCase().startsWith('m');
  }

  Future<void> markVerseRead(
    int readingPlanId,
    int bookId,
    int chapter,
    int verse, {
    DateTime? timestamp,
    DatabaseExecutor? executor,
  }) async {
    final db = executor ?? _database;
    await db.rawUpdate(
      'UPDATE rs_verse_state '
      'SET read_count = read_count + 1, last_read = ? '
      'WHERE reading_plan_id = ? AND book_id = ? AND chapter = ? AND verse = ?',
      [
        (timestamp ?? DateTime.now()).toIso8601String(),
        readingPlanId,
        bookId,
        chapter,
        verse,
      ],
    );
  }

  Future<void> resetVerseState(
    int readingPlanId,
    int bookId,
    int chapter,
    int verse, {
    DatabaseExecutor? executor,
  }) async {
    final db = executor ?? _database;
    await db.update(
      'rs_verse_state',
      {'read_count': 0, 'last_read': null},
      where:
          'reading_plan_id = ? AND book_id = ? AND chapter = ? AND verse = ?',
      whereArgs: [readingPlanId, bookId, chapter, verse],
    );
  }

  Future<int?> getVerseReadCount(
    int readingPlanId,
    int bookId,
    int chapter,
    int verse, {
    DatabaseExecutor? executor,
  }) async {
    final db = executor ?? _database;
    final rows = await db.query(
      'rs_verse_state',
      columns: ['read_count'],
      where:
          'reading_plan_id = ? AND book_id = ? AND chapter = ? AND verse = ?',
      whereArgs: [readingPlanId, bookId, chapter, verse],
      limit: 1,
    );

    return rows.isEmpty ? null : rows.first['read_count'] as int;
  }

  Future<Map<int, int>> getVerseReadCountsForChapter(
    int readingPlanId,
    int bookId,
    int chapter, {
    DatabaseExecutor? executor,
  }) async {
    final db = executor ?? _database;
    final rows = await db.rawQuery(
      'SELECT verse, read_count FROM rs_verse_state '
      'WHERE reading_plan_id = ? AND book_id = ? AND chapter = ?',
      [readingPlanId, bookId, chapter],
    );

    return {
      for (final row in rows) row['verse'] as int: row['read_count'] as int,
    };
  }

  Future<Map<int, ({int totalVerses, int versesRead})>>
  getReadingPlanProgress() async {
    final rows = await _database.rawQuery(
      'SELECT b.reading_plan_id AS reading_plan_id, '
      '       COUNT(v.verse) AS total_verses, '
      '       COALESCE(SUM(CASE WHEN v.read_count > 0 THEN 1 ELSE 0 END), 0) '
      '         AS verses_read '
      'FROM reading_plan_book b '
      'LEFT JOIN rs_verse_state v '
      '  ON v.reading_plan_id = b.reading_plan_id '
      ' AND v.book_id = b.book_id '
      'GROUP BY b.reading_plan_id',
    );

    return {
      for (final row in rows)
        row['reading_plan_id'] as int: (
          totalVerses: row['total_verses'] as int,
          versesRead: row['verses_read'] as int,
        ),
    };
  }

  Future<Map<int, RsBookStats>> getBookStats(int readingPlanId) async {
    final rows = await _database.rawQuery(
      'SELECT v.book_id AS book_id, '
      '       COUNT(*) AS total_verses, '
      '       SUM(CASE WHEN v.read_count > 0 THEN 1 ELSE 0 END) AS verses_read, '
      '       MAX(v.last_read) AS last_read '
      'FROM rs_verse_state v '
      'JOIN reading_plan_book b '
      '  ON b.reading_plan_id = v.reading_plan_id '
      ' AND b.book_id = v.book_id '
      'WHERE v.reading_plan_id = ? '
      'GROUP BY v.book_id',
      [readingPlanId],
    );

    return {
      for (final row in rows)
        row['book_id'] as int: RsBookStats(
          bookId: row['book_id'] as int,
          totalVerses: row['total_verses'] as int,
          versesRead: row['verses_read'] as int,
          lastRead: row['last_read'] != null
              ? DateTime.parse(row['last_read'] as String)
              : null,
        ),
    };
  }

  Future<bool> isBookComplete(
    int readingPlanId,
    int bookId, {
    DatabaseExecutor? executor,
  }) async {
    final db = executor ?? _database;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS total_verses, '
      '       SUM(CASE WHEN read_count > 0 THEN 1 ELSE 0 END) AS read_verses '
      'FROM rs_verse_state v '
      'WHERE v.reading_plan_id = ? AND v.book_id = ?',
      [readingPlanId, bookId],
    );

    final total = rows.first['total_verses'] as int? ?? 0;
    final read = rows.first['read_verses'] as int? ?? 0;
    return total > 0 && read == total;
  }

  Future<int> deleteRsLogsForVerse(
    int readingPlanId,
    int bookId,
    int chapter,
    int verse, {
    DatabaseExecutor? executor,
  }) async {
    final db = executor ?? _database;
    return await db.delete(
      'rs_log',
      where:
          'reading_plan_id = ? AND book_id = ? AND chapter = ? AND verse = ?',
      whereArgs: [readingPlanId, bookId, chapter, verse],
    );
  }

  void dispose() {
    _database.close();
    _initFuture = null;
  }

  Future<List<RsSession>> getSessionsForDate(
    DateTime date,
    int readingPlanId,
  ) async {
    final result = await _database.query(
      'rs_session',
      where: 'date(rs_date) = date(?) AND reading_plan_id = ?',
      whereArgs: [date.toIso8601String(), readingPlanId],
      orderBy: "start_time",
    );

    return result.map((e) => RsSession.fromMap(e)).toList();
  }

  Future<List<RsLog>> getRsLogForSession(int sessionId) async {
    final result = await _database.query(
      'rs_log',
      where: 'rs_session_id = ?',
      whereArgs: [sessionId],
      orderBy: "book_id, chapter, verse",
    );

    return result.map((e) => RsLog.fromMap(e)).toList();
  }

  Future<List<RsLog>> getRsLogForSessionAndVerse(
    int sessionId,
    int bookId,
    int chapter,
    int verse, {
    DatabaseExecutor? executor,
  }) async {
    final db = executor ?? _database;
    final result = await db.query(
      'rs_log',
      where: 'rs_session_id = ? and book_id = ? and chapter = ? and verse = ?',
      whereArgs: [sessionId, bookId, chapter, verse],
      orderBy: "book_id, chapter, verse",
    );

    return result.map((e) => RsLog.fromMap(e)).toList();
  }

  Future<int> getVersesReadToday(
    int readingPlanId,
    DateTime date, {
    DatabaseExecutor? executor,
  }) async {
    final db = executor ?? _database;
    final result = await db.rawQuery(
      'SELECT SUM(verses) FROM rs_session where date(rs_date) = date(?) and reading_plan_id = ?',
      [date.toIso8601String(), readingPlanId],
    );

    final count = Sqflite.firstIntValue(result) ?? 0;

    return count;
  }

  Future<int> getTotalSecondsReadToday(
    int readingPlanId,
    DateTime date, {
    DatabaseExecutor? executor,
  }) async {
    final db = executor ?? _database;
    final result = await db.rawQuery(
      "SELECT SUM(strftime('%s', end_time) - strftime('%s', start_time)) AS count "
      'FROM rs_session '
      'WHERE date(rs_date) = date(?) and reading_plan_id = ?',
      [date.toIso8601String(), readingPlanId],
    );

    final count = Sqflite.firstIntValue(result) ?? 0;

    return count;
  }
}
