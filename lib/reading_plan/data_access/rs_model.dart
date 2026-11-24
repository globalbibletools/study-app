enum GoalType { minutes, verses }

class DailyGoal {
  final GoalType type;
  final int value;

  const DailyGoal(this.type, this.value);
}

/// Formats a local date as the `YYYY-MM-DD` string stored in `rs_date`.
String dayString(DateTime date) {
  String pad2(int value) => value.toString().padLeft(2, '0');
  return '${date.year.toString().padLeft(4, '0')}-${pad2(date.month)}-${pad2(date.day)}';
}
