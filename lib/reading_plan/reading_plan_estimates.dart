import 'package:gbt/reading_plan/data_access/rs_model.dart';

class ReadingPlanEstimates {
  const ReadingPlanEstimates._();

  static const double estimatedVersesPerMinute = 5;

  static double versesPerDay({
    required GoalType goalType,
    required int goalValue,
  }) {
    if (goalValue <= 0) return 0;
    return goalType == GoalType.verses
        ? goalValue.toDouble()
        : goalValue * estimatedVersesPerMinute;
  }

  static bool hasEstimate({
    required int remainingVerses,
    required GoalType goalType,
    required int goalValue,
  }) {
    return remainingVerses > 0 &&
        versesPerDay(goalType: goalType, goalValue: goalValue) > 0;
  }

  static int daysFor({
    required int remainingVerses,
    required GoalType goalType,
    required int goalValue,
  }) {
    final perDay = versesPerDay(goalType: goalType, goalValue: goalValue);
    if (remainingVerses <= 0 || perDay <= 0) return 0;
    return (remainingVerses / perDay).ceil();
  }

  static double monthsForDays(int days) => days / 30.44;
}
