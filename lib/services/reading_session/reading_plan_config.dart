import 'package:gbt/common/bible_navigation.dart';
import 'package:gbt/services/reading_session/rs_model.dart';

/// Immutable snapshot of the parts of a reading plan that do not change while
/// a reading session is active.
class ReadingPlanConfig {
  final int planId;
  final String planName;
  final int collectionId;
  final DailyGoal dailyGoal;
  final List<ReadingPlanBook> books;
  final Set<int> bookIds;
  final int totalChapters;
  final int totalVerses;

  ReadingPlanConfig._({
    required this.planId,
    required this.planName,
    required this.collectionId,
    required this.dailyGoal,
    required this.books,
    required this.bookIds,
    required this.totalChapters,
    required this.totalVerses,
  });

  factory ReadingPlanConfig.fromPlanDetails(
    ReadingPlanDetails details,
    BibleNavigation bibleNavigation,
  ) {
    final books = List<ReadingPlanBook>.unmodifiable(details.books);

    var totalChapters = 0;
    var totalVerses = 0;
    for (final book in books) {
      totalChapters += bibleNavigation.getChapterCount(book.bookId);
      totalVerses += bibleNavigation.getTotalVerseCount(book.bookId);
    }

    return ReadingPlanConfig._(
      planId: details.readingPlan.id!,
      planName: details.readingPlan.planName,
      collectionId: details.readingPlan.collectionId,
      dailyGoal: details.dailyGoal,
      books: books,
      bookIds: Set<int>.unmodifiable(books.map((book) => book.bookId)),
      totalChapters: totalChapters,
      totalVerses: totalVerses,
    );
  }
}
