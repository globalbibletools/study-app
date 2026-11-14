import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:gbt/common/reference.dart';
import 'package:gbt/services/reading_session/reading_plan_config.dart';
import 'package:gbt/services/reading_session/reading_session_service.dart';
import 'package:gbt/services/logging/log.dart' as log;
import 'package:gbt/services/reading_session/rs_model.dart';
import 'package:gbt/services/service_locator.dart';

class ReadingSessionUiState {
  const ReadingSessionUiState({
    required this.sessionId,
    required this.config,
    required this.bookIds,
    required this.versesToday,
    required this.goalAlreadyReachedToday,
    required this.resumePosition,
    required this.sessionStartTime,
  });

  final int sessionId;
  final ReadingPlanConfig config;
  final Set<int> bookIds;
  final int versesToday;
  final bool goalAlreadyReachedToday;
  final Reference? resumePosition;
  final DateTime sessionStartTime;

  static const _undefined = Object();

  ReadingSessionUiState copyWith({
    int? sessionId,
    int? versesToday,
    bool? goalAlreadyReachedToday,
    Object? resumePosition = _undefined,
    DateTime? sessionStartTime,
  }) {
    return ReadingSessionUiState(
      sessionId: sessionId ?? this.sessionId,
      config: config,
      bookIds: bookIds,
      versesToday: versesToday ?? this.versesToday,
      goalAlreadyReachedToday:
          goalAlreadyReachedToday ?? this.goalAlreadyReachedToday,
      resumePosition: resumePosition == _undefined
          ? this.resumePosition
          : resumePosition as Reference?,
      sessionStartTime: sessionStartTime ?? this.sessionStartTime,
    );
  }
}

class ReadingSessionViewModel with WidgetsBindingObserver {
  ReadingSessionViewModel() : this.withService(getIt<ReadingSessionService>());

  ReadingSessionViewModel.withService(this._service) {
    WidgetsBinding.instance.addObserver(this);
  }

  static Duration heartbeatInterval = const Duration(seconds: 60);

  final ReadingSessionService _service;

  final sessionNotifier = ValueNotifier<ReadingSessionUiState?>(null);
  final secondsTodayNotifier = ValueNotifier<int>(0);
  final sessionSecondsNotifier = ValueNotifier<int>(0);
  final goalReachedNotifier = ValueNotifier<bool>(false);
  final bookCompletedNotifier = ValueNotifier<BookCompletedEvent?>(null);
  final hudVisible = ValueNotifier<bool>(false);

  ReadingSessionUiState? get session => sessionNotifier.value;
  ReadingPlanConfig? get planConfig => session?.config;
  Set<int>? get readingPlanBooks => session?.bookIds;
  Reference? get nextResumePosition => session?.resumePosition;
  bool get hasActiveSession => session != null;
  int? get sessionId => session?.sessionId;

  bool _requestLocked = false;
  bool _disposed = false;
  bool _goalLatch = false;
  bool _timerPaused = false;

  DateTime? _sessionDay;
  int _sessionReadSeconds = 0;
  DateTime _lastTickAt = DateTime.now();
  DateTime _lastFlushAt = DateTime.now();

  Timer? _tickTimer;

  Future<void> startSession(int planId) async {
    if (!_tryLockRequest('start session for plan $planId')) return;

    try {
      if (hasActiveSession) {
        await _endActiveSession();
        if (_disposed) return;
      }

      final snapshot = await _service.startSession(planId);
      if (_disposed) return;

      if (snapshot == null) {
        throw StateError('Reading plan not found: $planId');
      }

      final progress = snapshot.progress;
      final config = snapshot.config;

      _sessionDay = progress.sessionDay;
      _sessionReadSeconds = progress.sessionReadSeconds;
      _lastTickAt = progress.asOf;
      _lastFlushAt = progress.asOf;
      _goalLatch = progress.goalAlreadyReachedToday;

      sessionNotifier.value = ReadingSessionUiState(
        sessionId: progress.sessionId,
        config: config,
        bookIds: config.bookIds,
        versesToday: progress.versesToday,
        goalAlreadyReachedToday: progress.goalAlreadyReachedToday,
        resumePosition: null,
        sessionStartTime: progress.sessionStartTime,
      );
      secondsTodayNotifier.value = progress.secondsToday;
      sessionSecondsNotifier.value = progress.sessionReadSeconds;
      goalReachedNotifier.value = false;
      bookCompletedNotifier.value = null;
      hudVisible.value = true;

      _scheduleNextTick();
    } finally {
      _unlockRequest();
    }
  }

  Future<void> endSession() async {
    if (!_tryLockRequest('end session')) return;

    try {
      await _endActiveSession();
    } finally {
      _unlockRequest();
    }
  }

  /// Finalizes the active session. The caller must hold the request lock.
  Future<void> _endActiveSession() async {
    _tickTimer?.cancel();
    _tickTimer = null;

    final now = DateTime.now();
    await _rolloverIfNeeded(now, timerActive: !_timerPaused);
    if (!_timerPaused) {
      _accumulateElapsed(now);
    }

    final sessionId = session?.sessionId;
    if (sessionId != null) {
      await _service.endSession(
        sessionId,
        readSeconds: _sessionReadSeconds,
        at: now,
      );
      if (_disposed) return;
    }

    _clearPresentation();
  }

