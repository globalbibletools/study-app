import 'dart:math' as math;

import 'package:gbt/common/reference.dart';
import 'package:gbt/reading_plan/data_access/reading_plan_repository.dart'
    as repo;
import 'package:gbt/reading_plan/data_access/rs_database.dart';
import 'package:gbt/reading_plan/model.dart' show dayString;
import 'package:gbt/reading_plan/data_access/session_log_repository.dart';
import 'package:gbt/reading_plan/data_access/session_repository.dart';
import 'package:gbt/services/service_locator.dart';

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

class ReadingSessionService {
  ReadingSessionService() : this.withDatabase(getIt<ReadingSessionDatabase>());

  ReadingSessionService.withDatabase(this._database);

  final ReadingSessionDatabase _database;

  Future<int?> startSession(int planId) async {
    await _requireReadingPlan(planId);

    final now = DateTime.now();
    final session = await _database.session.commit(
      Session(
        rsDate: _day(now),
        startTime: now,
        endTime: now,
        readSeconds: 0,
        verses: 0,
        readingPlanId: planId,
      ),
    );

    return session.id;
  }

  Future<void> endSession(
    int sessionId, {
    required int readSeconds,
    DateTime? at,
  }) async {
    final session = await _requireSession(sessionId);

    final now = at ?? DateTime.now();
    _ensureSessionIsCurrent(session, now);

    final closed = session.copyWith(
      endTime: now,
      readSeconds: math.max(session.readSeconds, readSeconds),
    );

    await _database.transaction((txn) async {
      await _database.session.commit(closed, executor: txn);
      await _database.daySummary.upsert(
        session.readingPlanId,
        session.rsDate,
        executor: txn,
      );
    });
  }

  Future<BookCompletedEvent?> setVerseRead(
    int sessionId, {
    required int bookId,
    required int chapter,
    required int verse,
    required bool read,
    DateTime? at,
  }) async {
    final now = at ?? DateTime.now();
    final session = await _requireSession(sessionId);

    _ensureSessionIsCurrent(session, now);

    final planId = session.readingPlanId;
    final plan = await _requireReadingPlan(planId);
    if (!plan.bookIds.contains(bookId)) {
      return null;
    }

    final event = await _database.transaction((txn) async {
      final existingLog = await _database.sessionLog.getVerseLogForSession(
        session.id!,
        bookId,
        chapter,
        verse,
        executor: txn,
      );
      final readThisSession = existingLog != null;

      var updatedSession = session;
      BookCompletedEvent? event;

      if (read && !readThisSession) {
        final existingCount =
            await _database.verseState.getReadCount(
              planId,
              bookId,
              chapter,
              verse,
              executor: txn,
            ) ??
            0;

        await _database.sessionLog.append(
          SessionLogEntry(
            sessionId: session.id!,
            readingPlanId: planId,
            bookId: bookId,
            chapter: chapter,
            verse: verse,
            dateTime: now,
          ),
          executor: txn,
        );

        updatedSession = session.copyWith(verses: session.verses + 1);

        await _database.verseState.markRead(
          planId,
          bookId,
          chapter,
          verse,
          timestamp: now,
          executor: txn,
        );

        if (existingCount == 0 &&
            await _database.verseState.isBookComplete(
              planId,
              bookId,
              executor: txn,
            )) {
          final completedIndex = plan.bookIds.indexOf(bookId);
          final nextBookId =
              completedIndex >= 0 && completedIndex + 1 < plan.bookIds.length
              ? plan.bookIds[completedIndex + 1]
              : null;
          final resumePosition = nextBookId == null
              ? null
              : Reference(bookId: nextBookId, chapter: 1, verse: 1);
          event = BookCompletedEvent(
            completedBookId: bookId,
            nextBookId: nextBookId,
            resumePosition: resumePosition,
          );
        }
      } else if (!read && readThisSession) {
        await _database.sessionLog.remove(existingLog.id!, executor: txn);
        await _database.verseState.unmarkRead(
          planId,
          bookId,
          chapter,
          verse,
          executor: txn,
        );

        updatedSession = session.copyWith(
          verses: math.max(0, session.verses - 1),
        );
      }

      if (read != readThisSession) {
        await _database.session.commit(updatedSession, executor: txn);
        await _database.daySummary.upsert(
          planId,
          session.rsDate,
          executor: txn,
        );
      }

      return event;
    });

    return event;
  }

  Future<void> extendSession(
    int sessionId, {
    required int readSeconds,
    DateTime? at,
  }) async {
    final now = at ?? DateTime.now();
    final session = await _requireSession(sessionId);

    _ensureSessionIsCurrent(session, now);

    final updated = session.copyWith(
      endTime: now,
      readSeconds: math.max(session.readSeconds, readSeconds),
    );

    await _database.transaction((txn) async {
      await _database.session.commit(updated, executor: txn);
      await _database.daySummary.upsert(
        session.readingPlanId,
        session.rsDate,
        executor: txn,
      );
    });
  }

  Future<int?> rolloverSession(
    int sessionId, {
    required DateTime at,
    required int oldReadSeconds,
    required int newReadSeconds,
  }) async {
    final session = await _requireSession(sessionId);

    final today = _day(at);
    final sessionDay = _day(session.rsDate);
    if (_sameDay(sessionDay, today)) {
      throw StateError(
        'Session $sessionId is already on '
        '${dayString(today)}.',
      );
    }
    if (today.isBefore(sessionDay)) {
      throw StateError(
        'Cannot roll session $sessionId back from '
        '${dayString(sessionDay)} to '
        '${dayString(today)}.',
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
    final newSession = Session(
      rsDate: today,
      startTime: today,
      endTime: at,
      readSeconds: math.max(0, newReadSeconds),
      verses: 0,
      readingPlanId: session.readingPlanId,
    );

    final inserted = await _database.transaction((txn) async {
      await _database.session.commit(closed, executor: txn);
      await _database.daySummary.upsert(
        session.readingPlanId,
        closed.rsDate,
        preserveStoredGoalSnapshot: true,
        executor: txn,
      );

      final inserted = await _database.session.commit(
        newSession,
        executor: txn,
      );
      if (inserted.readSeconds > 0) {
        await _database.daySummary.upsert(
          session.readingPlanId,
          inserted.rsDate,
          executor: txn,
        );
      }
      return inserted;
    });

    return inserted.id;
  }

  void _ensureSessionIsCurrent(Session session, DateTime at) {
    final today = _day(at);
    if (_sameDay(session.rsDate, today)) return;

    throw StateError(
      'Session ${session.id} belongs to '
      '${dayString(session.rsDate)}, but the current day is '
      '${dayString(today)}. Call rolloverSession first.',
    );
  }

  Future<repo.ReadingPlan> _requireReadingPlan(int planId) async {
    final plan = await _database.readingPlans.getById(planId);
    if (plan == null) {
      throw StateError('Reading plan not found: $planId');
    }
    return plan;
  }

  Future<Session> _requireSession(int sessionId) async {
    final session = await _database.session.getById(sessionId);
    if (session == null) {
      throw StateError('Reading session not found: $sessionId');
    }
    return session;
  }

  static DateTime _day(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  static bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
