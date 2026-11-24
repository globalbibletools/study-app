import 'package:gbt/common/reference.dart';
import 'package:gbt/reading_plan/reading_plan_read_models.dart';
import 'package:gbt/reading_plan/rs_model.dart';

ReadingPlanConfig planConfig({
  int id = 7,
  String name = 'Ruth Plan',
  int collectionId = 1,
  GoalType goalType = GoalType.verses,
  int goalValue = 10,
  List<int> bookIds = const [8],
  bool isBookmarked = false,
  DateTime? createdAt,
}) {
  return ReadingPlanConfig(
    planId: id,
    planName: name,
    collectionId: collectionId,
    isBookmarked: isBookmarked,
    createdAt: createdAt ?? DateTime(2026, 1, 1),
    dailyGoal: DailyGoal(goalType, goalValue),
    books: [
      for (var i = 0; i < bookIds.length; i++)
        ReadingPlanBook(readingPlanId: id, bookId: bookIds[i], ord: i + 1),
    ],
  );
}

ReadingPlanProgress planProgress({
  int id = 7,
  List<int> bookIds = const [8],
  List<BookProgress> bookStats = const [],
  int? totalVerses,
  int? versesRead,
  Reference? resumePosition,
}) {
  final stats = <BookProgress>[];
  if (bookStats.isNotEmpty) {
    stats.addAll(bookStats);
  } else if (bookIds.isNotEmpty) {
    for (var i = 0; i < bookIds.length; i++) {
      stats.add(
        BookProgress(
          bookId: bookIds[i],
          totalVerses: i == 0 ? totalVerses ?? 0 : 0,
          versesRead: i == 0 ? versesRead ?? 0 : 0,
        ),
      );
    }
  } else if (totalVerses != null || versesRead != null) {
    stats.add(
      BookProgress(
        bookId: 0,
        totalVerses: totalVerses ?? 0,
        versesRead: versesRead ?? 0,
      ),
    );
  }

  return ReadingPlanProgress(
    planId: id,
    bookProgress: {for (final stat in stats) stat.bookId: stat},
    resumePosition: resumePosition,
  );
}

ReadingPlanSummary planSummary({
  String name = 'Ruth Plan',
  int id = 7,
  int collectionId = 1,
  GoalType goalType = GoalType.verses,
  int goalValue = 10,
  List<int> bookIds = const [8],
  bool isBookmarked = false,
  DateTime? createdAt,
  List<BookProgress> bookStats = const [],
  int? totalVerses,
  int? versesRead,
  Reference? resumePosition,
  DayProgress? today,
}) {
  return ReadingPlanSummary(
    config: planConfig(
      id: id,
      name: name,
      collectionId: collectionId,
      goalType: goalType,
      goalValue: goalValue,
      bookIds: bookIds,
      isBookmarked: isBookmarked,
      createdAt: createdAt,
    ),
    progress: planProgress(
      id: id,
      bookIds: bookIds,
      bookStats: bookStats,
      totalVerses: totalVerses,
      versesRead: versesRead,
      resumePosition: resumePosition,
    ),
    today: today ?? DayProgress.empty(DateTime.now()),
  );
}

BookProgress bookStats(
  int bookId, {
  required int totalVerses,
  required int versesRead,
}) {
  return BookProgress(
    bookId: bookId,
    totalVerses: totalVerses,
    versesRead: versesRead,
  );
}
