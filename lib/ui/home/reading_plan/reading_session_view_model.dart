import 'dart:async';

import 'package:flutter/foundation.dart';
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

class ReadingSessionViewModel {
  ReadingSessionViewModel() : this.withService(getIt<ReadingSessionService>());

  ReadingSessionViewModel.withService(this._service);

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

  DateTime? _sessionDay;
  DateTime _sessionStart = DateTime.now();
  DateTime _anchorAt = DateTime.now();
  DateTime _lastFlushAt = DateTime.now();
  DateTime? _lastTickSessionStart;
  int _daySecondsAtAnchor = 0;

  Timer? _tickTimer;

  Future<void> startSession(int planId) async {
    if (!_tryLockRequest('start session for plan $planId')) return;

    try {
      final previousSessionId = session?.sessionId;
      if (previousSessionId != null) {
        await _service.endSession(previousSessionId);
        if (_disposed) return;
        _clearPresentation();
      }

      final snapshot = await _service.startSession(planId);
      if (_disposed) return;

      if (snapshot == null) {
        throw StateError('Reading plan not found: $planId');
      }

      final progress = snapshot.progress;
      final config = snapshot.config;

      _sessionDay = progress.sessionDay;
      _sessionStart = progress.sessionStartTime;
      _daySecondsAtAnchor = progress.secondsToday;
      _anchorAt = progress.asOf;
      _lastFlushAt = progress.asOf;
      _lastTickSessionStart = progress.sessionStartTime;
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
      sessionSecondsNotifier.value = progress.asOf
          .difference(progress.sessionStartTime)
          .inSeconds;
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
      _tickTimer?.cancel();
      _tickTimer = null;

      final sessionId = session?.sessionId;
      if (sessionId != null) {
        await _service.endSession(sessionId);
        if (_disposed) return;
      }

      _clearPresentation();
    } finally {
      _unlockRequest();
    }
  }

  Future<Map<int, int>?> markVerseAsRead(
    int bookId,
    int chapter,
    int verse,
  ) async {
    if (!_tryLockRequest('mark verse $bookId:$chapter:$verse as read')) {
      return null;
    }

    try {
      final sessionId = session?.sessionId;
      if (sessionId == null) return null;

      final result = await _service.markVerseAsRead(
        sessionId,
        bookId,
        chapter,
        verse,
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
      return result.verseReadCounts;
    } finally {
      _unlockRequest();
    }
  }

  Future<Map<int, int>?> resetVerseProgress(
    int bookId,
    int chapter,
    int verse,
  ) async {
    if (!_tryLockRequest('reset verse $bookId:$chapter:$verse progress')) {
      return null;
    }

    try {
      final sessionId = session?.sessionId;
      if (sessionId == null) return null;

      final result = await _service.resetVerseProgress(
        sessionId,
        bookId,
        chapter,
        verse,
      );
      if (_disposed || result == null) return null;

      _applyProgress(result.progress);
      _checkGoalReached();
      return result.verseReadCounts;
    } finally {
      _unlockRequest();
    }
  }

  Future<Map<int, int>> getVerseReadCounts(int bookId, int chapter) async {
    final sessionId = session?.sessionId;
    if (sessionId == null) return const {};
    return _service.getVerseReadCounts(sessionId, bookId, chapter);
  }

  void toggleDisplayGoalProgress() {
    hudVisible.value = !hudVisible.value;
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

    _sessionDay = progress.sessionDay;
    if (dayChanged) {
      _goalLatch = progress.goalAlreadyReachedToday;
    }

    _sessionStart = progress.sessionStartTime;
    _daySecondsAtAnchor = progress.secondsToday;
    _anchorAt = progress.asOf;
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

    secondsTodayNotifier.value = progress.secondsToday;
    sessionSecondsNotifier.value = progress.asOf
        .difference(progress.sessionStartTime)
        .inSeconds;
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
    if (_disposed || !hasActiveSession) return;

    final now = DateTime.now();

    final daySeconds =
        _daySecondsAtAnchor + now.difference(_anchorAt).inSeconds;
    if (daySeconds >= secondsTodayNotifier.value) {
      secondsTodayNotifier.value = daySeconds;
    }

    final sessionSeconds = now.difference(_sessionStart).inSeconds;
    if (_lastTickSessionStart != _sessionStart ||
        sessionSeconds >= sessionSecondsNotifier.value) {
      sessionSecondsNotifier.value = sessionSeconds;
    }
    _lastTickSessionStart = _sessionStart;

    _checkGoalReached();

    if (now.difference(_lastFlushAt) >= heartbeatInterval) {
      _flush();
    }

    _scheduleNextTick();
  }

  Future<void> _flush() async {
    if (!_tryLockRequest('heartbeat')) return;

    try {
      final sessionId = session?.sessionId;
      if (sessionId == null) return;

      final progress = await _service.heartbeat(sessionId);
      if (_disposed || progress == null) return;

      _applyProgress(progress);
      _checkGoalReached();
    } finally {
      _unlockRequest();
    }
  }

  void _scheduleNextTick() {
    _tickTimer?.cancel();
    if (_disposed || !hasActiveSession) return;

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
    _daySecondsAtAnchor = 0;
    _lastTickSessionStart = null;
    _sessionStart = DateTime.now();
    _anchorAt = DateTime.now();
    _lastFlushAt = DateTime.now();

    sessionNotifier.value = null;
    secondsTodayNotifier.value = 0;
    sessionSecondsNotifier.value = 0;
    goalReachedNotifier.value = false;
    bookCompletedNotifier.value = null;
    hudVisible.value = false;
  }

  void dispose() {
    _disposed = true;
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