  Future<Map<int, VerseReadState>?> setVerseRead(
    VerseReadOptions options,
  ) async {
    if (!_tryLockRequest(
      'set verse ${options.bookId}:${options.chapter}:${options.verse} '
      'read state to ${options.read}',
    )) {
      return null;
    }

    try {
      final now = DateTime.now();
      await _rolloverIfNeeded(now, timerActive: !_timerPaused);
      if (!_timerPaused) {
        _accumulateElapsed(now);
      }

      final sessionId = session?.sessionId;
      if (sessionId == null) return null;

      final result = await _service.setVerseRead(
        sessionId,
        options,
        readSeconds: _sessionReadSeconds,
        at: now,
      );
      if (_disposed || result == null) return null;

      _applyProgress(result.progress);

      final event = result.bookCompleted;
      if (event != null) {
        final current = session;
        if (current != null) {
          sessionNotifier.value = current.copyWith(
            resumePosition: event.resumePosition,
          );
        }
        bookCompletedNotifier.value = event;
      }

      _checkGoalReached();
      return result.verseReadStates;
    } finally {
      _unlockRequest();
    }
  }

  Future<Map<int, VerseReadState>> getVerseReadStates(
    int bookId,
    int chapter,
  ) async {
    final sessionId = session?.sessionId;
    if (sessionId == null) return const {};
    return _service.getVerseReadStates(sessionId, bookId, chapter);
  }

