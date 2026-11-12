import 'package:gbt/common/bible_navigation.dart';
import 'package:gbt/common/reference.dart';
import 'package:gbt/services/reading_session/rs_database.dart';
import 'package:gbt/services/reading_session/rs_model.dart';
import 'package:gbt/services/service_locator.dart';

class ReadingPlanService {
  ReadingPlanService() : _database = getIt<ReadingSessionDatabase>();

  ReadingPlanService.withDatabase(this._database);

  final ReadingSessionDatabase _database;
  late final _bibleNavigation = getIt<BibleNavigation>();

  Future<List<ReadingPlanDetails>> getReadingPlans() {
    return _database.getReadingPlans();
  }

  Future<ReadingPlanDetails?> getReadingPlanById(int planId) {
    return _database.getReadingPlanById(planId);
  }

  Future<List<RsBookStats>> getBooksStats(int readingPlanId) async {
    final stats = await _database.getBookStats(readingPlanId);

    return [
      for (int bookId = 1; bookId <= _bibleNavigation.getBooksCount(); bookId++)
        stats[bookId] ?? _emptyStats(bookId),
    ];
  }

  Future<Reference?> getResumeReference(int planId, {Reference? after}) async {
    final resume = await _database.getResumeReference(planId, after: after);
    return resume ?? after;
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
    );
  }

  Future<ReadingPlan> saveReadingPlan({
    ReadingPlanDetails? existingPlanDetails,
    required String planName,
    required int collectionId,
    required GoalType goalType,
    required int goalValue,
    required Set<int> selectedBookIds,
  }) {
    final List<int> orderedBookIds = [];
    if (existingPlanDetails != null) {
      for (final b in existingPlanDetails.books) {
        if (selectedBookIds.contains(b.bookId)) {
          orderedBookIds.add(b.bookId);
        }
      }
    }
    final existingBookIdsSet = orderedBookIds.toSet();
    final newlyAddedBooks =
        selectedBookIds.where((b) => !existingBookIdsSet.contains(b)).toList()
          ..sort();
    orderedBookIds.addAll(newlyAddedBooks);

    return _database.saveReadingPlan(
      existingPlan: existingPlanDetails?.readingPlan,
      planName: planName,
      collectionId: collectionId,
      goalType: goalType.name,
      goalValue: goalValue,
      orderedBookIds: orderedBookIds,
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
