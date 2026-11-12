import 'package:gbt/common/reference.dart';

enum GoalType { minutes, verses }

enum ProgressType { byBook, bySection }

class DailyGoal {
  final GoalType type;
  final int value;

  const DailyGoal(this.type, this.value);
}

class ReadingPlan {
  final int? id;
  final String planName;
  final DateTime createdAt;
  final DateTime? lastRead;
  final int collectionId;
  final String goalType;
  final int goalValue;
  final bool isBookmarked;

  ReadingPlan({
    this.id,
    required this.planName,
    required this.createdAt,
    this.lastRead,
    required this.collectionId,
    required this.goalType,
    required this.goalValue,
    required this.isBookmarked,
  });

  static const _undefined = Object();

  ReadingPlan copyWith({
    Object? id = _undefined,
    String? planName,
    DateTime? createdAt,
    Object? lastRead = _undefined,
    int? collectionId,
    String? goalType,
    int? goalValue,
    bool? isBookmarked,
  }) {
    return ReadingPlan(
      id: id == _undefined ? this.id : id as int?,
      planName: planName ?? this.planName,
      createdAt: createdAt ?? this.createdAt,
      lastRead: lastRead == _undefined ? this.lastRead : lastRead as DateTime?,
      collectionId: collectionId ?? this.collectionId,
      goalType: goalType ?? this.goalType,
      goalValue: goalValue ?? this.goalValue,
      isBookmarked: isBookmarked ?? this.isBookmarked,
    );
  }

  factory ReadingPlan.fromMap(Map<String, dynamic> map) {
    return ReadingPlan(
      id: map['id'],
      planName: map['plan_name'],
      createdAt: DateTime.parse(map['created_at']),
      lastRead: map['last_read'] != null
          ? DateTime.parse(map['last_read'])
          : null,
      collectionId: map['collection_id'],
      goalType: map['goal_type'],
      goalValue: map['goal_value'],
      isBookmarked: map['is_bookmarked'] == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'plan_name': planName,
      'created_at': createdAt.toIso8601String(),
      'last_read': lastRead?.toIso8601String(),
      'collection_id': collectionId,
      'goal_type': goalType,
      'goal_value': goalValue,
      'is_bookmarked': isBookmarked ? 1 : 0,
    };
  }
}

class ReadingPlanBook {
  final int? id;
  final int readingPlanId;
  final int bookId;
  final int ord;

  ReadingPlanBook({
    this.id,
    required this.readingPlanId,
    required this.bookId,
    required this.ord,
  });

  static const _undefined = Object();

  ReadingPlanBook copyWith({
    Object? id = _undefined,
    int? readingPlanId,
    int? bookId,
    int? ord,
  }) {
    return ReadingPlanBook(
      id: id == _undefined ? this.id : id as int?,
      readingPlanId: readingPlanId ?? this.readingPlanId,
      bookId: bookId ?? this.bookId,
      ord: ord ?? this.ord,
    );
  }

  factory ReadingPlanBook.fromMap(Map<String, dynamic> map) {
    return ReadingPlanBook(
      id: map['id'],
      readingPlanId: map['reading_plan_id'],
      bookId: map['book_id'],
      ord: map['ord'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'reading_plan_id': readingPlanId,
      'book_id': bookId,
      'ord': ord,
    };
  }
}

class ReadingPlanDetails {
  ReadingPlan readingPlan;
  final List<ReadingPlanBook> books;
  int totalChapters;
  int totalVerses;
  int versesRead;
  int booksRead;
  DailyGoal dailyGoal;
  Reference? resumePosition;

  ReadingPlanDetails(this.readingPlan, this.books)
    : totalChapters = 0,
      totalVerses = 0,
      versesRead = 0,
      booksRead = 0,
      dailyGoal = DailyGoal(
        (readingPlan.goalType == "M" ||
                readingPlan.goalType.toLowerCase().startsWith("m"))
            ? GoalType.minutes
            : GoalType.verses,
        readingPlan.goalValue,
      );
}

class RsSession {
  final int? id;
  final DateTime rsDate;
  final DateTime startTime;
  final DateTime? endTime;
  final int verses;
  final int readingPlanId;

  RsSession({
    this.id,
    required this.rsDate,
    required this.startTime,
    this.endTime,
    required this.verses,
    required this.readingPlanId,
  });

  static const _undefined = Object();

  RsSession copyWith({
    Object? id = _undefined,
    DateTime? rsDate,
    DateTime? startTime,
    Object? endTime = _undefined,
    int? verses,
    int? readingPlanId,
  }) {
    return RsSession(
      id: id == _undefined ? this.id : id as int?,
      rsDate: rsDate ?? this.rsDate,
      startTime: startTime ?? this.startTime,
      endTime: endTime == _undefined ? this.endTime : endTime as DateTime?,
      verses: verses ?? this.verses,
      readingPlanId: readingPlanId ?? this.readingPlanId,
    );
  }

  factory RsSession.fromMap(Map<String, dynamic> map) {
    return RsSession(
      id: map['id'],
      rsDate: DateTime.parse(map['rs_date']),
      startTime: DateTime.parse(map['start_time']),
      endTime: map['end_time'] != null ? DateTime.parse(map['end_time']) : null,
      verses: map['verses'],
      readingPlanId: map['reading_plan_id'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'rs_date': rsDate.toIso8601String(),
      'start_time': startTime.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'verses': verses,
      'reading_plan_id': readingPlanId,
    };
  }
}

class RsLog {
  final int? id;
  final int sessionId;
  final int bookId;
  final int chapter;
  final int verse;
  final DateTime dateTime;
  final int readingPlanId;

