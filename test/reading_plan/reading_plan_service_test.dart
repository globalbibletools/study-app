import 'package:flutter_test/flutter_test.dart';
import 'package:gbt/common/reference.dart';
import 'package:gbt/reading_plan/data_access/day_summary_repository.dart';
import 'package:gbt/reading_plan/data_access/reading_plan_repository.dart';
import 'package:gbt/reading_plan/data_access/rs_database.dart';
import 'package:gbt/reading_plan/data_access/session_log_repository.dart';
import 'package:gbt/reading_plan/data_access/session_repository.dart';
import 'package:gbt/reading_plan/data_access/verse_state_repository.dart';
import 'package:gbt/reading_plan/model.dart';
import 'package:gbt/reading_plan/reading_plan_service.dart';
import 'package:gbt/services/service_locator.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../fixtures/bible_navigation_fixture.dart';

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ReadingSessionDatabase database;
  late ReadingPlanService planService;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    database = ReadingSessionDatabase(
      databasePath: inMemoryDatabasePath,
      verseInventoryProvider: (bookIds) async =>
          createTestVerseInventory(bookIds: bookIds),
    );
    await database.init();
    getIt.registerSingleton<ReadingSessionDatabase>(database);
    planService = ReadingPlanService();
  });

  tearDown(() async {
    database.dispose();
    await getIt.reset();
  });

  DateTime dayOnly(DateTime date) => DateTime(date.year, date.month, date.day);

  Future<Map<int, _BookStatsSnapshot>> bookStats(int planId) async {
    final stats = await database.verseState.getBookStats(planId);
    return {
      for (final entry in stats.entries) entry.key: _snapshotOf(entry.value),
    };
  }

  Future<void> expectMaterializedWithNoReads(
    int planId,
    List<int> bookIds,
  ) async {
    final stats = await database.verseState.getBookStats(planId);
    expect(stats.keys.toSet(), bookIds.toSet());

    for (final bookId in bookIds) {
      final inventory = createTestVerseInventory(bookIds: {bookId});
      final expectedVerses = inventory.values.fold<int>(
        0,
        (total, verses) => total + verses.length,
      );
      final book = stats[bookId]!;
      expect(book.totalVerses, expectedVerses, reason: 'book $bookId total');
      expect(book.versesRead, 0, reason: 'book $bookId read');
      expect(book.lastRead, isNull, reason: 'book $bookId lastRead');
      expect(
        book.resumePosition,
        Reference(bookId: bookId, chapter: 1, verse: 1),
        reason: 'book $bookId resume',
      );

      for (final entry in inventory.entries) {
        final (_, chapter) = entry.key;
        for (final verse in entry.value) {
          expect(
            await database.verseState.getReadCount(
              planId,
              bookId,
              chapter,
              verse,
            ),
            0,
            reason: 'book $bookId $chapter:$verse',
          );
        }
      }
    }
  }

  Future<Session> insertSession({
    required int planId,
    required DateTime date,
    int hour = 9,
    int readSeconds = 300,
    int verses = 2,
    bool isManual = true,
  }) {
    final day = dayOnly(date);
    final start = DateTime(day.year, day.month, day.day, hour);
    return database.session.commit(
      Session(
        rsDate: day,
        startTime: start,
        endTime: start.add(Duration(seconds: readSeconds)),
        readSeconds: readSeconds,
        verses: verses,
        readingPlanId: planId,
        isManual: isManual,
      ),
    );
  }

  Future<void> insertLog(
    Session session, {
    required int bookId,
    int chapter = 1,
    int verse = 1,
  }) {
    return database.sessionLog.append(
      SessionLogEntry(
        sessionId: session.id!,
        readingPlanId: session.readingPlanId,
        bookId: bookId,
        chapter: chapter,
        verse: verse,
        dateTime: session.startTime,
      ),
    );
  }

  group('saveReadingPlan', () {
    test('creates a plan and materializes verse state', () async {
      final before = DateTime.now();
      final planId = await planService.saveReadingPlan(
        planName: 'Morning Reading',
        goalType: GoalType.verses,
        goalValue: 20,
        bookIds: [63, 64],
      );
      final after = DateTime.now();

      final fetched = (await database.readingPlans.getById(planId))!;
      expect(fetched.createdAt.isBefore(before), isFalse);
      expect(fetched.createdAt.isAfter(after), isFalse);
      expect(
        fetched,
        ReadingPlan(
          id: planId,
          planName: 'Morning Reading',
          createdAt: fetched.createdAt,
          goalType: GoalType.verses,
          goalValue: 20,
          isBookmarked: false,
          bookIds: [63, 64],
        ),
      );

      await expectMaterializedWithNoReads(planId, [63, 64]);
    });

    test(
      'updates an existing plan, preserving id, createdAt, and bookmark',
      () async {
        final planId = await planService.saveReadingPlan(
          planName: 'Original',
          goalType: GoalType.verses,
          goalValue: 10,
          bookIds: [63],
        );
        await planService.setReadingPlanBookmark(planId, true);
        await database.verseState.markRead(
          planId,
          63,
          1,
          1,
          timestamp: DateTime(2026, 11, 1, 9),
        );

        final before = (await database.readingPlans.getById(planId))!;
        final book63Before = (await bookStats(planId))[63]!;
        expect(book63Before.versesRead, 1);
        expect(
          book63Before.resumePosition,
          const Reference(bookId: 63, chapter: 1, verse: 2),
        );

        final savedId = await planService.saveReadingPlan(
          planId: planId,
          planName: 'Renamed',
          goalType: GoalType.minutes,
          goalValue: 5,
          bookIds: [63, 64],
        );

        expect(savedId, planId);
        expect(
          await database.readingPlans.getById(planId),
          before.copyWith(
            planName: 'Renamed',
            goalType: GoalType.minutes,
            goalValue: 5,
            bookIds: [63, 64],
          ),
        );
        expect((await bookStats(planId))[63], book63Before);
      },
    );

    test(
      'materializes verse state for books added to an existing plan',
      () async {
        final planId = await planService.saveReadingPlan(
          planName: 'Growing Plan',
          goalType: GoalType.verses,
          goalValue: 10,
          bookIds: [63],
        );

        final before = await bookStats(planId);
        expect(before.keys.toSet(), {63});
        expect(before.containsKey(64), isFalse);
        final book63Before = before[63]!;

        await planService.saveReadingPlan(
          planId: planId,
          planName: 'Growing Plan',
          goalType: GoalType.verses,
          goalValue: 10,
          bookIds: [63, 64],
        );

        final after = await bookStats(planId);
        expect(after.keys.toSet(), {63, 64});
        expect(after[63], book63Before);
        expect(after[64], (
          totalVerses: 15,
          versesRead: 0,
          lastRead: null,
          resumePosition: const Reference(bookId: 64, chapter: 1, verse: 1),
        ));

        final inventory = createTestVerseInventory(bookIds: {64});
        for (final entry in inventory.entries) {
          final (_, chapter) = entry.key;
          for (final verse in entry.value) {
            expect(
              await database.verseState.getReadCount(
                planId,
                64,
                chapter,
                verse,
              ),
              0,
              reason: 'book 64 $chapter:$verse',
            );
          }
        }
      },
    );

    test('rolls back when book ids are duplicated', () async {
      final planId = await planService.saveReadingPlan(
        planName: 'Stable',
        goalType: GoalType.verses,
        goalValue: 10,
        bookIds: [63],
      );
      final plansBefore = await database.readingPlans.list();

      await expectLater(
        planService.saveReadingPlan(
          planId: planId,
          planName: 'Broken',
          goalType: GoalType.minutes,
          goalValue: 1,
          bookIds: [64, 64],
        ),
        throwsA(isA<DatabaseException>()),
      );

      expect(await database.readingPlans.list(), plansBefore);
    });

    test('throws for a missing plan id', () async {
      final plansBefore = await database.readingPlans.list();

      await expectLater(
        planService.saveReadingPlan(
          planId: 99999,
          planName: 'New From Missing',
          goalType: GoalType.minutes,
          goalValue: 3,
          bookIds: [65],
        ),
        throwsA(_notFoundError('Reading plan not found: 99999')),
      );

      expect(await database.readingPlans.list(), plansBefore);
    });
  });

  group('setReadingPlanBookmark', () {
    test('updates the whole plan record for true and false', () async {
      final planId = await planService.saveReadingPlan(
        planName: 'Bookmark Test',
        goalType: GoalType.verses,
        goalValue: 7,
        bookIds: [63, 64],
      );
      final before = (await database.readingPlans.getById(planId))!;

      await planService.setReadingPlanBookmark(planId, true);
      expect(
        await database.readingPlans.getById(planId),
        before.copyWith(isBookmarked: true),
      );

      await planService.setReadingPlanBookmark(planId, false);
      expect(
        await database.readingPlans.getById(planId),
        before.copyWith(isBookmarked: false),
      );
    });

    test('throws for a missing plan id', () async {
      final plansBefore = await database.readingPlans.list();

      await expectLater(
        planService.setReadingPlanBookmark(99999, true),
        throwsA(_notFoundError('Reading plan not found: 99999')),
      );

      expect(await database.readingPlans.list(), plansBefore);
    });
  });

  group('deleteReadingPlan', () {
    test('removes the plan and all of its dependent rows', () async {
      final planA = await planService.saveReadingPlan(
        planName: 'Plan A',
        goalType: GoalType.verses,
        goalValue: 5,
        bookIds: [63],
      );
      final planB = await planService.saveReadingPlan(
        planName: 'Plan B',
        goalType: GoalType.verses,
        goalValue: 5,
        bookIds: [64],
      );
      final firstDay = DateTime(2026, 11, 20);
      final secondDay = DateTime(2026, 11, 21);

      final aFirst = await insertSession(
        planId: planA,
        date: firstDay,
        hour: 8,
      );
      final aSecond = await insertSession(
        planId: planA,
        date: secondDay,
        hour: 9,
      );
      await database.daySummary.upsert(planA, firstDay);
      await database.daySummary.upsert(planA, secondDay);
      await insertLog(aFirst, bookId: 63, verse: 1);
      await insertLog(aSecond, bookId: 63, verse: 2);
      await database.verseState.markRead(
        planA,
        63,
        1,
        1,
        timestamp: DateTime(2026, 11, 20, 8),
      );

      final bSession = await insertSession(
        planId: planB,
        date: firstDay,
        hour: 10,
      );
      await database.daySummary.upsert(planB, firstDay);
      await insertLog(bSession, bookId: 64);
      await database.verseState.markRead(
        planB,
        64,
        1,
        1,
        timestamp: DateTime(2026, 11, 20, 10),
      );

      final planBBefore = (await database.readingPlans.getById(planB))!;
      final bSessionsBefore = await database.session.listForDate(
        firstDay,
        planB,
      );
      final bSummaryBefore = (await database.daySummary.get(planB, firstDay))!;
      final bStatsBefore = await bookStats(planB);
      final bLogBefore = await database.sessionLog.listForSession(bSession.id!);

      await planService.deleteReadingPlan(planA);

      expect(await database.readingPlans.getById(planA), isNull);
      expect(await database.session.listForDate(firstDay, planA), isEmpty);
      expect(await database.session.listForDate(secondDay, planA), isEmpty);
      expect(await database.session.getById(aFirst.id!), isNull);
      expect(await database.session.getById(aSecond.id!), isNull);
      expect(await database.daySummary.get(planA, firstDay), isNull);
      expect(await database.daySummary.get(planA, secondDay), isNull);
      expect(await database.verseState.getBookStats(planA), isEmpty);
      expect(await database.verseState.getReadCount(planA, 63, 1, 1), isNull);
      expect(await database.sessionLog.listForSession(aFirst.id!), isEmpty);
      expect(await database.sessionLog.listForSession(aSecond.id!), isEmpty);

      expect(await database.readingPlans.getById(planB), planBBefore);
      expect(
        await database.session.listForDate(firstDay, planB),
        bSessionsBefore,
      );
      expect(await database.daySummary.get(planB, firstDay), bSummaryBefore);
      expect(await bookStats(planB), bStatsBefore);
      expect(
        await database.sessionLog.listForSession(bSession.id!),
        bLogBefore,
      );
    });

    test('throws for a missing plan id', () async {
      final plansBefore = await database.readingPlans.list();

      await expectLater(
        planService.deleteReadingPlan(99999),
        throwsA(_notFoundError('Reading plan not found: 99999')),
      );

      expect(await database.readingPlans.list(), plansBefore);
    });
  });

  group('addManualSession', () {
    test('records the session and today\'s day summary', () async {
      final planId = await planService.saveReadingPlan(
        planName: 'Manual Session Test',
        goalType: GoalType.minutes,
        goalValue: 10,
        bookIds: [63],
      );
      final requested = DateTime.now();
      final day = dayOnly(requested);
      final before = requested;

      await planService.addManualSession(
        readingPlanId: planId,
        date: requested,
        minutes: 12.5,
        verses: 8,
      );
      final after = DateTime.now();

      final saved = (await database.session.listForDate(day, planId)).single;
      expect(saved.startTime.isBefore(before), isFalse);
      expect(saved.startTime.isAfter(after), isFalse);
      expect(
        saved,
        Session(
          id: saved.id,
          rsDate: day,
          startTime: saved.startTime,
          endTime: saved.startTime.add(const Duration(seconds: 750)),
          readSeconds: 750,
          verses: 8,
          readingPlanId: planId,
          isManual: true,
        ),
      );

      expect(
        await database.daySummary.get(planId, day),
        DaySummary(
          readingPlanId: planId,
          rsDate: day,
          rsSeconds: 750,
          rsVerses: 8,
          goalType: GoalType.minutes,
          goalValue: 10,
          goalReached: true,
        ),
      );

      expect(await database.sessionLog.listForSession(saved.id!), isEmpty);
      await expectMaterializedWithNoReads(planId, [63]);
    });

    test('preserves a past day\'s stored goal snapshot', () async {
      final planId = await planService.saveReadingPlan(
        planName: 'Past Snapshot Test',
        goalType: GoalType.verses,
        goalValue: 5,
        bookIds: [63],
      );
      final pastDay = dayOnly(
        DateTime.now().subtract(const Duration(days: 30)),
      );

      await planService.addManualSession(
        readingPlanId: planId,
        date: pastDay,
        minutes: 4,
        verses: 4,
      );
      expect(
        await database.daySummary.get(planId, pastDay),
        DaySummary(
          readingPlanId: planId,
          rsDate: pastDay,
          rsSeconds: 240,
          rsVerses: 4,
          goalType: GoalType.verses,
          goalValue: 5,
          goalReached: false,
        ),
      );

      final planBefore = (await database.readingPlans.getById(planId))!;
      final updatedId = await planService.saveReadingPlan(
        planId: planId,
        planName: planBefore.planName,
        goalType: GoalType.minutes,
        goalValue: 20,
        bookIds: planBefore.bookIds,
      );
      expect(updatedId, planId);
      expect(
        await database.readingPlans.getById(planId),
        planBefore.copyWith(goalType: GoalType.minutes, goalValue: 20),
      );

      await planService.addManualSession(
        readingPlanId: planId,
        date: pastDay,
        minutes: 6,
        verses: 2,
      );

      expect(
        await database.daySummary.get(planId, pastDay),
        DaySummary(
          readingPlanId: planId,
          rsDate: pastDay,
          rsSeconds: 600,
          rsVerses: 6,
          goalType: GoalType.verses,
          goalValue: 5,
          goalReached: true,
        ),
      );
      expect(await database.session.listForDate(pastDay, planId), hasLength(2));
    });

    test('rejects invalid input without writing anything', () async {
      final planId = await planService.saveReadingPlan(
        planName: 'Manual Validation Test',
        goalType: GoalType.verses,
        goalValue: 5,
        bookIds: [63],
      );
      final day = dayOnly(DateTime.now());

      final invalidInputs = <(double, int)>[
        (-1, 1),
        (1, -1),
        (0, 0),
        (double.nan, 1),
        (double.infinity, 1),
      ];
      for (final (minutes, verses) in invalidInputs) {
        await expectLater(
          planService.addManualSession(
            readingPlanId: planId,
            date: day,
            minutes: minutes,
            verses: verses,
          ),
          throwsArgumentError,
          reason: 'minutes=$minutes verses=$verses',
        );
      }

      expect(await database.session.listForDate(day, planId), isEmpty);
      expect(await database.daySummary.get(planId, day), isNull);
    });

    test(
      'throws for a missing reading plan without writing anything',
      () async {
        final day = dayOnly(DateTime.now());

        await expectLater(
          planService.addManualSession(
            readingPlanId: 99999,
            date: day,
            minutes: 5,
            verses: 1,
          ),
          throwsA(_notFoundError('Reading plan not found: 99999')),
        );

        expect(await database.session.listForDate(day, 99999), isEmpty);
        expect(await database.daySummary.get(99999, day), isNull);
      },
    );
  });

  group('deleteManualSession', () {
    test('recomputes day summaries and respects goal snapshots', () async {
      final planId = await planService.saveReadingPlan(
        planName: 'Manual Delete Test',
        goalType: GoalType.minutes,
        goalValue: 10,
        bookIds: [63],
      );
      final today = dayOnly(DateTime.now());

      await planService.addManualSession(
        readingPlanId: planId,
        date: today,
        minutes: 6,
        verses: 4,
      );
      final first = (await database.session.listForDate(today, planId)).single;
      await planService.addManualSession(
        readingPlanId: planId,
        date: today,
        minutes: 5,
        verses: 2,
      );
      final second = (await database.session.listForDate(
        today,
        planId,
      )).singleWhere((session) => session.id != first.id);
      final firstBefore = (await database.session.getById(first.id!))!;
      final secondBefore = (await database.session.getById(second.id!))!;

      await planService.deleteManualSession(firstBefore.id!);

      expect(await database.session.getById(firstBefore.id!), isNull);
      expect(await database.session.getById(secondBefore.id!), secondBefore);
      expect(
        await database.daySummary.get(planId, today),
        DaySummary(
          readingPlanId: planId,
          rsDate: today,
          rsSeconds: secondBefore.readSeconds,
          rsVerses: secondBefore.verses,
          goalType: GoalType.minutes,
          goalValue: 10,
          goalReached: secondBefore.readSeconds >= 10 * 60,
        ),
      );

      await planService.deleteManualSession(secondBefore.id!);

      expect(await database.session.getById(secondBefore.id!), isNull);
      expect(await database.daySummary.get(planId, today), isNull);
      expect(await database.session.listForDate(today, planId), isEmpty);

      final pastDay = dayOnly(
        DateTime.now().subtract(const Duration(days: 30)),
      );
      await planService.addManualSession(
        readingPlanId: planId,
        date: pastDay,
        minutes: 4,
        verses: 4,
      );
      await planService.addManualSession(
        readingPlanId: planId,
        date: pastDay,
        minutes: 2,
        verses: 1,
      );
      final pastSessions = await database.session.listForDate(pastDay, planId);
      expect(pastSessions, hasLength(2));

      final plan = (await database.readingPlans.getById(planId))!;
      await planService.saveReadingPlan(
        planId: planId,
        planName: plan.planName,
        goalType: GoalType.minutes,
        goalValue: 20,
        bookIds: plan.bookIds,
      );

      final deleted = pastSessions.first;
      final remaining = (await database.session.getById(
        pastSessions.last.id!,
      ))!;
      await planService.deleteManualSession(deleted.id!);

      expect(await database.session.getById(deleted.id!), isNull);
      expect(
        await database.daySummary.get(planId, pastDay),
        DaySummary(
          readingPlanId: planId,
          rsDate: pastDay,
          rsSeconds: remaining.readSeconds,
          rsVerses: remaining.verses,
          goalType: GoalType.minutes,
          goalValue: 10,
          goalReached: remaining.readSeconds >= 10 * 60,
        ),
      );
    });

    test(
      'removes the day summary when the deleted session is the last one',
      () async {
        final planId = await planService.saveReadingPlan(
          planName: 'Last Session Test',
          goalType: GoalType.minutes,
          goalValue: 10,
          bookIds: [63],
        );
        final day = dayOnly(DateTime.now());

        await planService.addManualSession(
          readingPlanId: planId,
          date: day,
          minutes: 5,
          verses: 2,
        );
        final session = (await database.session.listForDate(
          day,
          planId,
        )).single;
        expect(
          await database.daySummary.get(planId, day),
          DaySummary(
            readingPlanId: planId,
            rsDate: day,
            rsSeconds: 300,
            rsVerses: 2,
            goalType: GoalType.minutes,
            goalValue: 10,
            goalReached: false,
          ),
        );

        await planService.deleteManualSession(session.id!);

        expect(await database.session.getById(session.id!), isNull);
        expect(await database.session.listForDate(day, planId), isEmpty);
        expect(await database.daySummary.get(planId, day), isNull);
      },
    );

    test('rejects a non-manual session without changing it', () async {
      final planId = await planService.saveReadingPlan(
        planName: 'Non-Manual Session Test',
        goalType: GoalType.verses,
        goalValue: 5,
        bookIds: [63],
      );
      final session = await insertSession(
        planId: planId,
        date: DateTime(2026, 11, 18),
        isManual: false,
      );
      final before = (await database.session.getById(session.id!))!;

      await expectLater(
        planService.deleteManualSession(session.id!),
        throwsStateError,
      );

      expect(await database.session.getById(session.id!), before);
    });

    test('throws for a missing session without changing anything', () async {
      final planId = await planService.saveReadingPlan(
        planName: 'Missing Session Test',
        goalType: GoalType.minutes,
        goalValue: 10,
        bookIds: [63],
      );
      final pastDay = dayOnly(DateTime.now().subtract(const Duration(days: 7)));
      await planService.addManualSession(
        readingPlanId: planId,
        date: pastDay,
        minutes: 3,
        verses: 2,
      );

      final sessionsBefore = await database.session.listForDate(
        pastDay,
        planId,
      );
      final summaryBefore = await database.daySummary.get(planId, pastDay);

      await expectLater(
        planService.deleteManualSession(999999),
        throwsA(_notFoundError('Session not found: 999999')),
      );

      expect(
        await database.session.listForDate(pastDay, planId),
        sessionsBefore,
      );
      expect(await database.daySummary.get(planId, pastDay), summaryBefore);
    });
  });
}
