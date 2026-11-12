import 'package:flutter_test/flutter_test.dart';
import 'package:gbt/common/bible_navigation.dart';
import 'package:gbt/services/reading_session/reading_plan_service.dart';
import 'package:gbt/services/reading_session/reading_session_service.dart';
import 'package:gbt/services/reading_session/rs_database.dart';
import 'package:gbt/services/reading_session/rs_model.dart';
import 'package:gbt/services/service_locator.dart';
import 'package:gbt/ui/home/reading_plan/reading_session_view_model.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../fixtures/bible_navigation_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ReadingSessionDatabase rsDb;
  late ReadingPlanService planService;
  late ReadingSessionService sessionService;
  late ReadingSessionViewModel viewModel;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
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
    planService = ReadingPlanService.withDatabase(rsDb);
    sessionService = ReadingSessionService.withDatabase(rsDb);
    viewModel = ReadingSessionViewModel.withService(sessionService);
  });

  tearDown(() {
    viewModel.dispose();
    rsDb.dispose();
  });

  tearDownAll(() {
    if (getIt.isRegistered<BibleNavigation>()) {
      getIt.unregister<BibleNavigation>();
    }
  });

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

      await viewModel.startSession(plan.id!);
      await Future<void>.delayed(const Duration(seconds: 1));
      await viewModel.endSession();

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

        await viewModel.startSession(plan.id!);
        await viewModel.markVerseAsRead(63, 1, 1);

        await Future<void>.delayed(const Duration(seconds: 2));
        await viewModel.markVerseAsRead(63, 1, 2);
        await viewModel.markVerseAsRead(63, 1, 3);

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

        await viewModel.startSession(plan.id!);
        for (int v = 1; v <= 3; v++) {
          await viewModel.markVerseAsRead(63, 1, v);
        }
        expect((await summaryFor(plan.id!, today)).goalReached, isTrue);

        await planService.saveReadingPlan(
          existingPlanDetails: await planService.getReadingPlanById(plan.id!),
          planName: 'Goal Change Test',
          collectionId: 1,
          goalType: GoalType.verses,
          goalValue: 10,
          selectedBookIds: {63},
        );

        await viewModel.markVerseAsRead(63, 1, 4);

        final todaysSummary = await summaryFor(plan.id!, today);
        expect(todaysSummary.goalReached, isFalse);
        expect(todaysSummary.goalValue, 10);
        expect(todaysSummary.rsVerses, 4);

        final pastSummary = await summaryFor(plan.id!, yesterday);
        expect(pastSummary.goalReached, isTrue);
        expect(pastSummary.goalValue, 3);
        expect(pastSummary.rsVerses, 5);
      },
    );

    test(
      'idle heartbeat refreshes the session and summary without marks',
      () async {
        final previousInterval = ReadingSessionViewModel.heartbeatInterval;
        ReadingSessionViewModel.heartbeatInterval = const Duration(seconds: 1);
        addTearDown(() {
          ReadingSessionViewModel.heartbeatInterval = previousInterval;
        });

        final plan = await planService.saveReadingPlan(
          planName: 'Idle Flush Test',
          collectionId: 1,
          goalType: GoalType.verses,
          goalValue: 10,
          selectedBookIds: {63},
        );

        await viewModel.startSession(plan.id!);
        await viewModel.markVerseAsRead(63, 1, 1);

        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final endBefore = (await rsDb.getSessionsForDate(
          today,
          plan.id!,
        )).single.endTime;
        final secondsBefore = (await summaryFor(plan.id!, today)).rsSeconds;

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

      await viewModel.startSession(plan.id!);
      await viewModel.markVerseAsRead(63, 1, 1);

      final after = await planService.getMonthProgress(plan.id!, month);
      final todayCell = after[now.day - 1];
      expect(todayCell.empty, isFalse);
      expect(todayCell.verses, 1);
      expect(todayCell.goalReached, isFalse);
    });
  });
}
