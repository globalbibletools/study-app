enum GoalType {
  minutes,
  verses;

  static GoalType fromStorage(String? stored) {
    return stored != null && stored.toLowerCase().startsWith('m')
        ? GoalType.minutes
        : GoalType.verses;
  }

  String get storageValue => name;
}

String dayString(DateTime date) {
  String pad2(int value) => value.toString().padLeft(2, '0');
  return '${date.year.toString().padLeft(4, '0')}-${pad2(date.month)}-${pad2(date.day)}';
}

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
