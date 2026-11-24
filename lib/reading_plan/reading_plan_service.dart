import 'package:gbt/common/bible_navigation.dart';
import 'package:gbt/common/reference.dart';
import 'package:gbt/reading_plan/reading_plan_repository.dart' as repo;
import 'package:gbt/reading_plan/rs_database.dart';
import 'package:gbt/reading_plan/rs_model.dart';
import 'package:gbt/services/service_locator.dart';

class ReadingPlanService {
  ReadingPlanService()
    : this.withDependencies(
        database: getIt<ReadingSessionDatabase>(),
        bibleNavigation: getIt<BibleNavigation>(),
      );

  ReadingPlanService.withDependencies({
    required ReadingSessionDatabase database,
    required BibleNavigation bibleNavigation,
  }) : _database = database,
       _bibleNavigation = bibleNavigation;

  final ReadingSessionDatabase _database;
  final BibleNavigation _bibleNavigation;

  Future<List<ReadingPlanDetails>> getReadingPlans() {
    return _database.getReadingPlans();
  }

  Future<ReadingPlanDetails?> getReadingPlanById(int planId) async {
    final details = await _database.getReadingPlanById(planId);
    if (details == null) return null;

    details.resumePosition = await _database.getResumeReference(planId);
    return details;
  }

  Future<List<RsBookStats>> getBooksStats(int readingPlanId) async {
    final stats = await _database.getBookStats(readingPlanId);

    return [
      for (int bookId = 1; bookId <= _bibleNavigation.getBooksCount(); bookId++)
        stats[bookId] ?? _emptyStats(bookId),
    ];
  }

  Future<Reference?> getResumeReference(int planId) {
    return _database.getResumeReference(planId);
  }

  Future<DayProgress> getDayProgress(int readingPlanId, DateTime date) async {
    final day = DateTime(date.year, date.month, date.day);
    final summary = await _database.getDaySummary(readingPlanId, day);

    if (summary == null) return DayProgress.empty(day);

    return DayProgress(
      day,
      _roundedMinutes(summary.rsSeconds),
      summary.rsVerses,
      summary.goalReached,
    );
  }

  double _roundedMinutes(int seconds) => (seconds / 6).round() / 10;

  Future<SessionDetails> addManualSession({
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

    final day = _dayOnly(date);
    final now = DateTime.now();
    final isToday = _sameDay(day, now);

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

    return SessionDetails(session, const []);
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
          preserveStoredGoalSnapshot: !_sameDay(session.rsDate, DateTime.now()),
          executor: txn,
        );
      }
    });

    return true;
  }

  static bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Future<List<DayProgress>> getMonthProgress(
    int readingPlanId,
    DateTime month,
  ) async {
    final int daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final DateTime startOfMonth = DateTime(month.year, month.month, 1);
    final DateTime endOfMonth = DateTime(month.year, month.month + 1, 0);

    final List<RsDaySummary> daySummariesForCurrentMonth = await _database
        .getDaySummariesBetween(readingPlanId, startOfMonth, endOfMonth);

    final monthData = <DayProgress>[];
    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(month.year, month.month, day);
      final summary = daySummariesForCurrentMonth
          .where((summary) => summary.rsDate.day == day)
          .firstOrNull;

      if (summary == null) {
        monthData.add(DayProgress.empty(date));
      } else {
        monthData.add(
          DayProgress(
            date,
            _roundedMinutes(summary.rsSeconds),
            summary.rsVerses,
            summary.goalReached,
          ),
        );
      }
    }

    return monthData;
  }

  Future<List<SessionDetails>> getDetailedProgressFor(
    DateTime date,
    int readingPlanId,
  ) async {
    final List<RsSession> sessions = await _database.getSessionsForDate(
      date,
      readingPlanId,
    );

    final result = <SessionDetails>[];

    for (final session in sessions) {
      final List<RsLog> logs = await _database.getRsLogForSession(session.id!);

      final progress = <DetailedProgess>[];
      DetailedProgess? current;

      for (final entry in logs) {
        if (current == null ||
            current.bookId != entry.bookId ||
            current.chapter != entry.chapter ||
            entry.verse - current.toVerse > 1) {
          current = DetailedProgess(
            entry.bookId,
            entry.chapter,
            entry.verse,
            entry.verse,
          );
          progress.add(current);
        } else {
          current.toVerse = entry.verse;
        }
      }

      result.add(SessionDetails(session, progress));
    }

    return result;
  }

  Future<List<ReadingPlanDetails>> getReadingPlansWithProgress({
    DateTime? today,
  }) async {
    final plans = await getReadingPlans();
    final progress = await _database.getReadingPlanProgress();
    final day = _dayOnly(today ?? DateTime.now());
    final todaysSummary = await _database.getDaySummariesForDate(day);

    for (final plan in plans) {
      final planId = plan.readingPlan.id!;
      final planProgress = progress[planId];

      plan.totalVerses = planProgress?.totalVerses ?? 0;
      plan.versesRead = planProgress?.versesRead ?? 0;

      final summary = todaysSummary[planId];
      plan.todayProgress = summary == null
          ? DayProgress.empty(day)
          : DayProgress(
              day,
              _roundedMinutes(summary.rsSeconds),
              summary.rsVerses,
              summary.goalReached,
            );

      plan.resumePosition = await getResumeReference(planId);
    }

    return plans;
  }

  static DateTime _dayOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  RsBookStats _emptyStats(int bookId) {
    return RsBookStats(
      bookId: bookId,
      totalVerses: 0,
      versesRead: 0,
      lastRead: null,
      resumePosition: null,
    );
  }

  Future<int> saveReadingPlan({
    int? planId,
    required String planName,
    required GoalType goalType,
    required int goalValue,
    required List<int> bookIds,
  }) async {
    final existingPlan = planId == null || planId == 0
        ? null
        : await _database.readingPlans.getById(planId);

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

    final committedPlanId = await _database.readingPlans.commit(plan);

    final newlyAddedBookIds = bookIds.toSet().difference(previousBookIds);
    await _database.materializeVerseStateForPlan(
      committedPlanId,
      bookIds: newlyAddedBookIds,
    );

    return committedPlanId;
  }

  Future<void> setReadingPlanBookmark(int planId, bool isBookmarked) async {
    final savedPlan = await _database.readingPlans.getById(planId);
    if (savedPlan == null) return;

    await _database.readingPlans.commit(
      savedPlan.copyWith(isBookmarked: isBookmarked),
    );
  }

  Future<void> reorderReadingPlanBooks(
    int readingPlanId,
    List<int> bookIds,
  ) async {
    final plan = await _database.readingPlans.getById(readingPlanId);
    if (plan == null) return;

    await _database.readingPlans.commit(plan.copyWith(bookIds: bookIds));
  }

  Future<void> deleteReadingPlan(int planId) async {
    await _database.transaction((txn) async {
      await _database.sessionLog.deleteForPlanId(planId, executor: txn);
      await _database.deleteSessionsForPlan(planId, executor: txn);
      await _database.deleteDaySummariesForPlan(planId, executor: txn);
      await _database.deleteVerseStateForPlan(planId, executor: txn);
      await _database.readingPlans.delete(planId, executor: txn);
    });
  }
}
