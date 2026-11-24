import 'package:gbt/common/reference.dart';
import 'package:gbt/reading_plan/rs_database.dart';
import 'package:gbt/reading_plan/rs_model.dart';

class ReadingPlanReadModels {
  ReadingPlanReadModels(this._database);

  final ReadingSessionDatabase _database;

  Future<ReadingPlanConfig?> getPlanConfig(int planId) async {
    final configs = await _loadConfigs(planId: planId);
    return configs.firstOrNull;
  }

  Future<ReadingPlanSummary?> getPlanSummary(
    int planId, {
    DateTime? today,
  }) async {
    final configs = await _loadConfigs(planId: planId);
    if (configs.isEmpty) return null;

    final summaries = await _summariesFor(
      configs,
      dayOnly(today ?? DateTime.now()),
    );
    return summaries.firstOrNull;
  }

  Future<List<ReadingPlanSummary>> getPlanSummaries({DateTime? today}) async {
    final configs = await _loadConfigs();
    if (configs.isEmpty) return const [];

    return _summariesFor(configs, dayOnly(today ?? DateTime.now()));
  }

  Future<List<DayProgress>> getMonthProgress(int planId, DateTime month) async {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 0);
    final daysInMonth = end.day;

    final rows = await _database.read(
      (db) => db.query(
        'rs_day_summary',
        where: 'reading_plan_id = ? AND rs_date BETWEEN ? AND ?',
        whereArgs: [
          planId,
          RsDaySummary.dayString(start),
          RsDaySummary.dayString(end),
        ],
        orderBy: 'rs_date asc',
      ),
    );

    final byDay = {
      for (final row in rows)
        (row['rs_date'] as String): _dayProgressFromMap(row),
    };

