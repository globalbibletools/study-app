import 'package:gbt/services/reading_session/rs_manager.dart';
import 'package:gbt/services/reading_session/rs_model.dart';
import 'package:gbt/services/service_locator.dart';

class AddReadingPlanPanelManager {
  final _rsManager = getIt<ReadingSessionManager>();
  final ReadingPlanDetails? readingPlan;

  AddReadingPlanPanelManager(this.readingPlan);

  Future<ReadingPlan> addReadingPlan(
    String planName,
    int collectionId,
    GoalType goalType,
    int goalValue,
    Set<int> books,
  ) async {
    return await _rsManager.saveReadingPlan(
      existingPlanDetails: readingPlan,
      planName: planName,
      collectionId: collectionId,
      goalType: goalType,
      goalValue: goalValue,
      selectedBookIds: books,
    );
  }

  Future<void> deleteReadingPlan(int planId) async {
    await _rsManager.deleteReadingPlan(planId);
  }
}
