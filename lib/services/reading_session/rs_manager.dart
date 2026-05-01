import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:studyapp/common/bible_navigation.dart';
import 'package:studyapp/services/reading_session/rs_database.dart';
import 'package:studyapp/services/reading_session/rs_model.dart';
import 'package:studyapp/services/service_locator.dart';
import 'package:studyapp/services/settings/user_settings.dart';

enum StatsType { weekly, monthly }

enum GoalType { minutes, verses }

enum ProgressType { byBook, bySection }

class DailyGoal {
  final GoalType type;
  final int value;

  const DailyGoal(this.type, this.value);
}

class ReadingSessionManager {
  final _settings = getIt<UserSettings>();
  final _rsdbManager = getIt<ReadingSessionDatabase>();

  static int maximumReadCount = 10;

  ReadingSessionManager() {
    _getEmptyBookProgress();
  }

  final List<VoidCallback> _booksProgressListeners = [];
  final List<VoidCallback> _statsListeners = [];

  void subsribeForBookProgress(VoidCallback cb) {
    _booksProgressListeners.add(cb);
  }

  void unsubsribeForBookProgress(VoidCallback cb) {
    _booksProgressListeners.remove(cb);
  }

  void subsribeForStats(VoidCallback cb) {
    _statsListeners.add(cb);
  }

  void unsubsribeForStats(VoidCallback cb) {
    _statsListeners.remove(cb);
  }

  List<RsBookProgress>? _booksProgress;
  RsBookProgress? _latestBookProgress;
  List<DayProgress> _weekProgress = [];
  List<DayProgress> _monthProgress = [];

  late List<RsBookProgress> _emptyBooksProgress;

  List<RsBookProgress> get booksProgress =>
      _booksProgress ?? _emptyBooksProgress;
  RsBookProgress? get latestBookProgress => _latestBookProgress;
  List<DayProgress> get weekProgress => _weekProgress;
  List<DayProgress> get monthProgress => _monthProgress;
  DateTime? get currentSessionStartTime => _rsDailyLog?.startTime;

  RsDailyLog? _rsDailyLog;
  Timer? _timer;
  bool _goalAlreadyReached = false;
  final Map<int, Map<int, int>> _bookVerseReadCount = {};

  final readingModeNotifier = ValueNotifier<bool>(false);
  final displayGoalProgresNotifier = ValueNotifier<bool>(false);
  final totalVersesReadPerDay = ValueNotifier<int>(0);
  final totalSecondsReadPerDay = ValueNotifier<int>(0);
  final totalSecondsReadPerSession = ValueNotifier<int>(0);
  final goalReachedNotifier = ValueNotifier<bool>(false);

  Future<void> init() async {
    await _rsdbManager.init();
    await loadBooksProgress();
    readingModeNotifier.value = _rsDailyLog != null;
    getLatestBookProgress();
    await _loadMonthProgress();
  }

  Future<void> toggleReadingSession() async {
    if (_rsDailyLog == null) {
      await startReadingSession();
      return;
    }

    await endReadingSession();
  }

  void toggleDisplayGoalProgress() {
    displayGoalProgresNotifier.value = !displayGoalProgresNotifier.value;
  }

  DailyGoal? _dailyGoal;

  /// sets the daily goal in minutes
  Future<void> setDailyGoal(GoalType type, int value) async {
    _dailyGoal = DailyGoal(type, value);
    _settings.setDailyGoal('${type.name}-$value');
  }

  DailyGoal getDailyGoal() {
    if (_dailyGoal != null) {
      return _dailyGoal!;
    }

    String settingVal = _settings.dailyGoal ?? "${GoalType.minutes.name}-10";

    final spl = settingVal.split('-');

    final typeStr = spl.isNotEmpty ? spl[0] : GoalType.minutes.name;
    final valueStr = spl.length > 1 ? spl[1] : "10";

    final type = GoalType.values.firstWhere(
      (e) => e.name == typeStr,
      orElse: () => GoalType.minutes,
    );
    final value = int.tryParse(valueStr) ?? 10;

    _dailyGoal = DailyGoal(type, value);
    return _dailyGoal!;
  }

