import 'dart:math' as math;

import 'package:gbt/common/bible_navigation.dart';
import 'package:gbt/common/reference.dart';
import 'package:gbt/services/reading_session/reading_plan_config.dart';
import 'package:gbt/services/reading_session/rs_database.dart';
import 'package:gbt/services/reading_session/rs_model.dart';
import 'package:gbt/services/service_locator.dart';

class SessionProgress {
  const SessionProgress({
    required this.sessionId,
    required this.sessionDay,
    required this.sessionStartTime,
    required this.sessionReadSeconds,
    required this.versesToday,
    required this.secondsToday,
    required this.goalAlreadyReachedToday,
    required this.asOf,
  });

  final int sessionId;
  final DateTime sessionDay;
  final DateTime sessionStartTime;
  final int sessionReadSeconds;
  final int versesToday;
  final int secondsToday;
  final bool goalAlreadyReachedToday;
  final DateTime asOf;
}

class ActiveSessionSnapshot {
  const ActiveSessionSnapshot({required this.config, required this.progress});

  final ReadingPlanConfig config;
  final SessionProgress progress;
}

class BookCompletedEvent {
  const BookCompletedEvent({
    required this.completedBookId,
    required this.nextBookId,
    required this.resumePosition,
  });

  final int completedBookId;
  final int? nextBookId;
  final Reference? resumePosition;
}

class VerseReadResult {
  const VerseReadResult({
    required this.progress,
    required this.verseReadStates,
    this.bookCompleted,
  });

  final SessionProgress progress;
  final Map<int, VerseReadState> verseReadStates;
  final BookCompletedEvent? bookCompleted;
}

class ReadingSessionService {
  ReadingSessionService() : this.withDatabase(getIt<ReadingSessionDatabase>());

  ReadingSessionService.withDatabase(this._database);

  final ReadingSessionDatabase _database;
  late final _bibleNavigation = getIt<BibleNavigation>();

  Future<ActiveSessionSnapshot?> startSession(int planId) async {
    final details = await _database.getReadingPlanById(planId);
    if (details == null) return null;

    final config = ReadingPlanConfig.fromPlanDetails(details, _bibleNavigation);

    final now = DateTime.now();
    final today = _day(now);
    final session = await _database.insertSession(
      RsSession(
        rsDate: today,
        startTime: now,
        endTime: now,
        readSeconds: 0,
        verses: 0,
        readingPlanId: planId,
      ),
    );

    final progress = await _readProgress(session, now);
    return ActiveSessionSnapshot(config: config, progress: progress);
  }

  Future<ActiveSessionSnapshot?> loadSession(
    int sessionId, {
    DateTime? at,
  }) async {
    final session = await _database.getSessionById(sessionId);
    if (session == null) return null;

    final details = await _database.getReadingPlanById(session.readingPlanId);
    if (details == null) return null;

    final config = ReadingPlanConfig.fromPlanDetails(details, _bibleNavigation);
    final now = at ?? DateTime.now();
    final progress = await _readProgress(session, now);

    return ActiveSessionSnapshot(config: config, progress: progress);
  }

  Future<void> endSession(
    int sessionId, {
    required int readSeconds,
    DateTime? at,
  }) async {
    var session = await _database.getSessionById(sessionId);
    if (session == null) return;

    final now = at ?? DateTime.now();
    _ensureSessionIsCurrent(session, now);

    final closed = session.copyWith(
      endTime: now,
      readSeconds: math.max(session.readSeconds, readSeconds),
    );

    await _database.transaction((txn) async {
      await _database.updateSession(closed, executor: txn);
      await _database.upsertDaySummary(
        session.readingPlanId,
        session.rsDate,
        executor: txn,
      );
    });
  }

  Future<VerseReadResult?> setVerseRead(
    int sessionId,
    VerseReadOptions options, {
    required int readSeconds,
    DateTime? at,
  }) async {
    final bookId = options.bookId;
    final chapter = options.chapter;
    final verse = options.verse;
    final read = options.read;

    final now = at ?? DateTime.now();
    final session = await _database.getSessionById(sessionId);
    if (session == null) return null;

    _ensureSessionIsCurrent(session, now);

    final details = await _database.getReadingPlanById(session.readingPlanId);
    if (details == null) return null;

    final config = ReadingPlanConfig.fromPlanDetails(details, _bibleNavigation);
    final planId = session.readingPlanId;

    if (!config.bookIds.contains(bookId)) {
      return VerseReadResult(
        progress: await _readProgress(session, now),
        verseReadStates: await _database.getVerseReadStatesForChapter(
          planId,
          session.id!,
          bookId,
          chapter,
        ),
      );
    }

    final effectiveReadSeconds = math.max(session.readSeconds, readSeconds);
    final hasNewReadSeconds = effectiveReadSeconds > session.readSeconds;

    final outcome = await _database.transaction((txn) async {
      final logs = await _database.getRsLogForSessionAndVerse(
        session.id!,
        bookId,
        chapter,
        verse,
        executor: txn,
      );
      final readThisSession = logs.isNotEmpty;

      var updatedSession = session.copyWith(readSeconds: effectiveReadSeconds);
      BookCompletedEvent? event;

      if (read && !readThisSession) {
        final existingCount =
            await _database.getVerseReadCount(
              planId,
              bookId,
              chapter,
              verse,
              executor: txn,
            ) ??
            0;

        await _database.insertLog(
          RsLog(
            sessionId: session.id!,
            bookId: bookId,
            chapter: chapter,
            verse: verse,
            dateTime: now,
            readingPlanId: planId,
          ),
          executor: txn,
        );

        updatedSession = updatedSession.copyWith(
          verses: session.verses + 1,
          endTime: now,
        );

        await _database.markVerseRead(
          planId,
          bookId,
          chapter,
          verse,
          timestamp: now,
          executor: txn,
        );

        if (existingCount == 0 &&
            await _database.isBookComplete(planId, bookId, executor: txn)) {
          final reference = Reference(
            bookId: bookId,
            chapter: chapter,
            verse: verse,
          );
          final resumePosition = await _database.getResumeReference(
            planId,
            after: reference,
            executor: txn,
          );
          event = BookCompletedEvent(
            completedBookId: bookId,
            nextBookId: resumePosition?.bookId,
            resumePosition: resumePosition,
          );
        }
      } else if (!read && readThisSession) {
        await _database.deleteRsLogForSessionAndVerse(
          session.id!,
          bookId,
          chapter,
          verse,
          executor: txn,
        );
        await _database.unmarkVerseRead(
          planId,
          bookId,
          chapter,
          verse,
          executor: txn,
        );

        updatedSession = updatedSession.copyWith(
          verses: math.max(0, session.verses - 1),
          endTime: now,
        );
      }

      if (read != readThisSession || hasNewReadSeconds) {
        if (read == readThisSession) {
          updatedSession = updatedSession.copyWith(endTime: now);
        }
        await _database.updateSession(updatedSession, executor: txn);
        await _database.upsertDaySummary(planId, session.rsDate, executor: txn);
      }

      return (
        session: updatedSession,
        states: await _database.getVerseReadStatesForChapter(
          planId,
          updatedSession.id!,
          bookId,
          chapter,
          executor: txn,
        ),
        event: event,
      );
    });

    return VerseReadResult(
      progress: await _readProgress(outcome.session, now),
      verseReadStates: outcome.states,
      bookCompleted: outcome.event,
    );
  }

