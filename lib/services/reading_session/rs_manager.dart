import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:gbt/common/bible_navigation.dart';
import 'package:gbt/services/reading_session/rs_database.dart';
import 'package:gbt/services/reading_session/rs_model.dart';
import 'package:gbt/services/service_locator.dart';
import 'package:gbt/services/settings/user_settings.dart';

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
    final now = DateTime.now();
    _viewingMonth = DateTime(now.year, now.month, 1);
    _viewingWeekStart = _startOfWeek(now);
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
  late DateTime _viewingMonth;
  late DateTime _viewingWeekStart;

  late List<RsBookProgress> _emptyBooksProgress;

  List<RsBookProgress> get booksProgress =>
      _booksProgress ?? _emptyBooksProgress;
  RsBookProgress? get latestBookProgress => _latestBookProgress;
  List<DayProgress> get weekProgress => _weekProgress;
  List<DayProgress> get monthProgress => _monthProgress;
  DateTime get viewingMonth => _viewingMonth;
  DateTime get viewingWeekStart => _viewingWeekStart;
  bool get canGoToNextMonth {
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month, 1);
    return _viewingMonth.isBefore(currentMonth);
  }

  bool get canGoToNextWeek {
    final now = DateTime.now();
    return _viewingWeekStart.isBefore(_startOfWeek(now));
  }

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
    await _reloadFromDatabase();
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

  DailyGoal? getDailyGoal() {
    if (_dailyGoal != null) {
      return _dailyGoal!;
    }

    String? settingVal = _settings.dailyGoal;

    if (settingVal == null) {
      return null;
    }

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
    if (_rsDailyLog != null || getDailyGoal() == null) {
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

    displayGoalProgresNotifier.value = true;
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
    DailyGoal? dailyGoal = getDailyGoal();

    if (dailyGoal == null) {
      return;
    }

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
      current = await getVersesReadForChapter(bookId, chapter);
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
      await _updateBookProgress(rsLog, true);
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
    if (_rsDailyLog == null || _bookVerseReadCount.isEmpty) {
      return;
    }

    var rsDailyLog = _rsDailyLog!;
    final key = bookId * 1000 + chapter;

    Map<int, int>? verseReadCount = _bookVerseReadCount[key];
    //load cache if not already loaded
    verseReadCount ??= await getVersesReadForChapter(bookId, chapter);

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
      await _updateBookProgress(verseLogs.first, false);
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
    await _updateStatisticsBy(dailyLog, RsStatsType.daily, dailyLog.rsDate);
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
    final dailyGoal = getDailyGoal();

    if (dailyGoal == null) {
      return;
    }

    RsStats? stats = await _rsdbManager.findStatsByTypeAndDate(type, rsDate);

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
            versesRead: 0,
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
          versesRead: 0,
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
          versesRead: 0,
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

    int chapterVersesRead = await _rsdbManager.countVersesReadForChapter(
      rsLog.bookId,
      rsLog.chapter,
    );

    var chaptersRead = bookProgress.chaptersRead;
    var versesRead = bookProgress.versesRead;

    versesRead += 1;

    ChapterIdentifier? nextChapter;

    //if this verse is read and chapter is completed, increase the number of read chapters
    if (markVerseAsRead && totalChapterVerses == chapterVersesRead) {
      chaptersRead += 1;
    }
    //if this verse is unread, and chapter was already completed, reduce the number of read chapters
    else if (!markVerseAsRead && totalChapterVerses == chapterVersesRead - 1) {
      chaptersRead -= 1;
    }

    //if with reading progress, the last verse is completed, move to next chapter
    if (markVerseAsRead && verse > totalChapterVerses) {
      nextChapter = BibleNavigation.getNextChapter(
        ChapterIdentifier(bookId, chapter),
      );
    }
    //or move backward
    else if (!markVerseAsRead && verse == 1) {
      nextChapter = BibleNavigation.getPreviousChapter(
        ChapterIdentifier(bookId, chapter),
      );
    }

    //progress is within the same book, update the values
    if (nextChapter != null && nextChapter.bookId == bookId) {
      chapter = nextChapter.chapter;
      //start with the next unread verse of the chapter
      final versesReadForChapter = await getVersesReadForChapter(
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

    _booksProgress![rsLog.bookId - 1] = bookProgress;

    if (nextChapter != null && nextChapter.bookId != bookId) {
      //load the progress of the new book

      bookId = nextChapter.bookId;
      bookProgress = _booksProgress![bookId - 1];

      if (bookProgress.id == null) {
        bookProgress = RsBookProgress(
          bookId: bookId,
          chapter: nextChapter.chapter,
          verse: 1,
          chaptersRead: 0,
          versesRead: 0,
          updatedAt: DateTime.now(),
        );

        bookProgress = await _rsdbManager.insertBookProgresss(bookProgress);
      } else {
        bookProgress = bookProgress.copyWith(updatedAt: DateTime.now());
        await _rsdbManager.updateBookProgress(bookProgress);
      }
      _booksProgress![bookId - 1] = bookProgress;
    }

    //todo to be optimized
    await _reloadGoalProgressViews();

    for (VoidCallback x in _booksProgressListeners) {
      x.call();
    }
  }

  static DateTime _startOfWeek(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    return normalized.subtract(Duration(days: normalized.weekday - 1));
  }

  Future<void> loadMonthProgress(DateTime month) async {
    final startOfMonth = DateTime(month.year, month.month, 1);
    final endOfMonth = DateTime(month.year, month.month + 1, 0);

    final dailyStatsForMonth = await _rsdbManager.getRsStatsForType(
      RsStatsType.daily,
      startOfMonth,
      endOfMonth,
    );

    final statsByDate = {
      for (final stats in dailyStatsForMonth)
        DateTime(
          stats.statsDate.year,
          stats.statsDate.month,
          stats.statsDate.day,
        ): stats,
    };

    final List<DayProgress> monthData = [];

    for (int day = 1; day <= endOfMonth.day; day++) {
      final d = DateTime(month.year, month.month, day);
      final stats = statsByDate[d];

      if (stats != null) {
        monthData.add(
          DayProgress(
            d,
            stats.rsSeconds ~/ 60,
            stats.rsVerses,
            stats.goalReached,
          ),
        );
      } else {
        monthData.add(DayProgress.empty(d));
      }
    }

    _monthProgress = monthData;
  }

  Future<void> loadWeekProgress(DateTime weekStart) async {
    final normalizedStart = DateTime(
      weekStart.year,
      weekStart.month,
      weekStart.day,
    );
    final weekEnd = normalizedStart.add(const Duration(days: 6));

    final dailyStatsForWeek = await _rsdbManager.getRsStatsForType(
      RsStatsType.daily,
      normalizedStart,
      weekEnd,
    );

    final statsByDate = {
      for (final stats in dailyStatsForWeek)
        DateTime(
          stats.statsDate.year,
          stats.statsDate.month,
          stats.statsDate.day,
        ): stats,
    };

    final List<DayProgress> weekData = [];

    for (int i = 0; i < 7; i++) {
      final d = normalizedStart.add(Duration(days: i));
      final stats = statsByDate[DateTime(d.year, d.month, d.day)];

      if (stats != null) {
        weekData.add(
          DayProgress(
            d,
            stats.rsSeconds ~/ 60,
            stats.rsVerses,
            stats.goalReached,
          ),
        );
      } else {
        weekData.add(DayProgress.empty(d));
      }
    }

    _weekProgress = weekData;
  }

  Future<void> goToPreviousMonth() async {
    _viewingMonth = DateTime(_viewingMonth.year, _viewingMonth.month - 1, 1);
    await loadMonthProgress(_viewingMonth);
    _notifyStatsListeners();
  }

  Future<void> goToNextMonth() async {
    if (!canGoToNextMonth) {
      return;
    }
    _viewingMonth = DateTime(_viewingMonth.year, _viewingMonth.month + 1, 1);
    await loadMonthProgress(_viewingMonth);
    _notifyStatsListeners();
  }

  Future<void> goToPreviousWeek() async {
    _viewingWeekStart = _viewingWeekStart.subtract(const Duration(days: 7));
    await loadWeekProgress(_viewingWeekStart);
    _notifyStatsListeners();
  }

  Future<void> goToNextWeek() async {
    if (!canGoToNextWeek) {
      return;
    }
    _viewingWeekStart = _viewingWeekStart.add(const Duration(days: 7));
    await loadWeekProgress(_viewingWeekStart);
    _notifyStatsListeners();
  }

  Future<void> _reloadGoalProgressViews() async {
    await loadMonthProgress(_viewingMonth);
    await loadWeekProgress(_viewingWeekStart);
    _notifyStatsListeners();
  }

  void _notifyStatsListeners() {
    for (final listener in _statsListeners) {
      listener.call();
    }
  }

  Future<void> logManualDayEntry(
    DateTime date, {
    required int minutes,
    required int verses,
  }) async {
    if (minutes == 0 && verses == 0) {
      return;
    }

    final normalized = DateTime(date.year, date.month, date.day);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (normalized.isAfter(today)) {
      return;
    }

    final startTime = normalized.add(const Duration(hours: 12));
    final endTime = startTime.add(Duration(minutes: minutes));

    await _rsdbManager.insertDailyLog(
      RsDailyLog(
        rsDate: normalized,
        startTime: startTime,
        endTime: endTime,
        verses: verses,
      ),
    );

    await rebuildDailyStatsForDate(normalized);
    await _reloadGoalProgressViews();
  }

  Future<void> rebuildDailyStatsForDate(DateTime date) async {
    final normalized = DateTime(date.year, date.month, date.day);
    final dailyGoal = getDailyGoal();

    if (dailyGoal == null) {
      return;
    }

    final totalSeconds = await _rsdbManager.getTotalSecondsReadToday(normalized);
    final totalVerses = await _rsdbManager.getVersesReadToday(normalized);
    final goalReached =
        (dailyGoal.type == GoalType.minutes &&
            totalSeconds >= dailyGoal.value * 60) ||
        (dailyGoal.type == GoalType.verses && totalVerses >= dailyGoal.value);

    final existing = await _rsdbManager.findStatsByTypeAndDate(
      RsStatsType.daily,
      normalized,
    );

    if (totalSeconds == 0 && totalVerses == 0) {
      if (existing?.id != null) {
        await _rsdbManager.deleteStats(existing!.id!);
      }
    } else if (existing == null) {
      await _rsdbManager.insertStats(
        RsStats(
          type: RsStatsType.daily,
          statsDate: normalized,
          rsSeconds: totalSeconds,
          rsVerses: totalVerses,
          goalReached: goalReached,
        ),
      );
    } else {
      await _rsdbManager.updateStats(
        existing.copyWith(
          rsSeconds: totalSeconds,
          rsVerses: totalVerses,
          goalReached: goalReached,
        ),
      );
    }

    await _rebuildMonthlyStatsForMonth(normalized);
  }

  Future<void> _rebuildMonthlyStatsForMonth(DateTime date) async {
    final dailyGoal = getDailyGoal();

    if (dailyGoal == null) {
      return;
    }

    final startOfMonth = DateTime(date.year, date.month, 1);
    final endOfMonth = DateTime(date.year, date.month + 1, 0);
    final dailyStats = await _rsdbManager.getRsStatsForType(
      RsStatsType.daily,
      startOfMonth,
      endOfMonth,
    );

    var totalSeconds = 0;
    var totalVerses = 0;
    for (final stat in dailyStats) {
      totalSeconds += stat.rsSeconds;
      totalVerses += stat.rsVerses;
    }

    final existing = await _rsdbManager.findStatsByTypeAndDate(
      RsStatsType.monthly,
      endOfMonth,
    );

    if (totalSeconds == 0 && totalVerses == 0) {
      if (existing?.id != null) {
        await _rsdbManager.deleteStats(existing!.id!);
      }
      return;
    }

    final goalReached =
        (dailyGoal.type == GoalType.minutes &&
            totalSeconds >= dailyGoal.value * 60) ||
        (dailyGoal.type == GoalType.verses && totalVerses >= dailyGoal.value);

    if (existing == null) {
      await _rsdbManager.insertStats(
        RsStats(
          type: RsStatsType.monthly,
          statsDate: endOfMonth,
          rsSeconds: totalSeconds,
          rsVerses: totalVerses,
          goalReached: goalReached,
        ),
      );
    } else {
      await _rsdbManager.updateStats(
        existing.copyWith(
          rsSeconds: totalSeconds,
          rsVerses: totalVerses,
          goalReached: goalReached,
        ),
      );
    }
  }

  Future<void> _reloadFromDatabase() async {
    _bookVerseReadCount.clear();
    _booksProgress = null;
    _latestBookProgress = null;
    _weekProgress = [];
    _monthProgress = [];

    await loadBooksProgress();
    readingModeNotifier.value = _rsDailyLog != null;
    getLatestBookProgress();
    await _reloadGoalProgressViews();
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