  Future<void> startReadingSession() async {
    if (_rsDailyLog != null) {
      return;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    var rsDailyLog = RsDailyLog(rsDate: today, startTime: now, verses: 0);

    rsDailyLog = await _rsdbManager.insertDailyLog(rsDailyLog);

    _rsDailyLog = rsDailyLog;
    readingModeNotifier.value = true;
    goalReachedNotifier.value = false;
    _goalAlreadyReached = false;

    totalVersesReadPerDay.value = await _rsdbManager.getVersesReadToday(today);
    totalSecondsReadPerDay.value = await _rsdbManager.getTotalSecondsReadToday(
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
  }

  Future<void> endReadingSession() async {
    if (_rsDailyLog == null) {
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
      _updateStatistics(currentDailyLog);
    }

    _rsDailyLog = null;
    readingModeNotifier.value = false;
    _bookVerseReadCount.clear();
  }

  Future<Map<int, int>> getVersesReadForChapter(int bookId, int chapter) async {
    final key = bookId * 1000 + chapter;
    Map<int, int>? versesRead = _bookVerseReadCount[key];
    if (versesRead != null) {
      return versesRead;
    }
    versesRead = await _rsdbManager.getVersesReadForChapter(bookId, chapter);

    _bookVerseReadCount[key] = versesRead;
    return versesRead;
  }

  ///this function helps setting if the goal is reached within this running session.
  ///if the goal was previously reached, no need to reset this value to true
  void checkGoalReached(bool initialLoad) {
    DailyGoal dailyGoal = getDailyGoal();

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
    if (_rsDailyLog == null) {
      return;
    }

    final key = bookId * 1000 + chapter;

    Map<int, int>? current = _bookVerseReadCount[key];
    if (current == null) {
      current = {};
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
    );

    rsDailyLog = rsDailyLog.copyWith(verses: rsDailyLog.verses + 1);

    await _rsdbManager.insertLog(rsLog);

    await _rsdbManager.updateDailyLog(rsDailyLog);

    //book progress is only increased when we read the verse for the first time
    if (existingCount == 0) {
      _updateBookProgress(rsLog, true);
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
    if (_rsDailyLog == null) {
      return;
    }

    List<RsLog> verseLogs = await _rsdbManager.getRsLogForDailyLogAndVerse(
      _rsDailyLog!.id!,
      bookId,
      chapter,
      verse,
    );

    var rsDailyLog = _rsDailyLog!;
    final key = bookId * 1000 + chapter;
    final count = verseLogs.length;

    for (RsLog rsLog in verseLogs) {
      await _rsdbManager.deleteLog(rsLog.id!);
    }

    var currentReadCount = _bookVerseReadCount[key]![verse]!;
    currentReadCount -= count;
    _bookVerseReadCount[key]![verse] = currentReadCount;

    if (currentReadCount == 0) {
      _updateBookProgress(verseLogs.first, false);
    }

    rsDailyLog = rsDailyLog.copyWith(verses: rsDailyLog.verses - count);
    totalVersesReadPerDay.value = totalVersesReadPerDay.value - count;

    await _rsdbManager.updateDailyLog(rsDailyLog);
  }

  ///if the session started in a older day than today, then log it as a distinct entry
  ///this is mainly for sessions that starts before 12AM and ends after 12AM
  Future<RsDailyLog> _getTodaysReadingSession() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    var currentDailyLog = _rsDailyLog!;

    while (today != currentDailyLog.rsDate) {
      final nextDay = currentDailyLog.rsDate.add(Duration(days: 1));
      final endTime = nextDay.add(Duration(seconds: -1));

      final rsDailyLog = currentDailyLog.copyWith(endTime: endTime);

      await _rsdbManager.updateDailyLog(rsDailyLog);

      _updateStatistics(rsDailyLog);

      currentDailyLog = RsDailyLog(
        rsDate: nextDay,
        startTime: nextDay,
        verses: 0,
      );

      currentDailyLog = await _rsdbManager.insertDailyLog(currentDailyLog);
    }

    return currentDailyLog;
  }

  Future<void> _updateStatistics(RsDailyLog dailyLog) async {
    await _updateDailyStatistics(dailyLog);
    await _updateMonthlyStatistics(dailyLog);
  }

  Future<void> _updateDailyStatistics(RsDailyLog dailyLog) async {
    _updateStatisticsBy(dailyLog, RsStatsType.daily, dailyLog.rsDate);
  }

  Future<void> _updateMonthlyStatistics(RsDailyLog dailyLog) async {
    final lastDay = DateTime(
      dailyLog.rsDate.year,
      dailyLog.rsDate.month + 1,
      0,
    );

    _updateStatisticsBy(dailyLog, RsStatsType.monthly, lastDay);
  }

  Future<void> _updateStatisticsBy(
    RsDailyLog dailyLog,
    RsStatsType type,
    DateTime rsDate,
  ) async {
    RsStats? stats = await _rsdbManager.findStatsByTypeAndDate(type, rsDate);

    final seconds = dailyLog.endTime!.difference(dailyLog.startTime).inSeconds;

    final dailyGoal = getDailyGoal();

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
      );

      _rsdbManager.insertStats(stats);
    } else {
      stats = stats.copyWith(
        rsSeconds: totalSeconds,
        rsVerses: totalVerses,
        goalReached: goalReached,
      );
      _rsdbManager.updateStats(stats);
    }
  }