  RsLog({
    this.id,
    required this.sessionId,
    required this.bookId,
    required this.chapter,
    required this.verse,
    required this.dateTime,
    required this.readingPlanId,
  });

  static const _undefined = Object();

  RsLog copyWith({
    Object? id = _undefined,
    int? sessionId,
    int? bookId,
    int? chapter,
    int? verse,
    DateTime? dateTime,
    int? readingPlanId,
  }) {
    return RsLog(
      id: id == _undefined ? this.id : id as int?,
      sessionId: sessionId ?? this.sessionId,
      bookId: bookId ?? this.bookId,
      chapter: chapter ?? this.chapter,
      verse: verse ?? this.verse,
      dateTime: dateTime ?? this.dateTime,
      readingPlanId: readingPlanId ?? this.readingPlanId,
    );
  }

  factory RsLog.fromMap(Map<String, dynamic> map) {
    return RsLog(
      id: map['id'],
      sessionId: map['rs_session_id'],
      bookId: map['book_id'],
      chapter: map['chapter'],
      verse: map['verse'],
      dateTime: DateTime.parse(map['date_time']),
      readingPlanId: map['reading_plan_id'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'rs_session_id': sessionId,
      'book_id': bookId,
      'chapter': chapter,
      'verse': verse,
      'date_time': dateTime.toIso8601String(),
      'reading_plan_id': readingPlanId,
    };
  }
}

class RsDaySummary {
  final int readingPlanId;
  final DateTime rsDate;
  final int rsSeconds;
  final int rsVerses;
  final String? goalType;
  final int? goalValue;
  final bool goalReached;

  RsDaySummary({
    required this.readingPlanId,
    required this.rsDate,
    required this.rsSeconds,
    required this.rsVerses,
    this.goalType,
    this.goalValue,
    required this.goalReached,
  });

  static const _undefined = Object();

  RsDaySummary copyWith({
    Object? goalType = _undefined,
    Object? goalValue = _undefined,
    int? rsSeconds,
    int? rsVerses,
    bool? goalReached,
  }) {
    return RsDaySummary(
      readingPlanId: readingPlanId,
      rsDate: rsDate,
      rsSeconds: rsSeconds ?? this.rsSeconds,
      rsVerses: rsVerses ?? this.rsVerses,
      goalType: goalType == _undefined ? this.goalType : goalType as String?,
      goalValue: goalValue == _undefined ? this.goalValue : goalValue as int?,
      goalReached: goalReached ?? this.goalReached,
    );
  }

  factory RsDaySummary.fromMap(Map<String, dynamic> map) {
    return RsDaySummary(
      readingPlanId: map['reading_plan_id'],
      rsDate: DateTime.parse(map['rs_date']),
      rsSeconds: map['rs_seconds'],
      rsVerses: map['rs_verses'],
      goalType: map['goal_type'],
      goalValue: map['goal_value'],
      goalReached: map['goal_reached'] == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'reading_plan_id': readingPlanId,
      'rs_date': dayString(rsDate),
      'rs_seconds': rsSeconds,
      'rs_verses': rsVerses,
      'goal_type': goalType,
      'goal_value': goalValue,
      'goal_reached': goalReached ? 1 : 0,
    };
  }

  /// Formats a local date as the `YYYY-MM-DD` string stored in `rs_date`.
  static String dayString(DateTime date) {
    String pad2(int value) => value.toString().padLeft(2, '0');
    return '${date.year.toString().padLeft(4, '0')}-${pad2(date.month)}-${pad2(date.day)}';
  }
}

class RsVerseState {
  final int readingPlanId;
  final int bookId;
  final int chapter;
  final int verse;
  final int readCount;
  final DateTime? lastRead;

  const RsVerseState({
    required this.readingPlanId,
    required this.bookId,
    required this.chapter,
    required this.verse,
    required this.readCount,
    required this.lastRead,
  });

  factory RsVerseState.fromMap(Map<String, dynamic> map) {
    return RsVerseState(
      readingPlanId: map['reading_plan_id'],
      bookId: map['book_id'],
      chapter: map['chapter'],
      verse: map['verse'],
      readCount: map['read_count'] ?? 0,
      lastRead: map['last_read'] != null
          ? DateTime.parse(map['last_read'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'reading_plan_id': readingPlanId,
      'book_id': bookId,
      'chapter': chapter,
      'verse': verse,
      'read_count': readCount,
      'last_read': lastRead?.toIso8601String(),
    };
  }
}

class RsBookStats {
  final int bookId;
  final int totalVerses;
  final int versesRead;
  final DateTime? lastRead;

  const RsBookStats({
    required this.bookId,
    required this.totalVerses,
    required this.versesRead,
    required this.lastRead,
  });

  bool get isComplete => totalVerses > 0 && versesRead == totalVerses;
}

class DayProgress {
  final DateTime day;
  final int minutes;
  final int verses;
  final bool goalReached;
  final bool empty;

  DayProgress(this.day, this.minutes, this.verses, this.goalReached)
    : empty = false;

  DayProgress.empty(this.day)
    : minutes = 0,
      verses = 0,
      goalReached = false,
      empty = true;
}

class DetailedProgess {
  final int bookId;
  final int chapter;
  final int fromVerse;
  int toVerse;

  DetailedProgess(this.bookId, this.chapter, this.fromVerse, this.toVerse);
}

class SessionDetails {
  final RsSession rsSession;
  final List<DetailedProgess> progress;

  SessionDetails(this.rsSession, this.progress);
}
