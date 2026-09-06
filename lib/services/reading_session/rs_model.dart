import 'package:gbt/services/reading_session/rs_manager.dart';

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
  RsBookProgress? latestBookProgress;

  ReadingPlanDetails(this.readingPlan, this.books)
    : totalChapters = 0,
      totalVerses = 0,
      versesRead = 0,
      booksRead = 0,
      dailyGoal = DailyGoal(
        readingPlan.goalType == "M" ? GoalType.minutes : GoalType.verses,
        readingPlan.goalValue,
      );
}

class RsDailyLog {
  final int? id;
  final DateTime rsDate;
  final DateTime startTime;
  final DateTime? endTime;
  final int verses;
  final int readingPlanId;

  RsDailyLog({
    this.id,
    required this.rsDate,
    required this.startTime,
    this.endTime,
    required this.verses,
    required this.readingPlanId,
  });

  static const _undefined = Object();

  RsDailyLog copyWith({
    Object? id = _undefined,
    DateTime? rsDate,
    DateTime? startTime,
    Object? endTime = _undefined,
    int? verses,
    int? readingPlanId,
  }) {
    return RsDailyLog(
      id: id == _undefined ? this.id : id as int?,
      rsDate: rsDate ?? this.rsDate,
      startTime: startTime ?? this.startTime,
      endTime: endTime == _undefined ? this.endTime : endTime as DateTime?,
      verses: verses ?? this.verses,
      readingPlanId: readingPlanId ?? this.readingPlanId,
    );
  }

  factory RsDailyLog.fromMap(Map<String, dynamic> map) {
    return RsDailyLog(
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
  final int rsDailyLogId;
  final int bookId;
  final int chapter;
  final int verse;
  final DateTime dateTime;
  final int readingPlanId;

  RsLog({
    this.id,
    required this.rsDailyLogId,
    required this.bookId,
    required this.chapter,
    required this.verse,
    required this.dateTime,
    required this.readingPlanId,
  });

  static const _undefined = Object();

  RsLog copyWith({
    Object? id = _undefined,
    int? rsDailyLogId,
    int? bookId,
    int? chapter,
    int? verse,
    DateTime? dateTime,
    int? readingPlanId,
  }) {
    return RsLog(
      id: id == _undefined ? this.id : id as int?,
      rsDailyLogId: rsDailyLogId ?? this.rsDailyLogId,
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
      rsDailyLogId: map['rs_daily_log_id'],
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
      'rs_daily_log_id': rsDailyLogId,
      'book_id': bookId,
      'chapter': chapter,
      'verse': verse,
      'date_time': dateTime.toIso8601String(),
      'reading_plan_id': readingPlanId,
    };
  }
}

enum RsStatsType {
  daily('D'),
  monthly('M');

  final String value;
  const RsStatsType(this.value);
  static RsStatsType fromString(String value) {
    return RsStatsType.values.firstWhere((e) => e.value == value);
  }
}

class RsStats {
  final int? id;
  final RsStatsType type;
  final DateTime statsDate;
  final int rsSeconds;
  final int rsVerses;
  final bool goalReached;
  final int readingPlanId;

  RsStats({
    this.id,
    required this.type,
    required this.statsDate,
    required this.rsSeconds,
    required this.rsVerses,
    required this.goalReached,
    required this.readingPlanId,
  });

  static const _undefined = Object();

  RsStats copyWith({
    Object? id = _undefined,
    RsStatsType? type,
    DateTime? statsDate,
    int? rsSeconds,
    int? rsVerses,
    bool? goalReached,
    int? readingPlanId,
  }) {
    return RsStats(
      id: id == _undefined ? this.id : id as int?,
      type: type ?? this.type,
      statsDate: statsDate ?? this.statsDate,
      rsSeconds: rsSeconds ?? this.rsSeconds,
      rsVerses: rsVerses ?? this.rsVerses,
      goalReached: goalReached ?? this.goalReached,
      readingPlanId: readingPlanId ?? this.readingPlanId,
    );
  }

  factory RsStats.fromMap(Map<String, dynamic> map) {
    return RsStats(
      id: map['id'],
      type: RsStatsType.fromString(map['type']),
      statsDate: DateTime.parse(map['stats_date']),
      rsSeconds: map['rs_seconds'],
      rsVerses: map['rs_verses'],
      goalReached: map['goal_reached'] == 1,
      readingPlanId: map['reading_plan_id'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.value,
      'stats_date': statsDate.toIso8601String(),
      'rs_seconds': rsSeconds,
      'rs_verses': rsVerses,
      'goal_reached': goalReached ? 1 : 0,
      'reading_plan_id': readingPlanId,
    };
  }
}

class RsBookProgress {
  final int? id;
  final int bookId;
  final int chapter;
  final int verse;
  final int chaptersRead;
  final int versesRead;
  final DateTime updatedAt;
  final int readingPlanId;

  RsBookProgress({
    this.id,
    required this.bookId,
    required this.chapter,
    required this.verse,
    required this.chaptersRead,
    required this.versesRead,
    required this.updatedAt,
    required this.readingPlanId,
  });

  static const _undefined = Object();

  RsBookProgress copyWith({
    Object? id = _undefined,
    int? bookId,
    int? chapter,
    int? verse,
    int? chaptersRead,
    int? versesRead,
    DateTime? updatedAt,
    int? readingPlanId,
  }) {
    return RsBookProgress(
      id: id == _undefined ? this.id : id as int?,
      bookId: bookId ?? this.bookId,
      chapter: chapter ?? this.chapter,
      verse: verse ?? this.verse,
      chaptersRead: chaptersRead ?? this.chaptersRead,
      versesRead: versesRead ?? this.versesRead,
      updatedAt: updatedAt ?? DateTime.now(),
      readingPlanId: readingPlanId ?? this.readingPlanId,
    );
  }

  factory RsBookProgress.fromMap(Map<String, dynamic> map) {
    return RsBookProgress(
      id: map['id'],
      bookId: map['book_id'],
      chapter: map['chapter'],
      verse: map['verse'],
      chaptersRead: map['chapters_read'],
      versesRead: map['verses_read'],
      updatedAt: DateTime.parse(map['updated_at']),
      readingPlanId: map['reading_plan_id'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'book_id': bookId,
      'chapter': chapter,
      'verse': verse,
      'chapters_read': chaptersRead,
      'verses_read': versesRead,
      'updated_at': updatedAt.toIso8601String(),
      'reading_plan_id': readingPlanId,
    };
  }
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

class Session {
  final RsDailyLog rsDailyLog;
  final List<DetailedProgess> progress;

  Session(this.rsDailyLog, this.progress);
}
