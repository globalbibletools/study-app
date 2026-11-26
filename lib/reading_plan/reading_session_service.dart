import 'dart:math' as math;

import 'package:gbt/common/reference.dart';
import 'package:gbt/reading_plan/data_access/reading_plan_repository.dart'
    as repo;
import 'package:gbt/reading_plan/data_access/rs_database.dart';
import 'package:gbt/reading_plan/data_access/session_log_repository.dart';
import 'package:gbt/reading_plan/data_access/session_repository.dart';
import 'package:gbt/reading_plan/model.dart' show dayString;
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

  Future<int?> startSession(int planId) {
    return _database.unitOfWork((uow) async {
      await _requireReadingPlan(uow.readingPlans, planId);

      final now = DateTime.now();
      final session = await uow.session.commit(
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
    });
  }

  Future<void> endSession(
    int sessionId, {
    required int readSeconds,
    DateTime? at,
  }) {
    return _database.unitOfWork((uow) async {
      final session = await _requireSession(uow.session, sessionId);

      final now = at ?? DateTime.now();
      _ensureSessionIsCurrent(session, now);

      final closed = session.copyWith(
        endTime: now,
        readSeconds: math.max(session.readSeconds, readSeconds),
      );

      await uow.session.commit(closed);
      await uow.daySummary.upsert(session.readingPlanId, session.rsDate);
    });
  }

  Future<BookCompletedEvent?> setVerseRead(
    int sessionId, {
    required int bookId,
    required int chapter,
    required int verse,
    required bool read,
    DateTime? at,
  }) {
    return _database.unitOfWork((uow) async {
      final now = at ?? DateTime.now();
      final session = await _requireSession(uow.session, sessionId);

      _ensureSessionIsCurrent(session, now);

      final planId = session.readingPlanId;
      final plan = await _requireReadingPlan(uow.readingPlans, planId);
      if (!plan.bookIds.contains(bookId)) {
        return null;
      }

      final existingLog = await uow.sessionLog.getVerseLogForSession(
        session.id!,
        bookId,
        chapter,
        verse,
      );
      final readThisSession = existingLog != null;

      var updatedSession = session;
      BookCompletedEvent? event;

      if (read && !readThisSession) {
        final existingCount =
            await uow.verseState.getReadCount(planId, bookId, chapter, verse) ??
            0;

        await uow.sessionLog.append(
          SessionLogEntry(
            sessionId: session.id!,
            readingPlanId: planId,
            bookId: bookId,
            chapter: chapter,
            verse: verse,
            dateTime: now,
          ),
        );

        updatedSession = session.copyWith(verses: session.verses + 1);

        await uow.verseState.markRead(
          planId,
          bookId,
          chapter,
          verse,
          timestamp: now,
        );

        if (existingCount == 0 &&
            await uow.verseState.isBookComplete(planId, bookId)) {
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
        await uow.sessionLog.remove(existingLog.id!);
        await uow.verseState.unmarkRead(planId, bookId, chapter, verse);

        updatedSession = session.copyWith(
          verses: math.max(0, session.verses - 1),
        );
      }

      if (read != readThisSession) {
        await uow.session.commit(updatedSession);
        await uow.daySummary.upsert(planId, session.rsDate);
      }

      return event;
    });
  }

  Future<void> extendSession(
    int sessionId, {
    required int readSeconds,
    DateTime? at,
  }) {
    return _database.unitOfWork((uow) async {
      final now = at ?? DateTime.now();
      final session = await _requireSession(uow.session, sessionId);

      _ensureSessionIsCurrent(session, now);

      final updated = session.copyWith(
        endTime: now,
        readSeconds: math.max(session.readSeconds, readSeconds),
      );

      await uow.session.commit(updated);
      await uow.daySummary.upsert(session.readingPlanId, session.rsDate);
    });
  }

  Future<int?> rolloverSession(
    int sessionId, {
    required DateTime at,
    required int oldReadSeconds,
    required int newReadSeconds,
  }) {
    return _database.unitOfWork((uow) async {
      final session = await _requireSession(uow.session, sessionId);

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

      await uow.session.commit(closed);
      await uow.daySummary.upsert(
        session.readingPlanId,
        closed.rsDate,
        preserveStoredGoalSnapshot: true,
      );

      final inserted = await uow.session.commit(newSession);
      if (inserted.readSeconds > 0) {
        await uow.daySummary.upsert(session.readingPlanId, inserted.rsDate);
      }
      return inserted.id;
    });
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

  Future<repo.ReadingPlan> _requireReadingPlan(
    repo.ReadingPlanRepository readingPlans,
    int planId,
  ) async {
    final plan = await readingPlans.getById(planId);
    if (plan == null) {
      throw StateError('Reading plan not found: $planId');
    }
    return plan;
  }

  Future<Session> _requireSession(
    SessionRepository sessions,
    int sessionId,
  ) async {
    final session = await sessions.getById(sessionId);
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
