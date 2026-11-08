import 'package:gbt/common/bible_navigation.dart';
import 'package:gbt/services/reading_session/rs_database.dart';
import 'package:gbt/services/reading_session/rs_model.dart';
import 'package:gbt/services/reading_session/rs_types.dart';
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
