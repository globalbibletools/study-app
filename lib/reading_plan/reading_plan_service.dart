import 'package:gbt/reading_plan/data_access/reading_plan_repository.dart'
    as repo;
import 'package:gbt/reading_plan/data_access/rs_database.dart';
import 'package:gbt/reading_plan/data_access/session_repository.dart';
import 'package:gbt/reading_plan/model.dart';
import 'package:gbt/services/service_locator.dart';

class ReadingPlanService {
  final _database = getIt<ReadingSessionDatabase>();

  Future<void> addManualSession({
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

    await _database.unitOfWork((uow) async {
      await _requireReadingPlan(uow.readingPlans, readingPlanId);

      final day = _dayOnly(date);
      final now = DateTime.now();
      final isToday = _sameDay(day, now);

      await uow.session.commit(
        Session(
          rsDate: day,
          startTime: now,
          endTime: now.add(Duration(seconds: readSeconds)),
          readSeconds: readSeconds,
          verses: verses,
          readingPlanId: readingPlanId,
          isManual: true,
        ),
      );

      await uow.daySummary.upsert(
        readingPlanId,
        day,
        preserveStoredGoalSnapshot: !isToday,
      );
    });
  }

  Future<void> deleteManualSession(int sessionId) {
    return _database.unitOfWork((uow) async {
      final session = await uow.session.getById(sessionId);
      if (session == null) {
        throw StateError('Session not found: $sessionId');
      }
      if (!session.isManual) {
        throw StateError('Only manual sessions can be deleted.');
      }

      await uow.session.delete(sessionId);

      final remaining = await uow.session.countForDate(
        session.rsDate,
        session.readingPlanId,
      );
      if (remaining == 0) {
        await uow.daySummary.deleteForDay(
          session.readingPlanId,
          session.rsDate,
        );
      } else {
        await uow.daySummary.upsert(
          session.readingPlanId,
          session.rsDate,
          preserveStoredGoalSnapshot: !_sameDay(session.rsDate, DateTime.now()),
        );
      }
    });
  }

  static bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Future<repo.ReadingPlan> _requireReadingPlan(
    repo.ReadingPlanRepository readingPlans,
    int planId,
  ) async {
    final plan = await readingPlans.getById(planId);
    if (plan == null) {
      throw StateError('Reading plan not found: $planId');
    }
    return plan;
  }

  static DateTime _dayOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  Future<int> saveReadingPlan({
    int? planId,
    required String planName,
    required GoalType goalType,
    required int goalValue,
    required List<int> bookIds,
  }) {
    return _database.unitOfWork((uow) async {
      final existingPlan = planId == null
          ? null
          : await _requireReadingPlan(uow.readingPlans, planId);

      final previousBookIds = existingPlan?.bookIds.toSet() ?? const <int>{};
      final plan = existingPlan == null
          ? repo.ReadingPlan(
              id: 0,
              planName: planName,
              createdAt: DateTime.now(),
              goalType: goalType,
              goalValue: goalValue,
              isBookmarked: false,
              bookIds: List<int>.of(bookIds),
            )
          : existingPlan.copyWith(
              planName: planName,
              goalType: goalType,
              goalValue: goalValue,
              bookIds: List<int>.of(bookIds),
            );

      final committedPlanId = await uow.readingPlans.commit(plan);

      final newlyAddedBookIds = bookIds.toSet().difference(previousBookIds);
      await uow.verseState.materialize(
        committedPlanId,
        bookIds: newlyAddedBookIds,
      );

      return committedPlanId;
    });
  }

  Future<void> setReadingPlanBookmark(int planId, bool isBookmarked) {
    return _database.unitOfWork((uow) async {
      final savedPlan = await _requireReadingPlan(uow.readingPlans, planId);

      await uow.readingPlans.commit(
        savedPlan.copyWith(isBookmarked: isBookmarked),
      );
    });
  }

  Future<void> deleteReadingPlan(int planId) {
    return _database.unitOfWork((uow) async {
      await _requireReadingPlan(uow.readingPlans, planId);

      await uow.sessionLog.deleteForPlanId(planId);
      await uow.session.deleteForPlanId(planId);
      await uow.daySummary.deleteForPlanId(planId);
      await uow.verseState.deleteForPlanId(planId);
      await uow.readingPlans.delete(planId);
    });
  }
}
