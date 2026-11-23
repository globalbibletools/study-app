import 'package:gbt/common/bible_navigation.dart';
import 'package:gbt/common/reference.dart';
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
      summary.rsSeconds ~/ 60,
      summary.rsVerses,
      summary.goalReached,
    );
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
            summary.rsSeconds ~/ 60,
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

  Future<List<ReadingPlanDetails>> getReadingPlansWithProgress() async {
    final plans = await getReadingPlans();
    final progress = await _database.getReadingPlanProgress();

    for (final plan in plans) {
      final planId = plan.readingPlan.id!;
      final planProgress = progress[planId];

      plan.totalVerses = planProgress?.totalVerses ?? 0;
      plan.versesRead = planProgress?.versesRead ?? 0;

      plan.resumePosition = await getResumeReference(planId);
    }

    return plans;
  }

  RsBookStats _emptyStats(int bookId) {
    return RsBookStats(
      bookId: bookId,
      totalVerses: 0,
      versesRead: 0,
      lastRead: null,
      resumePosition: null,
    );
  }

  Future<ReadingPlan> saveReadingPlan({
    ReadingPlanDetails? existingPlanDetails,
    required String planName,
    required int collectionId,
    required GoalType goalType,
    required int goalValue,
    required Set<int> selectedBookIds,
    List<int>? orderedBookIds,
  }) {
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
      if (existingPlanDetails != null) {
        for (final b in existingPlanDetails.books) {
          if (selectedBookIds.contains(b.bookId)) {
            orderedIds.add(b.bookId);
          }
        }
      }
      final existingBookIdsSet = orderedIds.toSet();
      final newlyAddedBooks =
          selectedBookIds.where((b) => !existingBookIdsSet.contains(b)).toList()
            ..sort();
      orderedIds.addAll(newlyAddedBooks);
    }

    return _database.saveReadingPlan(
      existingPlan: existingPlanDetails?.readingPlan,
      planName: planName,
      collectionId: collectionId,
      goalType: goalType.name,
      goalValue: goalValue,
      orderedBookIds: orderedIds,
    );
  }

  Future<ReadingPlan> setReadingPlanBookmark(
    ReadingPlan readingPlan,
    bool isBookmarked,
  ) async {
    final updatedPlan = readingPlan.copyWith(isBookmarked: isBookmarked);
    await _database.updateReadingPlan(updatedPlan);
    return updatedPlan;
  }

  Future<void> reorderReadingPlanBooks(
    int readingPlanId,
    List<ReadingPlanBook> books,
  ) {
    final updatedBooks = [
      for (int i = 0; i < books.length; i++)
        books[i].copyWith(readingPlanId: readingPlanId, ord: i + 1),
    ];
    return _database.updateReadingPlanBooks(updatedBooks);
  }

  Future<void> deleteReadingPlan(int planId) {
    return _database.deleteReadingPlan(planId);
  }
}
