import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:gbt/reading_plan/data_access/backup_rows.dart';
import 'package:gbt/reading_plan/data_access/reading_plan_repository.dart'
    show ReadingPlan;
import 'package:gbt/reading_plan/data_access/rs_database.dart';
import 'package:gbt/reading_plan/model.dart' show GoalType, dayString;
import 'package:gbt/services/service_locator.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' show DatabaseExecutor;

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

class ReadingPlanBackupService {
  ReadingPlanBackupService() : _database = getIt<ReadingSessionDatabase>();

  ReadingPlanBackupService.withDatabase(this._database);

  static const _backupFormatVersion = 2;
  static const _backupDirectoryName = 'backups';
  static const _backupFilePrefix = 'reading_session_';

  final ReadingSessionDatabase _database;

  Future<String> createBackup() async {
    final backupDir = await _getBackupDirectory();
    await backupDir.create(recursive: true);

    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final backupPath = join(
      backupDir.path,
      '$_backupFilePrefix$timestamp.json',
    );

    return exportBackup(backupPath);
  }

  Future<String> exportBackup(String backupPath) async {
    final file = File(backupPath);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(await buildBackupBytes(), flush: true);
    return file.path;
  }

  Future<Uint8List> buildBackupBytes() async {
    final payload = {
      'format_version': _backupFormatVersion,
      'created_at': DateTime.now().toIso8601String(),
      'tables': await exportTables(),
    };
    final encoded = utf8.encode(jsonEncode(payload));
    return Uint8List.fromList(encoded);
  }

  Future<Map<String, List<Map<String, Object?>>>> exportTables() async {
    await _database.init();
    return _database.transaction((txn) async {
      return {
        ...await _database.readingPlans.exportAll(executor: txn),
        'rs_session': await _database.session.exportAll(executor: txn),
        'rs_log': await _database.sessionLog.exportAll(executor: txn),
        'rs_day_summary': await _database.daySummary.exportAll(executor: txn),
      };
    });
  }

  Future<List<ReadingSessionBackupInfo>> listBackups() async {
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
    final file = File(backupPath);
    await restoreBackupJson(await file.readAsString());
  }

  Future<void> restoreBackupBytes(Uint8List bytes) async {
    await restoreBackupJson(utf8.decode(bytes));
  }

  Future<void> restoreBackupJson(String content) async {
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

    await _database.init();
    await _database.transaction((txn) async {
      await _database.verseState.deleteAll(executor: txn);

      if (version == 1) {
        await _restoreV1(tables, txn);
      } else {
        await _restoreCurrentFormat(tables, txn);
      }

      await _database.backfillVerseStateFromLog(txn);
      await _database.materializeAllVerseState(txn);
    });
  }

  Future<void> _restoreCurrentFormat(
    Map<String, dynamic> tables,
    DatabaseExecutor txn,
  ) async {
    await _database.readingPlans.importAll(tables, executor: txn);
    await _database.session.importAll(tables['rs_session'], executor: txn);
    await _database.sessionLog.importAll(tables['rs_log'], executor: txn);
    await _database.daySummary.importAll(
      tables['rs_day_summary'],
      executor: txn,
    );
  }

  Future<void> _restoreV1(
    Map<String, dynamic> tables,
    DatabaseExecutor txn,
  ) async {
    final sessionRows = parseBackupRows(tables['rs_daily_log'], 'rs_daily_log');
    final logRows = parseBackupRows(tables['rs_log'], 'rs_log');
    final statsRows = parseBackupRows(tables['rs_stats'], 'rs_stats');

    final defaultPlan = _defaultReadingPlan();
    await _database.readingPlans.importAll({
      'reading_plan': [defaultPlan.toPlanMap()],
      'reading_plan_book': defaultPlan.toBookMaps(),
    }, executor: txn);

    for (final row in sessionRows) {
      row['reading_plan_id'] = defaultPlan.id;
    }
    for (final row in logRows) {
      row['reading_plan_id'] = defaultPlan.id;
      row['rs_session_id'] = row.remove('rs_daily_log_id');
    }

    await _database.session.importAll(sessionRows, executor: txn);
    await _database.sessionLog.importAll(logRows, executor: txn);
    await _rebuildDaySummariesFromV1Stats(txn, statsRows, defaultPlan);
  }

  ReadingPlan _defaultReadingPlan() {
    return ReadingPlan(
      id: 1,
      planName: 'Whole Bible',
      createdAt: DateTime.now(),
      goalType: GoalType.minutes,
      goalValue: 10,
      isBookmarked: false,
      bookIds: [for (var bookId = 1; bookId <= 66; bookId++) bookId],
    );
  }

  Future<void> _rebuildDaySummariesFromV1Stats(
    DatabaseExecutor txn,
    List<Map<String, Object?>> statsRows,
    ReadingPlan plan,
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

    final dayTotals = <String, ({int seconds, int verses})>{};
    for (final row in await _database.session.exportAll(executor: txn)) {
      if (row['reading_plan_id'] != plan.id) continue;
      final day = dayString(DateTime.parse(row['rs_date'] as String));
      final totals = dayTotals[day] ?? (seconds: 0, verses: 0);
      dayTotals[day] = (
        seconds: totals.seconds + (row['read_seconds'] as int? ?? 0),
        verses: totals.verses + (row['verses'] as int? ?? 0),
      );
    }

    final summaryRows = <Map<String, Object?>>[];
    for (final entry in dayTotals.entries) {
      final day = entry.key;
      final rsSeconds = entry.value.seconds;
      final rsVerses = entry.value.verses;

      final storedFlag = dailyGoalReached[day];
      final int goalReached;
      if (storedFlag != null) {
        goalReached = storedFlag;
      } else {
        final reached = plan.goalType == GoalType.minutes
            ? rsSeconds >= plan.goalValue * 60
            : rsVerses >= plan.goalValue;
        goalReached = reached ? 1 : 0;
      }

      summaryRows.add({
        'reading_plan_id': plan.id,
        'rs_date': day,
        'rs_seconds': rsSeconds,
        'rs_verses': rsVerses,
        'goal_type': plan.goalType.storageValue,
        'goal_value': plan.goalValue,
        'goal_reached': goalReached,
      });
    }

    await _database.daySummary.importAll(summaryRows, executor: txn);
  }

  Future<Directory> _getBackupDirectory() async {
    final docDir = await getApplicationDocumentsDirectory();
    return Directory(join(docDir.path, _backupDirectoryName));
  }
}
