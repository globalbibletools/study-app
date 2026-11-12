import 'package:flutter_test/flutter_test.dart';
import 'package:gbt/common/bible_navigation.dart';
import 'package:gbt/services/reading_session/reading_plan_service.dart';
import 'package:gbt/services/reading_session/rs_database.dart';
import 'package:gbt/services/reading_session/reading_session_service.dart';
import 'package:gbt/services/reading_session/rs_model.dart';
import 'package:gbt/services/service_locator.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../fixtures/bible_navigation_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ReadingSessionDatabase rsDb;
  late ReadingPlanService planService;
  late ReadingSessionService rsManager;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    if (getIt.isRegistered<ReadingSessionDatabase>()) {
      getIt.unregister<ReadingSessionDatabase>();
    }
    if (getIt.isRegistered<ReadingSessionService>()) {
      getIt.unregister<ReadingSessionService>();
    }
    if (getIt.isRegistered<ReadingPlanService>()) {
      getIt.unregister<ReadingPlanService>();
    }
    if (getIt.isRegistered<BibleNavigation>()) {
      getIt.unregister<BibleNavigation>();
    }

    getIt.registerSingleton<BibleNavigation>(createTestBibleNavigation());

    rsDb = ReadingSessionDatabase(
      databaseName: 'reading_session_kill_resilience_test.db',
      verseInventoryProvider: (bookIds) async =>
          createTestVerseInventory(bookIds: bookIds),
    );
    await rsDb.resetDatabase();
    await rsDb.init();
    getIt.registerSingleton<ReadingSessionDatabase>(rsDb);
    planService = ReadingPlanService.withDatabase(rsDb);
    getIt.registerSingleton<ReadingPlanService>(planService);

    rsManager = ReadingSessionService();
    await rsManager.init();
    getIt.registerSingleton<ReadingSessionService>(rsManager);
  });

  tearDown(() async {
    // resetForDatabaseRestore cancels the timer and clears in-memory state
    // WITHOUT persisting a session close, so tests that simulate a killed
    // app can leave an open session behind without writing to it afterwards.
    await rsManager.resetForDatabaseRestore();
    rsDb.dispose();
  });

  tearDownAll(() async {
    if (getIt.isRegistered<ReadingSessionDatabase>()) {
      getIt.unregister<ReadingSessionDatabase>();
    }
    if (getIt.isRegistered<ReadingSessionService>()) {
      getIt.unregister<ReadingSessionService>();
    }
    if (getIt.isRegistered<ReadingPlanService>()) {
      getIt.unregister<ReadingPlanService>();
    }
    if (getIt.isRegistered<BibleNavigation>()) {
      getIt.unregister<BibleNavigation>();
    }
  });

  Future<ReadingPlanDetails> detailsFor(int planId) async {
    return (await planService.getReadingPlanById(planId))!;
  }

  Future<RsDaySummary> summaryFor(int planId, DateTime date) async {
    final summaries = await rsDb.getDaySummariesBetween(planId, date, date);
    expect(summaries, hasLength(1));
    return summaries.single;
  }

  group('kill-resilient persistence', () {
    test('ending a session without marking verses keeps the session', () async {
      final plan = await planService.saveReadingPlan(
        planName: 'Empty Session Test',
        collectionId: 1,
        goalType: GoalType.verses,
        goalValue: 10,
        selectedBookIds: {63},
      );

      await rsManager.startReadingSession(await detailsFor(plan.id!));
      await Future<void>.delayed(const Duration(seconds: 1));
      await rsManager.endReadingSession();

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final sessions = await rsDb.getSessionsForDate(today, plan.id!);
      expect(sessions, hasLength(1));
      expect(sessions.single.verses, 0);
      expect(sessions.single.endTime, isNotNull);

      final summary = await summaryFor(plan.id!, today);
      expect(summary.rsVerses, 0);
    });

    test(
      'a killed session still carries its marks and heartbeated duration',
      () async {
        final plan = await planService.saveReadingPlan(
          planName: 'Kill Test',
          collectionId: 1,
          goalType: GoalType.verses,
          goalValue: 10,
          selectedBookIds: {63},
        );

        await rsManager.startReadingSession(await detailsFor(plan.id!));
        await rsManager.markVerseAsRead(63, 1, 1);

        // Let real time pass so the heartbeat duration is observable at
        // second granularity.
        await Future<void>.delayed(const Duration(seconds: 2));
        await rsManager.markVerseAsRead(63, 1, 2);
        await rsManager.markVerseAsRead(63, 1, 3);

        // The app is killed here: no endReadingSession, no further writes.
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final killedSessions = await rsDb.getSessionsForDate(today, plan.id!);
        expect(killedSessions, hasLength(1));
        expect(killedSessions.single.verses, 3);
        expect(killedSessions.single.endTime, isNotNull);
        expect(
          killedSessions.single.endTime!.isAfter(
            killedSessions.single.startTime,
          ),
          isTrue,
        );

        final summary = await summaryFor(plan.id!, today);
        expect(summary.rsVerses, 3);
        expect(summary.rsSeconds, greaterThanOrEqualTo(1));

        // A freshly opened service/database sees the same accurate totals.
        final reopened = ReadingSessionService();
        await reopened.init();

        expect(await rsDb.getVersesReadToday(plan.id!, today), 3);
        expect(
          await rsDb.getTotalSecondsReadToday(plan.id!, today),
          greaterThanOrEqualTo(1),
        );
      },
    );

    test(
      'mid-day goal change applies to today (including un-reaching) while past days stay frozen',
      () async {
        final plan = await planService.saveReadingPlan(
          planName: 'Goal Change Test',
          collectionId: 1,
          goalType: GoalType.verses,
          goalValue: 3,
          selectedBookIds: {63},
        );

        // Seed a closed past-day session while the goal is still 3 verses:
        // its summary row freezes flag = 1 with the goal-3 snapshot.
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final yesterday = today.subtract(const Duration(days: 1));
        await rsDb.insertSession(
          RsSession(
            rsDate: yesterday,
            startTime: yesterday.add(const Duration(hours: 9)),
            endTime: yesterday.add(const Duration(hours: 9, minutes: 5)),
            verses: 5,
            readingPlanId: plan.id!,
          ),
        );
        await rsDb.upsertDaySummary(plan.id!, yesterday);
        expect((await summaryFor(plan.id!, yesterday)).goalReached, isTrue);

        // Today: reach the 3-verse goal.
        await rsManager.startReadingSession(await detailsFor(plan.id!));
        for (int v = 1; v <= 3; v++) {
          await rsManager.markVerseAsRead(63, 1, v);
        }
        expect((await summaryFor(plan.id!, today)).goalReached, isTrue);

        // Raise the goal to 10 verses mid-session.
        await planService.saveReadingPlan(
          existingPlanDetails: await detailsFor(plan.id!),
          planName: 'Goal Change Test',
          collectionId: 1,
          goalType: GoalType.verses,
          goalValue: 10,
          selectedBookIds: {63},
        );

        // The next write recomputes today against the new goal: un-reached.
        await rsManager.markVerseAsRead(63, 1, 4);

        final todaysSummary = await summaryFor(plan.id!, today);
        expect(todaysSummary.goalReached, isFalse);
        expect(todaysSummary.goalValue, 10);
        expect(todaysSummary.rsVerses, 4);

        // The past day keeps its flag and its goal snapshot.
        final pastSummary = await summaryFor(plan.id!, yesterday);
        expect(pastSummary.goalReached, isTrue);
        expect(pastSummary.goalValue, 3);
        expect(pastSummary.rsVerses, 5);
      },
    );

    test(
      'idle flush heartbeats the session and refreshes the summary without marks',
      () async {
        final previousThreshold = ReadingSessionService.idleFlushTickCount;
        ReadingSessionService.idleFlushTickCount = 2;
        addTearDown(() {
          ReadingSessionService.idleFlushTickCount = previousThreshold;
        });

        final plan = await planService.saveReadingPlan(
          planName: 'Idle Flush Test',
          collectionId: 1,
          goalType: GoalType.verses,
          goalValue: 10,
          selectedBookIds: {63},
        );

        await rsManager.startReadingSession(await detailsFor(plan.id!));
        await rsManager.markVerseAsRead(63, 1, 1);

        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final endBefore = (await rsDb.getSessionsForDate(
          today,
          plan.id!,
        )).single.endTime;
        final secondsBefore = (await summaryFor(plan.id!, today)).rsSeconds;

        // Let enough 1-second ticks elapse without any verse mark.
        await Future<void>.delayed(const Duration(milliseconds: 3000));

        final endAfter = (await rsDb.getSessionsForDate(
          today,
          plan.id!,
        )).single.endTime;
        final secondsAfter = (await summaryFor(plan.id!, today)).rsSeconds;

        expect(endAfter!.isAfter(endBefore!), isTrue);
        expect(secondsAfter, greaterThan(secondsBefore));
      },
    );

    test("today's calendar cell updates during a live session", () async {
      final plan = await planService.saveReadingPlan(
        planName: 'Live Cell Test',
        collectionId: 1,
        goalType: GoalType.verses,
        goalValue: 5,
        selectedBookIds: {63},
      );

      final now = DateTime.now();
      final month = DateTime(now.year, now.month);

      final before = await planService.getMonthProgress(plan.id!, month);
      expect(before[now.day - 1].empty, isTrue);

      await rsManager.startReadingSession(await detailsFor(plan.id!));
      await rsManager.markVerseAsRead(63, 1, 1);

      final after = await planService.getMonthProgress(plan.id!, month);
      final todayCell = after[now.day - 1];
      expect(todayCell.empty, isFalse);
      expect(todayCell.verses, 1);
      expect(todayCell.goalReached, isFalse);
    });
  });
}
