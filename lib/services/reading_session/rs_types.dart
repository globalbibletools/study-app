enum StatsType { weekly, monthly }

enum GoalType { minutes, verses }

enum ProgressType { byBook, bySection }

class DailyGoal {
  final GoalType type;
  final int value;

  const DailyGoal(this.type, this.value);
}