  Future<List<RsBookProgress>> loadBooksProgress() async {
    if (_booksProgress != null) {
      return _booksProgress!;
    }

    final booksCount = BibleNavigation.getBooksCount();
    final List<RsBookProgress> list = <RsBookProgress>[];

    List<RsBookProgress> storedProgresses = await _rsdbManager
        .getAllBookProgress();

    int nextBookId = 1;
    for (RsBookProgress progress in storedProgresses) {
      for (int i = nextBookId; i < progress.bookId; i++) {
        list.add(
          RsBookProgress(
            bookId: i,
            chapter: 1,
            verse: 1,
            chaptersRead: 0,
            updatedAt: DateTime.now(),
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
          updatedAt: DateTime.now(),
        ),
      );
    }

    _booksProgress = list;
    return list;
  }

  List<RsBookProgress> _getEmptyBookProgress() {
    final booksCount = BibleNavigation.getBooksCount();
    final List<RsBookProgress> list = <RsBookProgress>[];

    for (int i = 1; i <= booksCount; i++) {
      list.add(
        RsBookProgress(
          bookId: i,
          chapter: 1,
          verse: 1,
          chaptersRead: 0,
          updatedAt: DateTime.now(),
        ),
      );
    }
    _emptyBooksProgress = list;
    return list;
  }

  RsBookProgress? getLatestBookProgress() {
    if (_booksProgress == null) return null;

    final filtered = _booksProgress!.where((b) => b.id != null).toList();

    if (filtered.isEmpty) {
      _latestBookProgress = null;
      return null;
    }

    final latest = filtered.reduce(
      (a, b) => a.updatedAt.isAfter(b.updatedAt) ? a : b,
    );

    _latestBookProgress = latest;
    for (VoidCallback x in _booksProgressListeners) {
      x.call();
    }

    return latest;
  }

  Future<void> _updateBookProgress(RsLog rsLog, bool markVerseAsRead) async {
    RsBookProgress bookProgress = _booksProgress![rsLog.bookId - 1];

    var verse = rsLog.verse;
    var chapter = rsLog.chapter;
    var bookId = rsLog.bookId;

    if (markVerseAsRead) {
      verse = verse + 1;
    }

    //check count of all verses read in this chapter
    final totalChapterVerses = BibleNavigation.getVerseCount(
      rsLog.bookId,
      rsLog.chapter,
    );

    int versesRead = await _rsdbManager.countVersesReadForChapter(
      rsLog.bookId,
      rsLog.chapter,
    );

    var chaptersRead = bookProgress.chaptersRead;

    //if this verse is read and chapter is completed, increase the number of read chapters
    if (markVerseAsRead && totalChapterVerses == versesRead) {
      chaptersRead += 1;
      final nextChapter = BibleNavigation.getNextChapter(
        ChapterIdentifier(bookId, chapter),
      );
      if (nextChapter != null) {
        bookId = nextChapter.bookId;
        chapter = nextChapter.chapter;
      } else {
        bookId = 1;
        chapter = 1;
      }
    }
    //if this verse is unread, and chapter was already completed, reduce the number of read chapters
    else if (!markVerseAsRead && totalChapterVerses == versesRead - 1) {
      chaptersRead -= 1;
      if (versesRead == 0) {
        final prevChapter = BibleNavigation.getPreviousChapter(
          ChapterIdentifier(bookId, chapter),
        );
        if (prevChapter != null) {
          bookId = prevChapter.bookId;
          chapter = prevChapter.chapter;
        } else {
          bookId = 1;
          chapter = 1;
        }
      }
    }

    //this is to track the last verse read, so the user can resume reading at a later stage
    bookProgress = bookProgress.copyWith(
      bookId: bookId,
      chapter: chapter,
      verse: verse,
      chaptersRead: chaptersRead,
    );

    if (bookProgress.id == null) {
      bookProgress = await _rsdbManager.insertBookProgresss(bookProgress);
    } else {
      await _rsdbManager.updateBookProgress(bookProgress);
    }

    _booksProgress![rsLog.bookId - 1] = bookProgress;

    //todo to be optimized
    await _loadMonthProgress();

    for (VoidCallback x in _booksProgressListeners) {
      x.call();
    }
  }

  Future<void> _loadMonthProgress() async {
    DateTime now = DateTime.now();
    DateTime startOfMonth = DateTime(now.year, now.month, 1);
    DateTime endOfMonth = DateTime(now.year, now.month + 1, 0);

    List<RsStats> dailyStatsForCurrentMonth = await _rsdbManager
        .getRsStatsForType(RsStatsType.daily, startOfMonth, endOfMonth);

    final List<DayProgress> monthData = [];

    final List<DayProgress> weekData = [];

    int i = 0;

    for (
      DateTime d = startOfMonth;
      !d.isAfter(endOfMonth);
      d = d.add(const Duration(days: 1))
    ) {
      RsStats? stats;

      if (i < dailyStatsForCurrentMonth.length) {
        final current = dailyStatsForCurrentMonth[i];

        //enough to check with day since they belong to the same month and year
        if (current.statsDate.day == d.day) {
          stats = current;
          i++;
        }
      }

      DayProgress entry;

      if (stats != null) {
        log(
          "stats : ${stats.rsSeconds} ${stats.rsVerses} ${stats.goalReached} ${stats.statsDate}",
        );
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
      if (isSameWeek(entry.day, now)) {
        weekData.add(entry);
      }
    }
    _monthProgress = monthData;
    _weekProgress = weekData;

    for (VoidCallback x in _statsListeners) {
      x.call();
    }
  }

  bool isSameWeek(DateTime a, DateTime b) {
    final aStartOfWeek = a.subtract(Duration(days: a.weekday - 1));
    final bStartOfWeek = b.subtract(Duration(days: b.weekday - 1));

    return aStartOfWeek.year == bStartOfWeek.year &&
        aStartOfWeek.month == bStartOfWeek.month &&
        aStartOfWeek.day == bStartOfWeek.day;
  }

  Future<List<Session>> getDetailedProgressFor(DateTime date) async {
    List<RsDailyLog> rsDailyLogs = await _rsdbManager.getSessionsForDate(date);

    List<Session> sessions = [];

    for (RsDailyLog session in rsDailyLogs) {
      List<RsLog> logs = await _rsdbManager.getRsLogForDailyLog(session.id!);

      List<DetailedProgess> progress = [];

      DetailedProgess? current;

      for (RsLog entry in logs) {
        if (current == null ||
            current.bookId != entry.bookId ||
            current.chapter != entry.chapter ||
            entry.verse - current.toVerse > 1 ) {
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
