import 'package:gbt/reading_plan/data_access/backup_rows.dart';
import 'package:gbt/reading_plan/model.dart' show GoalType;
import 'package:sqflite/sqflite.dart';

class ReadingPlanRepository {
  ReadingPlanRepository(this._database);

  final Database _database;

  Future<ReadingPlan?> getById(int planId) async {
    final planRows = await _database.query(
      'reading_plan',
      where: 'id = ?',
      whereArgs: [planId],
      limit: 1,
    );
    if (planRows.isEmpty) return null;

    final bookRows = await _database.query(
      'reading_plan_book',
      columns: ['book_id'],
      where: 'reading_plan_id = ?',
      whereArgs: [planId],
      orderBy: 'ord',
    );

    return ReadingPlan.fromMaps(plan: planRows.first, books: bookRows);
  }

  Future<List<ReadingPlan>> list() async {
    final planRows = await _database.query(
      'reading_plan',
      orderBy: 'is_bookmarked desc, created_at desc',
    );
    if (planRows.isEmpty) return const [];

    final planIds = [for (final row in planRows) row['id'] as int];
    final placeholders = List.filled(planIds.length, '?').join(', ');
    final bookRows = await _database.query(
      'reading_plan_book',
      columns: ['reading_plan_id', 'book_id'],
      where: 'reading_plan_id IN ($placeholders)',
      whereArgs: planIds,
      orderBy: 'reading_plan_id, ord',
    );

    final booksByPlan = <int, List<Map<String, dynamic>>>{};
    for (final row in bookRows) {
      (booksByPlan[row['reading_plan_id'] as int] ??= []).add(row);
    }

    return [
      for (final row in planRows)
        ReadingPlan.fromMaps(
          plan: row,
          books: booksByPlan[row['id'] as int] ?? const [],
        ),
    ];
  }

  Future<int> commit(ReadingPlan plan) {
    return _database.transaction((txn) async {
      final planMap = plan.toPlanMap();
      final int planId;
      if (plan.id != 0) {
        planId = plan.id;
        await txn.update(
          'reading_plan',
          planMap,
          where: 'id = ?',
          whereArgs: [planId],
        );
      } else {
        planId = await txn.insert('reading_plan', planMap..remove('id'));
      }

      await txn.delete(
        'reading_plan_book',
        where: 'reading_plan_id = ?',
        whereArgs: [planId],
      );

      final batch = txn.batch();
      for (final row in plan.copyWith(id: planId).toBookMaps()) {
        batch.insert('reading_plan_book', row);
      }
      await batch.commit(noResult: true);

      return planId;
    });
  }

  Future<Map<String, List<Map<String, Object?>>>> exportAll({
    DatabaseExecutor? executor,
  }) async {
    final db = executor ?? _database;
    return {
      'reading_plan': await db.query('reading_plan', orderBy: 'id'),
      'reading_plan_book': await db.query(
        'reading_plan_book',
        orderBy: 'reading_plan_id, ord',
      ),
    };
  }

  static const _planColumns = [
    'id',
    'plan_name',
    'created_at',
    'goal_type',
    'goal_value',
    'is_bookmarked',
  ];

  static const _planBookColumns = ['reading_plan_id', 'book_id', 'ord'];

  Future<void> importAll(
    Map<String, Object?> tables, {
    required DatabaseExecutor executor,
  }) async {
    final planRows = parseBackupRows(tables['reading_plan'], 'reading_plan');
    final bookRows = parseBackupRows(
      tables['reading_plan_book'],
      'reading_plan_book',
    );

    await deleteAll(executor: executor);

    final batch = executor.batch();
    for (final row in planRows) {
      batch.insert('reading_plan', pickBackupColumns(row, _planColumns));
    }
    for (final row in bookRows) {
      batch.insert(
        'reading_plan_book',
        pickBackupColumns(row, _planBookColumns),
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> deleteAll({DatabaseExecutor? executor}) async {
    final db = executor ?? _database;
    await db.delete('reading_plan_book');
    await db.delete('reading_plan');
  }

  Future<void> delete(int planId, {DatabaseExecutor? executor}) async {
    Future<void> deleteRows(DatabaseExecutor db) async {
      await db.delete(
        'reading_plan_book',
        where: 'reading_plan_id = ?',
        whereArgs: [planId],
      );
      await db.delete('reading_plan', where: 'id = ?', whereArgs: [planId]);
    }

    if (executor != null) {
      await deleteRows(executor);
    } else {
      await _database.transaction(deleteRows);
    }
  }
}

class ReadingPlan {
  final int id; // 0 for new plans
  final String planName;
  final DateTime createdAt;
  final GoalType goalType;
  final int goalValue;
  final bool isBookmarked;
  final List<int> bookIds;

  ReadingPlan({
    required this.id,
    required this.planName,
    required this.createdAt,
    required this.goalType,
    required this.goalValue,
    required this.isBookmarked,
    required this.bookIds,
  });

  ReadingPlan copyWith({
    int? id,
    String? planName,
    DateTime? createdAt,
    GoalType? goalType,
    int? goalValue,
    bool? isBookmarked,
    List<int>? bookIds,
  }) {
    return ReadingPlan(
      id: id ?? this.id,
      planName: planName ?? this.planName,
      createdAt: createdAt ?? this.createdAt,
      goalType: goalType ?? this.goalType,
      goalValue: goalValue ?? this.goalValue,
      isBookmarked: isBookmarked ?? this.isBookmarked,
      bookIds: bookIds ?? this.bookIds,
    );
  }

  factory ReadingPlan.fromMaps({
    required Map<String, dynamic> plan,
    required List<Map<String, dynamic>> books,
  }) {
    return ReadingPlan(
      id: plan['id'] as int,
      planName: plan['plan_name'],
      createdAt: DateTime.parse(plan['created_at']),
      goalType: GoalType.fromStorage(plan['goal_type'] as String?),
      goalValue: plan['goal_value'],
      isBookmarked: plan['is_bookmarked'] == 1,
      bookIds: [for (final book in books) book['book_id'] as int],
    );
  }

  Map<String, dynamic> toPlanMap() {
    return {
      'id': id,
      'plan_name': planName,
      'created_at': createdAt.toIso8601String(),
      'goal_type': goalType.storageValue,
      'goal_value': goalValue,
      'is_bookmarked': isBookmarked ? 1 : 0,
    };
  }

  List<Map<String, dynamic>> toBookMaps() {
    return [
      for (var i = 0; i < bookIds.length; i++)
        {'reading_plan_id': id, 'book_id': bookIds[i], 'ord': i + 1},
    ];
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    if (other is! ReadingPlan ||
        other.id != id ||
        other.planName != planName ||
        other.createdAt != createdAt ||
        other.goalType != goalType ||
        other.goalValue != goalValue ||
        other.isBookmarked != isBookmarked ||
        other.bookIds.length != bookIds.length) {
      return false;
    }
    for (var i = 0; i < bookIds.length; i++) {
      if (other.bookIds[i] != bookIds[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    id,
    planName,
    createdAt,
    goalType,
    goalValue,
    isBookmarked,
    Object.hashAll(bookIds),
  );
}