    return [
      for (int day = 1; day <= daysInMonth; day++)
        byDay[RsDaySummary.dayString(DateTime(month.year, month.month, day))] ??
            DayProgress.empty(DateTime(month.year, month.month, day)),
    ];
  }

  Future<List<SessionDetails>> getDayActivity(int planId, DateTime date) async {
    final sessions = await _database.read(
      (db) => db.query(
        'rs_session',
        where: 'date(rs_date) = date(?) AND reading_plan_id = ?',
        whereArgs: [date.toIso8601String(), planId],
        orderBy: 'start_time',
      ),
    );
    if (sessions.isEmpty) return const [];

    final sessionIds = [for (final row in sessions) row['id'] as int];
    final placeholders = List.filled(sessionIds.length, '?').join(', ');
    final logRows = await _database.read(
      (db) => db.rawQuery(
        'SELECT * FROM rs_log '
        'WHERE rs_session_id IN ($placeholders) '
        'ORDER BY rs_session_id, book_id, chapter, verse',
        sessionIds,
      ),
    );

    final logsBySession = <int, List<RsLog>>{};
    for (final row in logRows) {
      final log = RsLog.fromMap(row);
      (logsBySession[log.sessionId] ??= []).add(log);
    }

    return [
      for (final row in sessions)
        SessionDetails(
          RsSession.fromMap(row),
          _foldContiguousRanges(logsBySession[row['id'] as int] ?? const []),
        ),
    ];
  }

  Future<ReadingSessionRuntime?> getSessionRuntime(int sessionId) async {
    final rows = await _database.read(
      (db) => db.query(
        'rs_session',
        where: 'id = ?',
        whereArgs: [sessionId],
        limit: 1,
      ),
    );
    if (rows.isEmpty) return null;

    final session = RsSession.fromMap(rows.first);
    final dayProgress = await _getDayProgress(
      session.readingPlanId,
      session.rsDate,
    );
    return ReadingSessionRuntime(
      sessionId: session.id!,
      planId: session.readingPlanId,
      sessionDay: dayOnly(session.rsDate),
      sessionStartTime: session.startTime,
      sessionReadSeconds: session.readSeconds,
      dayProgress: dayProgress,
    );
  }

  Future<Map<int, VerseReadState>> getVerseReadStates(
    int sessionId,
    int bookId,
    int chapter,
  ) async {
    final rows = await _database.read(
      (db) => db.rawQuery(
        'SELECT v.verse AS verse, MAX(0, v.read_count) AS read_count, '
        '       CASE WHEN l.id IS NULL THEN 0 ELSE 1 END AS read_this_session '
        'FROM rs_session s '
        'JOIN rs_verse_state v '
        '  ON v.reading_plan_id = s.reading_plan_id '
        ' AND v.book_id = ? '
        ' AND v.chapter = ? '
        'LEFT JOIN rs_log l '
        '  ON l.reading_plan_id = v.reading_plan_id '
        ' AND l.book_id = v.book_id '
        ' AND l.chapter = v.chapter '
        ' AND l.verse = v.verse '
        ' AND l.rs_session_id = s.id '
        'WHERE s.id = ?',
        [bookId, chapter, sessionId],
      ),
    );

    return {
      for (final row in rows)
        row['verse'] as int: VerseReadState(
          readCount: row['read_count'] as int,
          readThisSession: (row['read_this_session'] as int) == 1,
        ),
    };
  }

  /// Read counts for one chapter of a plan, independent of a session.
  Future<Map<int, int>> getVerseReadCounts(
    int planId,
    int bookId,
    int chapter,
  ) async {
    final rows = await _database.read(
      (db) => db.query(
        'rs_verse_state',
        columns: ['verse', 'read_count'],
        where: 'reading_plan_id = ? AND book_id = ? AND chapter = ?',
        whereArgs: [planId, bookId, chapter],
      ),
    );

    return {
      for (final row in rows) row['verse'] as int: row['read_count'] as int,
    };
  }

  Future<DayProgress> _getDayProgress(int planId, DateTime date) async {
    final day = dayOnly(date);
    final rows = await _database.read(
      (db) => db.query(
        'rs_day_summary',
        where: 'reading_plan_id = ? AND rs_date = ?',
        whereArgs: [planId, RsDaySummary.dayString(day)],
        limit: 1,
      ),
    );

    if (rows.isEmpty) return DayProgress.empty(day);
    return _dayProgressFromMap(rows.first);
  }

  Future<List<ReadingPlanSummary>> _summariesFor(
    List<ReadingPlanConfig> configs,
    DateTime day,
  ) async {
    final planIds = [for (final config in configs) config.planId];
    final statsByPlan = await _loadBookStats(planIds);
    final resumes = await _resumeReferences(planIds);
    final placeholders = List.filled(planIds.length, '?').join(', ');
    final summaryRows = await _database.read(
      (db) => db.query(
        'rs_day_summary',
        where: 'reading_plan_id IN ($placeholders) AND rs_date = ?',
        whereArgs: [...planIds, RsDaySummary.dayString(day)],
      ),
    );
    final todayByPlan = {
      for (final row in summaryRows)
        row['reading_plan_id'] as int: _dayProgressFromMap(row),
    };

    return [
      for (final config in configs)
        ReadingPlanSummary(
          config: config,
          progress: _progressFor(
            config,
            statsByPlan[config.planId] ?? const {},
            resumes[config.planId],
          ),
          today: todayByPlan[config.planId] ?? DayProgress.empty(day),
        ),
    ];
  }

  Future<List<ReadingPlanConfig>> _loadConfigs({int? planId}) async {
    final planRows = await _database.read(
      (db) => db.query(
        'reading_plan',
        where: planId == null ? null : 'id = ?',
        whereArgs: planId == null ? null : [planId],
        orderBy: planId == null ? 'is_bookmarked desc, created_at desc' : null,
      ),
    );
    if (planRows.isEmpty) return const [];

    final planIds = [for (final row in planRows) row['id'] as int];
    final placeholders = List.filled(planIds.length, '?').join(', ');
    final bookRows = await _database.read(
      (db) => db.query(
        'reading_plan_book',
        where: 'reading_plan_id IN ($placeholders)',
        whereArgs: planIds,
        orderBy: 'reading_plan_id, ord',
      ),
    );

    final booksByPlan = <int, List<ReadingPlanBook>>{};
    for (final row in bookRows) {
      final book = ReadingPlanBook.fromMap(row);
      (booksByPlan[book.readingPlanId] ??= []).add(book);
    }

    return [for (final row in planRows) _configFromRow(row, booksByPlan)];
  }

  ReadingPlanConfig _configFromRow(
    Map<String, Object?> row,
    Map<int, List<ReadingPlanBook>> booksByPlan,
  ) {
    final plan = ReadingPlan.fromMap(row);
    final books = booksByPlan[plan.id!] ?? const <ReadingPlanBook>[];
    return ReadingPlanConfig(
      planId: plan.id!,
      planName: plan.planName,
      collectionId: plan.collectionId,
      isBookmarked: plan.isBookmarked,
      createdAt: plan.createdAt,
      dailyGoal: DailyGoal.fromStored(plan.goalType, plan.goalValue),
      books: List.unmodifiable(books),
    );
  }

  Future<Map<int, Map<int, BookProgress>>> _loadBookStats(
    List<int> planIds,
  ) async {
    if (planIds.isEmpty) return const {};

    final placeholders = List.filled(planIds.length, '?').join(', ');
    final rows = await _database.read(
      (db) => db.rawQuery(
        'SELECT b.reading_plan_id AS reading_plan_id, '
        '       b.book_id AS book_id, '
        '       COUNT(v.verse) AS total_verses, '
        '       COALESCE(SUM(CASE WHEN v.read_count > 0 THEN 1 ELSE 0 END), 0) '
        '         AS verses_read '
        'FROM reading_plan_book b '
        'LEFT JOIN rs_verse_state v '
        '  ON v.reading_plan_id = b.reading_plan_id '
        ' AND v.book_id = b.book_id '
        'WHERE b.reading_plan_id IN ($placeholders) '
        'GROUP BY b.reading_plan_id, b.book_id',
        planIds,
      ),
    );

    final result = <int, Map<int, BookProgress>>{};
    for (final row in rows) {
      final planId = row['reading_plan_id'] as int;
      final bookId = row['book_id'] as int;
      (result[planId] ??= {})[bookId] = BookProgress(
        bookId: bookId,
        totalVerses: row['total_verses'] as int? ?? 0,
        versesRead: row['verses_read'] as int? ?? 0,
      );
    }
    return result;
  }

  Future<Map<int, Reference>> _resumeReferences(List<int> planIds) async {
    if (planIds.isEmpty) return const {};

    final placeholders = List.filled(planIds.length, '?').join(', ');
    final rows = await _database.read(
      (db) => db.rawQuery(
        'WITH last_read AS ('
        '  SELECT l.reading_plan_id AS reading_plan_id, '
        '         l.book_id AS book_id, l.chapter AS chapter, '
        '         l.verse AS verse, b.ord AS ord, '
        '         ROW_NUMBER() OVER ('
        '           PARTITION BY l.reading_plan_id '
        '           ORDER BY l.date_time DESC, l.id DESC'
        '         ) AS rn '
        '  FROM rs_log l '
        '  JOIN reading_plan_book b '
        '    ON b.reading_plan_id = l.reading_plan_id '
        '   AND b.book_id = l.book_id '
        '  WHERE l.reading_plan_id IN ($placeholders)'
        '), candidates AS ('
        '  SELECT b.reading_plan_id AS reading_plan_id, '
        '         v.book_id AS book_id, v.chapter AS chapter, '
        '         v.verse AS verse, '
        '         ROW_NUMBER() OVER ('
        '           PARTITION BY b.reading_plan_id '
        '           ORDER BY b.ord, v.chapter, v.verse'
        '         ) AS rn '
        '  FROM reading_plan_book b '
        '  JOIN rs_verse_state v '
        '    ON v.reading_plan_id = b.reading_plan_id '
        '   AND v.book_id = b.book_id '
        '  LEFT JOIN last_read lr '
        '    ON lr.reading_plan_id = b.reading_plan_id '
        '   AND lr.rn = 1 '
        '  WHERE b.reading_plan_id IN ($placeholders) '
        '    AND ('
        '      lr.reading_plan_id IS NULL '
        '      OR b.ord > lr.ord '
        '      OR ('
        '        b.ord = lr.ord '
        '        AND ('
        '          v.chapter > lr.chapter '
        '          OR ('
        '            v.chapter = lr.chapter '
        '            AND v.verse > lr.verse'
        '          )'
        '        )'
        '      )'
        '    )'
        ') '
        'SELECT reading_plan_id, book_id, chapter, verse '
        'FROM candidates WHERE rn = 1',
        [...planIds, ...planIds],
      ),
    );

    return {
      for (final row in rows)
        row['reading_plan_id'] as int: Reference(
          bookId: row['book_id'] as int,
          chapter: row['chapter'] as int,
          verse: row['verse'] as int,
        ),
    };
  }

  ReadingPlanProgress _progressFor(
    ReadingPlanConfig config,
    Map<int, BookProgress> stats,
    Reference? resumePosition,
  ) {
    return ReadingPlanProgress(
      planId: config.planId,
      bookProgress: Map.unmodifiable({
        for (final book in config.books)
          book.bookId:
              stats[book.bookId] ??
              BookProgress(bookId: book.bookId, totalVerses: 0, versesRead: 0),
      }),
      resumePosition: resumePosition,
    );
  }

  static List<VerseRange> _foldContiguousRanges(List<RsLog> logs) {
    final progress = <VerseRange>[];
    int? bookId;
    int? chapter;
    var fromVerse = 0;
    var toVerse = 0;
    var hasRange = false;

    void flush() {
      if (!hasRange) return;
      progress.add(VerseRange(bookId!, chapter!, fromVerse, toVerse));
      hasRange = false;
    }

    for (final entry in logs) {
      if (!hasRange ||
          bookId != entry.bookId ||
          chapter != entry.chapter ||
          entry.verse - toVerse > 1) {
        flush();
        bookId = entry.bookId;
        chapter = entry.chapter;
        fromVerse = entry.verse;
        toVerse = entry.verse;
        hasRange = true;
      } else {
        toVerse = entry.verse;
      }
    }
    flush();

    return progress;
  }

  static DayProgress _dayProgressFromMap(Map<String, Object?> row) {
    final date = DateTime.parse(row['rs_date'] as String);
    return DayProgress(
      day: dayOnly(date),
      seconds: row['rs_seconds'] as int? ?? 0,
      verses: row['rs_verses'] as int? ?? 0,
      goalReached: row['goal_reached'] == 1,
      hasSummary: true,
      goalType: row['goal_type'] as String?,
      goalValue: row['goal_value'] as int?,
    );
  }
}

