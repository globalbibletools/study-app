import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:gbt/asyncutils/serial_queue.dart';
import 'package:gbt/common/reference.dart';
import 'package:gbt/reading_plan/data_access/reading_plan_queries.dart';
import 'package:gbt/reading_plan/data_access/reading_plan_read_models.dart';
import 'package:gbt/reading_plan/reading_session_service.dart';
import 'package:gbt/services/logging/log.dart' as log;
import 'package:gbt/services/service_locator.dart';
import 'package:gbt/ui/home/common/navigation_view_model.dart';

export 'package:gbt/reading_plan/data_access/reading_plan_read_models.dart'
    show VerseReadState;

class ReadingSessionViewModel extends ChangeNotifier
    with WidgetsBindingObserver {
  ReadingSessionViewModel()
    : this.withDependencies(
        service: getIt<ReadingSessionService>(),
        queries: getIt<ReadingPlanQueries>(),
        navigationViewModel: getIt<NavigationViewModel>(),
      );

  ReadingSessionViewModel.withDependencies({
    required ReadingSessionService service,
    required ReadingPlanQueries queries,
    required NavigationViewModel navigationViewModel,
  }) : _service = service,
       _queries = queries,
       _navigationViewModel = navigationViewModel {
    WidgetsBinding.instance.addObserver(this);
  }

  final ReadingSessionService _service;
  final ReadingPlanQueries _queries;
  final NavigationViewModel _navigationViewModel;

  final _commands = SerialQueue();

  final _goalReachedController = StreamController<void>.broadcast();
  Stream<void> get goalReached => _goalReachedController.stream;

  final _bookCompletedController =
      StreamController<BookCompletedEvent>.broadcast();
  Stream<BookCompletedEvent> get bookCompleted =>
      _bookCompletedController.stream;

  ReadingPlanConfig? _config;
  ReadingPlanConfig? get planConfig => _config;

  SessionRuntime? _runtime;
  SessionRuntime? get sessionRuntime => _runtime;
  bool get hasActiveSession => _runtime != null;
  int? get sessionId => _runtime?.sessionId;

  Reference? _resumePosition;
  Reference? get nextResumePosition => _resumePosition;

  Set<int>? get readingPlanBooks => _config?.bookIds.toSet();

  bool _hudVisible = false;
  bool get hudVisible => _hudVisible;

  final _secondsTodayNotifier = ValueNotifier<int>(0);
  ValueListenable<int> get secondsToday => _secondsTodayNotifier;

  final _sessionSecondsNotifier = ValueNotifier<int>(0);
  ValueListenable<int> get sessionSeconds => _sessionSecondsNotifier;

  bool _goalLatch = false;
  bool _timerPaused = false;

  DateTime? _sessionDay;
  int _sessionReadMilliseconds = 0;
  int _dayReadMilliseconds = 0;
  DateTime _lastTickAt = DateTime.now();
  DateTime _lastFlushAt = DateTime.now();

  int get _sessionReadSeconds => _sessionReadMilliseconds ~/ 1000;

  Timer? _tickTimer;
  static Duration heartbeatInterval = const Duration(seconds: 60);

  Future<void> startSession(int planId) {
    return _commands.run(() async {
      if (hasActiveSession) {
        await _endActiveSession();
      }

      final sessionId = await _service.startSession(planId);

      if (sessionId == null) {
        throw StateError('Reading plan not found: $planId');
      }

      final summary = await _queries.getPlanSummary(planId);
      final runtime = await _queries.getSessionRuntime(sessionId);

      if (summary == null || runtime == null) {
        throw StateError('Reading session not found: $sessionId');
      }

      final now = DateTime.now();
      final progress = runtime.dayProgress;
      final config = summary.config;

      _sessionDay = runtime.sessionDay;
      _sessionReadMilliseconds = runtime.sessionReadSeconds * 1000;
      _dayReadMilliseconds = progress.seconds * 1000;
      _lastTickAt = now;
      _lastFlushAt = now;
      _goalLatch = progress.goalReached;

      _setState(() {
        _config = config;
        _runtime = runtime;
        _resumePosition = null;
        _hudVisible = true;
      });
      _secondsTodayNotifier.value = progress.seconds;
      _sessionSecondsNotifier.value = _sessionReadSeconds;

      _navigationViewModel.navigateTo(summary.resumeTarget);

      _scheduleNextTick();
    });
  }

  Future<void> endSession() {
    return _commands.run(_endActiveSession);
  }

  /// Finalizes the active session.
  Future<void> _endActiveSession() async {
    _tickTimer?.cancel();
    _tickTimer = null;

    final now = DateTime.now();
    await _rolloverIfNeeded(now, timerActive: !_timerPaused);

    if (!_timerPaused) {
      _accumulateElapsed(now);
    }

    final sessionId = _runtime?.sessionId;
    if (sessionId != null) {
      await _service.endSession(
        sessionId,
        readSeconds: _sessionReadSeconds,
        at: now,
      );
    }

    _clearPresentation();
  }

  Future<Map<int, VerseReadState>?> setVerseRead({
    required int bookId,
    required int chapter,
    required int verse,
    required bool read,
  }) {
    return _commands.run(() async {
      final now = DateTime.now();
      await _rolloverIfNeeded(now, timerActive: !_timerPaused);

      if (!_timerPaused) {
        _accumulateElapsed(now);
      }

      final sessionId = _runtime?.sessionId;
      if (sessionId == null) return null;

      final event = await _service.setVerseRead(
        sessionId,
        bookId: bookId,
        chapter: chapter,
        verse: verse,
        read: read,
        at: now,
      );

      if (!await _refreshRuntime(sessionId, asOf: now)) return null;

      if (event != null) {
        if (_runtime != null && event.resumePosition != _resumePosition) {
          _setState(() => _resumePosition = event.resumePosition);
        }
        _bookCompletedController.add(event);
      }

      _checkGoalReached();
      return await _queries.getVerseReadStates(sessionId, bookId, chapter);
    });
  }

  Future<Map<int, VerseReadState>> getVerseReadStates(
    int bookId,
    int chapter,
  ) async {
    final sessionId = _runtime?.sessionId;
    if (sessionId == null) return const {};
    return _queries.getVerseReadStates(sessionId, bookId, chapter);
  }

  void toggleDisplayGoalProgress() {
    _setState(() => _hudVisible = !_hudVisible);
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
  Future<void> pauseTimer() {
    return _commands.run(() async {
      if (_timerPaused) return;

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
    });
  }

  /// Resumes accumulating read time without counting the time spent
  /// backgrounded. Rolls the session forward if the day changed while the
  /// timer was paused.
  Future<void> resumeTimer() {
    return _commands.run(() async {
      if (!_timerPaused) return;

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

      _timerPaused = false;
      _lastTickAt = DateTime.now();
      _lastFlushAt = DateTime.now();
      _scheduleNextTick();
    });
  }

  Future<void> resetForDatabaseRestore() {
    return _commands.run(() async {
      _tickTimer?.cancel();
      _tickTimer = null;

      _clearPresentation();
    });
  }

  Future<bool> _refreshRuntime(int sessionId, {DateTime? asOf}) async {
    final runtime = await _queries.getSessionRuntime(sessionId);
    if (runtime == null) return false;

    _applyRuntime(runtime, asOf: asOf);
    return true;
  }

  void _applyRuntime(SessionRuntime runtime, {DateTime? asOf}) {
    final now = asOf ?? DateTime.now();
    final progress = runtime.dayProgress;
    final previousDay = _sessionDay;
    final dayChanged =
        previousDay != null && !_sameDay(previousDay, runtime.sessionDay);
    final currentSessionId = _runtime?.sessionId;
    final sessionChanged =
        currentSessionId != null && currentSessionId != runtime.sessionId;

    _sessionDay = runtime.sessionDay;
    if (dayChanged) {
      _goalLatch = progress.goalReached;
    }

    if (sessionChanged || dayChanged) {
      // A day/session rollover starts a fresh accumulated duration.
      _sessionReadMilliseconds = runtime.sessionReadSeconds * 1000;
      _dayReadMilliseconds = progress.seconds * 1000;
      _lastTickAt = now;
    } else {
      _sessionReadMilliseconds = math.max(
        _sessionReadMilliseconds,
        runtime.sessionReadSeconds * 1000,
      );
      _dayReadMilliseconds = math.max(
        _dayReadMilliseconds,
        progress.seconds * 1000,
      );
    }
    _lastFlushAt = now;

    final current = _runtime;
    if (current != null) {
      final presentationChanged =
          current.sessionId != runtime.sessionId ||
          current.versesToday != runtime.versesToday ||
          current.goalAlreadyReachedToday != runtime.goalAlreadyReachedToday ||
          current.sessionStartTime != runtime.sessionStartTime;
      _setState(() => _runtime = runtime, notify: presentationChanged);
    }

    _sessionSecondsNotifier.value = _sessionReadSeconds;
    _secondsTodayNotifier.value = _dayReadMilliseconds ~/ 1000;
  }

  void _checkGoalReached() {
    final runtime = _runtime;
    final config = _config;
    if (runtime == null || config == null) return;

    final dailyGoal = config.dailyGoal;
    final reached = dailyGoal.type == GoalType.verses
        ? runtime.versesToday >= dailyGoal.value
        : _secondsTodayNotifier.value >= 60 * dailyGoal.value;

    if (!reached || _goalLatch) return;

    _goalLatch = true;
    _goalReachedController.add(null);
  }

  void _onTick() {
    if (_commands.isClosed) return;

    unawaited(
      _commands.runCoalesced('tick', () async {
        try {
          if (_timerPaused || !hasActiveSession) return;

          final now = DateTime.now();
          final dayChanged =
              _sessionDay != null && !_sameDay(_sessionDay!, now);

          if (dayChanged) {
            try {
              await _rolloverIfNeeded(now, timerActive: true);
              _checkGoalReached();
            } catch (error, stackTrace) {
              log.error(
                'Failed to roll reading session over at midnight',
                error: error,
                stackTrace: stackTrace,
              );
            }
            return;
          }

          _accumulateElapsed(now);
          _checkGoalReached();

          if (now.difference(_lastFlushAt) >= heartbeatInterval) {
            try {
              await _flush(at: now);
            } catch (error, stackTrace) {
              log.error(
                'Failed to flush reading session heartbeat',
                error: error,
                stackTrace: stackTrace,
              );
            }
          }
        } finally {
          _scheduleNextTick();
        }
      }),
    );
  }

  Future<void> _flush({DateTime? at, bool timerActive = true}) async {
    final now = at ?? DateTime.now();
    await _rolloverIfNeeded(now, timerActive: timerActive);

    if (timerActive) {
      _accumulateElapsed(now);
    }

    final sessionId = _runtime?.sessionId;
    if (sessionId == null) return;

    await _service.extendSession(
      sessionId,
      readSeconds: _sessionReadSeconds,
      at: now,
    );
    if (!await _refreshRuntime(sessionId, asOf: now)) return;

    _checkGoalReached();
  }

  void _scheduleNextTick() {
    _tickTimer?.cancel();
    if (_commands.isClosed || _timerPaused || !hasActiveSession) return;

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

    _setState(() {
      _config = null;
      _runtime = null;
      _resumePosition = null;
      _hudVisible = false;
    });
    _secondsTodayNotifier.value = 0;
    _sessionSecondsNotifier.value = 0;
  }

  void _accumulateElapsed(DateTime now) {
    final elapsedMilliseconds = now.difference(_lastTickAt).inMilliseconds;
    if (elapsedMilliseconds <= 0) return;

    _lastTickAt = now;
    _sessionReadMilliseconds += elapsedMilliseconds;
    _dayReadMilliseconds += elapsedMilliseconds;
    _sessionSecondsNotifier.value = _sessionReadSeconds;
    _secondsTodayNotifier.value = _dayReadMilliseconds ~/ 1000;
  }

  Future<void> _rolloverIfNeeded(
    DateTime now, {
    required bool timerActive,
  }) async {
    final sessionId = _runtime?.sessionId;
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

    final newSessionId = await _service.rolloverSession(
      sessionId,
      at: now,
      oldReadSeconds: _sessionReadSeconds + oldDayExtra,
      newReadSeconds: newDayExtra,
    );
    if (newSessionId == null) return;

    await _refreshRuntime(newSessionId, asOf: now);
  }

  static DateTime _day(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  static bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void _setState(VoidCallback fn, {bool notify = true}) {
    fn();
    if (notify) notifyListeners();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tickTimer?.cancel();
    _tickTimer = null;

    unawaited(() async {
      await _commands.close();

      _secondsTodayNotifier.dispose();
      _sessionSecondsNotifier.dispose();
      _goalReachedController.close();
      _bookCompletedController.close();
      super.dispose();
    }());
  }
}
