import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:gbt/services/reading_session/rs_model.dart';

class ReadingSessionBackupInfo {
  const ReadingSessionBackupInfo({
    required this.path,
    required this.name,
    required this.modifiedAt,
    required this.sizeBytes,
  });

  final String path;
  final String name;
  final DateTime modifiedAt;
  final int sizeBytes;
}

class ReadingSessionDatabase {
  static const _databaseName = 'reading_session.db';
  static const _databaseVersion = 3;
  static const _backupFormatVersion = 2;
  static const _backupDirectoryName = 'backups';
  static const _backupFilePrefix = 'reading_session_';

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

  Future<void> __executeSqlBatch(Batch batch, String sql) async {
    final statements = sql
        .split(RegExp(r';\s*\n'))
        .where((s) => s.trim().isNotEmpty);

    for (final statement in statements) {
      batch.execute(statement);
    }
  }

  Future<String> createBackup() async {
    await init();
    final backupDir = await _getBackupDirectory();
    await backupDir.create(recursive: true);

    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final backupPath = join(
      backupDir.path,
      '$_backupFilePrefix$timestamp.json',
    );

    return writeBackupToPath(backupPath);
  }

  Future<String> writeBackupToPath(String backupPath) async {
    await init();
    final file = File(backupPath);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(await buildBackupBytes(), flush: true);
    return file.path;
  }

  Future<Uint8List> buildBackupBytes() async {
    await init();
    final payload = await _buildBackupPayload();
    final encoded = utf8.encode(jsonEncode(payload));
    return Uint8List.fromList(encoded);
  }

  Future<Map<String, Object?>> _buildBackupPayload() async {
    return {
      'format_version': _backupFormatVersion,
      'created_at': DateTime.now().toIso8601String(),
      'tables': {
        'reading_plan': await _database.query('reading_plan', orderBy: 'id'),
        'reading_plan_book': await _database.query(
          'reading_plan_book',
          orderBy: 'id',
        ),
        'rs_daily_log': await _database.query('rs_daily_log', orderBy: 'id'),
        'rs_log': await _database.query('rs_log', orderBy: 'id'),
        'rs_stats': await _database.query('rs_stats', orderBy: 'id'),
        'rs_book_progress': await _database.query(
          'rs_book_progress',
          orderBy: 'id',
        ),
      },
    };
  }

  Future<List<ReadingSessionBackupInfo>> listBackups() async {
    await init();
    final backupDir = await _getBackupDirectory();
    if (!await backupDir.exists()) {
      return [];
    }

    final files = await backupDir
        .list()
        .where((entity) => entity is File && entity.path.endsWith('.json'))
        .cast<File>()
        .toList();

    final backups = <ReadingSessionBackupInfo>[];
    for (final file in files) {
      final stat = await file.stat();
      backups.add(
        ReadingSessionBackupInfo(
          path: file.path,
          name: basename(file.path),
          modifiedAt: stat.modified,
          sizeBytes: stat.size,
        ),
      );
    }

    backups.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
    return backups;
  }

  Future<void> restoreBackup(String backupPath) async {
    await init();
    final file = File(backupPath);
    await restoreBackupJson(await file.readAsString());
  }

  Future<void> restoreBackupBytes(Uint8List bytes) async {
    await init();
    await restoreBackupJson(utf8.decode(bytes));
  }

  Future<void> restoreBackupJson(String content) async {
    await init();
    final raw = jsonDecode(content);
    if (raw is! Map<String, dynamic>) {
      throw const FormatException('Invalid backup file.');
    }

    final tables = raw['tables'];
    if (tables is! Map<String, dynamic>) {
      throw const FormatException('Backup is missing table data.');
    }

    final version = raw['format_version'];
    if (version is! int) {
      throw const FormatException('Backup is missing version data.');
    }

    if (version == 1) {
      await restoreBackupJson1(tables);
    } else {}
  }

