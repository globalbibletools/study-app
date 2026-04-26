import 'dart:developer';

import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:studyapp/services/reading_session/rs_model.dart';

class ReadingSessionDatabase {
  static const _databaseName = 'reading_session.db';
  static const _databaseVersion = 1;

  late Database _database;

  Future<void> init() async {
    //await resetDatabase();
    await _initDatabase(_databaseName);
  }

  Future<void> resetDatabase() async {
    final path = await getDatabasesPath();
    final dbPath = '$path/$_databaseName';

    await deleteDatabase(dbPath);
  }

  Future<void> _initDatabase(String path) async {
    _database = await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: (db, version) async {
        log("Creating reading session database");
        String sql = await rootBundle.loadString(
          'assets/schemas/reading_session.sql',
        );
        await _executeSqlBatch(db, sql);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        log(
          "Upgrading reading session database from $oldVersion to $newVersion",
        );
        for (int v = oldVersion + 1; v <= newVersion; v++) {
          final file = 'assets/schemas/reading_session_$v.sql';
          final sql = await rootBundle.loadString(file);
          await _executeSqlBatch(db, sql);
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

  Future<int> updateLog(RsLog log) async {
    return await _database.update(
      'rs_log',
      log.toMap(),
      where: 'id = ?',
      whereArgs: [log.id],
    );
  }

  Future<int> deleteLog(int id) async {
    return await _database.delete('rs_log', where: 'id = ?', whereArgs: [id]);
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

  Future<int> deleteStats(int id) async {
    return await _database.delete('rs_stats', where: 'id = ?', whereArgs: [id]);
  }

  Future<RsStats?> findStatsByTypeAndDate(
    RsStatsType type,
    DateTime date,
  ) async {
    final result = await _database.query(
      'rs_stats',
      where: 'type = ? AND date(stats_date) = date(?)',
      whereArgs: [type.value, date.toIso8601String()],
    );

    if (result.isEmpty) return null;

    return RsStats.fromMap(result.first);
  }

  /* RS BOOK PROGRESS */
  Future<RsBookProgress> insertBookProgresss(
    RsBookProgress bookProgress,
  ) async {
    final id = await _database.insert(
      'rs_book_progress',
      bookProgress.toMap()..remove('id'),
    );
    return bookProgress.copyWith(id: id);
  }

  Future<int> updateBookProgress(RsBookProgress bookProgress) async {
    return await _database.update(
      'rs_book_progress',
      bookProgress.toMap(),
      where: 'id = ?',
      whereArgs: [bookProgress.id],
    );
  }

  Future<int> deleteBookProgress(int id) async {
    return await _database.delete(
      'rs_book_progress',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<RsBookProgress>> getAllBookProgress() async {
    final result = await _database.query(
      'rs_book_progress',
      orderBy: "book_id",
    );

    return result.map((e) => RsBookProgress.fromMap(e)).toList();
  }

  Future<int> countVersesReadForChapter(int bookId, int chapter) async {
    final result = await _database.rawQuery(
      'SELECT COUNT(distinct verse) AS count FROM rs_log where book_id = ? and chapter = ?',
      [bookId, chapter],
    );

    final count = Sqflite.firstIntValue(result) ?? 0;

    return count;
  }

  Future<Map<int, int>> getVersesReadForChapter(int bookId, int chapter) async {
    final result = await _database.rawQuery(
      'SELECT verse, count(*) count FROM rs_log where book_id = ? and chapter = ? group by verse',
      [bookId, chapter],
    );

    if (result.isEmpty) return {};

    Map<int, int> res = {};
    for (final row in result) {
      final verse = row['verse'] as int?;
      final count = row['count'] as int?;

      if (verse == null || count == null) {
        continue;
      }

      res[verse] = count;
    }

    return res;
  }

  void dispose() {
    _database.close();
  }

  Future<List<RsStats>> getRsStatsForType(
    RsStatsType type,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final result = await _database.query(
      'rs_stats',
      where: 'type = ? AND date(stats_date) between date(?) and date(?)',
      whereArgs: [
        type.value,
        startDate.toIso8601String(),
        endDate.toIso8601String(),
      ],
    );

    return result.map((e) => RsStats.fromMap(e)).toList();
  }

  Future<List<RsDailyLog>> getSessionsForDate(DateTime date) async {
    final result = await _database.query(
      'rs_daily_log',
      where: 'date(rs_date) = date(?)',
      whereArgs: [date.toIso8601String()],
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

  Future<int> getVersesReadToday(DateTime date) async {
    final result = await _database.rawQuery(
      'SELECT SUM(verses) FROM rs_daily_log where date(rs_date) = date(?) and end_time is not null',
      [date.toIso8601String()],
    );

    final count = Sqflite.firstIntValue(result) ?? 0;

    return count;
  }

  Future<int> getTotalSecondsReadToday(DateTime date) async {
    final result = await _database.rawQuery(
      "SELECT SUM(strftime('%s', end_time) - strftime('%s', start_time)) AS count "
      'FROM rs_daily_log '
      'WHERE date(rs_date) = date(?) AND end_time IS NOT NULL',
      [date.toIso8601String()],
    );

    final count = Sqflite.firstIntValue(result) ?? 0;

    return count;
  }
}