class DailyGoal {
  const DailyGoal(this.type, this.value);

  factory DailyGoal.fromStored(String? stored, int value) {
    return DailyGoal(goalTypeFromStored(stored), value);
  }

  final GoalType type;
  final int value;
}

class ReadingPlanConfig {
  const ReadingPlanConfig({
    required this.planId,
    required this.planName,
    required this.collectionId,
    required this.isBookmarked,
    required this.createdAt,
    required this.dailyGoal,
    required this.books,
  });

  final int planId;
  final String planName;
  final int collectionId;
  final bool isBookmarked;
  final DateTime createdAt;
  final DailyGoal dailyGoal;
  final List<ReadingPlanBook> books;

  List<int> get bookIds => [for (final book in books) book.bookId];

  ReadingPlanConfig copyWith({
    int? planId,
    String? planName,
    int? collectionId,
    bool? isBookmarked,
    DateTime? createdAt,
    DailyGoal? dailyGoal,
    List<ReadingPlanBook>? books,
  }) {
    return ReadingPlanConfig(
      planId: planId ?? this.planId,
      planName: planName ?? this.planName,
      collectionId: collectionId ?? this.collectionId,
      isBookmarked: isBookmarked ?? this.isBookmarked,
      createdAt: createdAt ?? this.createdAt,
      dailyGoal: dailyGoal ?? this.dailyGoal,
      books: books ?? this.books,
    );
  }
}

