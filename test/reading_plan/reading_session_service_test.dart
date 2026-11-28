import 'package:flutter_test/flutter_test.dart';
import 'package:gbt/common/reference.dart';
import 'package:gbt/reading_plan/data_access/day_summary_repository.dart';
import 'package:gbt/reading_plan/data_access/rs_database.dart';
import 'package:gbt/reading_plan/data_access/session_log_repository.dart';
import 'package:gbt/reading_plan/data_access/session_repository.dart';
import 'package:gbt/reading_plan/data_access/verse_state_repository.dart';
import 'package:gbt/reading_plan/model.dart';
import 'package:gbt/reading_plan/reading_plan_service.dart';
import 'package:gbt/services/service_locator.dart';
import 'package:gbt/reading_plan/reading_session_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../fixtures/bible_navigation_fixture.dart';
import '../fixtures/user_settings_fixture.dart';

typedef _BookStatsSnapshot = ({
  int totalVerses,
  int versesRead,
  DateTime? lastRead,
  Reference? resumePosition,
});

_BookStatsSnapshot _snapshotOf(BookStats stats) => (
  totalVerses: stats.totalVerses,
  versesRead: stats.versesRead,
  lastRead: stats.lastRead,
  resumePosition: stats.resumePosition,
);

Matcher _notFoundError(String message) =>
    isA<StateError>().having((error) => error.message, 'message', message);

