import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:gbt/common/bible_navigation.dart';
import 'package:gbt/services/reading_session/rs_database.dart';
import 'package:gbt/services/reading_session/rs_model.dart';
import 'package:gbt/services/service_locator.dart';

enum StatsType { weekly, monthly }

enum GoalType { minutes, verses }

enum ProgressType { byBook, bySection }

class DailyGoal {
  final GoalType type;
  final int value;

  const DailyGoal(this.type, this.value);
}

class ReadingSessionManager {
  final _rsdbManager = getIt<ReadingSessionDatabase>();
  late final _bibleNavigation = getIt<BibleNavigation>();

  static int maximumReadCount = 10;

  ReadingSessionManager();

  final List<VoidCallback> _statsListeners = [];

  void subscribeForStats(VoidCallback cb) {
    _statsListeners.add(cb);
  }

  void unsubscribeForStats(VoidCallback cb) {
    _statsListeners.remove(cb);
  }

  final Map<int, List<RsBookProgress>> _booksProgress = {};
  final Map<int, List<DayProgress>> _monthProgress = {};

  DateTime? get currentSessionStartTime => _rsDailyLog?.startTime;

  ReadingPlanDetails? _readingPlan;
  RsDailyLog? _rsDailyLog;
  Timer? _timer;
  bool _goalAlreadyReached = false;
  final Map<(int, int, int), Map<int, int>> _bookVerseReadCount = {};
  Set<int>? _books;

  final readingModeNotifier = ValueNotifier<bool>(false);
  final displayGoalProgresNotifier = ValueNotifier<bool>(false);
  final totalVersesReadPerDay = ValueNotifier<int>(0);
  final totalSecondsReadPerDay = ValueNotifier<int>(0);
  final totalSecondsReadPerSession = ValueNotifier<int>(0);
  final goalReachedNotifier = ValueNotifier<bool>(false);
  final bookCompletedNotifier = ValueNotifier<(int, int)>((0, 0));

  Future<void> init() async {
    await _rsdbManager.init();
    await _reloadFromDatabase();
  }

  ReadingPlanDetails? getReadingPlan() => _readingPlan;
  Set<int>? get readingPlanBooks => _books;

  RsBookProgress? getBookProgressForActivePlan(int bookId) {
    final planId = _readingPlan?.readingPlan.id;
    if (planId == null) return null;
    final list = _booksProgress[planId];
    if (list == null || bookId < 1 || bookId > list.length) return null;
    final progress = list[bookId - 1];
    return progress.id != null ? progress : null;
  }

  void toggleDisplayGoalProgress() {
    displayGoalProgresNotifier.value = !displayGoalProgresNotifier.value;
  }