class ReadingPlanSummary {
  const ReadingPlanSummary({
    required this.config,
    required this.progress,
    required this.today,
  });

  final ReadingPlanConfig config;
  final ReadingPlanProgress progress;
  final DayProgress today;

  int get planId => config.planId;
  String get planName => config.planName;
  bool get isBookmarked => config.isBookmarked;
  DailyGoal get dailyGoal => config.dailyGoal;
  List<ReadingPlanBook> get books => config.books;
  Map<int, BookProgress> get bookProgress => progress.bookProgress;
  int get totalVerses => progress.totalVerses;
  int get versesRead => progress.versesRead;
  int get booksRead => progress.booksRead;
  Reference? get resumePosition => progress.resumePosition;

  Reference get resumeTarget {
    final resumePosition = progress.resumePosition;
    if (resumePosition != null) return resumePosition;

    return Reference(
      bookId: books.isNotEmpty ? books.first.bookId : 1,
      chapter: 1,
      verse: 1,
    );
  }

  ReadingPlanSummary copyWith({
    ReadingPlanConfig? config,
    ReadingPlanProgress? progress,
    DayProgress? today,
  }) {
    return ReadingPlanSummary(
      config: config ?? this.config,
      progress: progress ?? this.progress,
      today: today ?? this.today,
    );
  }
}

