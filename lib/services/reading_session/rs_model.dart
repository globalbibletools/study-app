class RsDailyLog {
  final int? id;
  final DateTime rsDate;
  final DateTime startTime;
  final DateTime? endTime;
  final int verses;

  RsDailyLog({
    this.id,
    required this.rsDate,
    required this.startTime,
    this.endTime,
    required this.verses,
  });

  static const _undefined = Object();

  RsDailyLog copyWith({
    Object? id = _undefined,
    DateTime? rsDate,
    DateTime? startTime,
    Object? endTime = _undefined,
    int? verses,
  }) {
    return RsDailyLog(
      id: id == _undefined ? this.id : id as int?,
      rsDate: rsDate ?? this.rsDate,
      startTime: startTime ?? this.startTime,
      endTime: endTime == _undefined ? this.endTime : endTime as DateTime?,
      verses: verses ?? this.verses,
    );
  }

  factory RsDailyLog.fromMap(Map<String, dynamic> map) {
    return RsDailyLog(
      id: map['id'],
      rsDate: DateTime.parse(map['rs_date']),
      startTime: DateTime.parse(map['start_time']),
      endTime: map['end_time'] != null ? DateTime.parse(map['end_time']) : null,
      verses: map['verses'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'rs_date': rsDate.toIso8601String(),
      'start_time': startTime.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'verses': verses,
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

  RsLog({
    this.id,
    required this.rsDailyLogId,
    required this.bookId,
    required this.chapter,
    required this.verse,
    required this.dateTime,
  });

  static const _undefined = Object();

  RsLog copyWith({
    Object? id = _undefined,
    int? rsDailyLogId,
    int? bookId,
    int? chapter,
    int? verse,
    DateTime? dateTime,
  }) {
    return RsLog(
      id: id == _undefined ? this.id : id as int?,
      rsDailyLogId: rsDailyLogId ?? this.rsDailyLogId,
      bookId: bookId ?? this.bookId,
      chapter: chapter ?? this.chapter,
      verse: verse ?? this.verse,
      dateTime: dateTime ?? this.dateTime,
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

  RsStats({
    this.id,
    required this.type,
    required this.statsDate,
    required this.rsSeconds,
    required this.rsVerses,
    required this.goalReached,
  });

  static const _undefined = Object();

  RsStats copyWith({
    Object? id = _undefined,
    RsStatsType? type,
    DateTime? statsDate,
    int? rsSeconds,
    int? rsVerses,
    bool? goalReached,
  }) {
    return RsStats(
      id: id == _undefined ? this.id : id as int?,
      type: type ?? this.type,
      statsDate: statsDate ?? this.statsDate,
      rsSeconds: rsSeconds ?? this.rsSeconds,
      rsVerses: rsVerses ?? this.rsVerses,
      goalReached: goalReached ?? this.goalReached,
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
    };
  }
}

class RsBookProgress {
  final int? id;
  final int bookId;
  final int chapter;
  final int verse;
  final int chaptersRead;
  final DateTime updatedAt;

  RsBookProgress({
    this.id,
    required this.bookId,
    required this.chapter,
    required this.verse,
    required this.chaptersRead,
    required this.updatedAt,
  });

  static const _undefined = Object();

  RsBookProgress copyWith({
    Object? id = _undefined,
    int? bookId,
    int? chapter,
    int? verse,
    int? chaptersRead,
    DateTime? updatedAt,
  }) {
    return RsBookProgress(
      id: id == _undefined ? this.id : id as int?,
      bookId: bookId ?? this.bookId,
      chapter: chapter ?? this.chapter,
      verse: verse ?? this.verse,
      chaptersRead: chaptersRead ?? this.chaptersRead,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  factory RsBookProgress.fromMap(Map<String, dynamic> map) {
    return RsBookProgress(
      id: map['id'],
      bookId: map['book_id'],
      chapter: map['chapter'],
      verse: map['verse'],
      chaptersRead: map['chapters_read'],
      updatedAt: DateTime.parse(map['updated_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'book_id': bookId,
      'chapter': chapter,
      'verse': verse,
      'chapters_read': chaptersRead,
      'updated_at': updatedAt.toIso8601String(),
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
