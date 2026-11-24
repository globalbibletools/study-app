import 'package:gbt/common/reference.dart';
import 'package:gbt/reading_plan/data_access/rs_model.dart' show GoalType;

export 'package:gbt/reading_plan/data_access/rs_model.dart' show GoalType;

class DailyGoal {
  const DailyGoal(this.type, this.value);

  final GoalType type;
  final int value;
}

GoalType goalTypeFromStored(String? stored) {
  return stored != null && stored.toLowerCase().startsWith('m')
      ? GoalType.minutes
      : GoalType.verses;
}

DailyGoal? dailyGoalFromStored(String? storedType, int? value) {
  if (value == null) return null;
  return DailyGoal(goalTypeFromStored(storedType), value);
}

class ReadingPlanConfig {
  ReadingPlanConfig({
    required this.planId,
    required this.planName,
    required this.isBookmarked,
    required this.createdAt,
    required this.dailyGoal,
    required List<int> bookIds,
  }) : bookIds = List.unmodifiable(bookIds);

  final int planId;
  final String planName;
  final bool isBookmarked;
  final DateTime createdAt;
  final DailyGoal dailyGoal;

  final List<int> bookIds;

  ReadingPlanConfig copyWith({
    int? planId,
    String? planName,
    bool? isBookmarked,
    DateTime? createdAt,
    DailyGoal? dailyGoal,
    List<int>? bookIds,
  }) {
    return ReadingPlanConfig(
      planId: planId ?? this.planId,
      planName: planName ?? this.planName,
      isBookmarked: isBookmarked ?? this.isBookmarked,
      createdAt: createdAt ?? this.createdAt,
      dailyGoal: dailyGoal ?? this.dailyGoal,
      bookIds: bookIds ?? this.bookIds,
    );
  }
}

class ReadingPlanProgress {
  ReadingPlanProgress({
    required this.planId,
    required Map<int, BookProgress> bookProgress,
    required this.resumePosition,
  }) : bookProgress = Map.unmodifiable(bookProgress);

  final int planId;
  final Map<int, BookProgress> bookProgress;
  final Reference? resumePosition;

  late final int totalVerses = bookProgress.values.fold(
    0,
    (sum, book) => sum + book.totalVerses,
  );
  late final int versesRead = bookProgress.values.fold(
    0,
    (sum, book) => sum + book.versesRead,
  );
  late final int booksRead = bookProgress.values
      .where((book) => book.isComplete)
      .length;

  bool get isComplete => totalVerses > 0 && versesRead == totalVerses;
}

class BookProgress {
  const BookProgress({
    required this.bookId,
    required this.totalVerses,
    required this.versesRead,
  });

  final int bookId;
  final int totalVerses;
  final int versesRead;

  bool get isComplete => totalVerses > 0 && versesRead == totalVerses;
}

class DailyProgress {
  const DailyProgress({
    required this.day,
    required this.seconds,
    required this.verses,
    required this.goalReached,
    required this.goal,
    this.hasSummary = true,
  });

  factory DailyProgress.empty(DateTime day) {
    return DailyProgress(
      day: DateTime(day.year, day.month, day.day),
      seconds: 0,
      verses: 0,
      goalReached: false,
      goal: null,
      hasSummary: false,
    );
  }

  final DateTime day;
  final int seconds;
  final int verses;
  final bool goalReached;
  final DailyGoal? goal;
  final bool hasSummary;

  bool get hasActivity => seconds > 0 || verses > 0;
  double get minutes => (seconds / 6).round() / 10;
}

class ReadingPlanSummary {
  const ReadingPlanSummary({
    required this.config,
    required this.progress,
    required this.today,
  });

  final ReadingPlanConfig config;
  final ReadingPlanProgress progress;
  final DailyProgress today;

  ReadingPlanSummary copyWith({
    ReadingPlanConfig? config,
    ReadingPlanProgress? progress,
    DailyProgress? today,
  }) {
    return ReadingPlanSummary(
      config: config ?? this.config,
      progress: progress ?? this.progress,
      today: today ?? this.today,
    );
  }

  int get planId => config.planId;
  String get planName => config.planName;
  bool get isBookmarked => config.isBookmarked;
  DailyGoal get dailyGoal => config.dailyGoal;
  List<int> get bookIds => config.bookIds;
  Map<int, BookProgress> get bookProgress => progress.bookProgress;
  int get totalVerses => progress.totalVerses;
  int get versesRead => progress.versesRead;
  int get booksRead => progress.booksRead;
  bool get isComplete => progress.isComplete;
  Reference? get resumePosition => progress.resumePosition;

  Reference get resumeTarget {
    final resume = progress.resumePosition;
    if (resume != null) return resume;

    return Reference(
      bookId: bookIds.isNotEmpty ? bookIds.first : 1,
      chapter: 1,
      verse: 1,
    );
  }
}

class DayActivity {
  DayActivity({required DateTime day, required List<SessionActivity> sessions})
    : day = DateTime(day.year, day.month, day.day),
      sessions = List.unmodifiable(sessions);

  final DateTime day;
  final List<SessionActivity> sessions;

  int get totalSeconds =>
      sessions.fold(0, (sum, session) => sum + session.readSeconds);
  int get totalVerses =>
      sessions.fold(0, (sum, session) => sum + session.verses);
  double get totalMinutes => (totalSeconds / 6).round() / 10;
}

class SessionActivity {
  SessionActivity({
    required this.sessionId,
    required this.startTime,
    required this.readSeconds,
    required this.verses,
    required this.isManual,
    required List<VerseRange> ranges,
  }) : ranges = List.unmodifiable(ranges);

  final int sessionId;
  final DateTime startTime;
  final int readSeconds;
  final int verses;
  final bool isManual;
  final List<VerseRange> ranges;

  double get minutes => (readSeconds / 6).round() / 10;
}

class VerseRange {
  const VerseRange(this.bookId, this.chapter, this.fromVerse, this.toVerse);

  final int bookId;
  final int chapter;
  final int fromVerse;
  final int toVerse;
}

class SessionRuntime {
  const SessionRuntime({
    required this.sessionId,
    required this.planId,
    required this.sessionDay,
    required this.sessionStartTime,
    required this.sessionReadSeconds,
    required this.dayProgress,
  });

  final int sessionId;
  final int planId;
  final DateTime sessionDay;
  final DateTime sessionStartTime;
  final int sessionReadSeconds;
  final DailyProgress dayProgress;

  int get versesToday => dayProgress.verses;
  int get secondsToday => dayProgress.seconds;
  bool get goalAlreadyReachedToday => dayProgress.goalReached;
}

class VerseReadState {
  const VerseReadState({
    required this.readCount,
    required this.readThisSession,
  });

  final int readCount;
  final bool readThisSession;
}