class ReadingPlanProgress {
  ReadingPlanProgress({
    required this.planId,
    required this.bookProgress,
    required this.resumePosition,
  });

  final int planId;
  final Map<int, BookProgress> bookProgress;
  final Reference? resumePosition;

  late final int totalVerses = bookProgress.values.fold(
    0,
    (sum, stat) => sum + stat.totalVerses,
  );

  late final int versesRead = bookProgress.values.fold(
    0,
    (sum, stat) => sum + stat.versesRead,
  );

  late final int booksRead = bookProgress.values
      .where((stat) => stat.isComplete)
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

class DayProgress {
  const DayProgress({
    required this.day,
    required this.seconds,
    required this.verses,
    required this.goalReached,
    required this.hasSummary,
    this.goalType,
    this.goalValue,
  });

  factory DayProgress.empty(DateTime day) {
    return DayProgress(
      day: dayOnly(day),
      seconds: 0,
      verses: 0,
      goalReached: false,
      hasSummary: false,
    );
  }

  factory DayProgress.minutes(
    DateTime day,
    num minutes,
    int verses,
    bool goalReached,
  ) {
    return DayProgress(
      day: dayOnly(day),
      seconds: (minutes * 60).round(),
      verses: verses,
      goalReached: goalReached,
      hasSummary: true,
    );
  }

  final DateTime day;
  final int seconds;
  final int verses;
  final bool goalReached;
  final bool hasSummary;

  /// The goal snapshot stored with the day, if one was recorded.
  final String? goalType;
  final int? goalValue;

  double get minutes => (seconds / 6).round() / 10;

  bool get empty => !hasSummary;
}

class ReadingSessionRuntime {
  const ReadingSessionRuntime({
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
  final DayProgress dayProgress;

  int get versesToday => dayProgress.verses;

  int get secondsToday => dayProgress.seconds;

  bool get goalAlreadyReachedToday => dayProgress.goalReached;
}

class VerseRange {
  const VerseRange(this.bookId, this.chapter, this.fromVerse, this.toVerse);

  final int bookId;
  final int chapter;
  final int fromVerse;
  final int toVerse;
}

class SessionDetails {
  const SessionDetails(this.rsSession, this.progress);

  final RsSession rsSession;
  final List<VerseRange> progress;
}
