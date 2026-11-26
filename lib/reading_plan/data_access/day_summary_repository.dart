import 'package:gbt/reading_plan/data_access/backup_rows.dart';
import 'package:gbt/reading_plan/model.dart';
import 'package:gbt/reading_plan/model.dart' as model show dayString;
import 'package:sqflite/sqflite.dart';

class DaySummaryRepository {
  DaySummaryRepository(this._database);

  final DatabaseExecutor _database;

  Future<void> upsert(
    int readingPlanId,
    DateTime date, {
    bool preserveStoredGoalSnapshot = false,
  }) async {
    final totals = await _database.rawQuery(
      'SELECT coalesce(sum(read_seconds), 0) AS rs_seconds, '
      'coalesce(sum(verses), 0) AS rs_verses '
      'FROM rs_session '
      'WHERE reading_plan_id = ? AND date(rs_date) = date(?)',
      [readingPlanId, date.toIso8601String()],
    );

    final rsSeconds = totals.first['rs_seconds'] as int? ?? 0;
    final rsVerses = totals.first['rs_verses'] as int? ?? 0;

    String? storedGoalType;
    int? storedGoalValue;
    if (preserveStoredGoalSnapshot) {
      final stored = await _database.query(
        'rs_day_summary',
        columns: ['goal_type', 'goal_value'],
        where: 'reading_plan_id = ? AND rs_date = ?',
        whereArgs: [readingPlanId, DaySummary.dayString(date)],
        limit: 1,
      );
      if (stored.isNotEmpty) {
        storedGoalType = stored.first['goal_type'] as String?;
        storedGoalValue = stored.first['goal_value'] as int?;
      }
    }
    if (storedGoalType == null || storedGoalValue == null) {
      final plan = await _database.query(
        'reading_plan',
        columns: ['goal_type', 'goal_value'],
        where: 'id = ?',
        whereArgs: [readingPlanId],
        limit: 1,
      );
      storedGoalType = plan.isEmpty ? null : plan.first['goal_type'] as String?;
      storedGoalValue = plan.isEmpty ? null : plan.first['goal_value'] as int?;
    }

    final goalType = GoalType.fromStorage(storedGoalType);
    final goalValue = storedGoalValue ?? 0;
    final goalReached = goalType == GoalType.minutes
        ? rsSeconds >= goalValue * 60
        : rsVerses >= goalValue;

    await _database.insert(
      'rs_day_summary',
      DaySummary(
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

  Future<DaySummary?> get(int readingPlanId, DateTime date) async {
    final rows = await _database.query(
      'rs_day_summary',
      where: 'reading_plan_id = ? AND rs_date = ?',
      whereArgs: [readingPlanId, DaySummary.dayString(date)],
      limit: 1,
    );

    return rows.isEmpty ? null : DaySummary.fromMap(rows.first);
  }

  Future<List<DaySummary>> listBetween(
    int readingPlanId,
    DateTime start,
    DateTime end,
  ) async {
    final rows = await _database.query(
      'rs_day_summary',
      where: 'reading_plan_id = ? AND rs_date BETWEEN ? AND ?',
      whereArgs: [
        readingPlanId,
        DaySummary.dayString(start),
        DaySummary.dayString(end),
      ],
      orderBy: 'rs_date asc',
    );

    return [for (final row in rows) DaySummary.fromMap(row)];
  }

  Future<List<Map<String, Object?>>> exportAll() async {
    return _database.query(
      'rs_day_summary',
      orderBy: 'reading_plan_id, rs_date',
    );
  }

  static const _summaryColumns = [
    'reading_plan_id',
    'rs_date',
    'rs_seconds',
    'rs_verses',
    'goal_type',
    'goal_value',
    'goal_reached',
  ];

  Future<void> importAll(Object? rows) async {
    final summaryRows = parseBackupRows(rows, 'rs_day_summary');

    await _database.delete('rs_day_summary');

    final batch = _database.batch();
    for (final row in summaryRows) {
      batch.insert('rs_day_summary', pickBackupColumns(row, _summaryColumns));
    }
    await batch.commit(noResult: true);
  }

  Future<int> deleteForDay(int readingPlanId, DateTime date) {
    return _database.delete(
      'rs_day_summary',
      where: 'reading_plan_id = ? AND rs_date = ?',
      whereArgs: [readingPlanId, DaySummary.dayString(date)],
    );
  }

  Future<int> deleteForPlanId(int readingPlanId) {
    return _database.delete(
      'rs_day_summary',
      where: 'reading_plan_id = ?',
      whereArgs: [readingPlanId],
    );
  }
}

class DaySummary {
  const DaySummary({
    required this.readingPlanId,
    required this.rsDate,
    required this.rsSeconds,
    required this.rsVerses,
    required this.goalType,
    required this.goalValue,
    required this.goalReached,
  });

  final int readingPlanId;
  final DateTime rsDate;
  final int rsSeconds;
  final int rsVerses;
  final GoalType goalType;
  final int goalValue;
  final bool goalReached;

  factory DaySummary.fromMap(Map<String, Object?> map) {
    return DaySummary(
      readingPlanId: map['reading_plan_id'] as int,
      rsDate: DateTime.parse(map['rs_date'] as String),
      rsSeconds: map['rs_seconds'] as int,
      rsVerses: map['rs_verses'] as int,
      goalType: GoalType.fromStorage(map['goal_type'] as String?),
      goalValue: map['goal_value'] as int? ?? 0,
      goalReached: map['goal_reached'] == 1,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'reading_plan_id': readingPlanId,
      'rs_date': dayString(rsDate),
      'rs_seconds': rsSeconds,
      'rs_verses': rsVerses,
      'goal_type': goalType.storageValue,
      'goal_value': goalValue,
      'goal_reached': goalReached ? 1 : 0,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is DaySummary &&
        other.readingPlanId == readingPlanId &&
        other.rsDate == rsDate &&
        other.rsSeconds == rsSeconds &&
        other.rsVerses == rsVerses &&
        other.goalType == goalType &&
        other.goalValue == goalValue &&
        other.goalReached == goalReached;
  }

  @override
  int get hashCode => Object.hash(
    readingPlanId,
    rsDate,
    rsSeconds,
    rsVerses,
    goalType,
    goalValue,
    goalReached,
  );

  /// Formats a local date as the `YYYY-MM-DD` string stored in `rs_date`.
  static String dayString(DateTime date) => model.dayString(date);
}
