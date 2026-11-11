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
  static const _databaseVersion = 4;

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
      'rs_daily_log': await _database.query('rs_daily_log', orderBy: 'id'),
      'rs_log': await _database.query('rs_log', orderBy: 'id'),
      'rs_stats': await _database.query('rs_stats', orderBy: 'id'),
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
    final dailyLogRows = _parseBackupRows(tables['rs_daily_log']);
    final logRows = _parseBackupRows(tables['rs_log']);
    final statsRows = _parseBackupRows(tables['rs_stats']);

    final file = 'assets/schemas/reading_session_data.sql';
    final sql = await rootBundle.loadString(file);

    await _database.transaction((txn) async {
      final batch = txn.batch();

      batch.delete('rs_log');
      batch.delete('rs_daily_log');
      batch.delete('rs_stats');
      batch.delete('rs_verse_state');
      batch.delete('reading_plan_book');
      batch.delete('reading_plan');

      await __executeSqlBatch(batch, sql);

      for (final row in dailyLogRows) {
        row['reading_plan_id'] = 1;
        batch.insert('rs_daily_log', row);
      }
      for (final row in logRows) {
        row['reading_plan_id'] = 1;
        batch.insert('rs_log', row);
      }
      for (final row in statsRows) {
        row['reading_plan_id'] = 1;
        batch.insert('rs_stats', row);
      }

      await batch.commit(noResult: true);
    });

    await _backfillVerseStateFromLog(_database);
    await _materializeAllVerseState(_database);
  }

  Future<void> _restoreBackupTablesV2(Map<String, dynamic> tables) async {
    final readingPlanRows = _parseBackupRows(tables['reading_plan']);
    final readingPlanBookRows = _parseBackupRows(tables['reading_plan_book']);
    final dailyLogRows = _parseBackupRows(tables['rs_daily_log']);
    final logRows = _parseBackupRows(tables['rs_log']);
    final statsRows = _parseBackupRows(tables['rs_stats']);

    await _database.transaction((txn) async {
      final batch = txn.batch();

      batch.delete('rs_log');
      batch.delete('rs_daily_log');
      batch.delete('rs_stats');
      batch.delete('rs_verse_state');
      batch.delete('reading_plan_book');
      batch.delete('reading_plan');

      for (final row in readingPlanRows) {
        batch.insert('reading_plan', row);
      }
      for (final row in readingPlanBookRows) {
        batch.insert('reading_plan_book', row);
      }
      for (final row in dailyLogRows) {
        batch.insert('rs_daily_log', row);
      }
      for (final row in logRows) {
        batch.insert('rs_log', row);
      }
      for (final row in statsRows) {
        batch.insert('rs_stats', row);
      }

      await batch.commit(noResult: true);
    });

    await _backfillVerseStateFromLog(_database);
    await _materializeAllVerseState(_database);
  }

  List<Map<String, Object?>> _parseBackupRows(Object? rows) {
    if (rows is! List) {
      throw const FormatException('Backup table payload is invalid.');
    }

    return rows.map((row) {
      if (row is! Map) {
        throw const FormatException('Backup row payload is invalid.');
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
        'rs_daily_log',
        where: 'reading_plan_id = ?',
        whereArgs: [planId],
      );
      batch.delete(
        'rs_stats',
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

  /* RS DAILY LOG */
  Future<RsDailyLog> insertDailyLog(RsDailyLog log) async {
    final id = await _database.insert(
      'rs_daily_log',
      log.toMap()..remove('id'),
    );
    return log.copyWith(id: id);
  }

  Future<int> updateDailyLog(RsDailyLog log) async {
    return await _database.update(
      'rs_daily_log',
      log.toMap(),
      where: 'id = ?',
      whereArgs: [log.id],
    );
  }

  Future<int> deleteDailyLog(int id) async {
    return await _database.delete(
      'rs_daily_log',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /* RS LOG */
  Future<RsLog> insertLog(RsLog log) async {
    final id = await _database.insert('rs_log', log.toMap()..remove('id'));
    return log.copyWith(id: id);
  }

  Future<Reference?> getResumeReference(
    int readingPlanId, {
    Reference? after,
  }) async {
    final List<Map<String, Object?>> rows;

    if (after == null) {
      rows = await _database.rawQuery(
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
      rows = await _database.rawQuery(
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

  /* RS STATS */
  Future<RsStats> insertStats(RsStats stats) async {
    final id = await _database.insert('rs_stats', stats.toMap()..remove('id'));
    return stats.copyWith(id: id);
  }

  Future<int> updateStats(RsStats stats) async {
    return await _database.update(
      'rs_stats',
      stats.toMap(),
      where: 'id = ?',
      whereArgs: [stats.id],
    );
  }

  Future<RsStats?> findStatsByTypeAndDateForPlan(
    RsStatsType type,
    DateTime date,
    int readingPlanId,
  ) async {
    final result = await _database.query(
      'rs_stats',
      where: 'type = ? AND date(stats_date) = date(?) AND reading_plan_id = ?',
      whereArgs: [type.value, date.toIso8601String(), readingPlanId],
    );

    if (result.isEmpty) return null;

    return RsStats.fromMap(result.first);
  }

  Future<void> markVerseRead(
    int readingPlanId,
    int bookId,
    int chapter,
    int verse,
  ) async {
    await _database.rawUpdate(
      'UPDATE rs_verse_state '
      'SET read_count = read_count + 1, last_read = ? '
      'WHERE reading_plan_id = ? AND book_id = ? AND chapter = ? AND verse = ?',
      [DateTime.now().toIso8601String(), readingPlanId, bookId, chapter, verse],
    );
  }

  Future<void> resetVerseState(
    int readingPlanId,
    int bookId,
    int chapter,
    int verse,
  ) async {
    await _database.update(
      'rs_verse_state',
      {'read_count': 0, 'last_read': null},
      where:
          'reading_plan_id = ? AND book_id = ? AND chapter = ? AND verse = ?',
      whereArgs: [readingPlanId, bookId, chapter, verse],
    );
  }

  Future<Map<int, int>> getVerseReadCountsForChapter(
    int readingPlanId,
    int bookId,
    int chapter,
  ) async {
    final rows = await _database.rawQuery(
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

  Future<bool> isBookComplete(int readingPlanId, int bookId) async {
    final rows = await _database.rawQuery(
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
    int verse,
  ) async {
    return await _database.delete(
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

  Future<List<RsStats>> getRsStatsForType(
    RsStatsType type,
    DateTime startDate,
    DateTime endDate,
    int readingPlanId,
  ) async {
    final result = await _database.query(
      'rs_stats',
      where:
          'type = ? AND date(stats_date) between date(?) and date(?) AND reading_plan_id = ?',
      whereArgs: [
        type.value,
        startDate.toIso8601String(),
        endDate.toIso8601String(),
        readingPlanId,
      ],
      orderBy: "stats_date asc",
    );

    return result.map((e) => RsStats.fromMap(e)).toList();
  }

  Future<List<RsDailyLog>> getSessionsForDate(
    DateTime date,
    int readingPlanId,
  ) async {
    final result = await _database.query(
      'rs_daily_log',
      where: 'date(rs_date) = date(?) AND reading_plan_id = ?',
      whereArgs: [date.toIso8601String(), readingPlanId],
      orderBy: "start_time",
    );

    return result.map((e) => RsDailyLog.fromMap(e)).toList();
  }

  Future<List<RsLog>> getRsLogForDailyLog(int rsDailyLogId) async {
    final result = await _database.query(
      'rs_log',
      where: 'rs_daily_log_id = ?',
      whereArgs: [rsDailyLogId],
      orderBy: "book_id, chapter, verse",
    );

    return result.map((e) => RsLog.fromMap(e)).toList();
  }

  Future<List<RsLog>> getRsLogForDailyLogAndVerse(
    int rsDailyLogId,
    int bookId,
    int chapter,
    int verse,
  ) async {
    final result = await _database.query(
      'rs_log',
      where:
          'rs_daily_log_id = ? and book_id = ? and chapter = ? and verse = ?',
      whereArgs: [rsDailyLogId, bookId, chapter, verse],
      orderBy: "book_id, chapter, verse",
    );

    return result.map((e) => RsLog.fromMap(e)).toList();
  }

  Future<int> getVersesReadToday(int readingPlanId, DateTime date) async {
    final result = await _database.rawQuery(
      'SELECT SUM(verses) FROM rs_daily_log where date(rs_date) = date(?) and end_time is not null and reading_plan_id = ?',
      [date.toIso8601String(), readingPlanId],
    );

    final count = Sqflite.firstIntValue(result) ?? 0;

    return count;
  }

  Future<int> getTotalSecondsReadToday(int readingPlanId, DateTime date) async {
    final result = await _database.rawQuery(
      "SELECT SUM(strftime('%s', end_time) - strftime('%s', start_time)) AS count "
      'FROM rs_daily_log '
      'WHERE date(rs_date) = date(?) AND end_time IS NOT NULL and reading_plan_id = ?',
      [date.toIso8601String(), readingPlanId],
    );

    final count = Sqflite.firstIntValue(result) ?? 0;

    return count;
  }
}
