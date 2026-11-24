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

/// The read state of a single verse as it relates to the active session.
class VerseReadState {
  const VerseReadState({
    required this.readCount,
    required this.readThisSession,
  });

  /// Total number of times this verse has ever been read.
  final int readCount;

  /// Whether this verse has been read in the current session.
  final bool readThisSession;
}

/// Options for setting a verse's read state in the active session.
class VerseReadOptions {
  const VerseReadOptions({
    required this.bookId,
    required this.chapter,
    required this.verse,
    required this.read,
  });

  final int bookId;
  final int chapter;
  final int verse;
  final bool read;
}
