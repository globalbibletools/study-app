import 'dart:async';
import 'dart:typed_data';

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

  static int maximumReadCount = 10;

  ReadingSessionManager();

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

  final Map<int, List<RsBookProgress>> _booksProgress = {};
  RsBookProgress? _latestBookProgress;
  final Map<int, List<DayProgress>> _monthProgress = {};

  RsBookProgress? get latestBookProgress => _latestBookProgress;
  DateTime? get currentSessionStartTime => _rsDailyLog?.startTime;

  ReadingPlanDetails? _readingPlan;
  RsDailyLog? _rsDailyLog;
  Timer? _timer;
  bool _goalAlreadyReached = false;
  final Map<int, Map<int, int>> _bookVerseReadCount = {};
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

  void toggleDisplayGoalProgress() {
    displayGoalProgresNotifier.value = !displayGoalProgresNotifier.value;
  }

  Future<void> startReadingSession(ReadingPlanDetails readingPlan) async {
    if (_readingPlan != null) return;

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
      _updateStatistics(currentDailyLog);
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
    final key = bookId * 1000 + chapter;
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
    if (_readingPlan == null) {
      return;
    }

    final key = bookId * 1000 + chapter;

    Map<int, int>? current = _bookVerseReadCount[key];
    if (current == null) {
      current = await getVersesReadForChapter(
        _readingPlan!.readingPlan.id!,
        bookId,
        chapter,
      );

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
      await _updateBookProgress(rsDailyLog.readingPlanId, rsLog, true);
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
    if (_readingPlan == null || _bookVerseReadCount.isEmpty) {
      return;
    }

    var rsDailyLog = _rsDailyLog!;
    final key = bookId * 1000 + chapter;

    Map<int, int>? verseReadCount = _bookVerseReadCount[key];

    //load cache if not already loaded
    verseReadCount ??= await getVersesReadForChapter(
      _readingPlan!.readingPlan.id!,
      bookId,
      chapter,
    );

    if (!verseReadCount.containsKey(verse)) {
      //should not reach here
      return;
    }

    List<RsLog> verseLogs = await _rsdbManager.getRsLogForDailyLogAndVerse(
      _rsDailyLog!.id!,
      bookId,
      chapter,
      verse,
    );

    final count = verseLogs.length;

    for (RsLog rsLog in verseLogs) {
      await _rsdbManager.deleteLog(rsLog.id!);
    }

    var currentReadCount = verseReadCount[verse]!;
    currentReadCount -= count;
    verseReadCount[verse] = currentReadCount;

    if (currentReadCount == 0) {
      await _updateBookProgress(
        rsDailyLog.readingPlanId,
        verseLogs.first,
        false,
      );
    }

    rsDailyLog = rsDailyLog.copyWith(verses: rsDailyLog.verses - count);
    totalVersesReadPerDay.value = totalVersesReadPerDay.value - count;

    await _rsdbManager.updateDailyLog(rsDailyLog);
  }

  Future<String> createBackup() async {
    return _rsdbManager.createBackup();
  }

  Future<String> exportBackup(String backupPath) async {
    return _rsdbManager.writeBackupToPath(backupPath);
  }

  Future<Uint8List> buildBackupBytes() async {
    return _rsdbManager.buildBackupBytes();
  }

  Future<List<ReadingSessionBackupInfo>> listBackups() async {
    return _rsdbManager.listBackups();
  }

  Future<void> restoreBackup(String backupPath) async {
    await _resetBeforeRestore();
    await _rsdbManager.restoreBackup(backupPath);
    await _reloadFromDatabase();
  }

  Future<void> restoreBackupBytes(Uint8List bytes) async {
    await _resetBeforeRestore();
    await _rsdbManager.restoreBackupBytes(bytes);
    await _reloadFromDatabase();
  }

  Future<void> _resetBeforeRestore() async {
    _timer?.cancel();
    _timer = null;
    _rsDailyLog = null;
    _readingPlan = null;
    readingModeNotifier.value = false;
    displayGoalProgresNotifier.value = false;
    totalVersesReadPerDay.value = 0;
    totalSecondsReadPerDay.value = 0;
    totalSecondsReadPerSession.value = 0;
    goalReachedNotifier.value = false;
    _goalAlreadyReached = false;
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
      if (progress[i].day != dailyLog.rsDate) continue;
      progress[i] = DayProgress(
        stats.statsDate,
        stats.rsSeconds ~/ 60,
        stats.rsVerses,
        stats.goalReached,
      );
    }
  }

  Future<void> _updateMonthlyStatistics(RsDailyLog dailyLog) async {
    final lastDay = DateTime(
      dailyLog.rsDate.year,
      dailyLog.rsDate.month + 1,
      0,
    );

    _updateStatisticsBy(dailyLog, RsStatsType.monthly, lastDay);
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

    final booksCount = BibleNavigation.getBooksCount();
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

  RsBookProgress? getLatestBookProgress(int readingPlanId) {
    final readingProgress = _booksProgress[readingPlanId];
    if (readingProgress == null) return null;

    final filtered = readingProgress.where((b) => b.id != null).toList();

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

  Future<ChapterIdentifier?> _updateBookProgress(
    int readingPlanId,
    RsLog rsLog,
    bool markVerseAsRead,
  ) async {
    if (_readingPlan == null) return null;

    RsBookProgress bookProgress =
        _booksProgress[readingPlanId]![rsLog.bookId - 1];

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

    int chapterVersesRead = await _rsdbManager.countVersesReadForChapter(
      _readingPlan!.readingPlan.id!,
      rsLog.bookId,
      rsLog.chapter,
    );

    var chaptersRead = bookProgress.chaptersRead;
    var versesRead = bookProgress.versesRead;

    if (markVerseAsRead) {
      versesRead += 1;
    } else {
      versesRead -= 1;
    }

    ChapterIdentifier? nextChapter;

    //if this verse is read and chapter is completed, increase the number of read chapters
    if (markVerseAsRead && totalChapterVerses == chapterVersesRead) {
      chaptersRead += 1;
    }
    //if this verse is unread, and chapter was already completed, reduce the number of read chapters
    else if (!markVerseAsRead && totalChapterVerses == chapterVersesRead - 1) {
      chaptersRead -= 1;
    }

    bool chapterCompleted = false;

    //if with reading progress, the last verse is completed, move to next chapter
    if (markVerseAsRead && verse > totalChapterVerses) {
      nextChapter = BibleNavigation.getNextChapterForReadingPlan(
        ChapterIdentifier(bookId, chapter),
        _readingPlan!,
      );
      chapterCompleted = true;
    }
    //or move backward
    else if (!markVerseAsRead && verse == 1) {
      nextChapter = BibleNavigation.getPreviousChapterForReadingPlan(
        ChapterIdentifier(bookId, chapter),
        _readingPlan!,
      );
    }

    //progress is within the same book, update the values
    if (nextChapter != null && nextChapter.bookId == bookId) {
      chapter = nextChapter.chapter;
      //start with the next unread verse of the chapter
      final versesReadForChapter = await getVersesReadForChapter(
        _readingPlan!.readingPlan.id!,
        bookId,
        chapter,
      );
      final chapterVerseCount = BibleNavigation.getVerseCount(bookId, chapter);
      verse = 1;
      for (var i = 1; i <= chapterVerseCount; i++) {
        if ((versesReadForChapter[i] ?? 0) == 0) {
          verse = i;
          break;
        }
      }
    }

    //this is to track the last verse read, so the user can resume reading at a later stage
    bookProgress = bookProgress.copyWith(
      bookId: bookId,
      chapter: chapter,
      verse: verse,
      chaptersRead: chaptersRead,
      versesRead: versesRead,
      updatedAt: DateTime.now(),
    );

    if (bookProgress.id == null) {
      bookProgress = await _rsdbManager.insertBookProgresss(bookProgress);
    } else {
      await _rsdbManager.updateBookProgress(bookProgress);
    }

    _booksProgress[readingPlanId]![rsLog.bookId - 1] = bookProgress;

    if (nextChapter != null && nextChapter.bookId != bookId) {
      //load the progress of the new book

      final oldBookId = bookId;

      bookId = nextChapter.bookId;
      bookProgress = _booksProgress[readingPlanId]![bookId - 1];

      if (bookProgress.id == null) {
        bookProgress = RsBookProgress(
          bookId: bookId,
          chapter: nextChapter.chapter,
          verse: 1,
          chaptersRead: 0,
          versesRead: 0,
          updatedAt: DateTime.now(),
          readingPlanId: readingPlanId,
        );

        bookProgress = await _rsdbManager.insertBookProgresss(bookProgress);
      } else {
        bookProgress = bookProgress.copyWith(updatedAt: DateTime.now());
        await _rsdbManager.updateBookProgress(bookProgress);
      }
      _booksProgress[readingPlanId]![bookId - 1] = bookProgress;

      bookCompletedNotifier.value = (oldBookId, bookId);
    } else if (chapterCompleted) {
      bookCompletedNotifier.value = (bookId, 0);
    }

    //todo to be optimized
    await _loadMonthProgress(readingPlanId);

    for (VoidCallback x in _booksProgressListeners) {
      x.call();
    }

    return nextChapter;
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
    DateTime startOfMonth = DateTime(month.year, month.month, 1);
    DateTime endOfMonth = DateTime(month.year, month.month + 1, 0);

    List<RsStats> dailyStatsForCurrentMonth = await _rsdbManager
        .getRsStatsForType(
          RsStatsType.daily,
          startOfMonth,
          endOfMonth,
          readingPlanId,
        );

    final List<DayProgress> monthData = [];

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
    _bookVerseReadCount.clear();
    //_booksProgress = null;
    _latestBookProgress = null;
    _monthProgress.clear();

    //await loadBooksProgress();
    readingModeNotifier.value = _rsDailyLog != null;
    //getLatestBookProgress();
  }

  bool isSameWeek(DateTime a, DateTime b) {
    final aStartOfWeek = a.subtract(Duration(days: a.weekday - 1));
    final bStartOfWeek = b.subtract(Duration(days: b.weekday - 1));

    return aStartOfWeek.year == bStartOfWeek.year &&
        aStartOfWeek.month == bStartOfWeek.month &&
        aStartOfWeek.day == bStartOfWeek.day;
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