  void toggleDisplayGoalProgress() {
    hudVisible.value = !hudVisible.value;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        unawaited(resumeTimer());
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        unawaited(pauseTimer());
        break;
      case AppLifecycleState.inactive:
        break;
    }
  }

  /// Stops accumulating read time while the app is backgrounded. The current
  /// elapsed time is flushed to the database so a kill cannot lose it.
  Future<void> pauseTimer() async {
    if (_disposed || _timerPaused) return;

    final now = DateTime.now();
    _timerPaused = true;
    _tickTimer?.cancel();
    _tickTimer = null;

    if (!hasActiveSession) return;

    try {
      await _flush(at: now, timerActive: true);
    } catch (error, stackTrace) {
      log.error(
        'Failed to flush reading session while pausing',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Resumes accumulating read time without counting the time spent
  /// backgrounded. Rolls the session forward if the day changed while the
  /// timer was paused.
  Future<void> resumeTimer() async {
    if (_disposed || !_timerPaused) return;

    final now = DateTime.now();
    try {
      await _rolloverIfNeeded(now, timerActive: false);
    } catch (error, stackTrace) {
      log.error(
        'Failed to roll reading session over on resume',
        error: error,
        stackTrace: stackTrace,
      );
    }
    if (_disposed) return;

    _timerPaused = false;
    _lastTickAt = DateTime.now();
    _lastFlushAt = DateTime.now();
    _scheduleNextTick();
  }

  Future<void> resetForDatabaseRestore() async {
    if (!_tryLockRequest('reset session for database restore')) return;

    try {
      _tickTimer?.cancel();
      _tickTimer = null;

      _clearPresentation();
    } finally {
      _unlockRequest();
    }
  }

  bool _tryLockRequest(String request) {
    if (_disposed) {
      log.info('Ignoring $request because the view model was disposed');
      return false;
    }
    if (_requestLocked) {
      log.info('Ignoring $request because another session request is pending');
      return false;
    }
    _requestLocked = true;
    return true;
  }

  void _unlockRequest() {
    _requestLocked = false;
  }

  void _applyProgress(SessionProgress progress) {
    final previousDay = _sessionDay;
    final dayChanged =
        previousDay != null && !_sameDay(previousDay, progress.sessionDay);
    final currentSessionId = session?.sessionId;
    final sessionChanged =
        currentSessionId != null && currentSessionId != progress.sessionId;

    _sessionDay = progress.sessionDay;
    if (dayChanged) {
      _goalLatch = progress.goalAlreadyReachedToday;
    }

    if (sessionChanged || dayChanged) {
      // A day/session rollover starts a fresh accumulated duration.
      _sessionReadSeconds = progress.sessionReadSeconds;
      _lastTickAt = progress.asOf;
      secondsTodayNotifier.value = progress.secondsToday;
    } else {
      if (progress.sessionReadSeconds > _sessionReadSeconds) {
        _sessionReadSeconds = progress.sessionReadSeconds;
      }
      if (progress.secondsToday > secondsTodayNotifier.value) {
        secondsTodayNotifier.value = progress.secondsToday;
      }
    }
    _lastFlushAt = progress.asOf;

    final current = session;
    if (current != null) {
      final updated = current.copyWith(
        sessionId: progress.sessionId,
        versesToday: progress.versesToday,
        goalAlreadyReachedToday: progress.goalAlreadyReachedToday,
        sessionStartTime: progress.sessionStartTime,
      );
      if (updated.sessionId != current.sessionId ||
          updated.versesToday != current.versesToday ||
          updated.goalAlreadyReachedToday != current.goalAlreadyReachedToday ||
          updated.sessionStartTime != current.sessionStartTime) {
        sessionNotifier.value = updated;
      }
    }

    sessionSecondsNotifier.value = _sessionReadSeconds;
  }

  void _checkGoalReached() {
    final current = session;
    if (current == null) return;

    final dailyGoal = current.config.dailyGoal;
    final reached = dailyGoal.type == GoalType.verses
        ? current.versesToday >= dailyGoal.value
        : secondsTodayNotifier.value >= 60 * dailyGoal.value;

    if (!reached || _goalLatch) return;

    _goalLatch = true;
    goalReachedNotifier.value = true;
  }

  void _onTick() {
    if (_disposed || _timerPaused || !hasActiveSession) return;

    final now = DateTime.now();
    final dayChanged = _sessionDay != null && !_sameDay(_sessionDay!, now);

    if (dayChanged) {
      if (!_tryLockRequest('day rollover')) {
        _scheduleNextTick();
        return;
      }

      unawaited(_rolloverAtMidnight(now));
      return;
    }

    _accumulateElapsed(now);
    _checkGoalReached();

    if (now.difference(_lastFlushAt) >= heartbeatInterval) {
      unawaited(_flush(at: now));
    }

    _scheduleNextTick();
  }

  Future<void> _rolloverAtMidnight(DateTime now) async {
    try {
      await _rolloverIfNeeded(now, timerActive: true);
      if (_disposed) return;

      _checkGoalReached();
    } catch (error, stackTrace) {
      log.error(
        'Failed to roll reading session over at midnight',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _unlockRequest();
      _scheduleNextTick();
    }
  }

  Future<void> _flush({DateTime? at, bool timerActive = true}) async {
    if (!_tryLockRequest('heartbeat')) return;

    try {
      final now = at ?? DateTime.now();
      await _rolloverIfNeeded(now, timerActive: timerActive);
      if (timerActive) {
        _accumulateElapsed(now);
      }

      final sessionId = session?.sessionId;
      if (sessionId == null) return;

      final progress = await _service.heartbeat(
        sessionId,
        readSeconds: _sessionReadSeconds,
        at: now,
      );
      if (_disposed || progress == null) return;

      _applyProgress(progress);
      _checkGoalReached();
    } finally {
      _unlockRequest();
    }
  }

  void _scheduleNextTick() {
    _tickTimer?.cancel();
    if (_disposed || _timerPaused || !hasActiveSession) return;

    final now = DateTime.now();
    final delay = Duration(
      milliseconds: now.millisecond == 0 ? 1000 : 1000 - now.millisecond,
    );
    _tickTimer = Timer(delay, _onTick);
  }

  void _clearPresentation() {
    _tickTimer?.cancel();
    _tickTimer = null;

    _sessionDay = null;
    _goalLatch = false;
    _sessionReadSeconds = 0;
    _lastTickAt = DateTime.now();
    _lastFlushAt = DateTime.now();

    sessionNotifier.value = null;
    secondsTodayNotifier.value = 0;
    sessionSecondsNotifier.value = 0;
    goalReachedNotifier.value = false;
    bookCompletedNotifier.value = null;
    hudVisible.value = false;
  }

  void _accumulateElapsed(DateTime now) {
    final elapsed = now.difference(_lastTickAt).inSeconds;
    if (elapsed <= 0) return;

    _sessionReadSeconds += elapsed;
    secondsTodayNotifier.value += elapsed;
    sessionSecondsNotifier.value = _sessionReadSeconds;
    _lastTickAt = now;
  }

  Future<void> _rolloverIfNeeded(
    DateTime now, {
    required bool timerActive,
  }) async {
    final sessionId = session?.sessionId;
    final sessionDay = _sessionDay;
    if (sessionId == null || sessionDay == null || _sameDay(sessionDay, now)) {
      return;
    }

    var oldDayExtra = 0;
    var newDayExtra = 0;
    if (timerActive) {
      final elapsed = math.max(0, now.difference(_lastTickAt).inSeconds);
      final startOfToday = _day(now);
      oldDayExtra = math.min(
        math.max(0, startOfToday.difference(_lastTickAt).inSeconds),
        elapsed,
      );
      newDayExtra = elapsed - oldDayExtra;
    }

    final progress = await _service.rolloverSession(
      sessionId,
      at: now,
      oldReadSeconds: _sessionReadSeconds + oldDayExtra,
      newReadSeconds: newDayExtra,
    );
    if (_disposed || progress == null) return;

    _applyProgress(progress);
  }

  static DateTime _day(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _tickTimer?.cancel();
    _tickTimer = null;
    sessionNotifier.dispose();
    secondsTodayNotifier.dispose();
    sessionSecondsNotifier.dispose();
    goalReachedNotifier.dispose();
    bookCompletedNotifier.dispose();
    hudVisible.dispose();
  }

  static bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
