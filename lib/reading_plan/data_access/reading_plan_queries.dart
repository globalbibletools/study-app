import 'package:gbt/common/reference.dart';
import 'package:gbt/reading_plan/data_access/reading_plan_read_models.dart';
import 'package:gbt/reading_plan/model.dart' show dayString;
import 'package:sqflite/sqflite.dart';

typedef VerseInventoryProvider =
    Future<Map<(int, int), List<int>>> Function(Set<int> bookIds);

class ReadingPlanQueries {
  ReadingPlanQueries(
    this._database, {
    required VerseInventoryProvider verseInventoryProvider,
  }) : _verseInventoryProvider = verseInventoryProvider;

  final Database _database;
  final VerseInventoryProvider _verseInventoryProvider;

  Future<List<ReadingPlanSummary>> getPlanSummaries({DateTime? today}) async {
    final configs = await _loadConfigs();
    if (configs.isEmpty) return const [];

    return _summariesFor(configs, _dayOnly(today ?? DateTime.now()));
  }

  Future<ReadingPlanSummary?> getPlanSummary(
    int planId, {
    DateTime? today,
  }) async {
    final configs = await _loadConfigs(planId: planId);
    if (configs.isEmpty) return null;

    final summaries = await _summariesFor(
      configs,
      _dayOnly(today ?? DateTime.now()),
    );
    return summaries.firstOrNull;
  }

  Future<ReadingPlanConfig?> getPlanConfig(int planId) async {
    final configs = await _loadConfigs(planId: planId);
    return configs.firstOrNull;
  }

  Future<Map<int, DailyProgress>> getMonthDayProgress(
    int planId,
    DateTime month,
  ) async {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 0);

    final rows = await _database.query(
      'rs_day_summary',
      where: 'reading_plan_id = ? AND rs_date BETWEEN ? AND ?',
      whereArgs: [planId, dayString(start), dayString(end)],
      orderBy: 'rs_date asc',
    );