  Future<SessionProgress?> heartbeat(
    int sessionId, {
    required int readSeconds,
    DateTime? at,
  }) async {
    final now = at ?? DateTime.now();
    final session = await _database.getSessionById(sessionId);
    if (session == null) return null;

    _ensureSessionIsCurrent(session, now);

    final updated = session.copyWith(
      endTime: now,
      readSeconds: math.max(session.readSeconds, readSeconds),
    );

    await _database.transaction((txn) async {
      await _database.updateSession(updated, executor: txn);
      await _database.upsertDaySummary(
        session.readingPlanId,
        session.rsDate,
        executor: txn,
      );
    });

    return _readProgress(updated, now);
  }

  Future<SessionProgress?> rolloverSession(
    int sessionId, {
    required DateTime at,
    required int oldReadSeconds,
    required int newReadSeconds,
  }) async {
    final session = await _database.getSessionById(sessionId);
    if (session == null) return null;

    final today = _day(at);
    final sessionDay = _day(session.rsDate);
    if (_sameDay(sessionDay, today)) {
      throw StateError(
        'Session $sessionId is already on '
        '${RsDaySummary.dayString(today)}.',
      );
    }
    if (today.isBefore(sessionDay)) {
      throw StateError(
        'Cannot roll session $sessionId back from '
        '${RsDaySummary.dayString(sessionDay)} to '
        '${RsDaySummary.dayString(today)}.',
      );
    }

    final nextDay = DateTime(
      session.rsDate.year,
      session.rsDate.month,
      session.rsDate.day + 1,
    );
    final closed = session.copyWith(
      endTime: nextDay.subtract(const Duration(seconds: 1)),
      readSeconds: math.max(session.readSeconds, oldReadSeconds),
    );
    final newSession = RsSession(
      rsDate: today,
      startTime: today,
      endTime: at,
      readSeconds: math.max(0, newReadSeconds),
      verses: 0,
      readingPlanId: session.readingPlanId,
    );

    final inserted = await _database.transaction((txn) async {
      await _database.updateSession(closed, executor: txn);
      await _database.upsertDaySummary(
        session.readingPlanId,
        closed.rsDate,
        preserveStoredGoalSnapshot: true,
        executor: txn,
      );

      final inserted = await _database.insertSession(newSession, executor: txn);
      if (inserted.readSeconds > 0) {
        await _database.upsertDaySummary(
          session.readingPlanId,
          inserted.rsDate,
          executor: txn,
        );
      }
      return inserted;
    });

    return _readProgress(inserted, at);
  }

  Future<Map<int, VerseReadState>> getVerseReadStates(
    int sessionId,
    int bookId,
    int chapter,
  ) async {
    final session = await _database.getSessionById(sessionId);
    if (session == null) return const {};

    return _database.getVerseReadStatesForChapter(
      session.readingPlanId,
      session.id!,
      bookId,
      chapter,
    );
  }

  void _ensureSessionIsCurrent(RsSession session, DateTime at) {
    final today = _day(at);
    if (_sameDay(session.rsDate, today)) return;

    throw StateError(
      'Session ${session.id} belongs to '
      '${RsDaySummary.dayString(session.rsDate)}, but the current day is '
      '${RsDaySummary.dayString(today)}. Call rolloverSession first.',
    );
  }

  Future<SessionProgress> _readProgress(
    RsSession session,
    DateTime asOf,
  ) async {
    final planId = session.readingPlanId;
    final summary = await _database.getDaySummary(planId, session.rsDate);

    return SessionProgress(
      sessionId: session.id!,
      sessionDay: _day(session.rsDate),
      sessionStartTime: session.startTime,
      sessionReadSeconds: session.readSeconds,
      versesToday: await _database.getVersesReadToday(planId, session.rsDate),
      secondsToday: await _database.getTotalSecondsReadToday(
        planId,
        session.rsDate,
      ),
      goalAlreadyReachedToday: summary?.goalReached ?? false,
      asOf: asOf,
    );
  }

  static DateTime _day(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  static bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
