enum GoalType { minutes, verses }

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
  final String goalType;
  final int goalValue;
  final bool isBookmarked;

  ReadingPlan({
    this.id,
    required this.planName,
    required this.createdAt,
    this.lastRead,
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
    String? goalType,
    int? goalValue,
    bool? isBookmarked,
  }) {
    return ReadingPlan(
      id: id == _undefined ? this.id : id as int?,
      planName: planName ?? this.planName,
      createdAt: createdAt ?? this.createdAt,
      lastRead: lastRead == _undefined ? this.lastRead : lastRead as DateTime?,
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
  ReadingPlanDetails(this.readingPlan, this.books);

  final ReadingPlan readingPlan;
  final List<ReadingPlanBook> books;
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
