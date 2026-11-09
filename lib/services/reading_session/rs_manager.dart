import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:gbt/common/bible_navigation.dart';
import 'package:gbt/services/reading_session/rs_database.dart';
import 'package:gbt/services/reading_session/rs_model.dart';
import 'package:gbt/services/service_locator.dart';

export 'package:gbt/services/reading_session/rs_model.dart'
    show DailyGoal, GoalType, ProgressType, StatsType;

class ReadingSessionManager {
  final _rsdbManager = getIt<ReadingSessionDatabase>();
  late final _bibleNavigation = getIt<BibleNavigation>();

  static int maximumReadCount = 10;

  ReadingSessionManager();

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

  Future<RsBookProgress?> getBookProgressForActivePlan(int bookId) async {
    final planId = _readingPlan?.readingPlan.id;
    if (planId == null) return null;

    final progresses = await _rsdbManager.getAllBookProgress(planId);
    for (final progress in progresses) {
      if (progress.bookId == bookId) return progress;
    }
    return null;
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
    await _updateStatisticsBy(dailyLog, RsStatsType.daily, dailyLog.rsDate);

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

  Future<void> _recomputeBookProgress(
    int readingPlanId,
    int bookId,
    int touchedChapter, {
    required bool isNewUniqueVerseRead,
  }) async {
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

    final storedProgress = await _rsdbManager.getAllBookProgress(readingPlanId);
    final progressByBook = <int, RsBookProgress>{
      for (final progress in storedProgress) progress.bookId: progress,
    };

    RsBookProgress progressFor(int id) =>
        progressByBook[id] ??
        RsBookProgress(
          readingPlanId: readingPlanId,
          bookId: id,
          chapter: 1,
          verse: 1,
          chaptersRead: 0,
          versesRead: 0,
          updatedAt: DateTime.now(),
        );

    Future<void> saveProgress(RsBookProgress progress) async {
      if (progress.id == null) {
        progressByBook[progress.bookId] = await _rsdbManager
            .insertBookProgresss(progress);
      } else {
        await _rsdbManager.updateBookProgress(progress);
        progressByBook[progress.bookId] = progress;
      }
    }

    int cursorChapter;
    int cursorVerse;

    if (versesRead == totalBookVerses) {
      // Case C: Entire book is 100% read
      cursorChapter = totalBookChapters;
      cursorVerse = _bibleNavigation.getVerseCount(bookId, totalBookChapters);

      await saveProgress(
        progressFor(bookId).copyWith(
          chapter: cursorChapter,
          verse: cursorVerse,
          chaptersRead: chaptersRead,
          versesRead: versesRead,
          updatedAt: DateTime.now(),
        ),
      );

      int? nextBookId;
      if (_readingPlan != null && _readingPlan!.books.isNotEmpty) {
        final books = _readingPlan!.books;
        final curIdx = books.indexWhere((b) => b.bookId == bookId);
        final startIdx = curIdx >= 0 ? curIdx : 0;
        for (int i = 1; i <= books.length; i++) {
          final candidateIdx = (startIdx + i) % books.length;
          final candidateBookId = books[candidateIdx].bookId;
          final candidateProgress = progressFor(candidateBookId);
          if (candidateProgress.versesRead <
              _bibleNavigation.getTotalVerseCount(candidateBookId)) {
            nextBookId = candidateBookId;
            break;
          }
        }
      }

      if (nextBookId != null) {
        final nextProgress = progressFor(nextBookId);
        await saveProgress(
          nextProgress.id == null
              ? nextProgress
              : nextProgress.copyWith(updatedAt: DateTime.now()),
        );
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

      await saveProgress(
        progressFor(bookId).copyWith(
          chapter: cursorChapter,
          verse: cursorVerse,
          chaptersRead: chaptersRead,
          versesRead: versesRead,
          updatedAt: DateTime.now(),
        ),
      );
    }
  }

  Future<void> _reloadFromDatabase() async {
    _bookVerseReadCount.clear();
    readingModeNotifier.value = _rsDailyLog != null;
  }

  void dispose() {
    endReadingSession();
    _rsdbManager.dispose();
    _timer?.cancel();
  }
}
