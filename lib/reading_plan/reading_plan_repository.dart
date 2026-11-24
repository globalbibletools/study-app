import 'package:gbt/reading_plan/rs_model.dart' show GoalType;
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
      goalType: _goalTypeFromStorage(plan['goal_type'] as String?),
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
      'goal_type': _goalTypeToStorage(goalType),
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

  static GoalType _goalTypeFromStorage(String? stored) {
    // Legacy rows use the single-letter codes 'M'/'V'; newer rows use the
    // enum names. Both map back onto the enum here.
    final value = stored?.toLowerCase() ?? '';
    return value.startsWith('m') ? GoalType.minutes : GoalType.verses;
  }

  static String _goalTypeToStorage(GoalType goalType) => goalType.name;
}

