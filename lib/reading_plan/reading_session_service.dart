import 'dart:math' as math;

import 'package:gbt/common/reference.dart';
import 'package:gbt/reading_plan/rs_database.dart';
import 'package:gbt/reading_plan/rs_model.dart';
import 'package:gbt/services/service_locator.dart';

class VerseReadResult {
  const VerseReadResult({required this.sessionId, this.bookCompleted});

  final int sessionId;
  final BookCompletedEvent? bookCompleted;
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

class ReadingSessionService {
  ReadingSessionService() : this.withDatabase(getIt<ReadingSessionDatabase>());

  ReadingSessionService.withDatabase(this._database);

  final ReadingSessionDatabase _database;

  Future<int?> startSession(int planId) async {
    final plan = await _database.getReadingPlanById(planId);
    if (plan == null) return null;

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

    return session.id;
  }

  Future<void> endSession(
    int sessionId, {
    required int readSeconds,
    DateTime? at,
  }) async {
    final session = await _database.getSessionById(sessionId);
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

    final plan = await _database.getReadingPlanById(session.readingPlanId);
    if (plan == null) return null;

    final planId = session.readingPlanId;

    if (!plan.books.any((book) => book.bookId == bookId)) {
      return VerseReadResult(sessionId: session.id!);
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
          final completedIndex = plan.books.indexWhere(
            (book) => book.bookId == bookId,
          );
          final nextBookId =
              completedIndex >= 0 && completedIndex + 1 < plan.books.length
              ? plan.books[completedIndex + 1].bookId
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

      return (sessionId: updatedSession.id!, event: event);
    });

    return VerseReadResult(
      sessionId: outcome.sessionId,
      bookCompleted: outcome.event,
    );
  }

  Future<bool> heartbeat(
    int sessionId, {
    required int readSeconds,
    DateTime? at,
  }) async {
    final now = at ?? DateTime.now();
    final session = await _database.getSessionById(sessionId);
    if (session == null) return false;

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

    return true;
  }

  Future<int?> rolloverSession(
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

    return inserted.id;
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

  static DateTime _day(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  static bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
