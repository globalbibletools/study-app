import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:gbt/common/reference.dart';
import 'package:gbt/reading_plan/reading_plan_read_models.dart';
import 'package:gbt/reading_plan/reading_session_service.dart';
import 'package:gbt/reading_plan/rs_database.dart';
import 'package:gbt/services/logging/log.dart' as log;
import 'package:gbt/reading_plan/rs_model.dart';
import 'package:gbt/services/service_locator.dart';
import 'package:gbt/ui/home/common/navigation_view_model.dart';

class ReadingSessionUiState {
  const ReadingSessionUiState({required this.config, required this.session});

  final ReadingPlanConfig config;
  final ReadingSessionRuntime session;
}

class ReadingSessionViewModel with WidgetsBindingObserver {
  ReadingSessionViewModel()
    : this.withDependencies(
        service: getIt<ReadingSessionService>(),
        readModels: getIt<ReadingSessionDatabase>().readModels,
        navigationViewModel: getIt<NavigationViewModel>(),
      );

  ReadingSessionViewModel.withDependencies({
    required ReadingSessionService service,
    required ReadingPlanReadModels readModels,
    required NavigationViewModel navigationViewModel,
  }) : _service = service,
       _readModels = readModels,
       _navigationViewModel = navigationViewModel {
    WidgetsBinding.instance.addObserver(this);
  }

  static Duration heartbeatInterval = const Duration(seconds: 60);

  final ReadingSessionService _service;
  final ReadingPlanReadModels _readModels;
  final NavigationViewModel _navigationViewModel;

  final sessionNotifier = ValueNotifier<ReadingSessionUiState?>(null);
  final secondsTodayNotifier = ValueNotifier<int>(0);
  final sessionSecondsNotifier = ValueNotifier<int>(0);
  final goalReachedNotifier = ValueNotifier<bool>(false);
  final bookCompletedNotifier = ValueNotifier<BookCompletedEvent?>(null);
  final hudVisible = ValueNotifier<bool>(false);

  ReadingSessionUiState? get session => sessionNotifier.value;
  ReadingPlanConfig? get planConfig => session?.config;
  Set<int>? get readingPlanBooks => session?.config.bookIds.toSet();
  Reference? get nextResumePosition => _nextResumePosition;
  bool get hasActiveSession => session != null;
  int? get sessionId => session?.session.sessionId;

  Reference? _nextResumePosition;

  bool _requestLocked = false;
  bool _disposed = false;
  bool _goalLatch = false;
  bool _timerPaused = false;

  DateTime? _sessionDay;
  int _sessionReadMilliseconds = 0;
  int _dayReadMilliseconds = 0;
  DateTime _lastTickAt = DateTime.now();
  DateTime _lastFlushAt = DateTime.now();

  int get _sessionReadSeconds => _sessionReadMilliseconds ~/ 1000;

  Timer? _tickTimer;

  Future<void> startSession(int planId) async {
    if (!_tryLockRequest('start session for plan $planId')) return;

    try {
      if (hasActiveSession) {
        await _endActiveSession();
        if (_disposed) return;
      }

      final sessionId = await _service.startSession(planId);
      if (_disposed) return;

      if (sessionId == null) {
        throw StateError('Reading plan not found: $planId');
      }

      final summary = await _readModels.getPlanSummary(planId);
      final runtime = await _readModels.getSessionRuntime(sessionId);
      if (_disposed) return;

      if (summary == null || runtime == null) {
        throw StateError('Reading session could not be loaded: $sessionId');
      }

      final config = summary.config;
      final now = DateTime.now();
      _sessionDay = runtime.sessionDay;
      _sessionReadMilliseconds = runtime.sessionReadSeconds * 1000;
      _dayReadMilliseconds = runtime.secondsToday * 1000;
      _lastTickAt = now;
      _lastFlushAt = now;
      _goalLatch = runtime.goalAlreadyReachedToday;

      sessionNotifier.value = ReadingSessionUiState(
        config: config,
        session: runtime,
      );
      secondsTodayNotifier.value = runtime.secondsToday;
      sessionSecondsNotifier.value = _sessionReadSeconds;
      goalReachedNotifier.value = false;
      bookCompletedNotifier.value = null;
      hudVisible.value = true;

      _navigationViewModel.navigateTo(summary.resumeTarget);

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

    final sessionId = session?.session.sessionId;
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

      final sessionId = session?.session.sessionId;
      if (sessionId == null) return null;

      final result = await _service.setVerseRead(
        sessionId,
        options,
        readSeconds: _sessionReadSeconds,
        at: now,
      );
      if (_disposed || result == null) return null;

      final runtime = await _readModels.getSessionRuntime(result.sessionId);
      final verseReadStates = await _readModels.getVerseReadStates(
        result.sessionId,
        options.bookId,
        options.chapter,
      );
      if (_disposed) return null;

      if (runtime != null) {
        _applyProgress(runtime);
      }

      final event = result.bookCompleted;
      if (event != null) {
        _nextResumePosition = event.resumePosition;
        bookCompletedNotifier.value = event;
      }

      _checkGoalReached();
      return verseReadStates;
    } finally {
      _unlockRequest();
    }
  }

