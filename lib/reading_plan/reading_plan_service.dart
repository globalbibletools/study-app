import 'package:gbt/reading_plan/rs_database.dart';
import 'package:gbt/reading_plan/rs_model.dart';
import 'package:gbt/services/service_locator.dart';

class ReadingPlanService {
  ReadingPlanService()
    : this.withDependencies(database: getIt<ReadingSessionDatabase>());

  ReadingPlanService.withDependencies({
    required ReadingSessionDatabase database,
  }) : _database = database;

  final ReadingSessionDatabase _database;

  Future<int> addManualSession({
    required int readingPlanId,
    required DateTime date,
    required double minutes,
    required int verses,
  }) async {
    if (minutes.isNaN || minutes.isInfinite || minutes < 0) {
      throw ArgumentError.value(minutes, 'minutes', 'Must be non-negative.');
    }
    if (verses < 0) {
      throw ArgumentError.value(verses, 'verses', 'Must be non-negative.');
    }

    final readSeconds = (minutes * 60).round();
    if (readSeconds == 0 && verses == 0) {
      throw ArgumentError('Minutes and verses cannot both be zero.');
    }

    final day = dayOnly(date);
    final now = DateTime.now();
    final isToday = isSameDay(day, now);

    final session = await _database.transaction((txn) async {
      final inserted = await _database.insertSession(
        RsSession(
          rsDate: day,
          startTime: now,
          endTime: now.add(Duration(seconds: readSeconds)),
          readSeconds: readSeconds,
          verses: verses,
          readingPlanId: readingPlanId,
          isManual: true,
        ),
        executor: txn,
      );

      await _database.upsertDaySummary(
        readingPlanId,
        day,
        preserveStoredGoalSnapshot: !isToday,
        executor: txn,
      );

      return inserted;
    });

    return session.id!;
  }

  Future<bool> deleteManualSession(int sessionId) async {
    final session = await _database.getSessionById(sessionId);
    if (session == null) return false;
    if (!session.isManual) {
      throw StateError('Only manual sessions can be deleted.');
    }

    await _database.transaction((txn) async {
      await _database.deleteSession(sessionId, executor: txn);

      final remaining = await _database.getSessionCountForDate(
        session.rsDate,
        session.readingPlanId,
        executor: txn,
      );
      if (remaining == 0) {
        await _database.deleteDaySummary(
          session.readingPlanId,
          session.rsDate,
          executor: txn,
        );
      } else {
        await _database.upsertDaySummary(
          session.readingPlanId,
          session.rsDate,
          preserveStoredGoalSnapshot: !isSameDay(
            session.rsDate,
            DateTime.now(),
          ),
          executor: txn,
        );
      }
    });

    return true;
  }

  Future<int> saveReadingPlan({
    int? planId,
    required String planName,
    required int collectionId,
    required GoalType goalType,
    required int goalValue,
    required Set<int> selectedBookIds,
    List<int>? orderedBookIds,
  }) async {
    ReadingPlan? existingPlan;
    var existingBookIds = const <int>[];
    if (planId != null) {
      final details = await _database.getReadingPlanById(planId);
      if (details == null) {
        throw StateError('Reading plan not found: $planId');
      }
      existingPlan = details.readingPlan;
      existingBookIds = [for (final book in details.books) book.bookId];
    }

    final List<int> orderedIds;
    if (orderedBookIds != null) {
      final selected = <int>{};
      orderedIds = [
        for (final bookId in orderedBookIds)
          if (selectedBookIds.contains(bookId) && selected.add(bookId)) bookId,
      ];
      final missing =
          selectedBookIds.where((bookId) => !selected.contains(bookId)).toList()
            ..sort();
      orderedIds.addAll(missing);
    } else {
      orderedIds = [];
      for (final bookId in existingBookIds) {
        if (selectedBookIds.contains(bookId)) {
          orderedIds.add(bookId);
        }
      }
      final existingBookIdsSet = orderedIds.toSet();
      final newlyAddedBooks =
          selectedBookIds.where((b) => !existingBookIdsSet.contains(b)).toList()
            ..sort();
      orderedIds.addAll(newlyAddedBooks);
    }

    final savedPlan = await _database.saveReadingPlan(
      existingPlan: existingPlan,
      planName: planName,
      collectionId: collectionId,
      goalType: goalType.storedValue,
      goalValue: goalValue,
      orderedBookIds: orderedIds,
    );
    return savedPlan.id!;
  }

  Future<void> setReadingPlanBookmark(int planId, bool isBookmarked) async {
    final details = await _database.getReadingPlanById(planId);
    if (details == null) {
      throw StateError('Reading plan not found: $planId');
    }

    final updatedPlan = details.readingPlan.copyWith(
      isBookmarked: isBookmarked,
    );
    await _database.updateReadingPlan(updatedPlan);
  }

  Future<void> deleteReadingPlan(int planId) {
    return _database.deleteReadingPlan(planId);
  }
}