  Future<void> startReadingSession(ReadingPlanDetails readingPlan) async {
    if (_readingPlan != null) {
      if (_readingPlan!.readingPlan.id == readingPlan.readingPlan.id) {
        _readingPlan = readingPlan;
        _books = readingPlan.books.map((x) => x.bookId).toSet();
        readingModeNotifier.value = false;
        readingModeNotifier.value = true;
        return;
      }
      await endReadingSession();
    }

    _readingPlan = readingPlan;

    _books = _readingPlan!.books.map((x) => x.bookId).toSet();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    var rsDailyLog = RsDailyLog(
      rsDate: today,
      startTime: now,
      verses: 0,
      readingPlanId: readingPlan.readingPlan.id!,
    );

    rsDailyLog = await _rsdbManager.insertDailyLog(rsDailyLog);

    _rsDailyLog = rsDailyLog;

    readingModeNotifier.value = true;
    goalReachedNotifier.value = false;
    _goalAlreadyReached = false;

    totalVersesReadPerDay.value = await _rsdbManager.getVersesReadToday(
      readingPlan.readingPlan.id!,
      today,
    );
    totalSecondsReadPerDay.value = await _rsdbManager.getTotalSecondsReadToday(
      readingPlan.readingPlan.id!,
      today,
    );

    totalSecondsReadPerSession.value = 0;
    displayGoalProgresNotifier.value = false;

    checkGoalReached(true);

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      totalSecondsReadPerDay.value += 1;
      totalSecondsReadPerSession.value += 1;
      checkGoalReached(false);
    });

    displayGoalProgresNotifier.value = true;
  }

  Future<void> endReadingSession() async {
    if (_readingPlan == null) {
      readingModeNotifier.value = false;
      return;
    }

    _timer?.cancel();

    final now = DateTime.now();

    var currentDailyLog = await _getTodaysReadingSession();

    currentDailyLog = currentDailyLog.copyWith(endTime: now);

    if (currentDailyLog.verses == 0) {
      totalSecondsReadPerDay.value -= totalSecondsReadPerSession.value;
      totalSecondsReadPerSession.value = 0;
      //empty session, removing it
      await _rsdbManager.deleteDailyLog(currentDailyLog.id!);
    } else {
      await _rsdbManager.updateDailyLog(currentDailyLog);
      await _updateStatistics(currentDailyLog);
    }

    _rsDailyLog = null;
    _readingPlan = null;
    _books = null;
    readingModeNotifier.value = false;
    _bookVerseReadCount.clear();
  }

  Future<Map<int, int>> getVersesReadForChapter(
    int readingPlanId,
    int bookId,
    int chapter,
  ) async {
    final key = (readingPlanId, bookId, chapter);
    Map<int, int>? versesRead = _bookVerseReadCount[key];
    if (versesRead != null) {
      return versesRead;
    }
    versesRead = await _rsdbManager.getVersesReadForChapter(
      readingPlanId,
      bookId,
      chapter,
    );

    _bookVerseReadCount[key] = versesRead;

    return versesRead;
  }

  ///this function helps setting if the goal is reached within this running session.
  ///if the goal was previously reached, no need to reset this value to true
  void checkGoalReached(bool initialLoad) async {
    if (_readingPlan == null) return;

    DailyGoal dailyGoal = _readingPlan!.dailyGoal;

    bool goalReached = false;

    if (dailyGoal.type == GoalType.verses &&
        totalVersesReadPerDay.value >= dailyGoal.value) {
      goalReached = true;
    } else if (dailyGoal.type == GoalType.minutes &&
        totalSecondsReadPerDay.value >= 60 * dailyGoal.value) {
      goalReached = true;
    }

    if (goalReached && initialLoad) {
      _goalAlreadyReached = true;
    }

    goalReached = goalReached && !_goalAlreadyReached;

    if (_goalAlreadyReached || !goalReached) {
      return;
    }
    _goalAlreadyReached = true;
    goalReachedNotifier.value = true;
  }

  Future<void> markVerseAsRead(int bookId, int chapter, int verse) async {
    if (_readingPlan == null ||
        _books == null ||
        !_books!.contains(bookId) ||
        _rsDailyLog == null) {
      return;
    }

    final readingPlanId = _readingPlan!.readingPlan.id!;
    final key = (readingPlanId, bookId, chapter);

    Map<int, int>? current = _bookVerseReadCount[key];
    if (current == null) {
      current = await getVersesReadForChapter(readingPlanId, bookId, chapter);

      _bookVerseReadCount[key] = current;
    }
    final existingCount = current[verse] ?? 0;
    current[verse] = existingCount + 1;

    var rsDailyLog = await _getTodaysReadingSession();

    final now = DateTime.now();

    final rsLog = RsLog(
      rsDailyLogId: rsDailyLog.id!,
      bookId: bookId,
      chapter: chapter,
      verse: verse,
      dateTime: now,
      readingPlanId: rsDailyLog.readingPlanId,
    );

    rsDailyLog = rsDailyLog.copyWith(verses: rsDailyLog.verses + 1);

    await _rsdbManager.insertLog(rsLog);

    await _rsdbManager.updateDailyLog(rsDailyLog);

    //book progress is only increased when we read the verse for the first time
    if (existingCount == 0) {
      await _recomputeBookProgress(
        rsDailyLog.readingPlanId,
        bookId,
        chapter,
        isNewUniqueVerseRead: true,
      );
    }

    _rsDailyLog = rsDailyLog;

    totalVersesReadPerDay.value = totalVersesReadPerDay.value + 1;
    checkGoalReached(false);
  }

  Future<void> resetReadingCountForVerse(
    int bookId,
    int chapter,
    int verse,
  ) async {
    if (_readingPlan == null ||
        _rsDailyLog == null ||
        _books == null ||
        !_books!.contains(bookId)) {
      return;
    }

    final readingPlanId = _readingPlan!.readingPlan.id!;
    final key = (readingPlanId, bookId, chapter);

    Map<int, int>? verseReadCount = _bookVerseReadCount[key];

    //load cache if not already loaded
    verseReadCount ??= await getVersesReadForChapter(
      readingPlanId,
      bookId,
      chapter,
    );

    final List<RsLog> todayVerseLogs = await _rsdbManager
        .getRsLogForDailyLogAndVerse(_rsDailyLog!.id!, bookId, chapter, verse);
    final todaySessionCount = todayVerseLogs.length;

    await _rsdbManager.deleteRsLogsForVerse(
      readingPlanId,
      bookId,
      chapter,
      verse,
    );

    verseReadCount[verse] = 0;

    if (todaySessionCount > 0) {
      _rsDailyLog = _rsDailyLog!.copyWith(
        verses: math.max(0, _rsDailyLog!.verses - todaySessionCount),
      );
      totalVersesReadPerDay.value = math.max(
        0,
        totalVersesReadPerDay.value - todaySessionCount,
      );
      await _rsdbManager.updateDailyLog(_rsDailyLog!);
    }

    await _recomputeBookProgress(
      readingPlanId,
      bookId,
      chapter,
      isNewUniqueVerseRead: false,
    );
  }

  Future<void> resetForDatabaseRestore() async {
    await _resetBeforeRestore();
  }

  Future<void> reloadAfterDatabaseRestore() async {
    await _reloadFromDatabase();
  }

  Future<void> _resetBeforeRestore() async {
    _timer?.cancel();
    _timer = null;
    _rsDailyLog = null;
    _readingPlan = null;
    _books = null;
    readingModeNotifier.value = false;
    displayGoalProgresNotifier.value = false;
    totalVersesReadPerDay.value = 0;
    totalSecondsReadPerDay.value = 0;
    totalSecondsReadPerSession.value = 0;
    goalReachedNotifier.value = false;
    bookCompletedNotifier.value = (0, 0);
    _goalAlreadyReached = false;
  }

  ///if the session started in a older day than today, then log it as a distinct entry
  ///this is mainly for sessions that starts before 12AM and ends after 12AM
  Future<RsDailyLog> _getTodaysReadingSession() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    var currentDailyLog = _rsDailyLog!;

    while (today != currentDailyLog.rsDate) {
      final nextDay = DateTime(
        currentDailyLog.rsDate.year,
        currentDailyLog.rsDate.month,
        currentDailyLog.rsDate.day + 1,
      );
      final endTime = nextDay.add(const Duration(seconds: -1));

      final rsDailyLog = currentDailyLog.copyWith(endTime: endTime);

      await _rsdbManager.updateDailyLog(rsDailyLog);

      await _updateStatistics(rsDailyLog);

      currentDailyLog = RsDailyLog(
        rsDate: nextDay,
        startTime: nextDay,
        verses: 0,
        readingPlanId: _rsDailyLog!.readingPlanId,
      );

      currentDailyLog = await _rsdbManager.insertDailyLog(currentDailyLog);
    }

    return currentDailyLog;
  }

  Future<void> _updateStatistics(RsDailyLog dailyLog) async {
    await _updateDailyStatistics(dailyLog);
    await _updateMonthlyStatistics(dailyLog);

    for (VoidCallback x in _statsListeners) {
      x.call();
    }
  }

  Future<void> _updateDailyStatistics(RsDailyLog dailyLog) async {
    RsStats? stats = await _updateStatisticsBy(
      dailyLog,
      RsStatsType.daily,
      dailyLog.rsDate,
    );

    if (stats == null) return;

    List<DayProgress>? progress = _monthProgress[dailyLog.readingPlanId];

    progress ??= await _loadMonthProgress(dailyLog.readingPlanId);

    for (int i = 0; i < progress.length; i++) {
      if (progress[i].day.year == dailyLog.rsDate.year &&
          progress[i].day.month == dailyLog.rsDate.month &&
          progress[i].day.day == dailyLog.rsDate.day) {
        progress[i] = DayProgress(
          stats.statsDate,
          stats.rsSeconds ~/ 60,
          stats.rsVerses,
          stats.goalReached,
        );
        break;
      }
    }
  }

  Future<void> _updateMonthlyStatistics(RsDailyLog dailyLog) async {
    final lastDay = DateTime(
      dailyLog.rsDate.year,
      dailyLog.rsDate.month + 1,
      0,
    );

    await _updateStatisticsBy(dailyLog, RsStatsType.monthly, lastDay);
  }

  Future<RsStats?> _updateStatisticsBy(
    RsDailyLog dailyLog,
    RsStatsType type,
    DateTime rsDate,
  ) async {
    if (_readingPlan == null) return null;

    final dailyGoal = _readingPlan!.dailyGoal;

    RsStats? stats = await _rsdbManager.findStatsByTypeAndDateForPlan(
      type,
      rsDate,
      dailyLog.readingPlanId,
    );

    final seconds = dailyLog.endTime!.difference(dailyLog.startTime).inSeconds;

    final totalVerses = dailyLog.verses + (stats?.rsVerses ?? 0);
    final totalSeconds = seconds + (stats?.rsSeconds ?? 0);
    final goalReached =
        (dailyGoal.type == GoalType.minutes &&
            totalSeconds >= dailyGoal.value * 60) ||
        (dailyGoal.type == GoalType.verses && totalVerses >= dailyGoal.value);

    if (stats == null) {
      stats = RsStats(
        type: type,
        statsDate: rsDate,
        rsSeconds: totalSeconds,
        rsVerses: totalVerses,
        goalReached: goalReached,
        readingPlanId: dailyLog.readingPlanId,
      );

      await _rsdbManager.insertStats(stats);
    } else {
      stats = stats.copyWith(
        rsSeconds: totalSeconds,
        rsVerses: totalVerses,
        goalReached: goalReached,
      );
      await _rsdbManager.updateStats(stats);
    }

    return stats;
  }

  Future<List<RsBookProgress>> loadBooksProgress(int readingPlanId) async {
    final val = _booksProgress[readingPlanId];
    if (val != null) {
      return val;
    }

    final booksCount = _bibleNavigation.getBooksCount();
    final List<RsBookProgress> list = <RsBookProgress>[];

    List<RsBookProgress> storedProgresses = await _rsdbManager
        .getAllBookProgress(readingPlanId);

    int nextBookId = 1;
    for (RsBookProgress progress in storedProgresses) {
      for (int i = nextBookId; i < progress.bookId; i++) {
        list.add(
          RsBookProgress(
            bookId: i,
            chapter: 1,
            verse: 1,
            chaptersRead: 0,
            versesRead: 0,
            updatedAt: DateTime.now(),
            readingPlanId: readingPlanId,
          ),
        );
      }

      list.add(progress);
      nextBookId = progress.bookId + 1;
    }

    for (int i = nextBookId; i <= booksCount; i++) {
      list.add(
        RsBookProgress(
          bookId: i,
          chapter: 1,
          verse: 1,
          chaptersRead: 0,
          versesRead: 0,
          updatedAt: DateTime.now(),
          readingPlanId: readingPlanId,
        ),
      );
    }

    _booksProgress[readingPlanId] = list;
    return list;
  }

  RsBookProgress? getLatestBookProgress(
    int readingPlanId, {
    List<int>? orderedBookIds,
    Set<int>? planBookIds,
  }) {
    final readingProgress = _booksProgress[readingPlanId];
    if (readingProgress == null) return null;

    if (orderedBookIds != null && orderedBookIds.isNotEmpty) {
      final progressMap = <int, RsBookProgress>{};
      for (final p in readingProgress) {
        progressMap[p.bookId] = p;
      }

      for (final bookId in orderedBookIds) {
        final progress =
            progressMap[bookId] ??
            RsBookProgress(
              bookId: bookId,
              chapter: 1,
              verse: 1,
              chaptersRead: 0,
              versesRead: 0,
              updatedAt: DateTime.now(),
              readingPlanId: readingPlanId,
            );
        final totalVerses = _bibleNavigation.getTotalVerseCount(bookId);
        if (progress.versesRead < totalVerses) {
          return progress;
        }
      }

      final firstBookId = orderedBookIds.first;
      return progressMap[firstBookId] ??
          RsBookProgress(
            bookId: firstBookId,
            chapter: 1,
            verse: 1,
            chaptersRead: 0,
            versesRead: 0,
            updatedAt: DateTime.now(),
            readingPlanId: readingPlanId,
          );
    }

    final filtered = readingProgress
        .where(
          (b) =>
              b.id != null &&
              (planBookIds == null || planBookIds.contains(b.bookId)),
        )
        .toList();

    if (filtered.isEmpty) {
      return null;
    }

    final incomplete = filtered
        .where(
          (b) => b.versesRead < _bibleNavigation.getTotalVerseCount(b.bookId),
        )
        .toList();

    final candidates = incomplete.isNotEmpty ? incomplete : filtered;

    final latest = candidates.reduce(
      (a, b) => a.updatedAt.isAfter(b.updatedAt) ? a : b,
    );

    return latest;
  }

  Future<void> _recomputeBookProgress(
    int readingPlanId,
    int bookId,
    int touchedChapter, {
    required bool isNewUniqueVerseRead,
  }) async {
    await loadBooksProgress(readingPlanId);

    final chapterCounts = await _rsdbManager.getDistinctVersesReadPerChapter(
      readingPlanId,
      bookId,
    );
    final totalBookChapters = _bibleNavigation.getChapterCount(bookId);
    final totalBookVerses = _bibleNavigation.getTotalVerseCount(bookId);

    int versesRead = 0;
    for (final count in chapterCounts.values) {
      versesRead += count;
    }

    int chaptersRead = 0;
    for (int c = 1; c <= totalBookChapters; c++) {
      if ((chapterCounts[c] ?? 0) ==
          _bibleNavigation.getVerseCount(bookId, c)) {
        chaptersRead++;
      }
    }

    int cursorChapter;
    int cursorVerse;

    if (versesRead == totalBookVerses) {
      // Case C: Entire book is 100% read
      cursorChapter = totalBookChapters;
      cursorVerse = _bibleNavigation.getVerseCount(bookId, totalBookChapters);

      var currentProgress = _booksProgress[readingPlanId]![bookId - 1];
      currentProgress = currentProgress.copyWith(
        chapter: cursorChapter,
        verse: cursorVerse,
        chaptersRead: chaptersRead,
        versesRead: versesRead,
        updatedAt: DateTime.now(),
      );
      if (currentProgress.id == null) {
        currentProgress = await _rsdbManager.insertBookProgresss(
          currentProgress,
        );
      } else {
        await _rsdbManager.updateBookProgress(currentProgress);
      }
      _booksProgress[readingPlanId]![bookId - 1] = currentProgress;

      int? nextBookId;
      if (_readingPlan != null && _readingPlan!.books.isNotEmpty) {
        final books = _readingPlan!.books;
        final curIdx = books.indexWhere((b) => b.bookId == bookId);
        final startIdx = curIdx >= 0 ? curIdx : 0;
        for (int i = 1; i <= books.length; i++) {
          final candidateIdx = (startIdx + i) % books.length;
          final candidateBookId = books[candidateIdx].bookId;
          final candidateProgress =
              _booksProgress[readingPlanId]![candidateBookId - 1];
          if (candidateProgress.versesRead <
              _bibleNavigation.getTotalVerseCount(candidateBookId)) {
            nextBookId = candidateBookId;
            break;
          }
        }
      }

      if (nextBookId != null) {
        var nextProgress = _booksProgress[readingPlanId]![nextBookId - 1];
        if (nextProgress.id == null) {
          nextProgress = RsBookProgress(
            readingPlanId: readingPlanId,
            bookId: nextBookId,
            chapter: 1,
            verse: 1,
            chaptersRead: 0,
            versesRead: 0,
            updatedAt: DateTime.now(),
          );
          nextProgress = await _rsdbManager.insertBookProgresss(nextProgress);
        } else {
          nextProgress = nextProgress.copyWith(updatedAt: DateTime.now());
          await _rsdbManager.updateBookProgress(nextProgress);
        }
        _booksProgress[readingPlanId]![nextBookId - 1] = nextProgress;
      }

      if (isNewUniqueVerseRead) {
        bookCompletedNotifier.value = (bookId, nextBookId ?? 0);
      }
    } else {
      // Book is not yet complete. Check touched chapter vs other chapters.
      final touchedChapterCount = chapterCounts[touchedChapter] ?? 0;
      final touchedChapterTotal = _bibleNavigation.getVerseCount(
        bookId,
        touchedChapter,
      );

      if (touchedChapterCount < touchedChapterTotal) {
        // Case A: Touched chapter still has unread verses
        cursorChapter = touchedChapter;
        final versesReadForChapter = await _rsdbManager.getVersesReadForChapter(
          readingPlanId,
          bookId,
          touchedChapter,
        );
        cursorVerse = 1;
        for (int v = 1; v <= touchedChapterTotal; v++) {
          if ((versesReadForChapter[v] ?? 0) == 0) {
            cursorVerse = v;
            break;
          }
        }
      } else {
        // Case B: Touched chapter is 100% read, but versesRead < totalBookVerses
        // Scan [touchedChapter + 1 .. totalBookChapters, 1 .. touchedChapter - 1]
        final scanOrder = <int>[];
        for (int c = touchedChapter + 1; c <= totalBookChapters; c++) {
          scanOrder.add(c);
        }
        for (int c = 1; c < touchedChapter; c++) {
          scanOrder.add(c);
        }

        int targetChapter = touchedChapter;
        for (final c in scanOrder) {
          final cCount = chapterCounts[c] ?? 0;
          final cTotal = _bibleNavigation.getVerseCount(bookId, c);
          if (cCount < cTotal) {
            targetChapter = c;
            break;
          }
        }

        cursorChapter = targetChapter;
        final targetChapterTotal = _bibleNavigation.getVerseCount(
          bookId,
          targetChapter,
        );
        final versesReadForChapter = await _rsdbManager.getVersesReadForChapter(
          readingPlanId,
          bookId,
          targetChapter,
        );
        cursorVerse = 1;
        for (int v = 1; v <= targetChapterTotal; v++) {
          if ((versesReadForChapter[v] ?? 0) == 0) {
            cursorVerse = v;
            break;
          }
        }
      }

      var currentProgress = _booksProgress[readingPlanId]![bookId - 1];
      currentProgress = currentProgress.copyWith(
        chapter: cursorChapter,
        verse: cursorVerse,
        chaptersRead: chaptersRead,
        versesRead: versesRead,
        updatedAt: DateTime.now(),
      );
      if (currentProgress.id == null) {
        currentProgress = await _rsdbManager.insertBookProgresss(
          currentProgress,
        );
      } else {
        await _rsdbManager.updateBookProgress(currentProgress);
      }
      _booksProgress[readingPlanId]![bookId - 1] = currentProgress;
    }

    await _loadMonthProgress(readingPlanId);
  }

  Future<List<DayProgress>?> getMonthProgress(int readingPlanId) async {
    final res = _monthProgress[readingPlanId];

    if (res != null) {
      return res;
    }

    await _loadMonthProgress(readingPlanId);
    return _monthProgress[readingPlanId];
  }

  Future<List<DayProgress>> _loadMonthProgress(int readingPlanId) async {
    DateTime now = DateTime.now();

    List<DayProgress> monthData = await loadMonthProgress(readingPlanId, now);

    _monthProgress[readingPlanId] = monthData;

    for (VoidCallback x in _statsListeners) {
      x.call();
    }
    return monthData;
  }

  Future<List<DayProgress>> loadMonthProgress(
    int readingPlanId,
    DateTime month,
  ) async {
    final int daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final DateTime startOfMonth = DateTime(month.year, month.month, 1);
    final DateTime endOfMonth = DateTime(month.year, month.month + 1, 0);

    final List<RsStats> dailyStatsForCurrentMonth = await _rsdbManager
        .getRsStatsForType(
          RsStatsType.daily,
          startOfMonth,
          endOfMonth,
          readingPlanId,
        );

    final statsByDay = <int, RsStats>{};
    for (final s in dailyStatsForCurrentMonth) {
      statsByDay[s.statsDate.day] = s;
    }

    final List<DayProgress> monthData = [];

    for (int day = 1; day <= daysInMonth; day++) {
      final d = DateTime(month.year, month.month, day);
      final stats = statsByDay[day];

      final DayProgress entry;
      if (stats != null) {
        entry = DayProgress(
          d,
          stats.rsSeconds ~/ 60,
          stats.rsVerses,
          stats.goalReached,
        );
      } else {
        entry = DayProgress.empty(d);
      }

      monthData.add(entry);
    }
    return monthData;
  }

  Future<void> _reloadFromDatabase() async {
    _booksProgress.clear();
    _bookVerseReadCount.clear();
    _monthProgress.clear();
    readingModeNotifier.value = _rsDailyLog != null;
  }

  Future<List<ReadingPlanDetails>> getReadingPlansWithProgress() async {
    final plans = await _rsdbManager.getReadingPlans();

    for (final p in plans) {
      int totalChapters = 0;
      int versesCount = 0;
      int versesRead = 0;
      int booksRead = 0;

      final booksProgress = await loadBooksProgress(p.readingPlan.id!);
      final orderedBookIds = p.books.map((b) => b.bookId).toList();

      for (final b in p.books) {
        final bookChap = _bibleNavigation.getChapterCount(b.bookId);
        final bookVerses = _bibleNavigation.getTotalVerseCount(b.bookId);

        totalChapters += bookChap;
        versesCount += bookVerses;

        final bookVersesRead = booksProgress[b.bookId - 1].versesRead;
        versesRead += bookVersesRead;

        if (bookVersesRead >= bookVerses) {
          booksRead += 1;
        }
      }

      p.totalChapters = totalChapters;
      p.totalVerses = versesCount;
      p.versesRead = versesRead;
      p.booksRead = booksRead;
      p.latestBookProgress = getLatestBookProgress(
        p.readingPlan.id!,
        orderedBookIds: orderedBookIds,
      );
    }
    return plans;
  }

  Future<ReadingPlan> saveReadingPlan({
    ReadingPlanDetails? existingPlanDetails,
    required String planName,
    required int collectionId,
    required GoalType goalType,
    required int goalValue,
    required Set<int> selectedBookIds,
  }) async {
    final List<int> orderedBookIds = [];
    if (existingPlanDetails != null) {
      for (final b in existingPlanDetails.books) {
        if (selectedBookIds.contains(b.bookId)) {
          orderedBookIds.add(b.bookId);
        }
      }
    }
    final existingBookIdsSet = orderedBookIds.toSet();
    final newlyAddedBooks =
        selectedBookIds.where((b) => !existingBookIdsSet.contains(b)).toList()
          ..sort();
    orderedBookIds.addAll(newlyAddedBooks);

    final savedPlan = await _rsdbManager.saveReadingPlan(
      existingPlan: existingPlanDetails?.readingPlan,
      planName: planName,
      collectionId: collectionId,
      goalType: goalType.name,
      goalValue: goalValue,
      orderedBookIds: orderedBookIds,
    );

    final planId = savedPlan.id!;
    _booksProgress.remove(planId);
    await loadBooksProgress(planId);

    if (_readingPlan?.readingPlan.id == planId) {
      _readingPlan = await _rsdbManager.getReadingPlanById(planId);
      if (_readingPlan != null) {
        _books = _readingPlan!.books.map((b) => b.bookId).toSet();
        final currentGoal = _readingPlan!.dailyGoal;
        if (currentGoal.type == GoalType.verses) {
          if (totalVersesReadPerDay.value < currentGoal.value) {
            _goalAlreadyReached = false;
            goalReachedNotifier.value = false;
          } else {
            checkGoalReached(false);
          }
        } else if (currentGoal.type == GoalType.minutes) {
          if (totalSecondsReadPerDay.value < currentGoal.value * 60) {
            _goalAlreadyReached = false;
            goalReachedNotifier.value = false;
          } else {
            checkGoalReached(false);
          }
        }
        readingModeNotifier.value = false;
        readingModeNotifier.value = true;
      }
    }

    return savedPlan;
  }

  Future<bool> toggleReadingPlanBookmark(ReadingPlanDetails planDetails) async {
    final updatedPlan = planDetails.readingPlan.copyWith(
      isBookmarked: !planDetails.readingPlan.isBookmarked,
    );
    await _rsdbManager.updateReadingPlan(updatedPlan);
    planDetails.readingPlan = updatedPlan;
    if (_readingPlan?.readingPlan.id == updatedPlan.id) {
      _readingPlan!.readingPlan = updatedPlan;
    }
    return updatedPlan.isBookmarked;
  }

  Future<void> reorderReadingPlanBooks(
    int readingPlanId,
    List<ReadingPlanBook> books,
  ) async {
    await _rsdbManager.updateReadingPlanBooks(books);
    if (_readingPlan?.readingPlan.id == readingPlanId) {
      _readingPlan!.books
        ..clear()
        ..addAll(books);
      final orderedIds = books.map((b) => b.bookId).toList();
      _readingPlan!.latestBookProgress = getLatestBookProgress(
        readingPlanId,
        orderedBookIds: orderedIds,
      );
    }
  }

  Future<void> deleteReadingPlan(int planId) async {
    if (_readingPlan?.readingPlan.id == planId) {
      await _resetBeforeRestore();
    }
    await _rsdbManager.deleteReadingPlan(planId);
    _booksProgress.remove(planId);
    _monthProgress.remove(planId);
    _bookVerseReadCount.removeWhere((key, _) => key.$1 == planId);
  }

  Future<List<Session>> getDetailedProgressFor(
    DateTime date,
    int readingPlanId,
  ) async {
    List<RsDailyLog> rsDailyLogs = await _rsdbManager.getSessionsForDate(
      date,
      readingPlanId,
    );

    List<Session> sessions = [];

    for (RsDailyLog session in rsDailyLogs) {
      List<RsLog> logs = await _rsdbManager.getRsLogForDailyLog(session.id!);

      List<DetailedProgess> progress = [];

      DetailedProgess? current;

      for (RsLog entry in logs) {
        if (current == null ||
            current.bookId != entry.bookId ||
            current.chapter != entry.chapter ||
            entry.verse - current.toVerse > 1) {
          current = DetailedProgess(
            entry.bookId,
            entry.chapter,
            entry.verse,
            entry.verse,
          );
          progress.add(current);
        } else {
          current.toVerse = entry.verse;
        }
      }
      sessions.add(Session(session, progress));
    }
    return sessions;
  }

  void dispose() {
    endReadingSession();
    _rsdbManager.dispose();
    _timer?.cancel();
  }
}
