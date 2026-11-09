import 'package:gbt/common/bible_navigation.dart';
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

  Future<List<RsBookProgress>> getBooksProgress(int readingPlanId) async {
    final storedProgress = await _database.getAllBookProgress(readingPlanId);
    final progressByBook = {
      for (final progress in storedProgress) progress.bookId: progress,
    };

    return [
      for (int bookId = 1; bookId <= _bibleNavigation.getBooksCount(); bookId++)
        progressByBook[bookId] ?? _emptyProgress(readingPlanId, bookId),
    ];
  }

  Future<RsBookProgress?> getLatestBookProgress(
    int readingPlanId, {
    List<int>? orderedBookIds,
    Set<int>? planBookIds,
  }) async {
    final storedProgress = await _database.getAllBookProgress(readingPlanId);
    final progressByBook = {
      for (final progress in storedProgress) progress.bookId: progress,
    };

    if (orderedBookIds != null && orderedBookIds.isNotEmpty) {
      return _latestBookProgress(readingPlanId, orderedBookIds, progressByBook);
    }

    final filtered = storedProgress
        .where(
          (progress) =>
              planBookIds == null || planBookIds.contains(progress.bookId),
        )
        .toList();

    if (filtered.isEmpty) return null;

    final incomplete = filtered
        .where(
          (progress) =>
              progress.versesRead <
              _bibleNavigation.getTotalVerseCount(progress.bookId),
        )
        .toList();
    final candidates = incomplete.isNotEmpty ? incomplete : filtered;

    return candidates.reduce(
      (a, b) => a.updatedAt.isAfter(b.updatedAt) ? a : b,
    );
  }

  Future<List<DayProgress>> getMonthProgress(
    int readingPlanId,
    DateTime month,
  ) async {
    final int daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final DateTime startOfMonth = DateTime(month.year, month.month, 1);
    final DateTime endOfMonth = DateTime(month.year, month.month + 1, 0);

    final List<RsStats> dailyStatsForCurrentMonth = await _database
        .getRsStatsForType(
          RsStatsType.daily,
          startOfMonth,
          endOfMonth,
          readingPlanId,
        );

    final statsByDay = <int, RsStats>{};
    for (final stats in dailyStatsForCurrentMonth) {
      statsByDay[stats.statsDate.day] = stats;
    }

    final monthData = <DayProgress>[];
    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(month.year, month.month, day);
      final stats = statsByDay[day];

      if (stats == null) {
        monthData.add(DayProgress.empty(date));
      } else {
        monthData.add(
          DayProgress(
            date,
            stats.rsSeconds ~/ 60,
            stats.rsVerses,
            stats.goalReached,
          ),
        );
      }
    }

    return monthData;
  }

  Future<List<Session>> getDetailedProgressFor(
    DateTime date,
    int readingPlanId,
  ) async {
    final List<RsDailyLog> sessions = await _database.getSessionsForDate(
      date,
      readingPlanId,
    );

    final result = <Session>[];

    for (final session in sessions) {
      final List<RsLog> logs = await _database.getRsLogForDailyLog(session.id!);

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

      result.add(Session(session, progress));
    }

    return result;
  }

  Future<List<ReadingPlanDetails>> getReadingPlansWithProgress() async {
    final plans = await getReadingPlans();

    for (final plan in plans) {
      final planId = plan.readingPlan.id!;
      final orderedBookIds = plan.books.map((b) => b.bookId).toList();
      final storedProgress = await _database.getAllBookProgress(planId);
      final progressByBook = {
        for (final progress in storedProgress) progress.bookId: progress,
      };

      int totalChapters = 0;
      int totalVerses = 0;
      int versesRead = 0;
      int booksRead = 0;

      for (final bookId in orderedBookIds) {
        final progress =
            progressByBook[bookId] ?? _emptyProgress(planId, bookId);
        progressByBook[bookId] = progress;

        final bookChapterCount = _bibleNavigation.getChapterCount(bookId);
        final bookVerseCount = _bibleNavigation.getTotalVerseCount(bookId);

        totalChapters += bookChapterCount;
        totalVerses += bookVerseCount;
        versesRead += progress.versesRead;

        if (progress.versesRead >= bookVerseCount) {
          booksRead += 1;
        }
      }

      plan.totalChapters = totalChapters;
      plan.totalVerses = totalVerses;
      plan.versesRead = versesRead;
      plan.booksRead = booksRead;
      plan.latestBookProgress = _latestBookProgress(
        planId,
        orderedBookIds,
        progressByBook,
      );
    }

    return plans;
  }

  RsBookProgress? _latestBookProgress(
    int planId,
    List<int> orderedBookIds,
    Map<int, RsBookProgress> progressByBook,
  ) {
    if (orderedBookIds.isEmpty) return null;

    for (final bookId in orderedBookIds) {
      final progress = progressByBook[bookId] ?? _emptyProgress(planId, bookId);
      if (progress.versesRead < _bibleNavigation.getTotalVerseCount(bookId)) {
        return progress;
      }
    }

    final firstBookId = orderedBookIds.first;
    return progressByBook[firstBookId] ?? _emptyProgress(planId, firstBookId);
  }

  RsBookProgress _emptyProgress(int planId, int bookId) {
    return RsBookProgress(
      readingPlanId: planId,
      bookId: bookId,
      chapter: 1,
      verse: 1,
      chaptersRead: 0,
      versesRead: 0,
      updatedAt: DateTime.now(),
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