  Future<void> restoreBackupJson1(Map<String, dynamic> tables) async {
    final dailyLogRows = _parseBackupRows(tables['rs_daily_log']);
    final logRows = _parseBackupRows(tables['rs_log']);
    final statsRows = _parseBackupRows(tables['rs_stats']);
    final bookProgressRows = _parseBackupRows(tables['rs_book_progress']);

    final file = 'assets/schemas/reading_session_data.sql';
    final sql = await rootBundle.loadString(file);

    await _database.transaction((txn) async {
      final batch = txn.batch();

      batch.delete('reading_plan');
      batch.delete('reading_plan_book');
      batch.delete('rs_log');
      batch.delete('rs_stats');
      batch.delete('rs_book_progress');
      batch.delete('rs_daily_log');

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
      for (final row in bookProgressRows) {
        row['reading_plan_id'] = 1;
        batch.insert('rs_book_progress', row);
      }

      await batch.commit(noResult: true);
    });
  }

  Future<void> restoreBackupJson2(Map<String, dynamic> tables) async {
    final readingPlanRows = _parseBackupRows(tables['reading_plan']);
    final readingPlanBookRows = _parseBackupRows(tables['reading_plan_book']);
    final dailyLogRows = _parseBackupRows(tables['rs_daily_log']);
    final logRows = _parseBackupRows(tables['rs_log']);
    final statsRows = _parseBackupRows(tables['rs_stats']);
    final bookProgressRows = _parseBackupRows(tables['rs_book_progress']);

    await _database.transaction((txn) async {
      final batch = txn.batch();

      batch.delete('reading_plan');
      batch.delete('reading_plan_book');
      batch.delete('rs_log');
      batch.delete('rs_stats');
      batch.delete('rs_book_progress');
      batch.delete('rs_daily_log');

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
      for (final row in bookProgressRows) {
        batch.insert('rs_book_progress', row);
      }

      await batch.commit(noResult: true);
    });
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

  Future<Directory> _getBackupDirectory() async {
    final docDir = await getApplicationDocumentsDirectory();
    return Directory(join(docDir.path, _backupDirectoryName));
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

  Future<ReadingPlan> insertReadingPlan(ReadingPlan plan) async {
    final id = await _database.insert(
      'reading_plan',
      plan.toMap()..remove('id'),
    );
    return plan.copyWith(id: id);
  }

  Future<void> insertReadingPlanBooks(List<ReadingPlanBook> books) async {
    for (ReadingPlanBook b in books) {
      await _database.insert('reading_plan_book', b.toMap()..remove('id'));
    }
  }

  Future<void> deleteReadingPlanBooks(int readingPlanId) async {
    await _database.delete(
      'reading_plan_book',
      where: 'reading_plan_id = ?',
      whereArgs: [readingPlanId],
    );
  }

  void updateReadingPlanBooks(List<ReadingPlanBook> books) async {
    for (ReadingPlanBook b in books) {
      await _database.update(
        'reading_plan_book',
        b.toMap(),
        where: 'id = ?',
        whereArgs: [b.id],
      );
    }
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

  Future<List<RsBookProgress>> getAllBookProgress(int readingPlanId) async {
    final result = await _database.query(
      'rs_book_progress',
      where: 'reading_plan_id = ?',
      whereArgs: [readingPlanId],
      orderBy: "book_id",
    );

    return result.map((e) => RsBookProgress.fromMap(e)).toList();
  }

  Future<int> countVersesReadForChapter(
    int readingPlanId,
    int bookId,
    int chapter,
  ) async {
    final result = await _database.rawQuery(
      'SELECT COUNT(distinct verse) AS count FROM rs_log where book_id = ? and chapter = ? and reading_plan_id = ?',
      [bookId, chapter, readingPlanId],
    );

    final count = Sqflite.firstIntValue(result) ?? 0;

    return count;
  }

  Future<Map<int, int>> getVersesReadForChapter(
    int readingPlanId,
    int bookId,
    int chapter,
  ) async {
    final result = await _database.rawQuery(
      'SELECT verse, count(*) count FROM rs_log where book_id = ? and chapter = ? and reading_plan_id = ? group by verse',
      [bookId, chapter, readingPlanId],
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