  Future<Map<int, VerseReadState>> getVerseReadStates(
    int bookId,
    int chapter,
  ) async {
    final sessionId = session?.session.sessionId;
    if (sessionId == null) return const {};
    return _readModels.getVerseReadStates(sessionId, bookId, chapter);
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

  void _applyProgress(ReadingSessionRuntime progress) {
    final previousDay = _sessionDay;
    final dayChanged =
        previousDay != null && !isSameDay(previousDay, progress.sessionDay);
    final currentSessionId = session?.session.sessionId;
    final sessionChanged =
        currentSessionId != null && currentSessionId != progress.sessionId;

    _sessionDay = progress.sessionDay;
    if (dayChanged) {
      _goalLatch = progress.goalAlreadyReachedToday;
    }

    if (sessionChanged || dayChanged) {
      // A day/session rollover starts a fresh accumulated duration.
      _sessionReadMilliseconds = progress.sessionReadSeconds * 1000;
      _dayReadMilliseconds = progress.secondsToday * 1000;
      _lastTickAt = DateTime.now();
    } else {
      _sessionReadMilliseconds = math.max(
        _sessionReadMilliseconds,
        progress.sessionReadSeconds * 1000,
      );
      _dayReadMilliseconds = math.max(
        _dayReadMilliseconds,
        progress.secondsToday * 1000,
      );
    }
    _lastFlushAt = DateTime.now();

    final current = session;
    if (current != null) {
      final updated = ReadingSessionUiState(
        config: current.config,
        session: progress,
      );
      if (updated.session.sessionId != current.session.sessionId ||
          updated.session.versesToday != current.session.versesToday ||
          updated.session.goalAlreadyReachedToday !=
              current.session.goalAlreadyReachedToday ||
          updated.session.sessionStartTime !=
              current.session.sessionStartTime) {
        sessionNotifier.value = updated;
      }
    }

    sessionSecondsNotifier.value = _sessionReadSeconds;
    secondsTodayNotifier.value = _dayReadMilliseconds ~/ 1000;
  }

  void _checkGoalReached() {
    final current = session;
    if (current == null) return;

    final dailyGoal = current.config.dailyGoal;
    final reached = dailyGoal.type == GoalType.verses
        ? current.session.versesToday >= dailyGoal.value
        : secondsTodayNotifier.value >= 60 * dailyGoal.value;

    if (!reached || _goalLatch) return;

    _goalLatch = true;
    goalReachedNotifier.value = true;
  }

  void _onTick() {
    if (_disposed || _timerPaused || !hasActiveSession) return;

    final now = DateTime.now();
    final dayChanged = _sessionDay != null && !isSameDay(_sessionDay!, now);

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

      final sessionId = session?.session.sessionId;
      if (sessionId == null) return;

      final updated = await _service.heartbeat(
        sessionId,
        readSeconds: _sessionReadSeconds,
        at: now,
      );
      if (_disposed || !updated) return;

      final runtime = await _readModels.getSessionRuntime(sessionId);
      if (_disposed || runtime == null) return;

      _applyProgress(runtime);
      _checkGoalReached();
    } finally {
      _unlockRequest();
    }
  }

  void _scheduleNextTick() {
    _tickTimer?.cancel();
    if (_disposed || _timerPaused || !hasActiveSession) return;

    _tickTimer = Timer(const Duration(seconds: 1), _onTick);
  }

  void _clearPresentation() {
    _tickTimer?.cancel();
    _tickTimer = null;

    _sessionDay = null;
    _goalLatch = false;
    _sessionReadMilliseconds = 0;
    _dayReadMilliseconds = 0;
    _lastTickAt = DateTime.now();
    _lastFlushAt = DateTime.now();

    sessionNotifier.value = null;
    _nextResumePosition = null;
    secondsTodayNotifier.value = 0;
    sessionSecondsNotifier.value = 0;
    goalReachedNotifier.value = false;
    bookCompletedNotifier.value = null;
    hudVisible.value = false;
  }

  void _accumulateElapsed(DateTime now) {
    final elapsedMilliseconds = now.difference(_lastTickAt).inMilliseconds;
    if (elapsedMilliseconds <= 0) return;

    _lastTickAt = now;
    _sessionReadMilliseconds += elapsedMilliseconds;
    _dayReadMilliseconds += elapsedMilliseconds;
    sessionSecondsNotifier.value = _sessionReadSeconds;
    secondsTodayNotifier.value = _dayReadMilliseconds ~/ 1000;
  }

  Future<void> _rolloverIfNeeded(
    DateTime now, {
    required bool timerActive,
  }) async {
    final sessionId = session?.session.sessionId;
    final sessionDay = _sessionDay;
    if (sessionId == null || sessionDay == null || isSameDay(sessionDay, now)) {
      return;
    }

    var oldDayExtra = 0;
    var newDayExtra = 0;
    if (timerActive) {
      final elapsed = math.max(0, now.difference(_lastTickAt).inSeconds);
      final startOfToday = dayOnly(now);
      oldDayExtra = math.min(
        math.max(0, startOfToday.difference(_lastTickAt).inSeconds),
        elapsed,
      );
      newDayExtra = elapsed - oldDayExtra;
    }

    final newSessionId = await _service.rolloverSession(
      sessionId,
      at: now,
      oldReadSeconds: _sessionReadSeconds + oldDayExtra,
      newReadSeconds: newDayExtra,
    );
    if (_disposed || newSessionId == null) return;

    final runtime = await _readModels.getSessionRuntime(newSessionId);
    if (_disposed || runtime == null) return;

    _applyProgress(runtime);
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
}