Matcher _staleSessionError() => isA<StateError>().having(
  (error) => error.message,
  'message',
  contains('Call rolloverSession first'),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ReadingSessionDatabase database;
  late ReadingPlanService planService;
  late ReadingSessionService sessionService;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    getIt.registerSingleton(await createTestUserSettings());
    getIt.registerSingleton(createTestBibleNavigation());
    database = ReadingSessionDatabase.inMemory();
    await database.init();
    getIt.registerSingleton<ReadingSessionDatabase>(database);
    planService = ReadingPlanService();
    sessionService = ReadingSessionService();
  });

  tearDown(() async {
    database.dispose();
    await getIt.reset();
  });

  DateTime dayOnly(DateTime date) => DateTime(date.year, date.month, date.day);

  Future<int> createPlan({
    String name = 'Test Plan',
    GoalType goalType = GoalType.verses,
    int goalValue = 5,
    List<int> bookIds = const [63],
  }) {
    return planService.saveReadingPlan(
      planName: name,
      goalType: goalType,
      goalValue: goalValue,
      bookIds: bookIds,
    );
  }

  Future<Session> insertSession({
    required int planId,
    required DateTime start,
    int readSeconds = 0,
    int verses = 0,
    bool isManual = false,
  }) {
    return database.session.commit(
      Session(
        rsDate: dayOnly(start),
        startTime: start,
        endTime: start.add(Duration(seconds: readSeconds)),
        readSeconds: readSeconds,
        verses: verses,
        readingPlanId: planId,
        isManual: isManual,
      ),
    );
  }

  Future<SessionLogEntry> insertLog(
    Session session, {
    int bookId = 63,
    int chapter = 1,
    int verse = 1,
    DateTime? at,
  }) async {
    final id = await database.sessionLog.append(
      SessionLogEntry(
        sessionId: session.id!,
        readingPlanId: session.readingPlanId,
        bookId: bookId,
        chapter: chapter,
        verse: verse,
        dateTime: at ?? session.startTime,
      ),
    );
    return (await database.sessionLog.listForSession(
      session.id!,
    )).singleWhere((entry) => entry.id == id);
  }

  Future<Map<int, _BookStatsSnapshot>> bookStats(int planId) async {
    final stats = await database.verseState.getBookStats(planId);
    return {
      for (final entry in stats.entries) entry.key: _snapshotOf(entry.value),
    };
  }

  group('startSession', () {
    test('creates an open session with zeroed totals for today', () async {
      final planId = await createPlan(bookIds: [63, 64]);
      final statsBefore = await bookStats(planId);

      final before = DateTime.now();
      final sessionId = (await sessionService.startSession(planId))!;
      final after = DateTime.now();

      final saved = (await database.session.getById(sessionId))!;
      expect(saved.startTime.isBefore(before), isFalse);
      expect(saved.startTime.isAfter(after), isFalse);
      expect(saved.endTime, saved.startTime);
      final day = dayOnly(saved.startTime);
      expect(
        saved,
        Session(
          id: sessionId,
          rsDate: day,
          startTime: saved.startTime,
          endTime: saved.startTime,
          readSeconds: 0,
          verses: 0,
          readingPlanId: planId,
          isManual: false,
        ),
      );

      expect(await database.sessionLog.listForSession(sessionId), isEmpty);
      expect(await database.daySummary.get(planId, day), isNull);
      expect(await bookStats(planId), statsBefore);
    });

    test('throws for a missing plan', () async {
      final sessionsBefore = await database.session.exportAll();
      final summariesBefore = await database.daySummary.exportAll();

      await expectLater(
        sessionService.startSession(99999),
        throwsA(_notFoundError('Reading plan not found: 99999')),
      );

      expect(await database.session.exportAll(), sessionsBefore);
      expect(await database.daySummary.exportAll(), summariesBefore);
    });
  });

  group('endSession', () {
    test('closes the session and writes the day summary', () async {
      final planId = await createPlan();
      final day = dayOnly(DateTime.now());
      final session = await insertSession(
        planId: planId,
        start: day.add(const Duration(hours: 9)),
      );
      final before = (await database.session.getById(session.id!))!;
      final at = day.add(const Duration(hours: 9, minutes: 5));
      final statsBefore = await bookStats(planId);

      await sessionService.endSession(session.id!, readSeconds: 300, at: at);

      expect(
        await database.session.getById(session.id!),
        before.copyWith(endTime: at, readSeconds: 300),
      );
      expect(
        await database.daySummary.get(planId, day),
        DaySummary(
          readingPlanId: planId,
          rsDate: day,
          rsSeconds: 300,
          rsVerses: 0,
          goalType: GoalType.verses,
          goalValue: 5,
          goalReached: false,
        ),
      );
      expect(await database.sessionLog.listForSession(session.id!), isEmpty);
      expect(await bookStats(planId), statsBefore);
    });

    test('keeps the larger read time and totals every session', () async {
      final planId = await createPlan();
      final day = dayOnly(DateTime.now());
      final first = await insertSession(
        planId: planId,
        start: day.add(const Duration(hours: 9)),
        readSeconds: 300,
        verses: 2,
      );
      final second = await insertSession(
        planId: planId,
        start: day.add(const Duration(hours: 10)),
        readSeconds: 60,
        verses: 1,
      );
      final firstBefore = (await database.session.getById(first.id!))!;
      final secondBefore = (await database.session.getById(second.id!))!;
      final at = day.add(const Duration(hours: 9, minutes: 30));

      await sessionService.endSession(first.id!, readSeconds: 120, at: at);

      expect(
        await database.session.getById(first.id!),
        firstBefore.copyWith(endTime: at, readSeconds: 300),
      );
      expect(await database.session.getById(second.id!), secondBefore);
      expect(
        await database.daySummary.get(planId, day),
        DaySummary(
          readingPlanId: planId,
          rsDate: day,
          rsSeconds: 360,
          rsVerses: 3,
          goalType: GoalType.verses,
          goalValue: 5,
          goalReached: false,
        ),
      );
    });

    test('throws for a missing session', () async {
      final sessionsBefore = await database.session.exportAll();
      final summariesBefore = await database.daySummary.exportAll();

      await expectLater(
        sessionService.endSession(999999, readSeconds: 60),
        throwsA(_notFoundError('Reading session not found: 999999')),
      );

      expect(await database.session.exportAll(), sessionsBefore);
      expect(await database.daySummary.exportAll(), summariesBefore);
    });

    test('throws for a stale session without changing it', () async {
      final planId = await createPlan();
      final today = dayOnly(DateTime.now());
      final yesterday = today.subtract(const Duration(days: 1));
      final session = await insertSession(
        planId: planId,
        start: yesterday.add(const Duration(hours: 9)),
        readSeconds: 300,
      );
      final before = (await database.session.getById(session.id!))!;

      await expectLater(
        sessionService.endSession(
          session.id!,
          readSeconds: 600,
          at: today.add(const Duration(hours: 9)),
        ),
        throwsA(_staleSessionError()),
      );

      expect(await database.session.getById(session.id!), before);
      expect(await database.daySummary.get(planId, yesterday), isNull);
    });
  });

  group('setVerseRead', () {
    test(
      'marks a verse and updates the session, log, state, and summary',
      () async {
        final planId = await createPlan();
        final day = dayOnly(DateTime.now());
        final session = await insertSession(
          planId: planId,
          start: day.add(const Duration(hours: 9)),
        );
        final before = (await database.session.getById(session.id!))!;
        final at = day.add(const Duration(hours: 9, minutes: 1));

        final result = await sessionService.setVerseRead(
          session.id!,
          bookId: 63,
          chapter: 1,
          verse: 1,
          read: true,
          at: at,
        );

        expect(result, isNull);
        expect(
          await database.session.getById(session.id!),
          before.copyWith(verses: 1),
        );

        final logs = await database.sessionLog.listForSession(session.id!);
        expect(logs, [
          SessionLogEntry(
            id: logs.single.id,
            sessionId: session.id!,
            readingPlanId: planId,
            bookId: 63,
            chapter: 1,
            verse: 1,
            dateTime: at,
          ),
        ]);
        expect((await bookStats(planId))[63], (
          totalVerses: 13,
          versesRead: 1,
          lastRead: at,
          resumePosition: const Reference(bookId: 63, chapter: 1, verse: 2),
        ));
        expect(
          await database.daySummary.get(planId, day),
          DaySummary(
            readingPlanId: planId,
            rsDate: day,
            rsSeconds: 0,
            rsVerses: 1,
            goalType: GoalType.verses,
            goalValue: 5,
            goalReached: false,
          ),
        );
      },
    );

    test('ignores a verse already read in this session', () async {
      final planId = await createPlan();
      final day = dayOnly(DateTime.now());
      final session = await insertSession(
        planId: planId,
        start: day.add(const Duration(hours: 9)),
      );
      final firstAt = day.add(const Duration(hours: 9, minutes: 1));
      final secondAt = day.add(const Duration(hours: 9, minutes: 2));

      await sessionService.setVerseRead(
        session.id!,
        bookId: 63,
        chapter: 1,
        verse: 1,
        read: true,
        at: firstAt,
      );
      final sessionAfterFirst = (await database.session.getById(session.id!))!;
      final logsAfterFirst = await database.sessionLog.listForSession(
        session.id!,
      );
      final statsAfterFirst = await bookStats(planId);
      final summaryAfterFirst = await database.daySummary.get(planId, day);

      // A later timestamp must not update session timing; extendSession/
      // endSession own that.
      final result = await sessionService.setVerseRead(
        session.id!,
        bookId: 63,
        chapter: 1,
        verse: 1,
        read: true,
        at: secondAt,
      );

      expect(result, isNull);
      expect(await database.session.getById(session.id!), sessionAfterFirst);
      expect(
        await database.sessionLog.listForSession(session.id!),
        logsAfterFirst,
      );
      expect(await bookStats(planId), statsAfterFirst);
      expect(await database.daySummary.get(planId, day), summaryAfterFirst);
    });

    test('unmarks a verse only for the current session', () async {
      final planId = await createPlan();
      final day = dayOnly(DateTime.now());
      final first = await insertSession(
        planId: planId,
        start: day.add(const Duration(hours: 9)),
      );
      final second = await insertSession(
        planId: planId,
        start: day.add(const Duration(hours: 10)),
      );
      final firstAt = day.add(const Duration(hours: 9, minutes: 1));
      final secondAt = day.add(const Duration(hours: 10, minutes: 1));
      final unmarkAt = day.add(const Duration(hours: 10, minutes: 2));

      await sessionService.setVerseRead(
        first.id!,
        bookId: 63,
        chapter: 1,
        verse: 1,
        read: true,
        at: firstAt,
      );
      await sessionService.setVerseRead(
        second.id!,
        bookId: 63,
        chapter: 1,
        verse: 1,
        read: true,
        at: secondAt,
      );
      final secondBeforeUnmark = (await database.session.getById(second.id!))!;
      final firstLogs = await database.sessionLog.listForSession(first.id!);

      final result = await sessionService.setVerseRead(
        second.id!,
        bookId: 63,
        chapter: 1,
        verse: 1,
        read: false,
        at: unmarkAt,
      );

      expect(result, isNull);
      expect(
        await database.session.getById(second.id!),
        secondBeforeUnmark.copyWith(verses: 0),
      );
      expect(await database.sessionLog.listForSession(first.id!), firstLogs);
      expect(await database.sessionLog.listForSession(second.id!), isEmpty);
      expect(await database.verseState.getReadCount(planId, 63, 1, 1), 1);
      expect((await bookStats(planId))[63], (
        totalVerses: 13,
        versesRead: 1,
        lastRead: secondAt,
        resumePosition: const Reference(bookId: 63, chapter: 1, verse: 2),
      ));
      expect(
        await database.daySummary.get(planId, day),
        DaySummary(
          readingPlanId: planId,
          rsDate: day,
          rsSeconds: 0,
          rsVerses: 1,
          goalType: GoalType.verses,
          goalValue: 5,
          goalReached: false,
        ),
      );
    });

    test('leaves records unchanged when unmarking a verse not marked this '
        'session', () async {
      final planId = await createPlan();
      final day = dayOnly(DateTime.now());
      final first = await insertSession(
        planId: planId,
        start: day.add(const Duration(hours: 9)),
      );
      final second = await insertSession(
        planId: planId,
        start: day.add(const Duration(hours: 10)),
      );
      final firstAt = day.add(const Duration(hours: 9, minutes: 1));
      final unmarkAt = day.add(const Duration(hours: 10, minutes: 1));

      await sessionService.setVerseRead(
        first.id!,
        bookId: 63,
        chapter: 1,
        verse: 1,
        read: true,
        at: firstAt,
      );
      final secondBefore = (await database.session.getById(second.id!))!;
      final logsBefore = await database.sessionLog.listForSession(second.id!);
      final statsBefore = await bookStats(planId);
      final summaryBefore = await database.daySummary.get(planId, day);

      final result = await sessionService.setVerseRead(
        second.id!,
        bookId: 63,
        chapter: 1,
        verse: 1,
        read: false,
        at: unmarkAt,
      );

      expect(result, isNull);
      expect(await database.session.getById(second.id!), secondBefore);
      expect(await database.sessionLog.listForSession(second.id!), logsBefore);
      expect(await bookStats(planId), statsBefore);
      expect(await database.daySummary.get(planId, day), summaryBefore);
    });

    test('ignores a book that is not part of the plan', () async {
      final planId = await createPlan();
      final day = dayOnly(DateTime.now());
      final session = await insertSession(
        planId: planId,
        start: day.add(const Duration(hours: 9)),
      );
      final before = (await database.session.getById(session.id!))!;
      final statsBefore = await bookStats(planId);

      final result = await sessionService.setVerseRead(
        session.id!,
        bookId: 64,
        chapter: 1,
        verse: 1,
        read: true,
        at: day.add(const Duration(hours: 9, minutes: 1)),
      );

      expect(result, isNull);
      expect(await database.session.getById(session.id!), before);
      expect(await database.sessionLog.listForSession(session.id!), isEmpty);
      expect(await database.verseState.getReadCount(planId, 64, 1, 1), isNull);
      expect(await bookStats(planId), statsBefore);
      expect(await database.daySummary.get(planId, day), isNull);
    });

    test(
      'reports completion of a book with the next resume position',
      () async {
        final planId = await createPlan(bookIds: [63, 64]);
        final day = dayOnly(DateTime.now());
        final session = await insertSession(
          planId: planId,
          start: day.add(const Duration(hours: 9)),
        );
        final before = (await database.session.getById(session.id!))!;
        final at = day.add(const Duration(hours: 9, minutes: 30));

        BookCompletedEvent? result;
        for (var verse = 1; verse <= 13; verse++) {
          result = await sessionService.setVerseRead(
            session.id!,
            bookId: 63,
            chapter: 1,
            verse: verse,
            read: true,
            at: at,
          );
        }

        final event = result!;
        expect(event.completedBookId, 63);
        expect(event.nextBookId, 64);
        expect(
          event.resumePosition,
          const Reference(bookId: 64, chapter: 1, verse: 1),
        );

        expect(
          await database.session.getById(session.id!),
          before.copyWith(verses: 13),
        );
        final logs = await database.sessionLog.listForSession(session.id!);
        expect(logs, [
          for (var i = 0; i < logs.length; i++)
            SessionLogEntry(
              id: logs[i].id,
              sessionId: session.id!,
              readingPlanId: planId,
              bookId: 63,
              chapter: 1,
              verse: i + 1,
              dateTime: at,
            ),
        ]);
        final stats = await bookStats(planId);
        expect(stats[63], (
          totalVerses: 13,
          versesRead: 13,
          lastRead: at,
          resumePosition: null,
        ));
        expect(stats[64], (
          totalVerses: 15,
          versesRead: 0,
          lastRead: null,
          resumePosition: const Reference(bookId: 64, chapter: 1, verse: 1),
        ));
        expect(
          await database.daySummary.get(planId, day),
          DaySummary(
            readingPlanId: planId,
            rsDate: day,
            rsSeconds: 0,
            rsVerses: 13,
            goalType: GoalType.verses,
            goalValue: 5,
            goalReached: true,
          ),
        );
      },
    );

    test(
      'reports completion of the final book without a next position',
      () async {
        final planId = await createPlan();
        final day = dayOnly(DateTime.now());
        final session = await insertSession(
          planId: planId,
          start: day.add(const Duration(hours: 9)),
        );
        final at = day.add(const Duration(hours: 9, minutes: 30));

        BookCompletedEvent? result;
        for (var verse = 1; verse <= 13; verse++) {
          result = await sessionService.setVerseRead(
            session.id!,
            bookId: 63,
            chapter: 1,
            verse: verse,
            read: true,
            at: at,
          );
        }

        final event = result!;
        expect(event.completedBookId, 63);
        expect(event.nextBookId, isNull);
        expect(event.resumePosition, isNull);
      },
    );

    test('throws for a missing session', () async {
      final sessionsBefore = await database.session.exportAll();

      await expectLater(
        sessionService.setVerseRead(
          999999,
          bookId: 63,
          chapter: 1,
          verse: 1,
          read: true,
        ),
        throwsA(_notFoundError('Reading session not found: 999999')),
      );

      expect(await database.session.exportAll(), sessionsBefore);
    });

    test('throws for a stale session without changing it', () async {
      final planId = await createPlan();
      final today = dayOnly(DateTime.now());
      final yesterday = today.subtract(const Duration(days: 1));
      final session = await insertSession(
        planId: planId,
        start: yesterday.add(const Duration(hours: 9)),
      );
      final before = (await database.session.getById(session.id!))!;

      await expectLater(
        sessionService.setVerseRead(
          session.id!,
          bookId: 63,
          chapter: 1,
          verse: 1,
          read: true,
          at: today.add(const Duration(hours: 9)),
        ),
        throwsA(_staleSessionError()),
      );

      expect(await database.session.getById(session.id!), before);
      expect(await database.sessionLog.listForSession(session.id!), isEmpty);
    });
  });

  group('extendSession', () {
    test('extends the session and refreshes the day summary', () async {
      final planId = await createPlan();
      final day = dayOnly(DateTime.now());
      final session = await insertSession(
        planId: planId,
        start: day.add(const Duration(hours: 9)),
        readSeconds: 120,
        verses: 2,
      );
      final before = (await database.session.getById(session.id!))!;
      final firstAt = day.add(const Duration(hours: 9, minutes: 5));
      final secondAt = day.add(const Duration(hours: 9, minutes: 10));
      final statsBefore = await bookStats(planId);

      await sessionService.extendSession(
        session.id!,
        readSeconds: 300,
        at: firstAt,
      );

      expect(
        await database.session.getById(session.id!),
        before.copyWith(endTime: firstAt, readSeconds: 300),
      );
      expect(
        await database.daySummary.get(planId, day),
        DaySummary(
          readingPlanId: planId,
          rsDate: day,
          rsSeconds: 300,
          rsVerses: 2,
          goalType: GoalType.verses,
          goalValue: 5,
          goalReached: false,
        ),
      );

      await sessionService.extendSession(
        session.id!,
        readSeconds: 200,
        at: secondAt,
      );

      expect(
        await database.session.getById(session.id!),
        before.copyWith(endTime: secondAt, readSeconds: 300),
      );
      expect(
        await database.daySummary.get(planId, day),
        DaySummary(
          readingPlanId: planId,
          rsDate: day,
          rsSeconds: 300,
          rsVerses: 2,
          goalType: GoalType.verses,
          goalValue: 5,
          goalReached: false,
        ),
      );
      expect(await database.sessionLog.listForSession(session.id!), isEmpty);
      expect(await bookStats(planId), statsBefore);
    });

    test('throws for a missing session', () async {
      final sessionsBefore = await database.session.exportAll();

      await expectLater(
        sessionService.extendSession(999999, readSeconds: 60),
        throwsA(_notFoundError('Reading session not found: 999999')),
      );

      expect(await database.session.exportAll(), sessionsBefore);
    });

    test('throws for a stale session without changing it', () async {
      final planId = await createPlan();
      final today = dayOnly(DateTime.now());
      final yesterday = today.subtract(const Duration(days: 1));
      final session = await insertSession(
        planId: planId,
        start: yesterday.add(const Duration(hours: 9)),
        readSeconds: 120,
      );
      final before = (await database.session.getById(session.id!))!;

      await expectLater(
        sessionService.extendSession(
          session.id!,
          readSeconds: 300,
          at: today.add(const Duration(hours: 9)),
        ),
        throwsA(_staleSessionError()),
      );

      expect(await database.session.getById(session.id!), before);
      expect(await database.daySummary.get(planId, yesterday), isNull);
    });
  });

  group('rolloverSession', () {
    test('closes the old day and opens the new day session', () async {
      final planId = await createPlan();
      final today = dayOnly(DateTime.now());
      final oldDay = today.subtract(const Duration(days: 1));
      final start = oldDay.add(const Duration(hours: 9));
      final old = await insertSession(
        planId: planId,
        start: start,
        readSeconds: 300,
        verses: 2,
      );
      final logAt = start.add(const Duration(minutes: 1));
      final oldLog = await insertLog(old, at: logAt);
      await database.verseState.markRead(planId, 63, 1, 1, timestamp: logAt);
      await database.daySummary.upsert(planId, oldDay);
      final oldBefore = (await database.session.getById(old.id!))!;
      final oldLogs = await database.sessionLog.listForSession(old.id!);
      final statsBefore = await bookStats(planId);
      final at = today.add(const Duration(hours: 8));

      final newSessionId = (await sessionService.rolloverSession(
        old.id!,
        at: at,
        oldReadSeconds: 600,
        newReadSeconds: 120,
      ))!;

      final closedEnd = oldDay.add(const Duration(days: 1, seconds: -1));
      expect(
        await database.session.getById(old.id!),
        oldBefore.copyWith(endTime: closedEnd, readSeconds: 600),
      );
      expect(
        await database.session.getById(newSessionId),
        Session(
          id: newSessionId,
          rsDate: today,
          startTime: today,
          endTime: at,
          readSeconds: 120,
          verses: 0,
          readingPlanId: planId,
          isManual: false,
        ),
      );
      expect(
        await database.daySummary.get(planId, oldDay),
        DaySummary(
          readingPlanId: planId,
          rsDate: oldDay,
          rsSeconds: 600,
          rsVerses: 2,
          goalType: GoalType.verses,
          goalValue: 5,
          goalReached: false,
        ),
      );
      expect(
        await database.daySummary.get(planId, today),
        DaySummary(
          readingPlanId: planId,
          rsDate: today,
          rsSeconds: 120,
          rsVerses: 0,
          goalType: GoalType.verses,
          goalValue: 5,
          goalReached: false,
        ),
      );
      expect(await database.sessionLog.listForSession(old.id!), oldLogs);
      expect(oldLogs, [oldLog]);
      expect(await database.sessionLog.listForSession(newSessionId), isEmpty);
      expect(await bookStats(planId), statsBefore);
    });

    test('handles a session left open across multiple days', () async {
      final planId = await createPlan();
      final today = dayOnly(DateTime.now());
      final oldDay = today.subtract(const Duration(days: 3));
      final old = await insertSession(
        planId: planId,
        start: oldDay.add(const Duration(hours: 9)),
        readSeconds: 300,
        verses: 2,
      );
      await database.daySummary.upsert(planId, oldDay);
      final oldBefore = (await database.session.getById(old.id!))!;
      final at = today.add(const Duration(hours: 8));

      final newSessionId = (await sessionService.rolloverSession(
        old.id!,
        at: at,
        oldReadSeconds: 600,
        newReadSeconds: 120,
      ))!;

      // The old session closes at the end of its own day, not at `at`.
      expect(
        await database.session.getById(old.id!),
        oldBefore.copyWith(
          endTime: oldDay.add(const Duration(days: 1, seconds: -1)),
          readSeconds: 600,
        ),
      );

      // The new session starts at midnight of the rollover day, while its
      // end time is the actual rollover moment.
      expect(
        await database.session.getById(newSessionId),
        Session(
          id: newSessionId,
          rsDate: today,
          startTime: today,
          endTime: at,
          readSeconds: 120,
          verses: 0,
          readingPlanId: planId,
          isManual: false,
        ),
      );

      expect(
        await database.daySummary.get(planId, oldDay),
        DaySummary(
          readingPlanId: planId,
          rsDate: oldDay,
          rsSeconds: 600,
          rsVerses: 2,
          goalType: GoalType.verses,
          goalValue: 5,
          goalReached: false,
        ),
      );
      expect(
        await database.daySummary.get(planId, today),
        DaySummary(
          readingPlanId: planId,
          rsDate: today,
          rsSeconds: 120,
          rsVerses: 0,
          goalType: GoalType.verses,
          goalValue: 5,
          goalReached: false,
        ),
      );

      // The skipped days have no sessions or summaries created for them.
      for (final skippedDay in [
        oldDay.add(const Duration(days: 1)),
        oldDay.add(const Duration(days: 2)),
      ]) {
        expect(await database.session.listForDate(skippedDay, planId), isEmpty);
        expect(await database.daySummary.get(planId, skippedDay), isNull);
      }
    });

    test(
      'preserves the old day goal snapshot and uses the current goal',
      () async {
        final planId = await createPlan();
        final today = dayOnly(DateTime.now());
        final oldDay = today.subtract(const Duration(days: 1));
        final old = await insertSession(
          planId: planId,
          start: oldDay.add(const Duration(hours: 9)),
          readSeconds: 300,
          verses: 2,
        );
        await database.daySummary.upsert(planId, oldDay);

        await planService.saveReadingPlan(
          planId: planId,
          planName: 'Test Plan',
          goalType: GoalType.minutes,
          goalValue: 20,
          bookIds: [63],
        );

        final newSessionId = (await sessionService.rolloverSession(
          old.id!,
          at: today.add(const Duration(hours: 8)),
          oldReadSeconds: 600,
          newReadSeconds: 120,
        ))!;

        expect(
          await database.daySummary.get(planId, oldDay),
          DaySummary(
            readingPlanId: planId,
            rsDate: oldDay,
            rsSeconds: 600,
            rsVerses: 2,
            goalType: GoalType.verses,
            goalValue: 5,
            goalReached: false,
          ),
        );
        expect(
          await database.daySummary.get(planId, today),
          DaySummary(
            readingPlanId: planId,
            rsDate: today,
            rsSeconds: 120,
            rsVerses: 0,
            goalType: GoalType.minutes,
            goalValue: 20,
            goalReached: false,
          ),
        );
        expect(
          await database.session.getById(newSessionId),
          Session(
            id: newSessionId,
            rsDate: today,
            startTime: today,
            endTime: today.add(const Duration(hours: 8)),
            readSeconds: 120,
            verses: 0,
            readingPlanId: planId,
            isManual: false,
          ),
        );
      },
    );

    test('does not create a new day summary when the new session has no read '
        'time', () async {
      final planId = await createPlan();
      final today = dayOnly(DateTime.now());
      final oldDay = today.subtract(const Duration(days: 1));
      final old = await insertSession(
        planId: planId,
        start: oldDay.add(const Duration(hours: 9)),
        readSeconds: 300,
        verses: 2,
      );
      await database.daySummary.upsert(planId, oldDay);

      final newSessionId = (await sessionService.rolloverSession(
        old.id!,
        at: today.add(const Duration(hours: 8)),
        oldReadSeconds: 300,
        newReadSeconds: 0,
      ))!;

      expect((await database.session.getById(newSessionId))!.readSeconds, 0);
      expect(await database.daySummary.get(planId, today), isNull);
      expect(
        await database.daySummary.get(planId, oldDay),
        DaySummary(
          readingPlanId: planId,
          rsDate: oldDay,
          rsSeconds: 300,
          rsVerses: 2,
          goalType: GoalType.verses,
          goalValue: 5,
          goalReached: false,
        ),
      );
    });

    test('rejects rolling over on the same day', () async {
      final planId = await createPlan();
      final day = dayOnly(DateTime.now());
      final session = await insertSession(
        planId: planId,
        start: day.add(const Duration(hours: 9)),
      );
      final before = (await database.session.getById(session.id!))!;

      await expectLater(
        sessionService.rolloverSession(
          session.id!,
          at: day.add(const Duration(hours: 12)),
          oldReadSeconds: 0,
          newReadSeconds: 0,
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('is already on'),
          ),
        ),
      );

      expect(await database.session.getById(session.id!), before);
      expect(await database.daySummary.get(planId, day), isNull);
    });

    test('rejects rolling back to an earlier day', () async {
      final planId = await createPlan();
      final today = dayOnly(DateTime.now());
      final session = await insertSession(
        planId: planId,
        start: today.add(const Duration(hours: 9)),
      );
      final before = (await database.session.getById(session.id!))!;

      await expectLater(
        sessionService.rolloverSession(
          session.id!,
          at: today.subtract(const Duration(days: 1)),
          oldReadSeconds: 0,
          newReadSeconds: 0,
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('Cannot roll session'),
          ),
        ),
      );

      expect(await database.session.getById(session.id!), before);
    });

    test('throws for a missing session', () async {
      final sessionsBefore = await database.session.exportAll();

      await expectLater(
        sessionService.rolloverSession(
          999999,
          at: dayOnly(DateTime.now()),
          oldReadSeconds: 0,
          newReadSeconds: 0,
        ),
        throwsA(_notFoundError('Reading session not found: 999999')),
      );

      expect(await database.session.exportAll(), sessionsBefore);
    });
  });
}
