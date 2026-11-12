import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:gbt/common/reference.dart';
import 'package:gbt/services/reading_session/rs_database.dart';
import 'package:gbt/services/reading_session/rs_model.dart';
import 'package:gbt/services/service_locator.dart';

export 'package:gbt/services/reading_session/rs_model.dart'
    show DailyGoal, GoalType, ProgressType;

class ReadingSessionService {
  final _rsdbManager = getIt<ReadingSessionDatabase>();

  static int maximumReadCount = 10;
  // Heartbeat time to flush the current timestamp to the session record
  // Prevents sessions from being ended without recording an end time if the app is killed.
  static int idleFlushTickCount = 60;

  ReadingSessionService();

  DateTime? get currentSessionStartTime => _rsSession?.startTime;

  ReadingPlanDetails? _readingPlan;
  RsSession? _rsSession;
  Reference? _nextResumePosition;
  Timer? _timer;
  bool _goalAlreadyReached = false;
  int _idleTicks = 0;
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
  Reference? get nextResumePosition => _nextResumePosition;

  void toggleDisplayGoalProgress() {
    displayGoalProgresNotifier.value = !displayGoalProgresNotifier.value;
  }

  Future<void> startReadingSession(ReadingPlanDetails readingPlan) async {
    _nextResumePosition = null;
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
    var rsSession = RsSession(
      rsDate: today,
      startTime: now,
      verses: 0,
      readingPlanId: readingPlan.readingPlan.id!,
    );

    rsSession = await _rsdbManager.insertSession(rsSession);

    _rsSession = rsSession;

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
      _idleTicks++;
      if (_idleTicks >= idleFlushTickCount) {
        _idleTicks = 0;
        _heartbeatSession();
      }
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

    var currentSession = await _getTodaysSession();

    currentSession = currentSession.copyWith(endTime: now);

    await _rsdbManager.updateSession(currentSession);
    await _rsdbManager.upsertDaySummary(
      currentSession.readingPlanId,
      currentSession.rsDate,
    );

    _rsSession = null;
    _readingPlan = null;
    _books = null;
    _nextResumePosition = null;
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
    versesRead = await _rsdbManager.getVerseReadCountsForChapter(
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
        _rsSession == null) {
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

    var rsSession = await _getTodaysSession();

    final now = DateTime.now();

    final rsLog = RsLog(
      sessionId: rsSession.id!,
      bookId: bookId,
      chapter: chapter,
      verse: verse,
      dateTime: now,
      readingPlanId: rsSession.readingPlanId,
    );

    rsSession = rsSession.copyWith(verses: rsSession.verses + 1, endTime: now);

    await _rsdbManager.insertLog(rsLog);

    await _rsdbManager.updateSession(rsSession);

    await _rsdbManager.markVerseRead(
      rsSession.readingPlanId,
      bookId,
      chapter,
      verse,
    );

    //book progress is only increased when we read the verse for the first time
    if (existingCount == 0) {
      await _recomputeBookProgress(
        rsSession.readingPlanId,
        Reference(bookId: bookId, chapter: chapter, verse: verse),
      );
    }

    _rsSession = rsSession;

    // Actively marking resets the idle flush counter.
    _idleTicks = 0;

    await _rsdbManager.upsertDaySummary(
      rsSession.readingPlanId,
      rsSession.rsDate,
    );

    totalVersesReadPerDay.value = totalVersesReadPerDay.value + 1;
    checkGoalReached(false);
  }

  Future<void> resetReadingCountForVerse(
    int bookId,
    int chapter,
    int verse,
  ) async {
    if (_readingPlan == null ||
        _rsSession == null ||
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
        .getRsLogForSessionAndVerse(_rsSession!.id!, bookId, chapter, verse);
    final todaySessionCount = todayVerseLogs.length;

    await _rsdbManager.deleteRsLogsForVerse(
      readingPlanId,
      bookId,
      chapter,
      verse,
    );

    await _rsdbManager.resetVerseState(readingPlanId, bookId, chapter, verse);

    verseReadCount[verse] = 0;

    if (todaySessionCount > 0) {
      _rsSession = _rsSession!.copyWith(
        verses: math.max(0, _rsSession!.verses - todaySessionCount),
        endTime: DateTime.now(),
      );
      totalVersesReadPerDay.value = math.max(
        0,
        totalVersesReadPerDay.value - todaySessionCount,
      );
      await _rsdbManager.updateSession(_rsSession!);
      await _rsdbManager.upsertDaySummary(
        _rsSession!.readingPlanId,
        _rsSession!.rsDate,
      );
    }
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
    _rsSession = null;
    _readingPlan = null;
    _books = null;
    _nextResumePosition = null;
    readingModeNotifier.value = false;
    displayGoalProgresNotifier.value = false;
    totalVersesReadPerDay.value = 0;
    totalSecondsReadPerDay.value = 0;
    totalSecondsReadPerSession.value = 0;
    goalReachedNotifier.value = false;
    bookCompletedNotifier.value = (0, 0);
    _goalAlreadyReached = false;
    _idleTicks = 0;
  }

  ///if the session started in a older day than today, then log it as a distinct entry
  ///this is mainly for sessions that starts before 12AM and ends after 12AM
  Future<RsSession> _getTodaysSession() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    var currentSession = _rsSession!;

    while (today != currentSession.rsDate) {
      final nextDay = DateTime(
        currentSession.rsDate.year,
        currentSession.rsDate.month,
        currentSession.rsDate.day + 1,
      );
      final endTime = nextDay.add(const Duration(seconds: -1));

      final rsSession = currentSession.copyWith(endTime: endTime);

      await _rsdbManager.updateSession(rsSession);

      await _rsdbManager.upsertDaySummary(
        rsSession.readingPlanId,
        rsSession.rsDate,
        preserveStoredGoalSnapshot: true,
      );

      currentSession = RsSession(
        rsDate: nextDay,
        startTime: nextDay,
        verses: 0,
        readingPlanId: _rsSession!.readingPlanId,
      );

      currentSession = await _rsdbManager.insertSession(currentSession);
    }

    return currentSession;
  }

  Future<void> _heartbeatSession() async {
    if (_readingPlan == null || _rsSession == null) return;

    final now = DateTime.now();
    var session = await _getTodaysSession();
    session = session.copyWith(endTime: now);

    await _rsdbManager.updateSession(session);
    _rsSession = session;

    await _rsdbManager.upsertDaySummary(session.readingPlanId, session.rsDate);
  }

  Future<void> _recomputeBookProgress(
    int readingPlanId,
    Reference currentReference,
  ) async {
    if (!await _rsdbManager.isBookComplete(
      readingPlanId,
      currentReference.bookId,
    )) {
      return;
    }

    final nextResumePosition = await _rsdbManager.getResumeReference(
      readingPlanId,
      after: currentReference,
    );
    _nextResumePosition = nextResumePosition;

    bookCompletedNotifier.value = (
      currentReference.bookId,
      nextResumePosition?.bookId ?? 0,
    );
  }

  Future<void> _reloadFromDatabase() async {
    _bookVerseReadCount.clear();
    readingModeNotifier.value = _rsSession != null;
  }

  void dispose() {
    endReadingSession();
    _rsdbManager.dispose();
    _timer?.cancel();
  }
}
