import 'package:gbt/services/reading_session/rs_database.dart';
import 'package:gbt/services/reading_session/rs_manager.dart';
import 'package:gbt/services/reading_session/rs_model.dart';
import 'package:gbt/services/service_locator.dart';

class AddReadingPlanPanelManager {
  final _rsdbManager = getIt<ReadingSessionDatabase>();
  final ReadingPlanDetails? readingPlan;

  AddReadingPlanPanelManager(this.readingPlan);

  Future<ReadingPlan> addReadingPlan(
    String planName,
    int collectionId,
    GoalType goalType,
    int goalValue,
    Set<int> books,
  ) async {
    ReadingPlan plan;

    if (readingPlan != null) {
      plan = readingPlan!.readingPlan.copyWith(
        planName: planName,
        collectionId: collectionId,
        goalType: goalType.name,
        goalValue: goalValue,
      );
      await _rsdbManager.updateReadingPlan(plan);
      await _rsdbManager.deleteReadingPlanBooks(plan.id!);
    } else {
      plan = ReadingPlan(
        planName: planName,
        createdAt: DateTime.now(),
        collectionId: collectionId,
        goalType: goalType.name,
        goalValue: goalValue,
        isBookmarked: false,
      );

      plan = await _rsdbManager.insertReadingPlan(plan);
    }

    int i = 1;
    List<ReadingPlanBook> planBooks = [];
    for (int b in books) {
      ReadingPlanBook book = ReadingPlanBook(
        readingPlanId: plan.id!,
        bookId: b,
        ord: i++,
      );
      planBooks.add(book);
    }

    await _rsdbManager.insertReadingPlanBooks(planBooks);

    return plan;
  }
}