    return {
      for (final row in rows)
        DateTime.parse(row['rs_date'] as String).day: _dayProgressFromMap(row),
    };
  }

  Future<DayActivity> getDayActivity(int planId, DateTime day) async {
    final date = _dayOnly(day);
    final sessionRows = await _database.query(
      'rs_session',
      where: 'date(rs_date) = date(?) AND reading_plan_id = ?',
      whereArgs: [date.toIso8601String(), planId],
      orderBy: 'start_time, id',
    );
    if (sessionRows.isEmpty) {
      return DayActivity(day: date, sessions: const []);
    }

    final sessionIds = [for (final row in sessionRows) row['id'] as int];
    final placeholders = List.filled(sessionIds.length, '?').join(', ');
    final logRows = await _database.rawQuery(
      'SELECT rs_session_id, book_id, chapter, verse '
      'FROM rs_log '
      'WHERE rs_session_id IN ($placeholders) '
      'ORDER BY rs_session_id, book_id, chapter, verse',
      sessionIds,
    );

    final logsBySession = <int, List<(int, int, int)>>{};
    for (final row in logRows) {
      final sessionId = row['rs_session_id'] as int;
      (logsBySession[sessionId] ??= []).add((
        row['book_id'] as int,
        row['chapter'] as int,
        row['verse'] as int,
      ));
    }

    return DayActivity(
      day: date,
      sessions: [
        for (final row in sessionRows)
          SessionActivity(
            sessionId: row['id'] as int,
            startTime: DateTime.parse(row['start_time'] as String),
            readSeconds: row['read_seconds'] as int? ?? 0,
            verses: row['verses'] as int? ?? 0,
            isManual: row['is_manual'] == 1,
            ranges: _foldRanges(logsBySession[row['id'] as int] ?? const []),
          ),
      ],
    );
  }

  Future<SessionRuntime?> getSessionRuntime(int sessionId) async {
    final rows = await _database.query(
      'rs_session',
      where: 'id = ?',
      whereArgs: [sessionId],
      limit: 1,
    );
    if (rows.isEmpty) return null;

    final row = rows.first;
    final planId = row['reading_plan_id'] as int;
    final day = _dayOnly(DateTime.parse(row['rs_date'] as String));
    return SessionRuntime(
      sessionId: sessionId,
      planId: planId,
      sessionDay: day,
      sessionStartTime: DateTime.parse(row['start_time'] as String),
      sessionReadSeconds: row['read_seconds'] as int? ?? 0,
      dayProgress: await getDayProgress(planId, day),
    );
  }

  Future<Map<int, VerseReadState>> getVerseReadStates(
    int sessionId,
    int bookId,
    int chapter,
  ) async {
    final rows = await _database.rawQuery(
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
    );

    return {
      for (final row in rows)
        row['verse'] as int: VerseReadState(
          readCount: row['read_count'] as int,
          readThisSession: (row['read_this_session'] as int) == 1,
        ),
    };
  }

  Future<DailyProgress> getDayProgress(int planId, DateTime date) async {
    final day = _dayOnly(date);
    final rows = await _database.query(
      'rs_day_summary',
      where: 'reading_plan_id = ? AND rs_date = ?',
      whereArgs: [planId, dayString(day)],
      limit: 1,
    );

    if (rows.isEmpty) return DailyProgress.empty(day);
    return _dayProgressFromMap(rows.first);
  }

  Future<List<ReadingPlanSummary>> _summariesFor(
    List<ReadingPlanConfig> configs,
    DateTime day,
  ) async {
    final planIds = [for (final config in configs) config.planId];
    final progressByPlan = await _loadBookProgress(configs);
    final resumes = await _resumeReferences(planIds);
    final placeholders = List.filled(planIds.length, '?').join(', ');
    final summaryRows = await _database.query(
      'rs_day_summary',
      where: 'reading_plan_id IN ($placeholders) AND rs_date = ?',
      whereArgs: [...planIds, dayString(day)],
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
            progressByPlan[config.planId] ?? const {},
            resumes[config.planId],
          ),
          today: todayByPlan[config.planId] ?? DailyProgress.empty(day),
        ),
    ];
  }

  Future<List<ReadingPlanConfig>> _loadConfigs({int? planId}) async {
    final planRows = await _database.query(
      'reading_plan',
      where: planId == null ? null : 'id = ?',
      whereArgs: planId == null ? null : [planId],
      orderBy: planId == null ? 'is_bookmarked desc, created_at desc' : null,
    );
    if (planRows.isEmpty) return const [];

    final planIds = [for (final row in planRows) row['id'] as int];
    final placeholders = List.filled(planIds.length, '?').join(', ');
    final bookRows = await _database.query(
      'reading_plan_book',
      columns: ['reading_plan_id', 'book_id'],
      where: 'reading_plan_id IN ($placeholders)',
      whereArgs: planIds,
      orderBy: 'reading_plan_id, ord',
    );

    final booksByPlan = <int, List<int>>{};
    for (final row in bookRows) {
      (booksByPlan[row['reading_plan_id'] as int] ??= []).add(
        row['book_id'] as int,
      );
    }

    return [
      for (final row in planRows)
        ReadingPlanConfig(
          planId: row['id'] as int,
          planName: row['plan_name'] as String,
          isBookmarked: row['is_bookmarked'] == 1,
          createdAt: DateTime.parse(row['created_at'] as String),
          dailyGoal: DailyGoal(
            GoalType.fromStorage(row['goal_type'] as String?),
            row['goal_value'] as int? ?? 0,
          ),
          bookIds: booksByPlan[row['id'] as int] ?? const [],
        ),
    ];
  }

  Future<Map<int, Map<int, BookProgress>>> _loadBookProgress(
    List<ReadingPlanConfig> configs,
  ) async {
    if (configs.isEmpty) return const {};

    final bookIds = <int>{for (final config in configs) ...config.bookIds};
    final expectedTotals = <int, int>{};
    if (bookIds.isNotEmpty) {
      final inventory = await _verseInventoryProvider(bookIds);
      inventory.forEach((key, verses) {
        final bookId = key.$1;
        expectedTotals[bookId] = (expectedTotals[bookId] ?? 0) + verses.length;
      });
    }

    final planIds = [for (final config in configs) config.planId];
    final placeholders = List.filled(planIds.length, '?').join(', ');
    final readRows = await _database.rawQuery(
      'SELECT reading_plan_id, book_id, '
      '       SUM(CASE WHEN read_count > 0 THEN 1 ELSE 0 END) AS verses_read '
      'FROM rs_verse_state '
      'WHERE reading_plan_id IN ($placeholders) '
      'GROUP BY reading_plan_id, book_id',
      planIds,
    );

    final readCounts = <(int, int), int>{};
    for (final row in readRows) {
      readCounts[(row['reading_plan_id'] as int, row['book_id'] as int)] =
          row['verses_read'] as int? ?? 0;
    }

    return {
      for (final config in configs)
        config.planId: {
          for (final bookId in config.bookIds)
            bookId: BookProgress(
              bookId: bookId,
              totalVerses: expectedTotals[bookId] ?? 0,
              versesRead: readCounts[(config.planId, bookId)] ?? 0,
            ),
        },
    };
  }

  Future<Map<int, Reference>> _resumeReferences(List<int> planIds) async {
    if (planIds.isEmpty) return const {};

    final placeholders = List.filled(planIds.length, '?').join(', ');
    final rows = await _database.rawQuery(
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
    Map<int, BookProgress> bookProgress,
    Reference? resumePosition,
  ) {
    return ReadingPlanProgress(
      planId: config.planId,
      bookProgress: {
        for (final bookId in config.bookIds)
          bookId:
              bookProgress[bookId] ??
              BookProgress(bookId: bookId, totalVerses: 0, versesRead: 0),
      },
      resumePosition: resumePosition,
    );
  }

  static List<VerseRange> _foldRanges(List<(int, int, int)> logs) {
    final ranges = <VerseRange>[];
    int? bookId;
    int? chapter;
    var fromVerse = 0;
    var toVerse = 0;
    var hasRange = false;

    void flush() {
      if (!hasRange) return;
      ranges.add(VerseRange(bookId!, chapter!, fromVerse, toVerse));
      hasRange = false;
    }

    for (final (logBookId, logChapter, verse) in logs) {
      if (!hasRange ||
          bookId != logBookId ||
          chapter != logChapter ||
          verse - toVerse > 1) {
        flush();
        bookId = logBookId;
        chapter = logChapter;
        fromVerse = verse;
        toVerse = verse;
        hasRange = true;
      } else {
        toVerse = verse;
      }
    }
    flush();

    return ranges;
  }

  static DailyProgress _dayProgressFromMap(Map<String, Object?> row) {
    final date = DateTime.parse(row['rs_date'] as String);
    return DailyProgress(
      day: _dayOnly(date),
      seconds: row['rs_seconds'] as int? ?? 0,
      verses: row['rs_verses'] as int? ?? 0,
      goalReached: row['goal_reached'] == 1,
      goal: dailyGoalFromStored(
        row['goal_type'] as String?,
        row['goal_value'] as int?,
      ),
    );
  }

  static DateTime _dayOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);
}
